org 0x7C00 ; where code will be loaded, support legacy boot, directive
bits 16 ; 16-bit code, backwards-compatibility with 8086 processor, directive

%define ENDL 0x0D, 0x0A ; define newline

; FAT12 header
jmp short start
nop

bdb_oem:                   db 'MSWIN4.1' ; 8 bytes
bdb_bytes_per_sector:      dw 512
bdb_sectors_per_cluster:   db 1
bdb_reserved_sectors:      dw 1
bdb_fat_count:             db 2
bdb_dir_entries_count:     dw 0E0h
bdb_total_sectors:         dw 2880 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type: db 0F0h ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:       dw 9 ; 9 sectors/FAT
bdb_sectors_per_track:     dw 18
bdb_heads:                 dw 2
bdb_hidden_sectors:        dd 0
bdb_large_sector_count:    dd 0

; extended boot record
ebr_drive_number:          db 0 ; 0x00 floppy, useless
                           db 0 ; reserved
ebr_signature:             db 29h
ebr_volume_id:             db 88h, 88h, 88h, 88h ; serial number
ebr_volume_label:          db 'WEIRD OS   ' ; 11 bytes padded string
ebr_system_id:             db 'FAT12   ' ; 8 bytes

; code

start:
    jmp main

; puts --- prints a string to the screen
; params:
; - ds:si points to string

puts:

    ; save registers we will modify
    push si
    push ax

.loop:

    lodsb ; loads next character in al
    or al, al ; sets zero flag if al null
    jz .done ; if zero flag set, finish program

    mov ah, 0x0e ; call 0e interrupt in bios (print char in tty mode)
    mov bh, 0 ; set page number to 0
    int 0x10
    jmp .loop ; do it again

.done:

    pop ax
    pop si
    ret ; program done

main:

    ; setup data segments
    mov ax, 0    ; write a constant to ax since it can write to ds and es
    mov ds, ax
    mov es, ax

    ; setup memory stack
    mov ss, ax
    mov sp, 0x7C00 ; stack grows downwards from where we are loaded in memory    

    ; read something from floppy disk
    ; bios set dl to drive num
    mov [ebr_drive_number], dl
    mov ax, 1 ; 2nd sector from disk (lba = 1)
    mov cl, 1 ; read 1 sector
    mov bx, 0x7E00 ; data after bootloader
    call disk_read

    ; print message
    mov si, msg_hello
    call puts
    
    cli ; disable interrupts to keep halt state
    hlt 

; error handlers

floppy_error:
    
    mov si, msg_read_error
    call puts
    jmp wait_and_reboot

wait_and_reboot:

    mov ah, 0
    int 16h ; wait for keypress
    jmp 0FFFFh:0 ; jump to beginning of bios

.halt:
    cli ; disable interrupts to keep halt state
    hlt

; disk routines

; lba_to_chs --- converts an lba address to a chs address
; params:
; - ax: lba address
; returns:
; - cx [bits 0-5]: sector number
; - cx [bits 6-15]: cylinder
; - dh: head

lba_to_chs:

    push ax
    push dx

    xor dx, dx ; dx = 0
    div word [bdb_sectors_per_track] ; ax = lba / sectors per track
                                     ; dx = lba % sectors per track
    inc dx ; dx = (lba % sectors per track + 1) = sector
    mov cx, dx ; cx = sector

    xor dx, dx ; dx = 0
    div word [bdb_heads] ; ax = (lba / sectors per track) / heads = cylinder
                         ; dx = (lba / sectors per track) % heads = head
    mov dh, dl ; dl = head
    mov ch, al ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah ; put upper 2 bits of cylinder in cl

    pop ax
    mov dl, al ; restore dl
    pop ax
    ret

; disk_read --- reads sectors from a disk
; params:
; - ax: lba address
; - cl: number of sectors to read
; - dl: drive number
; - es:bx memory address to store data

disk_read:

    ; save used registers
    push ax
    push bx
    push cx
    push dx
    push di

    push cx ; save cl for conversion function
    call lba_to_chs ; compute chs
    pop ax ; al = number of sectors to read

    mov ah, 02h
    mov di, 3 ; retry count

.retry:

    pusha ; save registers, bios does weird things to registers
    stc ; set carry flag, some bios don't set it
    int 13h ; carry flag cleared = success
    jnc .done

    ; if read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry

.fail:
    jmp floppy_error ; if attempts all fail

.done:

    popa

    ; restore used registers
    pop ax
    pop bx
    pop cx
    pop dx
    pop di
    ret

; disk_reset --- resets disk controller
; params:
; - dl: drive number

disk_reset:

    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret

msg_hello: db "Hello world!", ENDL, 0 ; initialize string
msg_read_error: db "Error - Floppy Read Failed!", ENDL, 0

times 510-($-$$) db 0 ; fill up program with 510 bytes of padding, for the bios
dw 0AA55h ; signature bytes, directive
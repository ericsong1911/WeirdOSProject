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

    ; print message
    mov si, msg_hello
    call puts

    hlt ; stop CPU execution

.halt:
    jmp .halt ; infinite loop in case processor restarts

msg_hello: db "Hello world!", ENDL, 0 ; initialize string

times 510-($-$$) db 0 ; fill up program with 510 bytes of padding, for the bios
dw 0AA55h ; signature bytes, directive

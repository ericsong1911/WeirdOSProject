org 0x7C00 ; where code will be loaded, support legacy boot, directive
bits 16 ; 16-bit code, backwards-compatibility with 8086 processor, directive

%define ENDL 0x0D, 0x0A ; define newline

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

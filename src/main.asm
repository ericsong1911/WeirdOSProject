org 0x7C00 ; where code will be loaded, support legacy boot, directive
bits 16 ; 16-bit code, backwards-compatibility with 8086 processor, directive

main:
    hlt ; stop CPU execution

.halt:
    jmp .halt ; infinite loop in case processor restarts

times 510-($-$$) db 0 ; fill up program with 510 bytes of padding, for the bios
dw 0AA55h ; signature bytes, directive

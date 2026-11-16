section .data
hextab db "0123456789ABCDEF"
usage db "usage: hexdump <fichier>", 10
usagelen equ $ - usage

section .bss
inbuf resb 65536
outbuf resb 3

section .text
global _start
_start:
        cmp qword [rsp], 2
        jne .error

        mov rax, 2
        mov rdi, [rsp+16]
        xor rsi, rsi
        xor rdx, rdx
        syscall
        test rax, rax
        js .error
        mov r12, rax

.readloop:
        mov rax, 0
        mov rdi, r12
        mov rsi, inbuf
        mov rdx, 65536
        syscall
        test rax, rax
        jle .done
        mov r13, rax

        xor r14, r14
.byteloop:
        cmp r14, r13
        jge .readloop

        movzx rax, byte [inbuf + r14]

        mov rbx, rax
        shr rbx, 4
        mov cl, [hextab + rbx]
        mov [outbuf], cl

        mov rbx, rax
        and rbx, 0x0F
        mov cl, [hextab + rbx]
        mov [outbuf + 1], cl

        mov byte [outbuf + 2], ' '

        mov rax, 1
        mov rdi, 1
        mov rsi, outbuf
        mov rdx, 3
        syscall

        inc r14
        jmp .byteloop

.done:
        mov rax, 3
        mov rdi, r12
        syscall

        mov rax, 60
        xor rdi, rdi
        syscall

.error:
        mov rax, 1
        mov rdi, 2
        mov rsi, usage
        mov rdx, usagelen
        syscall
        mov rax, 60
        mov rdi, 1
        syscall

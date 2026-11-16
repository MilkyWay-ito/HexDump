section .data
hextab db "0123456789ABCDEF"
usage db "usage: ./hexdump <fichier>", 10
usagelen equ $ - usage

section .bss
inbuf resb 65536
outbuf resb 3
offbuf resb 10
asciibuf resb 16

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
        xor r15, r15

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

        mov rbx, r15
        and rbx, 15
        test rbx, rbx
        jnz .skipoffset
        call .print_offset
.skipoffset:
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

        movzx rax, byte [inbuf + r14]
        cmp al, 0x20
        jb .notprint
        cmp al, 0x7E
        jbe .isprint
.notprint:
        mov al, '.'
.isprint:
        mov rbx, r15
        and rbx, 15
        mov [asciibuf + rbx], al

        inc r15
        mov rbx, r15
        and rbx, 15
        test rbx, rbx
        jnz .nonewline
        mov r8, 16
        call .print_ascii
.nonewline:
        inc r14
        jmp .byteloop

.done:
        mov r8, r15
        and r8, 15
        test r8, r8
        jz .closefile

        mov r9, 16
        sub r9, r8
.padloop:
        mov byte [outbuf], ' '
        mov byte [outbuf + 1], ' '
        mov byte [outbuf + 2], ' '
        mov rax, 1
        mov rdi, 1
        mov rsi, outbuf
        mov rdx, 3
        syscall
        dec r9
        jnz .padloop

        call .print_ascii

.closefile:
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

.print_offset:
        mov r9, r15
        mov rcx, 8
.offloop:
        dec rcx
        mov rbx, r9
        and rbx, 0x0F
        mov al, [hextab + rbx]
        mov [offbuf + rcx], al
        shr r9, 4
        test rcx, rcx
        jnz .offloop

        mov byte [offbuf + 8], ':'
        mov byte [offbuf + 9], ' '
        mov rax, 1
        mov rdi, 1
        mov rsi, offbuf
        mov rdx, 10
        syscall
        ret

.print_ascii:
        mov byte [outbuf], ' '
        mov rax, 1
        mov rdi, 1
        mov rsi, outbuf
        mov rdx, 1
        syscall

        mov rax, 1
        mov rdi, 1
        mov rsi, asciibuf
        mov rdx, r8
        syscall

        mov byte [outbuf], 10
        mov rax, 1
        mov rdi, 1
        mov rsi, outbuf
        mov rdx, 1
        syscall
        ret

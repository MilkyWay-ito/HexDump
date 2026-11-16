section .data
hextab db "0123456789ABCDEF"
usage db "usage: ./hexdump <fichier>", 10
usagelen equ $ - usage
star db "*", 10

colors db 27, "[90m", 27, "[32m", 27, "[33m", 27, "[34m", 27, "[31m"
reset db 27, "[0m"

m_elf64 db "Format : ELF 64-bit", 10
m_elf64_len equ $ - m_elf64
m_elf32 db "Format : ELF 32-bit", 10
m_elf32_len equ $ - m_elf32
m_png db "Format : PNG", 10
m_png_len equ $ - m_png
m_pdf db "Format : PDF", 10
m_pdf_len equ $ - m_pdf
m_zip db "Format : ZIP", 10
m_zip_len equ $ - m_zip
m_gif db "Format : GIF", 10
m_gif_len equ $ - m_gif
m_unknown db "Format : inconnu", 10
m_unknown_len equ $ - m_unknown

pfx db "./hexdump: "
pfxlen equ $ - pfx
e_noent db ": fichier introuvable", 10
e_noent_len equ $ - e_noent
e_acces db ": permission refusée", 10
e_acces_len equ $ - e_acces
e_isdir db ": c'est un dossier", 10
e_isdir_len equ $ - e_isdir
e_open db ": impossible d'ouvrir le fichier", 10
e_open_len equ $ - e_open
e_read db ": erreur de lecture", 10
e_read_len equ $ - e_read

section .bss
inbuf resb 65536
outbuf resb 8
offbuf resb 10
asciibuf resb 16
asciicol resb 16
asciiout resb 128
termios resb 64
curline resb 16
prevline resb 16
haveprev resb 1
starflag resb 1

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
        js .openerror
        mov r12, rax
        xor r15, r15

        mov rax, 16
        mov rdi, 1
        mov rsi, 0x5401
        mov rdx, termios
        syscall
        xor rbp, rbp
        test rax, rax
        jnz .readloop
        mov rbp, 1

.readloop:
        mov rax, 0
        mov rdi, r12
        mov rsi, inbuf
        mov rdx, 65536
        syscall
        test rax, rax
        jz .done
        js .readerror
        mov r13, rax

        test r15, r15
        jnz .skipmagic
        call .detect_magic
.skipmagic:
        xor r14, r14
.byteloop:
        cmp r14, r13
        jge .readloop

        mov rbx, r15
        and rbx, 15
        mov al, [inbuf + r14]
        mov [curline + rbx], al

        inc r15
        mov rbx, r15
        and rbx, 15
        test rbx, rbx
        jnz .nextbyte
        mov r8, 16
        call .emit_line
.nextbyte:
        inc r14
        jmp .byteloop

.done:
        mov r8, r15
        and r8, 15
        test r8, r8
        jz .checkstar
        call .emit_line
        jmp .closefile

.checkstar:
        cmp byte [starflag], 0
        je .closefile
        mov r9, r15
        call .fill_offset
        mov byte [offbuf + 8], 10
        mov rax, 1
        mov rdi, 1
        mov rsi, offbuf
        mov rdx, 9
        syscall

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

.openerror:
        neg rax
        mov rsi, e_open
        mov rdx, e_open_len
        cmp rax, 2
        jne .oe_acces
        mov rsi, e_noent
        mov rdx, e_noent_len
        jmp .syserr
.oe_acces:
        cmp rax, 13
        jne .syserr
        mov rsi, e_acces
        mov rdx, e_acces_len
        jmp .syserr

.readerror:
        neg rax
        mov rsi, e_read
        mov rdx, e_read_len
        cmp rax, 21
        jne .syserr
        mov rsi, e_isdir
        mov rdx, e_isdir_len

.syserr:
        mov r14, rsi
        mov r13, rdx

        mov rax, 1
        mov rdi, 2
        mov rsi, pfx
        mov rdx, pfxlen
        syscall

        mov rsi, [rsp+16]
        xor rdx, rdx
.slen:
        cmp byte [rsi + rdx], 0
        je .slend
        inc rdx
        jmp .slen
.slend:
        mov rax, 1
        mov rdi, 2
        syscall

        mov rax, 1
        mov rdi, 2
        mov rsi, r14
        mov rdx, r13
        syscall

        mov rax, 60
        mov rdi, 1
        syscall

.emit_line:
        cmp r8, 16
        jne .emit_print
        cmp byte [haveprev], 0
        je .emit_print
        mov rax, [curline]
        cmp rax, [prevline]
        jne .emit_print
        mov rax, [curline + 8]
        cmp rax, [prevline + 8]
        jne .emit_print

        cmp byte [starflag], 0
        jne .emit_ret
        mov byte [starflag], 1
        mov rax, 1
        mov rdi, 1
        mov rsi, star
        mov rdx, 2
        syscall
.emit_ret:
        ret

.emit_print:
        mov byte [starflag], 0
        mov r9, r15
        sub r9, r8
        call .print_offset

        xor r10, r10
.emit_byte:
        cmp r10, r8
        jge .emit_pad

        movzx rax, byte [curline + r10]
        call .classify
        mov [asciicol + r10], cl

        lea rdx, [rcx + rcx*4]
        mov r9d, [colors + rdx]
        mov [outbuf], r9d
        mov r9b, [colors + rdx + 4]
        mov [outbuf + 4], r9b

        mov rbx, rax
        shr rbx, 4
        mov r9b, [hextab + rbx]
        mov [outbuf + 5], r9b

        mov rbx, rax
        and rbx, 0x0F
        mov r9b, [hextab + rbx]
        mov [outbuf + 6], r9b

        mov byte [outbuf + 7], ' '

        cmp al, 0x20
        jb .emit_dot
        cmp al, 0x7E
        jbe .emit_char
.emit_dot:
        mov al, '.'
.emit_char:
        mov [asciibuf + r10], al

        mov rax, 1
        mov rdi, 1
        mov rsi, outbuf
        mov rdx, 8
        test rbp, rbp
        jnz .emit_write
        mov rsi, outbuf + 5
        mov rdx, 3
.emit_write:
        syscall

        inc r10
        jmp .emit_byte

.emit_pad:
        cmp r10, 16
        jge .emit_ascii
        mov byte [outbuf], ' '
        mov byte [outbuf + 1], ' '
        mov byte [outbuf + 2], ' '
        mov rax, 1
        mov rdi, 1
        mov rsi, outbuf
        mov rdx, 3
        syscall
        inc r10
        jmp .emit_pad

.emit_ascii:
        call .print_ascii

        mov rax, [curline]
        mov [prevline], rax
        mov rax, [curline + 8]
        mov [prevline + 8], rax
        mov byte [haveprev], 1
        ret

.classify:
        xor ecx, ecx
        test al, al
        jz .clsdone
        mov ecx, 3
        cmp al, 0xFF
        je .clsdone
        mov ecx, 2
        cmp al, 0x09
        je .clsdone
        cmp al, 0x0A
        je .clsdone
        cmp al, 0x0D
        je .clsdone
        mov ecx, 1
        cmp al, 0x20
        jb .clsother
        cmp al, 0x7E
        jbe .clsdone
.clsother:
        mov ecx, 4
.clsdone:
        ret

.detect_magic:
        cmp r13, 4
        jl .fmt_unknown
        cmp dword [inbuf], 0x464C457F
        je .fmt_elf
        cmp dword [inbuf], 0x474E5089
        je .fmt_png
        cmp dword [inbuf], 0x46445025
        je .fmt_pdf
        cmp dword [inbuf], 0x04034B50
        je .fmt_zip
        cmp dword [inbuf], 0x38464947
        je .fmt_gif
.fmt_unknown:
        mov rsi, m_unknown
        mov rdx, m_unknown_len
        jmp .fmt_print
.fmt_elf:
        mov rsi, m_elf64
        mov rdx, m_elf64_len
        cmp r13, 5
        jl .fmt_print
        cmp byte [inbuf + 4], 2
        je .fmt_print
        mov rsi, m_elf32
        mov rdx, m_elf32_len
        jmp .fmt_print
.fmt_png:
        mov rsi, m_png
        mov rdx, m_png_len
        jmp .fmt_print
.fmt_pdf:
        mov rsi, m_pdf
        mov rdx, m_pdf_len
        jmp .fmt_print
.fmt_zip:
        mov rsi, m_zip
        mov rdx, m_zip_len
        jmp .fmt_print
.fmt_gif:
        mov rsi, m_gif
        mov rdx, m_gif_len
.fmt_print:
        mov rax, 1
        mov rdi, 1
        syscall
        ret

.fill_offset:
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
        ret

.print_offset:
        call .fill_offset
        mov byte [offbuf + 8], ':'
        mov byte [offbuf + 9], ' '
        mov rax, 1
        mov rdi, 1
        mov rsi, offbuf
        mov rdx, 10
        syscall
        ret

.print_ascii:
        mov rdi, asciiout
        mov byte [rdi], ' '
        inc rdi
        xor r9, r9
.aloop:
        cmp r9, r8
        jge .aend
        test rbp, rbp
        jz .nocol
        movzx rdx, byte [asciicol + r9]
        lea rdx, [rdx + rdx*4]
        mov r10d, [colors + rdx]
        mov [rdi], r10d
        mov r10b, [colors + rdx + 4]
        mov [rdi + 4], r10b
        add rdi, 5
.nocol:
        mov r10b, [asciibuf + r9]
        mov [rdi], r10b
        inc rdi
        inc r9
        jmp .aloop
.aend:
        test rbp, rbp
        jz .noreset
        mov r10d, [reset]
        mov [rdi], r10d
        add rdi, 4
.noreset:
        mov byte [rdi], 10
        inc rdi
        mov rdx, rdi
        sub rdx, asciiout
        mov rax, 1
        mov rdi, 1
        mov rsi, asciiout
        syscall
        ret

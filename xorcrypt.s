section .data
    data_file db "data.dat", 0x0
    data_file_length equ $ - data_file

    key_file db "key.bin"
    key_file_length equ $ - key_file

    out_file db "data.enc"
    out_file_length equ $ - out_file

    buffer resb 16 

section .text
    global _start
    global main
    global read_file

read_file:
    push rbp
    mov rbp, rsp

    ; Open the file
    mov rax, 0x2                ; open syscall
    lea rdi, [data_file]        ; Pointer to data_file
    mov rsi, 0                  ; O_RDONLY flag set
    syscall

    mov r12, rax                ; Save fd of file in r12
     
    ; Read from the file
    mov rax, 0x0                ; read syscall
    mov rdi, r12                ; Copy fd to rdi
    lea rsi, [buffer]           ; Pointer to buffer to store data
    mov rdx, 0x10               ; Number of bytes to read
    syscall
    
    ; Print buffer
    mov rax, 1  
    mov rdi, 1
    mov rsi, buffer
    mov rdx, 0x10
    syscall

    mov rsp, rbp
    pop rbp
    ret

main:
    push rbp
    mov rbp, rsp

    call read_file

    mov rsp, rbp
    pop rbp
    ret

_start:
    mov rbp, rsp
    
    call main

    ; Exit the program
    ; exit syscall
    mov rax, 60
    mov rdi, 0
    syscall

section .data
    data_file db "data.dat", 0x0
    key_file db "key.bin", 0x0
    out_file db "data.enc", 0x0
    buffer_length db 0x10
    newline db 0xA

section .bss
    buffer resb 16
    padding resb 0x100


section .text
    global _start
    global main
    global fn_load_file
    global fn_error_exit
    global fn_xor_buf
    global fn_dbg_print_buf

; Functions 

fn_dbg_print_buf:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe

    ; Print buffer
    mov rax, 1  
    mov rdi, 1
    lea rsi, [buffer]
    movzx rdx, BYTE [buffer_length]
    syscall

    ; Print newline
    mov rax, 1  
    mov rdi, 1
    lea rsi, [newline]
    mov rdx, 0x1
    syscall

    mov rsp, rbp
    pop rbp
    ret

fn_error_exit:
    mov rax, 0x3c               ; exit syscall
    mov rdi, 0x1                ; Error code

fn_load_file:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe

    ; Open the file
    mov rax, 0x2                ; open syscall
    lea rdi, [data_file]        ; Pointer to data_file
    mov rsi, 0x0                ; O_RDONLY flag set
    syscall

    cmp rax, 0x0                ; Error handling
    jnl lbl_load_file_skip_error    
    call fn_error_exit
    
    lbl_load_file_skip_error:
    mov r12, rax                ; Save fd of file in r12
     
    ; Read from the file
    mov rax, 0x0                ; read syscall
    mov rdi, r12                ; Copy fd to rdi
    lea rsi, [buffer]           ; Pointer to buffer to store data
    mov rdx, buffer_length      ; Number of bytes to read
    syscall
    
    ; Close the fd
    mov rax, 0x3                ; close syscall
    mov rdi, r12                ; Copy fd to rdi
    syscall

    mov rsp, rbp
    pop rbp
    ret

fn_xor_buf:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe
    xor r12, r12

    call fn_dbg_print_buf

    xor rcx, rcx                ; Zero out counter

    lbl_xor_buf_loop:
        lea rsi, [buffer]                   ; Load address to rsi
        add rsi, rcx                        ; Modify offset
        mov al, byte [rsi]                  ; Move byte into al for XOR-ing
        xor al, 0x1                         ; XORs each byte with 0x1
        mov byte [rsi], al                  ; Replace buffer in-place
        inc rcx
        cmp cl, BYTE [buffer_length]
        jne lbl_xor_buf_loop

    call fn_dbg_print_buf

    mov rsp, rbp
    pop rbp
    ret

main:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe

    call fn_load_file

    call fn_xor_buf

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

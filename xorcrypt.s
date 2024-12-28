section .data
    data_file db "data.dat", 0x0

    key_file db "key.bin", 0x0

    out_file db "data.enc", 0x0

    buffer resb 16 

    newline db 0xA

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
    mov rsi, buffer
    mov rdx, 0x10
    syscall

    ; Print newline
    mov rax, 1  
    mov rdi, 1
    mov rsi, newline
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
    mov rdx, 0x10               ; Number of bytes to read
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

    call fn_dbg_print_buf

    mov rcx, 0x10               ; Initialize counter with length of buffer

    lbl_xor_buf_loop:
        lea rsi, [buffer + 0x10]
        sub rsi, rcx
        mov al, byte [rsi]
        xor al, 0x1                 ; XORs each byte with 0x1
        mov byte [rsi], al
        dec rcx
        jnz lbl_xor_buf_loop

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

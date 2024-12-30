section .data
    data_file db "data.dat", 0x0
    key_file db "key.bin", 0x0
    out_file db "data.enc", 0x0
    buf_in_len dq 0x10
    buf_key_len dq 0x10
    buf_out_len dq 0x10
    newline db 0xA

section .bss
    buf_in resb 16
    buf_key resb 16
    buf_out resb 16
    padding resb 0x10


section .text
    global _start
    global main
    global fn_load_file
    global fn_error_exit
    global fn_xor_buf
    global fn_dbg_print_buf_in

; Functions 

fn_dbg_print_buf_out:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe

    ; Print buf_out
    mov rax, 1  
    mov rdi, 1
    lea rsi, [buf_out]
    movzx rdx, BYTE [buf_out_len]
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

fn_dbg_print_buf_in:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe

    ; Print buf_in
    mov rax, 1  
    mov rdi, 1
    lea rsi, [buf_in]
    mov rdx, qword [buf_in_len]
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

; Opens up a file and reads up to buf_in_le bytes into buffer
; Arguments:
; *input_file_name - rdi - address of the null-terminated file name string
; *buffer - rsi - address of the buffer
; buf_in_le - rdx - number of bytes to read
fn_load_file:
    push rbp
    mov rbp, rsp
    sub rsp, 0x18               ; Stackframe
    push rsi                    ; Preserve address of buffer
    push rdx                    ; Preserver number of bytes to read

    ; Open the file
    mov rax, 0x2                ; open syscall
    ; lea rdi, [data_file]      ; Pointer to data_file
    mov rsi, 0x0                ; O_RDONLY flag set
    syscall

    cmp rax, 0x0                ; Error handling
    jnl lbl_load_file_skip_error    
    call fn_error_exit
    
    lbl_load_file_skip_error:
    mov r12, rax                ; Save fd of file in r12
     
    ; Read from the file
    mov rax, 0x0                        ; read syscall
    mov rdi, r12                        ; Copy fd to rdi
    pop rdx                             ; Get rdx from stack
    pop rsi                             ; Get rsi from stack
    ; lea rsi, [buf_in]                 ; Pointer to buf_in to store data
    ; movzx rdx, BYTE [buf_in_len]      ; Number of bytes to read
    syscall

    ; Close the fd
    mov rax, 0x3                        ; close syscall
    mov rdi, r12                        ; Copy fd to rdi
    syscall

    mov rsp, rbp
    pop rbp
    ret

; XORs the buf_in and buf_key and stores it into buf_out
; No arguments needed
fn_xor_buf:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                        ; Stackframe
    xor r12, r12

    call fn_dbg_print_buf_in

    lea rsi, [buf_in]                   ; Load buf_in address in rsi
    lea rdi, [buf_key]                  ; Load buf_key address in rdi
    lea rdx, [buf_out]                  ; Load buf_out address in rdx

    xor rcx, rcx                        ; Zero out counter

    lbl_xor_buf_loop:
        inc rsi                             ; Modify offset
        movzx rax, byte [rsi]               ; Move byte into al for XOR-ing
        
        inc rdi                             ; Modify offset
        movzx r9, byte [rdi]                ; Move byte into r9b for XOR-ing
        xor rax, r9                         ; XORs

        inc rdx                             ; Modify offset
        mov byte [rdx], al                  ; Replace buf_in in-place

        inc rcx
        cmp rcx, qword [buf_in_len]
        jne lbl_xor_buf_loop

    call fn_dbg_print_buf_out

    mov rsp, rbp
    pop rbp
    ret

main:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe

    ; Load buffer from input file
    lea rdi, [data_file]
    lea rsi, [buf_in]
    mov rdx, qword [buf_in_len]
    call fn_load_file

    ; Load buffer from key file
    lea rdi, [key_file]
    lea rsi, [buf_key]
    mov rdx, qword [buf_key_len]
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

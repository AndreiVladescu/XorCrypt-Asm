section .data
    in_file_str db "data.dat", 0x0
    key_file_str db "key.bin", 0x0
    out_file_str db "data.enc", 0x0
    err_msg db "Program exits due to errors", 0x0
    buf_in_len dq 0x10
    buf_key_len dq 0x10
    err_msg_len dq 0x1c
    newline db 0xA

section .bss
    buf_in resb 0x100
    buf_key resb 0x100
    padding resb 0x10
    stat_buf resb 144

section .text
    global _start
    global main
    global fn_load_file
    global fn_error_exit
    global fn_xor_buf
    global fn_stat_file
    global fn_store_data

; Functions

; Debug prints function only
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

; Function to exit
fn_error_exit:
    ; Print error message
    mov rax, 1  
    mov rdi, 1
    lea rsi, [err_msg]
    movzx rdx, byte [err_msg_len]
    syscall

    mov rax, 0x3c               ; exit syscall
    mov rdi, 0x1                ; Error code
    syscall

; Function to store the XORed data into the output file
fn_store_data:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe  

    ; Open the file
    mov rax, 0x2                ; open syscall
    lea rdi, [out_file_str]
    mov rsi, 0x241              ; Flags: O_CREAT (0x40) | O_WRONLY (0x01) | O_TRUNC (0x200)
    mov rdx, 0o644              ; Permissions: rw-r--r--
    syscall

    cmp rax, 0x0                ; Error handling
    jnl lbl_store_data_skip_error
    call fn_error_exit

    lbl_store_data_skip_error:

    mov r12, rax                ; Save fd in r12

    ; Write the modified XORed buffer into the newly opened file
    mov rax, 0x1                ; write syscall
    mov rdi, r12                ; Copy fd to rdi
    lea rsi, [buf_in]           ; Address of the buffer in rsi
    mov rdx, [buf_in_len]       ; Bytes to write
    syscall

    ; Close the fd
    mov rax, 0x3                ; close syscall
    mov rdi, r12                ; Copy fd to rdi
    syscall

    mov rsp, rbp
    pop rbp
    ret

; Function to get the size of a file
; Arguments:
; *input file name - rdi - address of the null-terminated file name string
; *stat_struct - rsi - address of the stat buffer structure 
; Return value:
; rax - Size of file
fn_stat_file:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8

    ; Call 'stat'
    mov rax, 4
    ; Address of file name is already in rdi
    ; Address of the stat buffer is already in rsi 
    syscall

    ; Check for errors
    cmp rax, 0
    jl fn_error_exit

    ; Load file size from the stat_buf
    mov rax, qword [stat_buf + 0x30]     ; Offset of `st_size` in stat structure

    mov rsp, rbp
    pop rbp
    ret
    
; Opens up a file and reads up to buf_in_len bytes into buffer
; Arguments:
; *input_file_name - rdi - address of the null-terminated file name string
; *buffer - rsi - address of the buffer
; buf_in_len - rdx - number of bytes to read
fn_load_file:
    push rbp
    mov rbp, rsp
    sub rsp, 0x18               ; Stackframe
    push rsi                    ; Preserve address of buffer
    push rdx                    ; Preserver number of bytes to read

    ; Open the file
    mov rax, 0x2                ; open syscall
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

    xor rcx, rcx                        ; Zero out counter

    lbl_xor_buf_loop:
        movzx rax, byte [rsi]               ; Move byte into al for XOR-ing
        
        inc rdi                             ; Modify offset
        movzx r9, byte [rdi]                ; Move byte into r9b for XOR-ing
        xor rax, r9                         ; XORs

        inc rdx                             ; Modify offset
        mov byte [rsi], al                  ; Replace buf_in in-place

        inc rsi                             ; Modify offset

        inc rcx
        cmp rcx, qword [buf_in_len]
        jne lbl_xor_buf_loop

    call fn_dbg_print_buf_in

    mov rsp, rbp
    pop rbp
    ret

main:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe

    ; Load input file size
    lea rdi, [in_file_str]
    lea rsi, [stat_buf]
    call fn_stat_file

    mov [buf_in_len], rax       ; Store the size of the file

    ; Load buffer from input file
    lea rdi, [in_file_str]
    lea rsi, [buf_in]
    mov rdx, qword [buf_in_len]
    call fn_load_file

    ; Load key file size
    lea rdi, [key_file_str]
    lea rsi, [stat_buf]
    call fn_stat_file

    mov [buf_key_len], rax      ; Store the size of the file

    ; Load buffer from key file
    lea rdi, [key_file_str]
    lea rsi, [buf_key]
    mov rdx, qword [buf_key_len]
    call fn_load_file

    ; Perform XOR of the buffer
    call fn_xor_buf

    ; Store result into output file
    call fn_store_data

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

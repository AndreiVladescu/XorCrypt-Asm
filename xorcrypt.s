section .data
    err_msg db "Program exits due to errors", 0xA
    ptr_buf_in dq 0x0
    ptr_buf_key dq 0x0
    ptr_in_file_str dq 0x0
    ptr_key_file_str dq 0x0
    ptr_out_file_str dq 0x0
    buf_in_len dq 0x10
    buf_key_len dq 0x10
    err_msg_len dq 0x1c
    newline db 0xA

section .bss
    stat_buf resb 144

section .text
    global _start
    global main
    global fn_load_file
    global fn_error_exit
    global fn_xor_buf
    global fn_stat_file
    global fn_store_data
    global fn_get_heap_mem
    global fn_free_heap_mem
    global fn_load_args
    global fn_xor_buf_ymm
; Functions

; Debug prints function only
fn_dbg_print_buf_in:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe

    ; Print input buffer
    mov rax, 1  
    mov rdi, 1
    mov rsi, [ptr_buf_in]
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
    ; Print error message to stderr
    mov rax, 1  
    mov rdi, 2
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
    push r12
    push r13

    ; Open the file
    mov rax, 0x2                ; open syscall
    mov rdi, [ptr_out_file_str]
    mov rsi, 0x241              ; Flags: O_CREAT (0x40) | O_WRONLY (0x01) | O_TRUNC (0x200)
    mov rdx, 0o644              ; Permissions: rw-r--r--
    syscall

    cmp rax, 0x0                ; Error handling
    jnl lbl_store_data_skip_error
    call fn_error_exit

    lbl_store_data_skip_error:

    mov r12, rax                ; Save fd in r12

    xor r13, r13                ; Bytes written so far

    ; Write the modified XORed buffer into the newly opened file
    ; write() may write less than requested, so loop until everything is out
    lbl_store_data_write_loop:
        cmp r13, qword [buf_in_len]
        jae lbl_store_data_write_done

        mov rax, 0x1                ; write syscall
        mov rdi, r12                ; Copy fd to rdi
        mov rsi, [ptr_buf_in]       ; Address of the buffer
        add rsi, r13                ; + bytes already written
        mov rdx, [buf_in_len]       ; Bytes left to write
        sub rdx, r13
        syscall

        cmp rax, 0x0                ; Error handling
        jg lbl_store_data_write_ok
        call fn_error_exit

    lbl_store_data_write_ok:
        add r13, rax
        jmp lbl_store_data_write_loop

    lbl_store_data_write_done:
    ; Close the fd
    mov rax, 0x3                ; close syscall
    mov rdi, r12                ; Copy fd to rdi
    syscall

    pop r13
    pop r12
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
    sub rsp, 0x8                         ; Stackframe

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

; Deallocated the memory
; Arguments:
; buf_addr - rdi - pointer to the address that will be freed
; buf_len - rsi - the number of bytes to deallocate
fn_free_heap_mem:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                        ; Stackframe

    ; Call 'munmap'
    mov rax, 0xb
    ; rdi is the pointer
    ; rsi is the length
    syscall

    mov rsp, rbp
    pop rbp
    ret

; Allocates memory dynamically on the heap to be more efficient when using smaller files
; Arguments:
; buf_len - rsi - the number of bytes to allocate for the buffer 
; Return value:
; rax - address of the allocated memory
fn_get_heap_mem:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                        ; Stackframe

    ; Call 'mmap'
    mov rax, 0x9
    mov rdi, 0x0                        ; Start address
    ; rsi is the length
    mov rdx, 0x3                        ; PROT_READ | PROT_WRITE
    mov r10, 0x22                       ; MAP_PRIVATE | MAP_ANONYMOUS
    xor r8, r8
    not r8                              ; Sets fd = -1, anonmyous mapping
    mov r9, 0x0                         ; Offset = 0
    syscall

    ; Check for error, the kernel returns -errno (-4095..-1)
    cmp rax, -4095
    jb lbl_get_heap_mem_skip_error
    call fn_error_exit

    lbl_get_heap_mem_skip_error:
    mov rsp, rbp
    pop rbp
    ret
; Opens up a file and reads exactly buf_in_len bytes into buffer
; Arguments:
; *input_file_name - rdi - address of the null-terminated file name string
; *buffer - rsi - address of the buffer
; buf_in_len - rdx - number of bytes to read
fn_load_file:
    push rbp
    mov rbp, rsp
    push r12
    push r13
    push r14
    push r15

    mov r13, rsi                ; Preserve address of buffer
    mov r14, rdx                ; Preserve number of bytes to read

    ; Open the file
    mov rax, 0x2                ; open syscall
    mov rsi, 0x0                ; O_RDONLY flag set
    syscall

    cmp rax, 0x0                ; Error handling
    jnl lbl_load_file_skip_error
    call fn_error_exit
    
    lbl_load_file_skip_error:
    mov r12, rax                ; Save fd of file in r12
    xor r15, r15                ; Bytes read so far

    ; Read from the file
    ; read() returns at most ~2GB per call and may return less, so loop
    lbl_load_file_read_loop:
        cmp r15, r14
        jae lbl_load_file_read_done

        mov rax, 0x0                    ; read syscall
        mov rdi, r12                    ; Copy fd to rdi
        lea rsi, [r13 + r15]            ; Buffer + bytes already read
        mov rdx, r14                    ; Bytes left to read
        sub rdx, r15
        syscall

        cmp rax, 0x0                    ; Error or unexpected end of file
        jg lbl_load_file_read_ok
        call fn_error_exit

    lbl_load_file_read_ok:
        add r15, rax
        jmp lbl_load_file_read_loop

    lbl_load_file_read_done:
    ; Close the fd
    mov rax, 0x3                        ; close syscall
    mov rdi, r12                        ; Copy fd to rdi
    syscall

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp
    ret

; XORs *ptr_buf_in and *ptr_buf_key and stores it in *ptr_buf_in
; The function is optimized using 256 bit (32 byte) YMM registers
; The key wraps around the data like in fn_xor_buf. The vector loop needs the
; key length to be a multiple of 32 bytes, otherwise it falls back to fn_xor_buf.
; Leftover bytes at the end (data length not divisible by 32) are XORed one by one.
; No arguments needed
fn_xor_buf_ymm:
    push rbp
    mov rbp, rsp

    mov r8, [buf_key_len]
    test r8, 0x1f                       ; Key length multiple of 32?
    jz lbl_xor_buf_ymm_start
    call fn_xor_buf                     ; No, use the byte-by-byte version
    jmp lbl_xor_buf_ymm_end

    lbl_xor_buf_ymm_start:
    mov rsi, [ptr_buf_in]               ; Load buf_in address in rsi
    mov rdi, [ptr_buf_key]              ; Load buf_key address in rdi
    mov rcx, [buf_in_len]
    and rcx, -0x20                      ; Bytes that fit in whole 32 byte blocks

    xor rax, rax                        ; Offset in the input data
    xor rdx, rdx                        ; Offset in the key

    lbl_xor_buf_ymm_loop:
        cmp rax, rcx
        jae lbl_xor_buf_ymm_tail

        vmovdqa ymm0, [rsi + rax]       ; Load 32 bytes of data in ymm0
        vpxor ymm0, ymm0, [rdi + rdx]   ; XOR with 32 bytes of key: ymm0 = ymm0 ^ key
        vmovdqa [rsi + rax], ymm0       ; Store 32 bytes back into the buffer

        add rax, 0x20                   ; 256 bits = 32 bytes
        add rdx, 0x20

        ; Circular looping through the key
        cmp rdx, r8
        jb lbl_xor_buf_ymm_loop
        xor rdx, rdx
        jmp lbl_xor_buf_ymm_loop

    ; XOR the remaining (< 32) bytes one by one
    lbl_xor_buf_ymm_tail:
        cmp rax, qword [buf_in_len]
        jae lbl_xor_buf_ymm_done

        movzx r9d, byte [rdi + rdx]
        xor byte [rsi + rax], r9b
        inc rax
        inc rdx
        jmp lbl_xor_buf_ymm_tail

    lbl_xor_buf_ymm_done:
    vzeroupper                          ; Avoid AVX-SSE transition penalties

    lbl_xor_buf_ymm_end:
    mov rsp, rbp
    pop rbp
    ret

; XORs *ptr_buf_in and *ptr_buf_key and stores it in *ptr_buf_in
; No arguments needed
fn_xor_buf:
    push rbp
    mov rbp, rsp

    mov rsi, [ptr_buf_in]               ; Load buf_in address in rsi
    mov rdi, [ptr_buf_key]              ; Load buf_key address in rdi
    mov rcx, [buf_in_len]               ; Data length
    mov r8, [buf_key_len]               ; Key length

    xor rax, rax                        ; Offset in the input data
    xor rdx, rdx                        ; Offset in the key

    lbl_xor_buf_loop:
        cmp rax, rcx                    ; Checked first, so empty files work
        jae lbl_xor_buf_done

        movzx r9d, byte [rdi + rdx]     ; Move key byte into r9b for XOR-ing
        xor byte [rsi + rax], r9b       ; XOR buf_in in-place

        inc rax                         ; Modify offset of the input data
        inc rdx                         ; Modify offset of the key

        ; Circular looping through the key
        cmp rdx, r8
        jb lbl_xor_buf_loop
        xor rdx, rdx                    ; Zeroes rdx to wrap around the key
        jmp lbl_xor_buf_loop

    lbl_xor_buf_done:
    mov rsp, rbp
    pop rbp
    ret

; Verifies wheter there are a number of 4 arguments (including the program itself)
; Will load the addresses to the strings in the pointer variables
; Argument 1: input file name
; Argument 2: key file name
; Argument 3: output file name
fn_load_args:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe

    mov rax, qword [rsp + 0x30] ; argc
    cmp rax, 0x4
    je lbl_load_args_skip_error
    call fn_error_exit

    lbl_load_args_skip_error:

    ; Load arguments' addresses to pointer
    mov rax, qword [rsp + 0x40] ; arg1
    mov [ptr_in_file_str], rax
    mov rax, qword [rsp + 0x48] ; arg2
    mov [ptr_key_file_str], rax
    mov rax, qword [rsp + 0x50] ; arg3
    mov [ptr_out_file_str], rax

    mov rsp, rbp
    pop rbp
    ret

main:
    push rbp
    mov rbp, rsp
    sub rsp, 0x8                ; Stackframe

    ; Verify if arguments are the correct number
    call fn_load_args

    ; Load input file size
    mov rdi, [ptr_in_file_str]
    lea rsi, [stat_buf]
    call fn_stat_file

    mov [buf_in_len], rax       ; Store the size of the file

    ; Allocate memory for the input data buffer
    ; (mmap refuses a length of 0, so an empty file still gets 1 byte)
    mov rsi, [buf_in_len]
    test rsi, rsi
    jnz lbl_main_in_len_ok
    inc rsi
    lbl_main_in_len_ok:
    call fn_get_heap_mem
    mov [ptr_buf_in], rax

    ; Load buffer from input file
    mov rdi, [ptr_in_file_str]
    mov rsi, [ptr_buf_in]
    mov rdx, qword [buf_in_len]
    call fn_load_file

    ; Load key file size
    mov rdi, [ptr_key_file_str]
    lea rsi, [stat_buf]
    call fn_stat_file

    mov [buf_key_len], rax      ; Store the size of the file

    ; An empty key can't be wrapped around the data
    test rax, rax
    jnz lbl_main_key_len_ok
    call fn_error_exit
    lbl_main_key_len_ok:

    ; Allocate memory for the key buffer
    mov rsi, [buf_key_len]
    call fn_get_heap_mem
    mov [ptr_buf_key], rax

    ; Load buffer from key file
    mov rdi, [ptr_key_file_str]
    mov rsi, [ptr_buf_key]
    mov rdx, qword [buf_key_len]
    call fn_load_file

    ; Perform XOR of the buffer
    ; The variant is picked at build time (see Makefile):
    ;   default      - AVX2 YMM version
    ;   -DUSE_GPR    - byte-by-byte version
    ;   -DNO_XOR     - no XOR at all, only I/O (benchmark baseline)
%ifdef NO_XOR
%elifdef USE_GPR
    call fn_xor_buf
%else
    call fn_xor_buf_ymm
%endif

    ; Store result into output file
    call fn_store_data

    ; Deallocate memory for the data and key buffers
    mov rdi, [ptr_buf_in]
    mov rsi, [buf_in_len]
    call fn_free_heap_mem

    mov rdi, [ptr_buf_key]
    mov rsi, [buf_key_len]
    call fn_free_heap_mem

    mov rsp, rbp
    pop rbp
    ret

_start:
    mov rbp, rsp

    call main

    ; Exit the program
    mov rax, 0x3c               ; exit syscall
    mov rdi, 0x0
    syscall

%define grid_len 81
%define grid_width 9
%define grid_last_index grid_len - 1
%define sgrid_len 27
%define sgrid_width 3
%define char_buf_len 1
%define excl_mask 0b0000000111111111
%define excl_empty 0b0000000000000000
%define certain_num_bitcount 8
%define input_buf_len 512
%define output_buf_len grid_len + grid_width + 1

section .bss
	; uninitialized grid for exclusion bits
	grid resw grid_len
	char_buf resb char_buf_len
	input_cnt resb 1
	input_buf resb input_buf_len
	output_buf resb output_buf_len
	; sgrid_excl:
	sy resb 1
	sx resb 1
	pass resb 1

section .text
	global _start

print:
	; newline chars are set at setup
	push rax
	push r8
	push r9
	push r10

	mov r8, 0 ; grid index
	mov r9, 1 ; column count
	mov r10, 0 ; output buf index
	.loop:
	; copy grid field to dbg buf and move grid ptr
	mov di, word grid[r8 * 2]
	call excl_to_char
	mov byte output_buf[r10], al
	inc r10
	cmp r9, grid_width
	jne .after_newline
	inc r10
	mov r9, 0
	.after_newline:
	inc r8
	inc r9
	cmp r8, grid_len
	jl .loop
	mov rax, 1
	mov rdi, 1
	mov rsi, output_buf
	mov rdx, output_buf_len
	syscall

	pop r10
	pop r9
	pop r8
	pop rax
	ret

char_to_excl: ; 8b » 16b
	cmp dil, '?'
	jne .unknown
	mov ax, 0
	ret
	.unknown:
	sub dil, '1'
	mov cl, dil
	; shift 1 bit at end by di bits to the left
	mov ax, 0b0000000000000001
	shl ax, cl
	not ax
	and ax, excl_mask
	ret

; returns a ? or a number based on the exclusions
excl_to_char: ; 16b » 8b
	popcnt dx, di
	cmp dx, certain_num_bitcount
	je excl_to_char.certain
	mov al, '?'
	ret
	.certain:
	xor di, excl_mask
	bsf ax, di
	add al, byte '1'
	ret

sgrid_excl:
	mov byte [sx], 0
	mov byte [sy], 0
	mov r8, 0 ; index
	mov r11w, word excl_empty ; exclusions
	mov byte [pass], 1
	.grid_loop:
	mov r9w, word grid[r8 * 2] ; grid value until after popcnt
	popcnt r10w, r9w ; popcnt grid value
	cmp byte [pass], 1
	jne .second_pass
	; first pass: Collect exclusions
		cmp r10w, word certain_num_bitcount
		jne .after_pass
		xor r9w, word excl_mask
		or r11w, r9w
		jmp .after_pass
	.second_pass:; Apply exclusions
		cmp r10w, word certain_num_bitcount
		je .after_pass ; skip excl apply if field is determined already
		mov word grid[r8 * 2], r11w
	.after_pass:
	; start of index pattern
	cmp r8, grid_last_index
	jne .no_return
	cmp byte [pass], 1
	jne .no_return
	ret
	.no_return:
	inc byte [sx]
	inc r8
	cmp byte [sx], sgrid_width
	jne .grid_loop
	add r8, sgrid_width * 2
	mov byte [sx], 0
	inc byte [sy]
	cmp byte [sy], sgrid_width
	jne .grid_loop
	mov byte [sy], 0
	cmp byte [pass], 1
	jne .current_pass_2
	; current pass 1
		sub r8, sgrid_len
		inc byte [pass]
		jmp .grid_loop
	.current_pass_2:
		cmp r8, grid_last_index ; Maybe move column
		jle .after_column_move
		sub r8, grid_len - sgrid_width
		.after_column_move:
		mov r11w, word excl_empty
		dec byte [pass]
		jmp .grid_loop

line_excl:
	mov rax, 0 ; ah: determined new bool, al: determined count
	mov al, grid_len
	mov byte [sx], 0
	mov byte [sy], 0
	mov r8, 0 ; index
	mov r11w, word excl_empty ; exclusions
	.h_collect:
		mov r9w, word grid[r8 * 2] ; r9w: field value
		popcnt r10w, r9w ; r10w: field value popcnt
		cmp r10w, word certain_num_bitcount
		jne .after_h_collect
		dec al ; count determined number, not used at v_collect to prevent double count
		xor r9w, word excl_mask
		or r11w, r9w
		.after_h_collect:
		inc byte [sx]
		inc r8
		cmp byte [sx], grid_width
		jne .h_collect
		mov byte [sx], 0
	sub r8, grid_width
	.h_apply:
		mov r9w, word grid[r8 * 2] ; r9w: field value
		popcnt r10w, r9w ; r10w: field value popcnt
		cmp r10w, word certain_num_bitcount
		je .after_h_apply
		or r9w, r11w
		mov word grid[r8 * 2], r9w
		popcnt r10w, r9w
		cmp r10w, word certain_num_bitcount
		jne .after_h_apply
		mov ah, 1
		.after_h_apply:
		inc byte [sx]
		inc r8
		cmp byte [sx], grid_width
		jne .h_apply
		mov byte [sx], 0
	mov r11w, word 0b000000000
	inc byte [sy]
	cmp byte [sy], grid_width
	jne .h_collect

	mov r8, 0 ; reset index
	mov r11w, word excl_empty ; reset exclusions
	.v_collect:
		mov r9w, word grid[r8 * 2] ; r9w: field value
		popcnt r10w, r9w ; r10w: field value popcnt
		cmp r10w, word certain_num_bitcount
		jne .after_v_collect
		xor r9w, word excl_mask
		or r11w, r9w
		.after_v_collect:
		add r8, grid_width
		cmp r8, grid_len
		jl .v_collect
	sub r8, grid_len
	.v_apply:
		mov r9w, word grid[r8 * 2] ; r9w: field value
		popcnt r10w, r9w ; r10w: field value popcnt
		cmp r10w, word certain_num_bitcount
		je .after_v_apply
		or r9w, r11w
		mov word grid[r8 * 2], r9w
		popcnt r10w, r9w
		cmp r10w, word certain_num_bitcount
		jne .after_v_apply
		mov ah, 1
		.after_v_apply:
		add r8, grid_width
		cmp r8, grid_len
		jl .v_apply
	mov r11w, excl_empty
	sub r8, grid_len - 1
	cmp r8, grid_width
	jne .v_collect
	ret

; check whether a value is
is_input: ; 8b » 64b
	cmp dil, '0'
	jl .invalid
	cmp dil, '9'
	jg .not_num
	mov rax, 1
	ret
	.not_num:
	cmp dil, '?'
	jne .invalid
	mov rax, 1
	ret
	.invalid:
	mov rax, 0
	ret

read:
	mov r10, 0 ; grid insert
	mov r11, 0 ; char or excl

	; stdin (512b) » input buffer
	.read_into_buf:
	mov rax, 0				; sys_read
	mov rdi, 0				; fd 0 (standard input)
	mov rsi, input_buf		; ptr to input
	mov rdx, input_buf_len	; number of bytes to read
	syscall
	mov r8, rax	; bytes read
	mov r9, 0	; input buf index

	; input buffer » grid (81w)
	.char_iter:
	mov r11b, byte input_buf[r9] ; char
	inc r9
	cmp r8, r9 ; bytes_read == ++input_buf_index
	jl .maybe_repeat ; jmp/if end of buffer reached
	mov dil, r11b
	call is_input
	cmp rax, 0
	je .char_iter ; skip char if it's not input
	mov dil, r11b
	call char_to_excl
	mov r11w, ax ; excl
	mov word grid[r10 * 2], r11w
	inc r10
	cmp r10, grid_len ; - 1
	jne .dont_process_grid
	call process_grid
	mov r10, 0 ; grid insert
	.dont_process_grid:
	jmp .char_iter

	.maybe_repeat:
	cmp r8, input_buf_len
	je .read_into_buf ; repeat if buffer was filled to capacity

	; exits if no more data is provided
	mov rax, 60
	mov rdi, 0
	syscall

process_grid:
	push r8
	push r9
	push r10
	push r11

	call sgrid_excl
	.before_line_excl:
	call line_excl
	cmp al, 0
	je .after_iter ; skip last iter grid is already fully determined
	cmp ah, 1
	je .before_line_excl
	.after_iter:
	call print

	pop r11
	pop r10
	pop r9
	pop r8
	ret

setup:
	; Sets the newlines for the output buffer, to avoid setting in loop
	mov byte output_buf[9], 10 ; newline
	mov byte output_buf[19], 10 ; newline
	mov byte output_buf[29], 10 ; newline
	mov byte output_buf[39], 10 ; newline
	mov byte output_buf[49], 10 ; newline
	mov byte output_buf[59], 10 ; newline
	mov byte output_buf[69], 10 ; newline
	mov byte output_buf[79], 10 ; newline
	mov byte output_buf[89], 10 ; newline
	mov byte output_buf[90], 10 ; newline
	ret

_start:
	call setup
	call read
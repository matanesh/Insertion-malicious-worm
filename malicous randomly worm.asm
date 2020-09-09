COMMENT @
Matan Eshel 203502802
Yogev Yosef 312273410
@

;1) because we want to run it multiple times and have a different path for the worm for each run

;2) -ask from the user a number before every run
;   -if there is an option to random a number as the seed
;	-use the date/hour as the seed
;	-use DS that usually changes in different runs as the seed

.model small
.stack 100h
.data
	WORM_SIGN EQU '@'
.code
	Old_int_off dw ?
	Old_int_seg dw ?
	
	;------------------------------------------------------------------------------------------------------------------------;
	;~~~~~~Move_Worm~~~~~~;
	
	;Inputs:
	;ax - has the current LFSR
	;di - has the offset in the screen
	
	;explanation:
	;the function move's the warm according to the 2 LSB of ax
	
	;Output:
	;none
	
	Move_Worm proc
	
		;delete the old cell
			mov dh, 0h
			mov dl, 0DBh 
			mov es:[di], dx
			
		mov cl, al
		and cl, 00000011b
		
		;Left case
		cmp cl, 00000000b
		jnz SkipRight
			sub di, 2h
			jmp Print
			
		SkipRight:	
		;Right case
		cmp cl, 00000011b
		jnz SkipUp
			add di, 2h
			jmp Print
			
		SkipUp:
		;Up case
		cmp cl, 00000010b
		jnz SkipDown
			sub di, 0A0h
			jmp CheckLimits ;when we move up we can have an exception from the screen
		
		SkipDown:
		;Down case
		cmp cl, 00000001b
			add di, 0A0h
			jmp CheckLimits ;when we move down we can have an exception from the screen
		
		CheckLimits:
			cmp di, 0FF00h ;case we are above the screen - di has a number with F___h (like negative number)
				ja fixLimits
			cmp di, 0F9Eh ;case we are beneath the screen
				ja fixLimits
			
			;if we are here it means the worm is in the screen limits
			jmp Print
		
		fixLimits:
			mov di, 7D0h ;initialize di as offset to the center 
			jmp Print
			
		Print:
			mov dh, 01000000b ;red background with black foreground
			mov dl, WORM_SIGN
			mov es:[di], dx
		ret
	Move_Worm endp
	;------------------------------------------------------------------------------------------------------------------------;


	;------------------------------------------------------------------------------------------------------------------------;
	;~~~~~~ISR_New_Int08~~~~~~;
	
	;Inputs:
	;ax - has the current LFSR
	;di - is the counter
	
	;explanation:
	;the function call the original int 08h and then calculate the next LFSR
	
	;Output:
	;none
	
	ISR_New_Int08 proc near
	
		pushf ;because iret of int 08h does popf
		call dword ptr [Old_int_off] ;call original interrupt Old_int_seg:Old_int_off int 08h	
		
		cmp si, 0
		jnz Continue
			mov si, 11d ;11 because of the dec in the end of the interrupt
			call Move_Worm
			
	Continue:
		call LFSR_Move
		dec si
		iret
	ISR_New_Int08 endp
	;------------------------------------------------------------------------------------------------------------------------;


	;------------------------------------------------------------------------------------------------------------------------;
	;~~~~~~LFSR_Move~~~~~~;
	
	;Inputs:
	;ax - has the current LFSR
	
	;explanation:
	;the function calculate the next LFSR and insert it to ax
	
	;Output:
	;ax - has the next LFSR
	
	LFSR_Move proc
	
	;saving the 15,16 bits in bh, bl
		mov bl, 10000000b ;in order to save the 16's bit
		and bl, ah
		mov bh, 01000000b ;in order to save the 15's bit
		and bh, ah
		
		;shifting the data in order to have 1/0
		mov cl, 7d ;shift the 16's bit
		shr bl, cl
		mov cl, 6d ;shift the 15's bit
		shr bh, cl
		
		xor bl, bh
		mov dh, bl ;saving the 15-16 xor in dh
		
		;saving the 8,13 bits in bl, bh
		mov bl, 10000000b ;in order to save the 8's bit
		and bl, al
		mov bh, 00010000b ;in order to save the 13's bit
		and bh, ah
		
		;shifting the data in order to have 1/0
		mov cl, 7d ;shift the 8's bit
		shr bl, cl
		mov cl, 4d ;shift the 13's bit
		shr bh, cl
		
		xor bl, bh
		mov dl, bl ;saving the 8-13 xor in dl
		
		xor dh, dl ;saving the (8-13) and (15-16) xor in dh
		
		mov dl, 00100000b ;in order to save the 6's bit
		and dl, al
		
				
		;shifting the data in order to have 1/0
		mov cl, 5d ;shift the 6's bit
		shr dl, cl
		
		xor dh, dl ;saving the last xor in dh
		not dh 
		
		;shifting the data to the 16's bit place
		mov cl, 7d
		shl dh, cl
		
		shr ax, 1 ;shifting the whole register
		
		or ah, dh ;inserting the new bit
		
		ret
	LFSR_Move endp
	;------------------------------------------------------------------------------------------------------------------------;

START:

	;blocking the option of interrupts until the start
	cli
	;extract the seg & off of the original interrupt
		mov al, 08h
		mov ah, 35h
		int 21h
		
	;insert the seg & off to the variable
		mov Old_int_off, bx
		mov ax, es
		mov Old_int_seg, ax
	
	;set the IVT table with the new interrupt
		mov ax, cs
		mov ds, ax	
		lea dx, ISR_New_Int08
		mov al, 08h
		mov ah, 25h	
		int 21h
		
	;setting extra segment to screen memory
		 mov ax, 0b800h
		 mov es, ax		
		 
	;initialize ax as the seed - the current time
		;get current minutes
			mov al ,02h
			out 70h, al

			in al ,71h
			mov bh ,al
			
		;get current seconds
			mov al ,0h
			out 70h, al

			in al ,71h
			mov bl ,al
			
		mov ax, bx	
		
	mov di, 7D0h ;initialize di as offset to the center
	mov si, 10d

	;initilize the first position of the game
		mov dh, 01000000b ;red background with black foreground
		mov dl, WORM_SIGN
		mov es:[di], dx
	sti
	
	L1:	
		jmp L1
		
	;return to OS
	mov ax, 4c00h
	int 21h
END START
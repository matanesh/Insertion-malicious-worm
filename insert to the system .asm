COMMENT @
Matan Eshel 203502802
Yogev Yosef 312273410
@

; question:
;1. yes it will be a problem becasue every time the TSR model will save a new place for the new code we wrote
; after a lots of time the memory will be full (it has only 64K bytes of memory)
;2. how to solve this problem?
;
;
;
;
.model tiny

.code
org 100h

START:

jmp Replace_ISR

	Old_int_off dw ?
	Old_int_seg dw ?
	Position dw ?
	Counter dw ?
	Seed dw ?
	;WORM_SIGN EQU '@'
	
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ the new ISR~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~;
	;~~~~~~~~~~~~~~~~~~~~~~~~~ISR_New_Int08~~~~~~~~~~~~~~~~~~~~~~~~;
	
	;Inputs:
	;Seed - has the current LFSR
	;Counter - is the counter
	;Position - the offset to the center
	
	;explanation:
	;the function call the original int 08h and then calculate the next LFSR
	
	;Output:
	;save the seconds on the stack
	
	ISR_New_Int08 proc near uses ax cx
	
	
		pushf ;because iret does popf
		call dword ptr cs:[Old_int_off] ;call original interrupt Old_int_seg:Old_int_off int 08h	
		
		
		
		mov ax, cs:[Counter]
		cmp ax, 0h
		jnz Continue
			mov ax, 11d ;11 because of the dec in the end of the interrupt
			mov cs:[Counter], ax
			call Move_Worm
			
	Continue:
		call LFSR_Move
		mov cx, cs:[Counter]
		dec cx
		mov cs:[Counter], cx
		
		iret
	ISR_New_Int08 endp
;------------------------------------------------------------------------------------------------------------------------;


;------------------------------------------------------------------------------------------------------------------------;
	;~~~Move_Worm~~~;
	
	;Inputs:
	;ax - has the current LFSR
	;
	
	;explanation:
	;the function move's the warm according to the 2 LSB of ax
	
	;Output:
	;none
	
	Move_Worm proc 
		;setting extra segment to screen memory
			 mov ax, 0b800h
			 mov es, ax	
		
		mov di, cs:[Position]
		mov ax, cs:[Seed]
		
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
			mov dl, '@'
			mov es:[di], dx
			
			mov cs:[Position], di ;updating the new position
		ret
	Move_Worm endp
	;------------------------------------------------------------------------------------------------------------------------;

	;------------------------------------------------------------------------------------------------------------------------;
	;~~~LFSR_Move~~~;
	
	;Inputs:
	;ax - has the current LFSR
	
	;explanation:
	;the function calculate the next LFSR and insert it to ax
	
	;Output:
	;ax - has the next LFSR
	
	LFSR_Move proc
	
	mov ax, cs:[Seed]  ; insert the value of seed into ax, ax is nedded for the lfsr algo' 
		
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
		
		
	mov cs:[Seed], ax  ; insert the value of seed into ax, ax is nedded for the lfsr algo' 
		
		
		ret
	LFSR_Move endp




;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Replace_ISR:

	mov ax, @data
	mov cs:[Position], 7D0h ;initialize thi offset! to the center
	mov cs:[Counter], 55d ; initialize the counter for every half second

	;blocking the option of interrupts until the start
	cli
	;extract the seg & off of the original interrupt
		mov al, 08h
		mov ah, 35h
		int 21h
		
	;insert the seg & off to the variable it return in es:bx
		mov cs:[Old_int_off], bx
		mov ax, es
		mov cs:[Old_int_seg], ax
	
	;set the IVT table with the new interrupt
		mov ax, cs
		mov ds, ax	
		mov dx, offset ISR_New_Int08
		mov al, 08h
		mov ah, 25h	
		int 21h
				 
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
			
		mov cs:[Seed], bx
		

	sti
;~~~~~~~~~~~~~~~~~~~~~~~


		
	;return to OS
	mov DX, 01E2h ; save the new isr we eritw in the code
	int 27h
END START

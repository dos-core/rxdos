
%if 0

int19 - RxDOS interrupt 19h handler

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

(c) Copyright 1990, 1999. Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

		; Note that we put nothing between the start of this
		;  file and the start of the i19 function!

		; Interrupt 19 - Ctrl Alt Delete
relocated i19:
	cli
	cld

	xor ax, ax
	mov es, ax

	mov ax, 70h
	mov ds, ax
	mov si, InterruptRestorationTable

.08:
	xor bx, bx
	mov bl, byte [ si ]
	cmp bl, -1
	jz .16

	inc si

	add bx, bx
	add bx, bx					; compute interrupt address
	mov dx, word [ si + 2 ]				; _segment
	mov ax, word [ si ]				; _pointer
							; restore interrupt
	mov word [ es:bx + 2 ], dx			; _segment
	mov word [ es:bx ], ax				; _pointer

	add si, byte 4
	jmp short .08

.16:
	int 19h					 	; go to original int 19
	iret


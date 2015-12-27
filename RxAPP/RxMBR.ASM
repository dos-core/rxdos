
%if 0

RxMBR - RxDOS Master Boot Record program

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

(c) Copyright 1990, 1999. Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

%include "RXDMACRO.MAC"
%include "RXDSTRUC.MAC"

		; reserved on stack
_diskPartitionTable		equ 0
_stackReserved			equ 2 + 40h

PART_BOOT			equ 80h
PART_NULLBOOT			equ 00h


				cpu 8086

%ifidni __OUTPUT_FORMAT__, obj
	segment RXMBR align=16 class=RXMBR use16 public vstart=7C00h
%else
			org 7C00h
%endif
	segment RXMBR


		; the RxDOS boot process begins here
RxDOS_MASTERBOOTLOAD:
	cli						; no interrupts
	cld						; all that we need to init

	mov ax, cs
	mov ds, ax					; set segments
	mov es, ax
	mov ss, ax					; set stack
	mov sp, 0600h - _stackReserved
	mov bp, sp
	sti						; re-enable interrupts

		; relocate MBR to 0060:0000
	mov di, 0600h					; 0060:0000 
	mov cx, (sizeSector / 2)			; size of sector in words
	repe movsw					; copy sector
	jmp 60h:RxDOS_MASTERBOOTLOAD_08

RxDOS_MASTERBOOTLOAD_08:
	mov cx, 4					; # arguments
	mov bx, RxDOS_MASTERBOOT_PARTITIONTABLE

RxDOS_MASTERBOOTLOAD_10:
	cmp byte [ _ptBootable + bx ], PART_BOOT	; [0000] == 80h
	jz RxDOS_MASTERBOOTLOAD_22			; yes -->
	cmp byte [ _ptBootable + bx ], PART_NULLBOOT	; [0000] == 00h
	jnz RxDOS_MASTERBOOTLOAD_CorruptTableError	; table is corrupted -->

	add bx, byte sizePARTITION
	loop RxDOS_MASTERBOOTLOAD_10

	int 18h						; if error

		; if boot partition located
RxDOS_MASTERBOOTLOAD_22:
	mov si, bx					; save pointer to this entry
	mov word [ _diskPartitionTable + bp ], bx

RxDOS_MASTERBOOTLOAD_24:
	add bx, byte sizePARTITION				; next entry
	dec cx						; see if more entries
	jz RxDOS_MASTERBOOTLOAD_32			; no more -->

		; only one entry in the table can be a boot entry
	cmp byte [ _ptBootable + bx ], PART_NULLBOOT	; [0000] == 00h
	jz RxDOS_MASTERBOOTLOAD_24			; see if all entries scanned ->
	jmp RxDOS_MASTERBOOTLOAD_CorruptTableError	; table is corrupted -->

		; boot partion located
RxDOS_MASTERBOOTLOAD_32:
	mov dx, word [ _ptBootable + si ]		; get bootable/ head
	mov cx, word [ _ptBeginSector + si ]		; get sector/ cylinder
	mov di, 5					; # retries

RxDOS_MASTERBOOTLOAD_36:
	mov bx, 7C00h					; where to load
	mov ax, 0201h					; BIOS command
	push di						; save retries
	int 13h						; try reading disk
	pop di						; retries
	jnc RxDOS_MASTERBOOTLOAD_44			; ok -->

	xor ax, ax					; reset disk on error
	int 13h						;
	dec di						; more retires to go
	jnz RxDOS_MASTERBOOTLOAD_36			; retries -->

		; Error Messages
RxDOS_MASTERBOOTLOAD_LoadError:
	mov si, RxDOS_MASTERBOOT_MsgErrorWhenLoading
	jmp short RxDOS_MASTERBOOT_DisplayMessage

RxDOS_MASTERBOOTLOAD_CorruptTableError:
	mov si, RxDOS_MASTERBOOT_MsgTableIsCorrupted
	jmp short RxDOS_MASTERBOOT_DisplayMessage

RxDOS_MASTERBOOTLOAD_OSMissingError:
	mov si, RxDOS_MASTERBOOT_MsgOSMissing

		; Display Message
RxDOS_MASTERBOOT_DisplayMessage:
	lodsb
	cmp al, 00
	jz RxDOS_MASTERBOOTLOAD_WaitLoop

	push si
	mov bx, 0007h					; attributes
	mov ah, 0Eh					; display character
	int 10h
	pop si
	jmp RxDOS_MASTERBOOT_DisplayMessage

		; Wait Loop
RxDOS_MASTERBOOTLOAD_WaitLoop:
	jmp RxDOS_MASTERBOOTLOAD_WaitLoop		; self loop -->

		; boot partion located
RxDOS_MASTERBOOTLOAD_44:
	mov di, (7C00h + sizeSector - 2)
	cmp word [ di ], RxDOS_PARTITIONSIGNATURE	; AA55
	jnz RxDOS_MASTERBOOTLOAD_OSMissingError

	mov si, word [ _diskPartitionTable + bp ]
	jmp 0:7C00h					; jmp FAR to 7C00 -->

		; Error Messages
RxDOS_MASTERBOOT_MsgTableIsCorrupted:
	db "Master Boot Table is corrupted.",0

RxDOS_MASTERBOOT_MsgErrorWhenLoading:
	db "Error when loading.",0

RxDOS_MASTERBOOT_MsgOSMissing:
	db "Operating System missing",0

		; partition table
	times 510-64-$+$$ db 0

RxDOS_MASTERBOOT_PARTITIONTABLE:
							; partition table patched here
	times 510-$+$$ db 0
	db 55h, 0AAh

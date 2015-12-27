
%if 0

RxVDISK - RxDOS virtual disk driver

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

(c) Copyright 1990, 1999. Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

%if 0

RxDOS VDISK Driver

Usage: rxvdisk [ size in kb ]

To use, add DEVICE=RXVDISK.SYS entry to (RX)CONFIG.SYS
Size argument is optional and is in KiB

%endif

%include "RXDMACRO.MAC"
%include "RXDSTRUC.MAC"


		; Macros
	%imacro computeaddress 2-3.nolist -
%ifnidni %3,-
		mov ax, %3
%endif
		mov dx, cs
		add dx, ( RxVDISK_DATASTORAGE - $$ ) / 16
		add ax, ax				; 2
		add ax, ax				; 4
		add ax, ax				; 8
		add ax, ax				; 10h
		add ax, ax				; 20h
		add dx, ax
		mov %1, dx
		xor %2, %2
	%endmacro

	%imacro computewords 0.nolist
		mov ax, (sizeSECTOR/ 2)
		mul cx
		mov cx, ax				; words to move
	%endmacro

	%imacro computebytes 0.nolist
		mov ax, sizeSECTOR
		mul cx
		mov cx, ax				; bytes to move
	%endmacro


				cpu 8086

%ifidni __OUTPUT_FORMAT__, obj
	segment RXVDISK align=16 class=RXVDISK use16 public start=0
%else
			org 0
%endif
	segment RXVDISK


		; Device Header
	devheader rxvdisk, -1, -1, (DEV_BLOCK| DEV_OUTPUTTILLBUSY), \
		RxVDISK_Strategy, RxVDISK_Interrupt, 1

		; RxVDISK Dispatch Table
%if 1
RxVDISK_Dispatch:
%else
rxvdisk_table:	db (.max - ($+1) ) / 2
%endif
		dw RxVDISK_DriverInit
		dw RxVDISK_MediaCheck
		dw RxVDISK_BuildBPB
		dw RxVDISK_Unsupported
		dw RxVDISK_Read
		dw RxVDISK_Read
		dw RxVDISK_Unsupported
		dw RxVDISK_Unsupported
		dw RxVDISK_Write
		dw RxVDISK_Write
%if 1
		dw RxVDISK_Unsupported
		dw RxVDISK_Unsupported
		dw RxVDISK_Unsupported
%endif
.max:


		; RxVDISK boot sector and BPB
RxVDISK_BOOTREC:times 3 db 0				; Jump
		db 'RxVDISK '				; OEM Name

RxVDISK_BOOTREC_BPB:
		dw 512					; bytes per sector
		db 1					; sectors per cluster
		dw 1					; reserved sectors
		db 1					; number of FAT copies
		dw 64					; max alloc root directory
		dw 360					; max sectors (360 = 180k)
		db 0FCh					; media descriptor
		dw 2					; sectors per fat
RxVDISK_BOOTREC_END:


		; RxVDISK BPB
RxVDISK_BPB	times (RxVDISK_BOOTREC_END - RxVDISK_BOOTREC_BPB) db 0


%if 1
		; RxVDISK strategy
RxVDISK_Strategy:
	retf
		; RxDOS 7.20N:	This assumes DOS won't destroy es:bx when
		;		performing the subsequent interrupt call.


		; RxVDISK interrupt (dispatcher)
RxVDISK_Interrupt:
%else
		; RxVDISK strategy (dispatcher)
RxVDISK_Strategy:
%endif

	SaveAllRegisters

	cld
	push es
	push bx
	setds cs

%if _386
	movzx ax, byte [ es:bx + rhFunction ]
%else
	xor ah, ah
	mov al, byte [ es:bx + rhFunction ]
%endif
	add ax, ax
	mov di, ax
	call word [ di + RxVDISK_Dispatch ]

	pop bx
	pop es
	or word [ es:bx + rhStatus ], OP_DONE

	RestoreAllRegisters

%if 0
		; RxVDISK interrupt
RxVDISK_Interrupt:
%endif
	retf


		; RxVDISK Media Check
RxVDISK_MediaCheck:

	mov byte [ es:bx + mrReturn ], MEDIA_UNCHANGED
	retn


		; RxVDISK Build BPB
RxVDISK_BuildBPB:

	push ds
	mov di, RxVDISK_BPB
	mov word [ es:bx + bbrBPBAddress + _pointer ], di
	mov word [ es:bx + bbrBPBAddress + _segment ], ds

	setes ds
	ComputeAddress ds, si, 0000			; sector 0

	mov si, (RxVDISK_BOOTREC_BPB - RxVDISK_BOOTREC)
	mov cx, (RxVDISK_BOOTREC_END - RxVDISK_BOOTREC_BPB)
	repz movsb					; copy BPB from boot record

	pop ds
	retn


		; RxVDISK Read
RxVDISK_Read:

	mov cx, word [ es:bx + rwrBytesReq ]		; sectors
	ComputeWords					; sectors --> words

	mov ax, word [ es:bx + rwrStartSec ]
	ComputeAddress ds, si				; compute address

	les di, [ es:bx + rwrBuffer ]
	repz movsw
	retn


		; RxVDISK Write
RxVDISK_Write:

	mov cx, word [ es:bx + rwrBytesReq ]		; sectors
	ComputeWords					; sectors --> words

	lds si, [ es:bx + rwrBuffer ]
	mov ax, word [ es:bx + rwrStartSec ]
	ComputeAddress es, di				; compute address

	repz movsw
	retn


		; Driver Init
RxVDISK_DriverInit:

	mov dx, ds
	add dx, ( RxVDISK_DATASTORAGE - $$ ) / 16

	; add cmd line parameter parsing here
	; irParamAddress resd 0-> RXCONFIG.SYS DEVICE= line

	add dx, 2D00h					; size **********
	mov word [ es:bx + irEndAddress + _pointer ], 0
	mov word [ es:bx + irEndAddress + _segment ], dx
	mov byte [ es:bx + irUnits ], 1			; units

	mov si, RxVDISK_BPB
	mov word [ es:bx + irParamAddress + _pointer ], si
	mov word [ es:bx + irParamAddress + _segment ], cs
	mov word [ es:bx + irMessageFlag ], 0

		; init BPB
	setes ds
	mov si, RxVDISK_BOOTREC_BPB
	mov di, RxVDISK_BPB
	mov cx, (RxVDISK_BOOTREC_END - RxVDISK_BOOTREC_BPB)
	repe movsb

		; init
	ComputeAddress es, di, 0000			; sector 0

	mov cx, word [ RxVDISK_BPB + _bpbMaxAllocRootDir ]
	shr cx, 1
	shr cx, 1
	shr cx, 1
	shr cx, 1					; alloc root dir x 32 / 512
	inc cx						; inc for boot sector
	add cx, word [ RxVDISK_BPB + _bpbSectorsPerFat ]

	; sectors per FAT is size / #sectors per cluster ==> bytes (FAT16 or FAT12)

	ComputeWords					; sectors --> words

	xor ax, ax
	repz stosw					; init boot + FAT + root sector

		; init boot sector
	xor di, di
	mov si, RxVDISK_BOOTREC
	mov cx, RxVDISK_BOOTREC_END - RxVDISK_BOOTREC
	repz movsb

		; init FAT sectors
	ComputeAddress es, di, 0001			; sector 1

	mov al, 0FCh
	stosb						; set media type

	mov al, 0FFh
	stosb						; mark first two entries in use
	stosb

	mov dx, rxvdisk_startupMsg
	Int21 DisplayString

RxVDISK_Unsupported:

	clc
	retn


		; RxVDISK data area
rxvdisk_startupMsg:
	db "RxDOS Real-Mode Virtual Disk",13,10,36,0

	align 16,db 0

RxVDISK_DATASTORAGE:

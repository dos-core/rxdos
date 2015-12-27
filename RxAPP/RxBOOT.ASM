
%if 0

RxBOOT - RxDOS Boot Sector program

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

		; Stack Arguments

	struc RXBOOT_STACKARGS
_rootDirectory			resd 1
_sizeRootDirectory		resw 1
_readDrive			resw 1
_readTrack			resw 1
_readSector			resw 1
_readHead			resw 1
_diskParameterTable		resb 12
_stackReserved			equ ($ - _diskParameterTable) + 20h
	endstruc

ROMBIOS_DISKTABLE		equ ( 1Eh * 4 )

		; buffers start elsewhere
RXDOS_READBUFFER		equ 500h

RXDOS_DOSLOADBUFFER		equ 700h

		; assume starts at 0000:7C00

				cpu 8086

%ifidni __OUTPUT_FORMAT__, obj
	segment RXBOOT align=16 class=RXBOOT use16 public vstart=7C00h
%else
			org 7C00h
%endif
	segment RXBOOT

RxDOS_START:			jmp RxDOS_LOAD

		; this information is standard for every boot sector
__bsOemName			db 'RxDOS6.0'		; 'RxDOS' if formatted by us
__bsBytesPerSector		dw 0			; 512 is default
__bsSectorsPerCluster		db 0
__bsResSectors			dw 0
__bsNumCopiesFAT		db 0
__bsMaxAllocRootDir		dw 0
__bsMaxSectors			dw 0			; if zero, see huge sectors
__bsMediaDescriptor		db 0
__bsSectorsPerFat		dw 0
__bsSectorsPerTrack		dw 0
__bsHeads			dw 0
__bsHiddenSectors		dd 0
__bsHugeSectors			dd 0

__bsDriveNumber			db 0
				db 0
__bsBootSignature		db 29h			; 29h if extended boot sector
__bsVolumeId			dd 0			; unique disk ID
__bsVolumeLabel			times sizeVolumeLabel db 32	; also stored in a special directory entry
__bsFileSystemType		db 'FAT12   '


		; the RxDOS boot process begins here
RxDOS_LOAD:
	cli						; no interrupts
	cld						; all that we need to init

	xor ax, ax
	mov ds, ax					; allow debugging
	mov es, ax					; allow debugging
	mov ss, ax					; allow debugging
	mov sp, 7C00h - _stackReserved
	mov bp, sp
	mov byte [ _readDrive + bp ], dl

	mov bx, ROMBIOS_DISKTABLE			; int 1E
	lds si, [ es:bx ]				; 0000:0078
	lea di, [ word _diskParameterTable + bp ]
	mov word [ es:bx ], di				; _pointer
	mov word [ es:bx + 2 ], ss			; _segment
	mov cx, sizeDISKPARAM
	repe movsb
	sti

	xor ax, ax
	mov ds, ax
	mov byte [ _diskParameterTable + _dptHeadSettleTime + bp ], 15
	mov cx, word [ __bsSectorsPerTrack ]
	mov byte [ _diskParameterTable + _dptSectorsPerTrack + bp ], cl

	int 13h						; reset disk drive (ax = 0)
	jc RxDOSLOAD_Error				; if error -->

		; if no huge sectors, fix up huge sectors
	mov ax, word [ __bsMaxSectors ]
	or ax, ax					; not a huge address disk ?
	jz RxDOSLOAD_08					; yes -->

	mov word [ __bsHugeSectors ], ax

		; compute logical sector address of Root Directory
RxDOSLOAD_08:
	mov bp, sp					; restore stack frame.
	xor ax, ax
	mov al, byte [ __bsNumCopiesFAT ]
	mul word [ __bsSectorsPerFat ]
	add ax, word [ __bsHiddenSectors + _low ]
	adc dx, word [ __bsHiddenSectors + _high ]

	add ax, word [ __bsResSectors ]
	adc dx, byte 0000

	mov word [ _rootDirectory + _low + bp ], ax
	mov word [ _rootDirectory + _high + bp ], dx

		; read first sector of Root Directory
	mov bx, RXDOS_READBUFFER
	call RxDOSPerformRead
	jc RxDOSLOAD_Error				; if error -->

	mov di, RXDOS_READBUFFER
	mov si, RxDOS_RXDOSBIOCOM
	mov cx, sizeFILENAME
	repe cmpsb					; compare first name
	jnz RxDOSLOAD_Error				; if not a system disk -->

	mov di, (RXDOS_READBUFFER + sizeDIRENTRY)
	mov cx, sizeFILENAME
	repe cmpsb					; compare second name
	jz RxDOSLOAD_LoadDOS				; if equal -->

		; can't load
RxDOSLOAD_Error:
	mov si, RxDOS_DISKERROR
	call RxDOSLOAD_DisplayMsg

	xor ax, ax
	int 16h					 ; wait on any key
	int 19h					 ; not expected to return
	jmp RxDOSLOAD_Error

		; load DOS
RxDOSLOAD_LoadDOS:
	mov ax, word [ __bsMaxAllocRootDir ]
	add ax, (sizeSector / sizeDIRENTRY) - 1
	mov cl, 4
	shr ax, cl					; sectors used by directory
	mov word [ _sizeRootDirectory + bp ], ax	; save size
	
	mov ax, word [ RXDOS_READBUFFER + deStartCluster ]
	dec ax
	dec ax						; subtract 2

	xor ch, ch
	mov cl, [ __bsSectorsPerCluster ]
	mul cx

	add ax, word [ _rootDirectory + _low + bp ]
	adc dx, word [ _rootDirectory + _high + bp ]
	add ax, word [ _sizeRootDirectory + bp ]
	adc dx, byte 0000

	mov bx, RXDOS_DOSLOADBUFFER			; where to load
	mov cx, 3					; read three sectors

RxDOSLOAD_LoadDOS_08:
	call RxDOSPerformRead
	jc RxDOSLOAD_Error				; if error -->

	add bx, word [ __bsBytesPerSector ]
	add ax, byte 0001
	adc dx, byte 0000
	loop RxDOSLOAD_LoadDOS_08

	mov ch, byte [ __bsMediaDescriptor ]
	mov dl, byte [ _readDrive + bp ]
	mov bx, word [ _rootDirectory + _low + bp ]
	mov ax, word [ _rootDirectory + _high + bp ]

	lea si, [ _diskParameterTable + bp ]
	jmp 70h:0					; RXDOS_DOSLOADBUFFER

		; Display Message
RxDOSLOAD_DisplayMsg:
	lodsb						; get character (ds:si)
	or al, al					; null terminator ?
	jz RxDOSLOAD_Return				; done -->

	push si
	mov ah, 0Eh
	mov bx, 0007h
	int 10h
	pop si
	jmp RxDOSLOAD_DisplayMsg

RxDOSLOAD_Return:
	retn

		; perform disk read
		;
		; dx:ax logical sector to read
		; es:bx read buffer address
RxDOSPerformRead:
	push bp
	push dx
	push ax
	push cx
	div word [ __bsSectorsPerTrack ]
	inc dl
	mov byte [ _readSector + bp ], dl

	xor dx, dx
	div word [ __bsHeads ]
	; mov word [ _readHead + bp ], ax		; don't need to save heads
	; mov byte [ _readTrack + bp ], dl		; dont need to save track
	mov dh, dl					; track

	clc
	mov cl, 6
	shl ah, cl					; move read head up
	or ah, byte [ _readSector + bp ]		; unused portion of sector
	mov cx, ax
	xchg ch, cl

	mov ax, 0201h					; read one sector.
	mov dl, byte [ _readDrive + bp ]
	int 13h
	jnc RxDOSPerformRead_08
	cmp ax, 11h					; ECC corrected data ?
	jz RxDOSPerformRead_08				; return no carry -->
	stc

RxDOSPerformRead_08:
	pop cx
	pop ax
	pop dx
	pop bp
	retn

%if 0
RxDOS_RXDOSBIOCOM:	db "RXDOSBIOSYS"
%else
RxDOS_RXDOSBIOCOM:	db "RXBIO   SYS"
%endif
RxDOS_RXDOSCOM:		db "RXDOS   SYS"

RxDOS_DISKERROR:	db "Not an RxDOS system disk or disk error",13,10
			db "Press any key to continue...",13,10,0

			times 510-$+$$ db 0
RxDOS_BootSignature:	db 055h, 0AAh

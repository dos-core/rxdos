
%if 0

RxD_BOOT - RxDOS Boot Sector write utility

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

				cpu 8086

%ifidni __OUTPUT_FORMAT__, obj
	segment RXD_BOOT align=16 class=RXD_BOOT use16 public start=100h
%else
			org 100h
%endif
	segment RXD_BOOT


		; Write Stub
		;
		; The stub loads at the normal 100h load address and writes
		; the boot sector to drive A:
		;
		; New for RxDOS 7.20N+:
		; - It's a raw .COM format file. The assembled boot sector
		;   is appended to the executable file.
		; - It uses DOS input/output functions.
		; - It can use either Int25/26 or direct device calls.
		;   (The default is to use Int25/26.)
		; - Better command line parsing.
		; - More or less robust checking if device is valid.
RxDOS_WRITESTUB:

	cli
	cld
	mov ax,cs
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov sp, RxDOS_WRITESTUB_STACK
	sti

%ifdef DEBUGINT24
	mov ax, 2524h
	mov dx, int24
	int 21h
%endif

	cmp word [eop+510],0AA55h			; at [eop], the bootsector starts
	je RxDOS_WRITESTUB_04				;  does the "magic" word match? -->
	mov si, RxDOS_NoBootImage			; otherwise error
	call _DisplayMsg
	Int21 TerminateProcess, 03


RxDOS_WRITESTUB_04:

		; see if drive specified
	Entry
	def	drive, 0000				; A:
	def	WriteOnce, FALSE
	def	SilentMode, FALSE
	def	isRemovable, TRUE
	def	UseDevice, FALSE

	xor bx, bx
	or bl, byte [ 80h ]				; count of command line characters
	jz RxDOS_WRITESTUB_36_1_z			;  no command line, default to A: -->

	mov byte [ bx + 81h ], ControlM			; make sure command line is terminated
	mov si, 81h

		; switch processing
RxDOS_WRITESTUB_06:
	lodsb						; scan command line
	_uppercase al
	cmp al, ControlM				; command line end ?
RxDOS_WRITESTUB_36_1_z:
	ifz RxDOS_WRITESTUB_36				; yes, use default drive (A:) or specified -->

	cmp al, 32					; space ?
	je RxDOS_WRITESTUB_06				; skip any leading spaces -->
	cmp al, 9					; tab ?
	je RxDOS_WRITESTUB_06				; skip any leading tabs -->
	cmp al, '-'					; switch character ?
	je RxDOS_WRITESTUB_08				; yes -->
	cmp al, '/'					; switch character ?
	jne RxDOS_WRITESTUB_22				; no, parse in drive

		; see if /1 (write once )
RxDOS_WRITESTUB_08:
	lodsb						; get character behind switch character
	_uppercase					; so we'll need less compares

	cmp al, 'H'					; help ?
	je RxDOS_WRITESTUB_10				; yes -->
	cmp al, '?'					; help ?
	jne RxDOS_WRITESTUB_12				; no -->

RxDOS_WRITESTUB_10:
	mov si, RxDOS_Usage
	call _DisplayMsg
	Int21 TerminateProcess, 255

RxDOS_WRITESTUB_12:
	cmp al, '1'					; write once ?
	jnz RxDOS_WRITESTUB_14				; no -->
	storarg _WriteOnce, TRUE			; set write once mode
	jmp short RxDOS_WRITESTUB_24			;  look if next character space, proceed

		; see if /s (silent mode)
RxDOS_WRITESTUB_14:
	cmp al, 'S'					; silent mode ?
	jnz RxDOS_WRITESTUB_16				; no -->
	storarg _SilentMode, TRUE			; set silent mode
	storarg _WriteOnce, TRUE			; silent sets write once mode also
	jmp short RxDOS_WRITESTUB_24			;  look if next character space, proceed

		; see if /d (use device driver for disk access)
RxDOS_WRITESTUB_16:
	cmp al, 'D'					; device driver?
	jnz RxDOS_WRITESTUB_30				; no, invalid switch -->
	storarg _UseDevice, TRUE			; set device driver mode
	jmp short RxDOS_WRITESTUB_24			;  look if next character space, proceed

		; drive letter processing
RxDOS_WRITESTUB_22:
	sub al, 'A'					; A - Z 
	jb RxDOS_WRITESTUB_10				; Below 'A' is invalid, display help
	cmp al, 'Z'-'A'					;
	ja RxDOS_WRITESTUB_10				; Above 'Z' is invalid, display help

	mov byte [ _drive + bp ], al			; set drive if other than A:
	lodsb
	cmp al,':'					; is next character a colon?
	je RxDOS_WRITESTUB_24				;  then eat it and proceed after the colon -->
	dec si						; otherwise proceed at next character

RxDOS_WRITESTUB_24:
	lodsb
	cmp al, '/'
	je RxDOS_WRITESTUB_08
	cmp al, '-'
	je RxDOS_WRITESTUB_08				; is switch character. parse -->

	cmp al, 32
	je RxDOS_WRITESTUB_06
	cmp al, 9
	je RxDOS_WRITESTUB_06				; is blank. get next -->
	cmp al, ControlM				; end of command line ?
	je RxDOS_WRITESTUB_36				;  then proceed with selected drive -->

RxDOS_WRITESTUB_30:					; invalid parameter
	mov si, RxDOS_InvalidParameter
	call _DisplayMsg
	Int21 TerminateProcess, 01

RxDOS_WRITESTUB_InvalidDrive:
	mov si, RxDOS_InvalidDrive
	call _DisplayMsg
	Int21 TerminateProcess, 02

		; test if drive removable
RxDOS_WRITESTUB_36:
	mov bl, byte [ _drive + bp ]
	inc bl
	Int21 IoControl, 08h				; is drive removable ?
	jc RxDOS_WRITESTUB_InvalidDrive			; invalid drive -->

	not ax						; 0000 if removable,
	and ax, 1					; ... convert to true or false
	mov word [ _isRemovable + bp ], ax		;

	mov bl, byte [ _drive + bp ]
	inc bl
	Int21 IoControl, 09h				; is drive remote ?
	jc RxDOS_WRITESTUB_40				; ignore possible unsupported error -->

	test dx, 1000h					; remote flag set ?
	jnz RxDOS_WRITESTUB_InvalidDrive		; cannot set invalid drive -->

		; Write message
RxDOS_WRITESTUB_40:
	mov dl, byte [ _drive + bp ]
	add dl, 'A'
	mov byte [ RxDOS_PressKeyWhenReady_Drive ], dl

	cmp word [ _SilentMode + bp ], byte 0		; silent mode ?
	jnz RxDOS_WRITESTUB_46				; ok to write -->

	mov si, RxDOS_PressKeyWhenReady
	call _DisplayMsg

RxDOS_WRITESTUB_42:
	mov ah, 08h
	int 21h						; wait for character from StdIn
	call getanswer
	jnz RxDOS_WRITESTUB_42				;  Loop if no answer found

	pushf
	mov ah, 02h
	mov dl, al
	int 21h						; display answer
	popf

	ifc RxDOS_WRITESTUB_80				; Answer was no -->
							;  otherwise: Yes, proceed
RxDOS_WRITESTUB_46:
	push cs
	pop es						; restore es

RxDOS_WRITESTUB_48:

	xor dx, dx
	mov dl, byte [ _drive + bp ]			; pass drive
	mov ax, word [ _UseDevice + bp ]		; pass UseDevice flag
	mov cx, DEVICEREAD				; read
	mov bx, _rwBUFFER				; to there
	call _DeviceReadWrite

	jc RxDOS_WRITESTUB_68				; if error -->

	cld
	mov si, _rwBUFFER + _bsBytesPerSector
	mov di, eop + _bsBytesPerSector
	mov cx, ( _bsDriveNumber - _bsBytesPerSector )
	repe movsb					; copy these parameters

	mov si, RxDOS_OEMNAME
	mov di, eop + _bsOemName
	mov cx, 8
	repe movsb					; copy OEM identifier

	push es
	xor ax, ax
	mov es, ax
	mov ax, word [ es:46Ch ]
	mov dx, word [ es:46Eh ]			; Actually it should be some mix of DOS date/time
							;  We just use the tick value as serial number
	pop es

	mov word [ _bsVolumeId + eop + _High ], dx
	mov word [ _bsVolumeId + eop + _Low ], ax

	xor dx, dx
	mov dl, byte [ _drive + bp ]			; pass drive
	mov ax, word [ _UseDevice + bp ]		; pass UseDevice flag
	mov cx, DEVICEWRITE				; write
	mov bx, eop					; from here
	call _DeviceReadWrite

	jnc RxDOS_WRITESTUB_72				; if everything is ok -->

RxDOS_WRITESTUB_68:
	cmp word [ _SilentMode + bp ], byte FALSE
	je RxDOS_WRITESTUB_70
	mov ax, 4C04h					; Terminate silent
	int 21h

RxDOS_WRITESTUB_70:
	mov si, RxDOS_diskA_NotReadyOrError
	call _DisplayMsg
	jmp short RxDOS_WRITESTUB_76

		; success. try again ?
RxDOS_WRITESTUB_72:
	mov si, RxDOS_diskA_WrittenSuccesfully
	call _DisplayMsg
	cmp word [ _WriteOnce + bp ], byte TRUE
	jz RxDOS_WRITESTUB_80

	mov si, RxDOS_diskA_WriteAnother
	call _DisplayMsg

RxDOS_WRITESTUB_76:
	mov ah, 08h
	int 21h						; wait for character from StdIn
	call getanswer
	jnz RxDOS_WRITESTUB_76				;  Loop if no answer found

	pushf
	mov ah, 02h
	mov dl, al
	int 21h						; display answer
	popf

	ifnc RxDOS_WRITESTUB_40				; Answer was yes -->
							;  otherwise: No
RxDOS_WRITESTUB_80:
	Int21 TerminateProcess, 00


		; Read or write boot sector, using device or Int25/Int26
		;
		; INP:	ax = UseDevice flag (if 0, use Int25 or Int26)
		;	cx = DEVICEWRITE or DEVICEREAD
		;	cs:bx-> Buffer
		;	dx = drive (0 = A:, ...)
		; OUT:	NC if no error
		;	if ax<>0, CY if DPB invalid or invalid device in DPB or device reported error
		;	if ax=0, CY if Int25 or Int26 returned an error
_DeviceReadWrite:
	or ax, ax
	jnz _DeviceReadWrite_Device			; Device flag set, go call device -->

	mov al, dl					; drive passed in dl
	xor dx, dx					; sector number 0
	cmp cx, DEVICEWRITE				; write ? ...
	mov cx, 1					; one sector
	setds cs					; make sure ds is correct
	jne _DeviceReadWrite_02				; ...else read -->
	int 26h
	db 0A9h						; "test ax, imm16" (skip "int imm8" opcode)

_DeviceReadWrite_02:
	int 25h
	sbb dx, dx					; 0 if NC, -1 if CY
	popf						; flags left on stack
	cmp dx, byte -1					; if it's -1, NC
							;  else CY
	cmc						; reverse CY/NC
	retn


_DeviceReadWrite_Device:
	entry
	ddef	DPB
	ddef	strategy
	ddef	interrupt

	push ds
	push bx
	inc dx						; 1 = A:, ...
	Int21 GetDriveParameterBlock			; get pointer to drive data
	stordarg _DPB, ds, bx				; drive parameter block

	cmp al, -1					; invalid drive or error ?
	pop ax						; (buffer address)
	pop ds
	jnz _DeviceReadWrite_04				; no, ok -->
	stc
	return

_DeviceReadWrite_04:

	getdarg es, si, _DPB				; drive parameter block

	mov bx, _ReqBlock
	mov byte [ bx + rwrFunction ], cl

	dec dx						; 0 = A:, ...
	mov byte [ bx + rwrUnit ], dl
	mov byte [ bx + rwrLength ], sizeREADReqHeader

	mov word [ bx + rwrBuffer + _pointer ], ax	; buffer address
	mov word [ bx + rwrBuffer + _segment ], cs
	mov word [ bx + rwrVolumeID + _pointer ], _rwVOLBUFFER
	mov word [ bx + rwrVolumeID + _segment ], cs

	mov al, byte [ es:si + _dpbMediaDescriptor ]
	mov byte [ bx + rwrMediaID ], al

	mov word [ bx + rwrBytesReq ], 1		; one sector
	mov word [ bx + rwrStartSec ], 0000		; address
	mov word [ bx + rwrHugeStartSec + _high ], 0000
	mov word [ bx + rwrHugeStartSec + _low ], 0000

		; cs:_ReqBlock-> filled request header

	lds dx, [ es:si + _dpbptrDeviceDriver ]
	Int21 GetDosDataTablePtr
	add bx, byte 22h

		; ds:dx-> Requested device header
		; es:bx-> List of List's NUL device

_DeviceReadWrite_08:
		; ds:dx-> Requested device header
		; es:bx-> Address to next device header, if valid
	les bx, [ es:bx ]				; es:bx-> next device header

		; let's check if we're at the end of the device header chain
	push bx
	mov bx, es
	inc bx						; segment 0FFFFh ?
	jz _DeviceReadWrite_12
	dec bx						; segment 0000h ?
	jz _DeviceReadWrite_12
	pop bx
	inc bx						; pointer 0FFFFh ?
	jz _DeviceReadWrite_14
	dec bx						; pointer 0000h allowed !

		; ds:dx-> Requested device header
		; es:bx-> A valid device header
		;
		; let's check if they match
	cmp bx, dx					; pointers match ?
	jne _DeviceReadWrite_08				; no, try next -->
	push bx
	push dx
	mov dx, ds
	mov bx, es
	cmp bx, dx					; segments match ?
	pop dx
	pop bx
	jne _DeviceReadWrite_08				; no, try next -->

		; (es:bx == ds:dx)-> BLOCK device header
	mov ax, word [ bx + devStrategy ]		; ds:bx also
	stordarg _strategy, ds, ax

	mov ax, word [ bx + devInterrupt ]		; ds:bx also
	stordarg _interrupt, ds, ax

	setes cs
	mov bx, _ReqBlock
	mov word [ bx + rwrStatus ], (OP_EXITERROR| devErrUnknownCommand)
	pushf
	cli
	 push bp
	call far [ bp + _strategy ]			; strategy
	 pop bp
	 push bp
	call far [ bp + _interrupt ]			; interrupt
	 pop bp
	popf

		; Note:	All registers (except cs:ip, ss:sp, bp) could have changed now.
	test word [ _ReqBlock + rwrStatus ], OP_ERROR	; (test sets NC)
	jz _DeviceReadWrite_24				; no error -->

	push bx

_DeviceReadWrite_12:
	pop bx

_DeviceReadWrite_14:
	stc						; else error

_DeviceReadWrite_24:
	setes cs
	setds cs					; restore
	return


		; Display Message
_DisplayMsg:
	lodsb						; get character (ds:si)
	or al, al					; null terminator ?
	jz .return					; done -->

	mov ah, 02h
	mov dl, al
	int 21h
	jmp short _DisplayMsg

.return:
	retn


getanswer:		; INP: al = character
			; OUT: ZR if answer found,
			;       NC if 'Yes'
			;       CY if 'No'
			;      NZ if no answer found
	_uppercase al
	gotos ControlM,	.yes				; Enter		--> Yes
	gotos ' ',	.yes				; Space		--> Yes
	gotos 'Y',	.yes				; 'Y'		--> Yes
	gotos 27,	.no				; Escape	--> No
	gotos ControlC,	.no				; ^C, ^Break	--> No
	gotos 'N',	.no				; 'N'		--> No
.no:
	stc
	retn
.yes:
	clc
	retn

%ifdef DEBUGINT24

int24:
	int3
	jmp far [ cs:pspCritErrorVect ]

%endif

		; Messages
RxDOS_OEMNAME:
	db 'RxDOS7.2'

RxDOS_Usage:
	db 13,10,"RxDOS boot sector write utility"
	db 13,10," Usage: RXD_BOOT[.COM] [drive[:]] [options]"
	db 13,10
	db 13,10," options:"
	db 13,10,"    /1    Don't ask to write to another disk"
	db 13,10,"    /S    Don't display anything"
	db 13,10,"    /D    Use the BLOCK device to access the disk"
	db 13,10,"    /?,/H Display this help message and exit"
	db 13,10,0

RxDOS_InvalidParameter:
	db 13,10,"Invalid parameter",0

RxDOS_PressKeyWhenReady:
	db 13,10,"Press Space to write boot sector to disk "

RxDOS_PressKeyWhenReady_Drive:
	db "A: ", 0

RxDOS_diskA_WrittenSuccesfully:
	db 13,10,"Disk updated.", 0

RxDOS_diskA_WriteAnother:
	db " Would you like to write another? (Y/N) ", 0

RxDOS_diskA_NotReadyOrError:
	db 13,10,"Disk error or drive not ready. Try again? (Y/N) ", 0

RxDOS_InvalidDrive:
	db 13,10,"Drive is invalid. Cannot write boot sector.", 0

RxDOS_NoBootImage:
	db 13,10,"Missing or invalid boot sector at end of program file.", 0

		; Drive Default Data
	
%if 0
		; Not yet used
DriveDefaultData:

	; 360k drive

	dw sizeSector				; __bsBytesPerSector
	db 2					; __bsSectorsPerCluster
	dw 1					; __bsResSectors
	db 2					; __bsNumCopiesFAT
	dw 112					; __bsMaxAllocRootDir
	dw 720					; __bsMaxSectors
	db 0FDh					; __bsMediaDescriptor
	dw 2					; __bsSectorsPerFat
	dw 9					; __bsSectorsPerTrack
	dw 2					; __bsHeads
	dd 0					; __bsHiddenSectors
	dd 0					; __bsHugeSectors

	; 1.2M drive

	dw sizeSector				; __bsBytesPerSector
	db 1					; __bsSectorsPerCluster
	dw 1					; __bsResSectors
	db 2					; __bsNumCopiesFAT
	dw 224					; __bsMaxAllocRootDir
	dw 2400					; __bsMaxSectors
	db 0F9h					; __bsMediaDescriptor
	dw 7					; __bsSectorsPerFat
	dw 15					; __bsSectorsPerTrack
	dw 2					; __bsHeads
	dd 0					; __bsHiddenSectors
	dd 0					; __bsHugeSectors

	; 720k drive

	dw sizeSector				; __bsBytesPerSector
	db 2					; __bsSectorsPerCluster
	dw 1					; __bsResSectors
	db 2					; __bsNumCopiesFAT
	dw 112					; __bsMaxAllocRootDir
	dw 1440					; __bsMaxSectors
	db 0F9h					; __bsMediaDescriptor
	dw 3					; __bsSectorsPerFat
	dw 9					; __bsSectorsPerTrack
	dw 2					; __bsHeads
	dd 0					; __bsHiddenSectors
	dd 0					; __bsHugeSectors

	; 1.44M drive

	dw sizeSector				; __bsBytesPerSector
	db 1					; __bsSectorsPerCluster
	dw 1					; __bsResSectors
	db 2					; __bsNumCopiesFAT
	dw 224					; __bsMaxAllocRootDir
	dw 2880					; __bsMaxSectors
	db 0F0h					; __bsMediaDescriptor
	dw 9					; __bsSectorsPerFat
	dw 18					; __bsSectorsPerTrack
	dw 2					; __bsHeads
	dd 0					; __bsHiddenSectors
	dd 0					; __bsHugeSectors

	dw -1
%endif

		; stack for stub

			align 2,db 0
			times 400h db 0
RxDOS_WRITESTUB_STACK:	dw 0

			align 2,db 0
_ReqBlock:		times sizeREADReqHeader db 0

		; working sector buffer

_rwBUFFER:		times sizeSector db 0
_rwVOLBUFFER:		times sizeSector db 0

eop:
		; The boot sector will appear here after it's appended
		; to the executable file (RXD_BOOT.COM)

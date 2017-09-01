
%if 0

RxDOSIOC - RxDOS Generic IO Control Function 440D Services

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

%if _BUILD_OBJ
	segment RXDOS align=16 class=RXDOS use16 public
	segment RXDOS

	global _IOControl_440D

	extern getDrive
	extern getDPB
	extern _mul32
	extern _RetCallersStackFrame
	extern AmountFreeSpace

	extern pexterrInvalidFunction
	extern pexterrFileNotFound
	extern pexterrPathNotFound
	extern pexterrIllegalName
	extern pexterrNoHandlesAvailable
	extern pexterrAccessDenied
	extern pexterrInvalidHandle
	extern pexterrArenaTrashed
	extern pexterrNotEnoughMemory
	extern pexterrInvalidBlock
	extern pexterrInvalidAccess
	extern pexterrInvalidDrive
	extern pexterrCurrentDirectory
	extern pexterrNoMoreFiles
	extern pexterrFileExists
%endif

		; RxDOS 7.20N:	Structs moved into RXDSTRUC.MAC


		; 440Dh Generic IOCTL
		;
		; Usage:
		; ax	440Dh
		; bl	drive number ( default= 0, A:= 1, ... )
		; ch	category code
		; cl	minor code (function)
		; ds:dx parameter block (returns data if function 60h or 61h)
_IOControl_440D:

	mov al, cl					; get fct minor code

	Goto 60h,	GetDeviceParameters

%if 0
	Goto 40h,	SetDeviceParameters
	Goto 41h,	WriteLogicalDeviceTrack
	Goto 42h,	FormatLogicalDeviceTrack
	Goto 46h,	SetVolumeSerialNumber
	Goto 47h,	SetAccessFlag

	Goto 4Ah,	LockLogicalVolume
	Goto 4Bh,	LockPhysicalVolume

	Goto 61h,	ReadLogicalDeviceTrack
	Goto 62h,	VerifyLogicalDeviceTrack
	Goto 66h,	GetVolumeSerialNumber
	Goto 67h,	GetAccessFlag
	Goto 68h,	SenseMediaType
	Goto 6Ah,	UnlockLogicalVolume
	Goto 6Bh,	UnlockPhysicalVolume
	Goto 6Ch,	GetLockFlag
	Goto 6Dh,	EnumerateOpenFiles
	Goto 6Eh,	FindSwapFile
	Goto 6Fh,	GetDriveMapInformation
	Goto 70h,	GetCurrentLockState
	Goto 71h,	GetFirstCluster
%endif

	mov ax, offset pexterrInvalidFunction
	stc
	retn


		; 440D 60 Get Device Parameters
		;
		; Get Device Parameters
		;
		; cx	buffer size (should equal sizeDPB + 2)
		; dl	drive
		; es:di pointer to buffer
GetDeviceParameters:

	Entry
	ddef	ptrtoBuffer
	def	_size, cx

	mov ax, pexterrInvalidFunction
	cmp cx, sizeExtDPB
	stc
	jnz Get_ExtDPB_return

	xor dh, dh
	mov ax, dx
	call getDPB					; get DPB
	jc Get_ExtDPB_return				; if error -->
	stordarg _ptrtoBuffer, es, bx			; save pointer

		; es:bx -> DPB for drive

	RetCallersStackFrame es, bx
	mov di, word [ es:bx + _DI ]
	mov es, word [ es:bx + _ES ]			; buffer address

	getdarg ds, si, _ptrtoBuffer			; save pointer
	getarg cx, __size

	sub cx, 2
	mov [ es:di ], cx				; set length in WORD
	add di, 2					; bump pointer
	repe movsb					; copy DPB to return address

	or ax, ax					; clear carry

Get_ExtDPB_return:
	retn

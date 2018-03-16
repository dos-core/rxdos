
%if 0

RxDOSF32 - RxDOS FAT32 services

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

	global _Int21Function73

	extern getDrive
	extern getDPB
	extern _mul32
	extern _RetCallersStackFrame
	extern AmountFreeSpace
	extern DefineDPB
	extern GetActualDrive

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
	extern pexterrBadReqStruc
	extern pexterrFileExists
%endif

		; 73xxh FAT32 Get/Set Structures
		;
		; Dispatch on function code services
_Int21Function73:

	Goto FAT32GetExtDPB_,		Get_ExtDPB		; 02h
	Goto FAT32GetExtFreeSpace_,	Get_ExtFreeSpace	; 03h
%if 0
	Goto FAT32SetExtDPBFormatting_,	SetDPB_Format		; 04h
%endif
	Goto FAT32ExtAbsDiskAccess_,	ExtAbsDiskAccess	; 05h

	mov ax, pexterrInvalidFunction
	stc
	retn


		; 7302h Get Extended DPB
		;
		; Get a copy of an Extended DPB (FAT32)
		;
		; cx	buffer size (should equal sizeExtDPB + 2)
		; dl	drive
		; es:di-> buffer
		;
		; Comment of some Microsoft header?:
		; When calling this function with DeviceIoControl, it is
		; recommended that the dwloControlCode parameter be set to
		; VWIN32_DIOC_DOS_IOCTL (see VWIN32.H). For additional infor-
		; mation, see Using VWIN32 to Carry Out MS-DOS Functions.
		;
		; cm: I do not know what this means.
Get_ExtDPB:

	Entry
	ddef	ptrtoBuffer

	mov ax, pexterrBadReqStruc
	cmp cx, byte sizeEXTDPB + 2
	jb Get_ExtDPB_return				; B == CY, so no need to do stc

	xor dh, dh
	mov ax, dx
	call getDPB					; get DPB
	jc Get_ExtDPB_return				; if error -->
	stordarg _ptrtoBuffer, es, bx			; save DPB pointer

	RetCallersStackFrame es, bx
	mov di, word [ es:bx + _DI ]
	push es
	mov es, word [ es:bx + _ES ]			; buffer address

	getdarg ds, si, _ptrtoBuffer			; get pointer
	mov ax, sizeEXTDPB
	stosw						; store used size
	push di
	repe movsb					; copy DPB to return address

	pop di						; es:di-> copied DPB (in user's buffer)
	pop ds						; now ds:bx-> User stack frame again
	cmp word [ bx + _SI ], 0F1A6h			; check signature in si
	je .signature_valid				; valid, return DPB as is -->
	xor ax, ax					; invalid, overwrite Next DPB and driver address
	mov word [ es:di + _dpbNextDPB + _segment ], ax
	mov word [ es:di + _dpbNextDPB + _pointer ], ax
	mov word [ es:di + _dpbptrDeviceDriver + _segment ], ax
	mov word [ es:di + _dpbptrDeviceDriver + _pointer ], ax

.signature_valid:
	clc

Get_ExtDPB_return:
	Return


		; 7303h Get_ExtFreeSpace
		;
		; Returns the total disk space and the free disk space
		;
		; cx	buffer size
		; es:di-> Extended free space structure
		; ds:dx-> ASCIZ path name. Must include drive.
Get_ExtFreeSpace:

	Entry
	ddef	pExtendedFreeSpaceTable

	mov ax, pexterrInvalidFunction
	cmp cx, byte sizeEXTENDEDFREESPACE
	stc
	ifnz Get_ExtFreeSpaceReturn

	RetCallersStackFrame ds, bx
	mov di, word [ _DI + bx ]
	mov es, word [ _ES + bx ]			; buffer address
	stordarg _pExtendedFreeSpaceTable, es, di

	mov si, word [ _DX + bx ]
	mov es, word [ _DS + bx ]			; ASCIZ drive
	call getDrive					; extract drive info
	ifc Get_ExtFreeSpaceReturn			; if error -->

	setDS ss
	call AmountFreeSpace				; DPB in es:bx
	setDS es					; ds:bx

	getdarg es, di, _pExtendedFreeSpaceTable
	clearMemory sizeEXTENDEDFREESPACE		; init return

	mov word [ es:di + _extFreeSize ], sizeEXTENDEDFREESPACE
	mov word [ es:di + _extFreeLevel ], 0

	mov ax, word [ _dpbBytesPerSector + bx ]
	mov word [ es:di + _extFreeBytesPerSector + _low ], ax		; num bytes per sector

	mov cx, word [ _dpbFreeCount + _high + bx ]
	mov dx, word [ _dpbFreeCount + _low + bx ]
	mov word [ es:di + _extFreeAvailableClusters + _low ], dx	; num available clusters
	mov word [ es:di + _extFreeAvailableClusters + _high ], cx	; num available clusters
	mov word [ es:di + _extFreeAvailableAllocationUnits + _low ], dx	; num free allocation units, w/o compression
	mov word [ es:di + _extFreeAvailableAllocationUnits + _high ], cx	; num free allocation units, w/o compression

	mov dx, word [ _dpbxMaxCluster + _low + bx ]
	mov cx, word [ _dpbxMaxCluster + _high + bx ]
	cmp word [ _dpbSectorsPerFat + bx ], byte 0000	; fat32 drive ?
	jz Get_ExtFreeSpace22				; yes -->
	mov dx, word [ _dpbMaxClusterNumber + bx ]
	xor cx, cx

Get_ExtFreeSpace22:
	mov word [ es:di + _extFreeTotalClusters + _low ], dx		; total num clusters for drive
	mov word [ es:di + _extFreeTotalClusters + _high ], cx		; total num clusters for drive
	mov word [ es:di + _extFreeTotalAllocationUnits + _low ], dx	; num total allocation units, w/o compression
	mov word [ es:di + _extFreeTotalAllocationUnits + _high ], cx	; num total allocation units, w/o compression

	mov ax, dx
	mov dx, cx

	xor cx, cx
	mov cl, byte [ _dpbClusterSizeMask + bx ]
	inc cx
	mov word [ es:di + _extFreeSectorsPerCluster + _low ], cx	; num sectors per cluster

	call _mul32
	mov word [ es:di + _extFreeTotalPhysSectors + _low ], ax	; num total physical sectors, w/o compression
	mov word [ es:di + _extFreeTotalPhysSectors + _high ], dx	; num total physical sectors, w/o compression

	mov ax, word [ es:di + _extFreeAvailableClusters + _low ]	; num available clusters
	mov dx, word [ es:di + _extFreeAvailableClusters + _high ]
	call _mul32

	mov word [ es:di + _extFreeAvailablePhysSectors + _low ], ax	; num free physical sectors, w/o compression
	mov word [ es:di + _extFreeAvailablePhysSectors + _high ], dx	; num free physical sectors, w/o compression
	clc

Get_ExtFreeSpaceReturn:
	Return

%if 0
		; 7304h Set/get DPB data, for formatting
		;
		; cx = buffer size
		; dl = drive number (0 = Default, 1 = A:, ...)
		; es:di-> Set_DPBFormat structure
SetDPB_Format:

	push dx
	call GetActualDrive
	jc SetDPB_Format_errordrive

	call getDPB					; es:bx-> requested DPB
	jc SetDPB_Format_errordrive

	RetCallersStackFrame ds, si
	push word [ _ES + si ]
	mov si, word [ _DI + si ]
	pop ds						; ds:si-> user's buffer

	lodsw
	cmp ax, cx
	mov ax, pexterrBadReqStruc
	jb SetDPB_Format_error				; Buffer size given here below? -->

	cmp cx, 8
	jb SetDPB_Format_error				; Buffer size too small -->

	lodsw
	or ax, ax
	jnz SetDPB_Format_error				; other values unknown

	lodsw
	xchg ax, dx
	lodsw
	or ax, ax
	jnz SetDPB_Format_error				; invalid function -->
	xchg ax, dx
	or ah, ah
	jnz SetDPB_Format_error				; invalid function -->
	
	gotos 00h, SetDPB_Format_GetSetFreeCount
	gotos 01h, SetDPB_Format_RebuildDPB
	gotos 02h, SetDPB_Format_MediaChange
	gotos 03h, SetDPB_Format_GetSetFAT32flags
	gotos 04h, SetDPB_Format_GetSetFAT32root

	mov ax, pexterrInvalidFunction

SetDPB_Format_error:
	stc
	retn
	
SetDPB_Format_errordrive:
	mov ax, pexterrInvalidDrive
	jmp short SetDPB_Format_error

SetDPB_Format_errorbadstruc:
	mov ax, pexterrBadReqStruc
	jmp short SetDPB_Format_error


SetDPB_Format_GetSetFreeCount:
		; ds:si-> structure
		; es:bx-> DPB
		;
		; freecount:	resd 1	; 0 to leave unchanged, -1 = unknown
		; nextfree:	resd 1	; 0 to leave unchanged, -1 = unknown

		; RxDOS 7.30: Should -1 cause us to count the actual value?

	cmp cx, 16
	jb SetDPB_Format_errorbadstruc
	
	call getdword
	push dx
	push ax
	call getdword					; dx:ax = Next free
	pop cx
	pop di						; di:cx = Free count
	
	push cx
	or cx, di
	pop cx
	jz .free_end					; if the dword is 0 don't update -->
	mov word [ es:bx + _dpbFreeCount + _low ], cx

	cmp word [ es:bx + _dpbSectorsPerFat ], byte 0
	jnz .free_end					; if not FAT32 done -->
	mov word [ es:bx + _dpbFreeCount + _high ], di	; else set high word as well

.free_end:
	push ax
	or ax, dx
	pop ax
	jz .next_end					; if the dword is 0 don't update -->

	cmp word [ es:bx + _dpbSectorsPerFat ], byte 0
	jnz .next_fat16					; if not FAT32 -->

.next_fat32:
	mov word [ es:bx + _dpbxNextFreeCluster + _low ], ax
	mov word [ es:bx + _dpbxNextFreeCluster + _high ], dx
	jmp short .next_end

.next_fat16:
	mov word [ es:bx + _dpbNextFree ], ax

.next_end:
	clc
	retn


SetDPB_Format_RebuildDPB:
		; ds:si-> structure
		; es:bx-> DPB
		;
		; unused:	resd 1
		; bpb:		resd 1		; -> source BPB

	cmp cx, 16
	jb SetDPB_Format_errorbadstruc

	lodsw
	lodsw						; ignore a dword
	call getdword					; dx:ax-> source BPB
	
	push dx
	push ax
	push es
	push bx						; push address to BPB and DPB buffer
	call DefineDPB
	retn


SetDPB_Format_MediaChange:
		; ds:si-> structure
		; es:bx-> DPB

	mov byte [ es:bx + _dpbAccessFlag ], -1
	clc
	retn


SetDPB_Format_GetSetFAT32flags:
		; ds:si-> structure
		; es:bx-> DPB

		; RxDOS 7.30:	This should likely fill in FAT copies when
		;		 they're enabled.

	cmp cx, 16
	jb SetDPB_Format_errorbadstruc

	call getdword

	cmp word [ es:bx + _dpbSectorsPerFat ], byte 0
	jnz .fat16
	
	push ax
	and ax, dx
	inc ax
	pop ax
	push word [ es:bx + _dpbxFlags ]		; previous value to return
	jz .get						; if the dword is -1 just get -->
	mov word [ es:bx + _dpbxFlags ], ax
.get:
	pop ax

.return:
	mov word [ si + _low ], ax
	mov word [ si + _high ], 0
	clc
	retn

.fat16:							; if FAT16, do nothing and return zero flags
	xor ax, ax
	jmp short .return


SetDPB_Format_GetSetFAT32root:
		; ds:si-> structure
		; es:bx-> DPB

		; RxDOS 7.30:	Missing implementation.

	cmp cx, 16
	jb SetDPB_Format_errorbadstruc

	call getdword

	push ax
	and ax, dx
	inc ax
	pop ax
	jz .get
;*****
%endif

		; INP:	ax = 7305h
		;	cx = FFFFh (ignored by us)
		;	dl = drive number (01h = A:)
		;	si & 1 == 0 if read, == 1 if write
		;	ds:bx -> disk packet, struc DISKIO
		;	dword [ds:bx + diskioStartSector] = sector number
		;	word [ds:bx + diskioSectors] = number of sectors
		;	dword [ds:bx + diskioBuffer] = buffer pointer
ExtAbsDiskAccess:
	cmp dl, 0
	je .invalid_drive
	mov al, dl
	dec ax
	mov cx, -1
	test si, 1
	jz .read
.write:
	mov si, DevWrite
	jmp @F
.read:
	mov si, DevRead
@@:
	push es
	pop ds
	mov di, bx
	call int_25_26_217305_common

	pushf
	RetCallersStackFrame ds, bx
	mov word [ bx + _AX ], ax
	popf
	retn

.invalid_drive:
	mov ax, 0101h		; ah = 01h "bad command",
				; al = 01h "unknown unit for driver"
	stc
	retn



%if 0

RxDOSFCB - RxDOS FCB processing support

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

(c) Copyright 1990, 1999. Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

%include "RXDMACRO.NEW"
%include "RXDSTRUC.NEW"

	cpu 8086

%if _BUILD_OBJ
	segment RXDOS align=16 class=RXDOS use16 public
	segment RXDOS

	global initFCBfromSFT
	global buildFindFromFCB
	global buildDTAfcbFind

	extern CopyBlock
	extern GetActualDrive
	extern getCurrDirCluster
	extern locateCCBPHeader

	extern _RxDOS_pDTA
%endif

		; Init FCB from an opened SFT
		;
		; Usage:
		; ds:si	FCB pointer
		; es:di	SFT pointer
		; ax	handle assigned
initFCBfromSFT:
	mov byte [ fcbSFN + si ], al
	mov word [ fcbRecordSize + si ], 128

	xor dx, dx
	mov word [ fcbRandomRecNo + _low + si ], dx
	mov word [ fcbRandomRecNo + _high + si ], dx
	mov word [ fcbCurrBlockNo + si ], dx
	mov word [ fcbCurrRecNo + si ], dx
	mov byte [ fcbFlags + si ], dl

	mov dx, word [ es:di + sftFileSize + _high ]
	mov ax, word [ es:di + sftFileSize + _low ]
	mov word [ fcbFileSize + _high + si ], dx
	mov word [ fcbFileSize + _low + si ], ax

	mov dx, word [ es:di + sftDate ]
	mov ax, word [ es:di + sftTime ]
	mov word [ fcbDate + si ], dx
	mov word [ fcbTime + si ], ax

	mov dx, word [ es:di + sftDCB + _high ]
	mov ax, word [ es:di + sftDCB + _low ]
	mov word [ fcbDHD + _high + si ], dx
	mov word [ fcbDHD + _low + si ], ax

	mov ax, word [ es:di + sftBegCluster ]
	mov word [ fcbBegClusterNo + si ], ax

	or word [ es:di + sftMode ], sftENTRY_ISFCB
	retn


		; Init Find Record from an FCB
		;
		; Usage:
		; stack	pointer to FCB
		; stack	pointer to find record
		; dx	dir offset to insert
		;
		; Returns:
		; es:di	points to find record
buildFindFromFCB:

	Entry 4
	darg	fcb
	darg	findEntry
	def	dirOffset, dx
	def	attributes, 0000

	saveRegisters ds, si, bx

		; if we have an extended FCB
	getdarg es, bx, _fcb
	cmp byte [ es:bx + extSignature ], -1		; do we have an extended FCB ?
	jnz buildFindFromFCB_08				; no -->

	mov al, byte [ es:bx + extAttribute ]		; get attributes from extended FCB
	mov byte [ _attributes + bp ], al
	add bx, byte sizeExtendedFCBHdr
	mov word [ _fcb + _pointer + bp ], bx		; adjust to FCB address

		; if we have a normal FCB
buildFindFromFCB_08:
	push ds
	setDS es
	lea si, [ byte fcbName + bx ]

	getdarg es, di, _findEntry
	lea di, [ byte findSrchName + di ]
	mov cx, sizeFILENAME

buildFindFromFCB_12:
	lodsb						; get character
	_upperCase al					; upper case
	stosb
	loop buildFindFromFCB_12

	pop ds
	getdarg es, bx, _fcb
	push word [ es:bx + fcbDrive ]
	call GetActualDrive				; correct drive
	call getCurrDirCluster

	getdarg es, di, _findEntry
	mov word [ es:di + findDirBegCluster + _low ], dx
	mov word [ es:di + findDirBegCluster + _high ], cx
	mov byte [ es:di + findSrchDrive ], al		; store drive

	mov al, byte [ _attributes + bp ]
	mov byte [ es:di + findSrchAttributes ], al

	mov ax, word [ _dirOffset + bp ]
	mov word [ es:di + findDirEntry ], ax

	restoreRegisters bx, si, ds
	Return


		; Build DTA record from FCB/find entry
		;
		; Usage:
		; stack	pointer to FCB
		; stack	pointer to find record
		;
		; Returns:
		; es:di	points to find record
buildDTAfcbFind:
	Entry 4
	darg	fcb
	darg	findEntry

	currSegment ds				; point to current segment
	lds di, [ _RxDOS_pDTA ]			; build DTA area

		; extended FCB passed ?
	getdarg es, bx, _fcb			; FCB address
	cmp byte [ es:bx + extSignature ], -1
	jnz _buildDTAfcbFind_12			; if not an extended FCB -->

	push es
	push bx					; extended FCB
	push ds
	push di					; DTA
	mov cx, sizeExtendedFCBHdr
	call CopyBlock				; copy 
	add di, byte sizeExtendedFCBHdr		; DTA pointer
	add bx, byte sizeExtendedFCBHdr		; FCB pointer

		; copy directory entry
_buildDTAfcbFind_12:
	push es
	push bx					; address of FCB (adjusted)

	getdarg es, si, _findEntry
	mov al, byte [ es:si + findSrchDrive ]
	mov byte [ findSrchDrive + di ], al
	inc byte [ findSrchDrive + di ]		; FCB drive is 01 ...

	lea di, [ byte findSrchName + di ]
	push di					; where to copy dir structure
	mov si, word [ es:si + findCCBPointer ]
	call locateCCBPHeader			; get buffers segment
	pop di					; restore di (DTA pointer)

	push es
	push si					; from directory entry
	push ds
	push di					; to DTA
	mov cx, sizeDIRENTRY
	call CopyBlock				; copy dir entry

		; update FCB for search next
	pop bx
	pop ds
	getdarg es, si, _findEntry
	mov cx, word [ es:si + findDirEntry ]
	mov word [ fcbCurrRecNo + bx ], cx
	mov dx, word [ es:si + findDirBegCluster + _low ]
	mov word [ fcbBegClusterNo + bx ], dx

	currSegment ds				; point to current segment
	clc

	Return

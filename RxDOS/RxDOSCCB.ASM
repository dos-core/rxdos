
%if 0

RxDOSCCB - RxDOS CCB cache and buffer manager

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

(c) Copyright 1990, 1999. Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

	cpu 8086

	segment RXDOS align=16 class=RXDOS use16 public
	segment RXDOS

%include "RXDMACRO.MAC"
%include "RXDSTRUC.MAC"

	global CCBChanged
	global SetCCBChanged
	global invalidateBuffers
	global linkBegCCB
	global locateCCBPHeader
	global readBuffer
	global readFATBuffer
	global readSelBuffer
	global SelBuffer
	global unlinkCCB
	global updateAllChangedCCBBuffers
	global updateCCB
	global updateChangedCCB
	global updateDriveBuffers

	extern DevRead
	extern DevWrite
	extern getAddrDPB
	extern _RxDOS_BufferList
	extern _RxDOS_pCDS
	extern _DebugInterruptTrap


		; Selected Buffer
		;
		; Input:
		; ax = drive
		; cx:dx = sector to read
		;
		; Output:
		; es:di-> selected buffer
		; NZ if buffer contains valid data
SelBuffer:

	SaveRegisters ax, bx, cx, dx

	les di, [ ss:_RxDOS_BufferList ]
	mov bx, -1

selBuffer_04:
	test byte [ es:di + ccbStatus  ], ( ccb_isVALID )
	jz selBuffer_08					; unallocated buffer -->

	cmp byte [ es:di + ccbDrive ], al		; compare drives
	jnz selBuffer_08				; not this block, try next -->

	cmp cx, word [ es:di + ccbLBN + _high ]		; compare logical block numbers
	jnz selBuffer_08				; not this block, try next -->
	cmp dx, word [ es:di + ccbLBN + _low ]		; compare logical block numbers
	jz selBuffer_36					; buffer located -->

selBuffer_08:
	test byte [ es:di + ccbStatus ], ( ccb_isONHOLD )
	jnz selBuffer_12				; if on hold, don't use -->
	mov bx, di					; save last buffer address

selBuffer_12:
	mov di, word [ es:di + ccbNext ]
	cmp di, byte -1
	jnz selBuffer_04
	
		; if could not find a matching buffer, find an empty buffer
	mov di, bx
	cmp di, byte -1					; buffer address available ?
	jnz selBuffer_30				; use the last referenced buffer -->

	les di, [ ss:_RxDOS_BufferList ]		; else must search buffers again

selBuffer_16:
	test byte [ es:di + ccbStatus ], ( ccb_isVALID )
	jz selBuffer_32					; unallocated buffer -->

	cmp word [ es:di + ccbNext ], byte -1
	jz selBuffer_30					; must write all, use least used -->
	mov di, word [ es:di + ccbNext ]
	jmp short selBuffer_16 

		; prepare returned buffer
selBuffer_30:
	call updateCCB					; just in case update required

selBuffer_32:
	mov byte [ es:di + ccbDrive ], al		; set drive
	mov word [ es:di + ccbLBN + _high ], cx		; set logical block number
	mov word [ es:di + ccbLBN + _low ], dx		; set logical block number
	mov byte [ es:di + ccbStatus ], 0		; clear status
	call setFlagIfDriveIsRemote			; sets remote flag

	push es
	push di
	call getAddrDPB					; pointer to DPB
	mov dx, es					; pointer was in es:bx

	pop di
	pop es
	mov word [ es:di + ccbDPB + _segment ], dx
	mov word [ es:di + ccbDPB + _pointer ], bx

selBuffer_36:
	cmp di, word [ ss:_RxDOS_BufferList + _pointer ]
	jz selBuffer_38					; if already at beginning -->

	call unlinkCCB					; unlink CCB buffer
	call linkBegCCB					; link to front of CCB chain

selBuffer_38:
	test byte [ es:di + ccbStatus ], ( ccb_isVALID )
	RestoreRegisters dx, cx, bx, ax
	retn


		; Is Drive Remote
		;
		; al = drive
		; es:di-> CCB buffer
setFlagIfDriveIsRemote:

	push ax
	push di
	push es

	mov cl, sizeCDS
	mul cl						; ax contains drive's entry in CDS
	les di, [ ss:_RxDOS_pCDS ]			; actual address of CDS
	add di, ax					; current drive
	test word [ es:di + _cdsFlags ], _CDS_NETWORKEDDRIVE	
	pop es
	pop di
	jz IfDriveIsRemote_12				; if not remote -->

	or byte [ es:di + ccbStatus ], ( ccb_isREMOTE )

IfDriveIsRemote_12:
	pop ax
	retn


		; Remove CCB Buffer from Linked List
		;
		; es:di-> CCB buffer
unlinkCCB:

	pushf						; save current interrupt status
	push ax
	push di
	cli						; disable interrupts

	mov ax, word [ es:di + ccbPrev ]
	mov di, word [ es:di + ccbNext ]
	cmp ax, byte -1					; no previous ?
	jnz unlinkCCB_06				; no -->
	mov word [ ss:_RxDOS_BufferList + _pointer ], di	; update beg of list if no previous

unlinkCCB_06:
	cmp di, byte -1					; no next pointer ?
	jz unlinkCCB_08					; skip removing its Prev pointer ->
	mov word [ es:di + ccbPrev ], ax		; next's prev fixed.

unlinkCCB_08:
	cmp ax, byte -1					; no previous ?
	jz unlinkCCB_12					; no -->
	xchg di, ax
	mov word [ es:di + ccbNext ], ax		; prev's next fixed.

unlinkCCB_12:
	pop di
	mov word [ es:di + ccbPrev ], -1		; unlink current pointers
	mov word [ es:di + ccbNext ], -1
	pop ax
	popf						; restore interrupt status
	retn


		; Link CCB Buffer to Beginning of List
		;
		; es:di-> CCB buffer 
linkBegCCB:

	pushf						; save current interrupt status
	push ax
	cli						; disable interrupts

	mov ax, di
	les di, [ ss:_RxDOS_BufferList ]
	cmp ax, di					; relinking CCB buffer to beg of list ?
	jz linkBegCCB_08				; yes, don't do it -->

	mov word [ es:di + ccbPrev ], ax		; previous to orig prev

	xchg di, ax
	mov word [ es:di + ccbNext ], ax		; this next to old next
	mov word [ es:di + ccbPrev ], -1		; current no more previous
	
	mov word [ ss:_RxDOS_BufferList + _pointer ], di

linkBegCCB_08:
	pop ax
	popf
	retn


		; Mark CCB buffer changed
		;
		; bx-> anywhere inside a valid buffer
SetCCBChanged:

	push di
	push si
	push bx
	mov si, bx
%if 0
		; RxDOS 7.20N:	Validate given segment matches our buffer segment.
		; RxDOS 7.20N:	RxDOSFCB needs that we don't compare the segment. The used
		;		FINDENTRY structure doesn't have space for the segment.
	mov bx, es
	cmp bx, word [ ss:_RxDOS_BufferList + _segment ]
	stc
	jne .invalid
%endif
	call locateCCBPHeader
%if 0
		; RxDOS 7.20N:	Abort if not located
	jc .invalid
%endif
	call CCBChanged

.invalid:

	pop bx
	pop si
	pop di
	retn


		; Mark CCB buffer changed
		;
		; es:di-> selected buffer
CCBChanged:

	or byte [ es:di + ccbStatus ], ( ccb_isDIRTY + ccb_isVALID )
	and byte [ es:di + ccbStatus ], ~ ( ccb_isONHOLD )
	retn


		; Locate from reference actual start of CCB buffer
		;
		; Input:
		; si-> into a CCB buffer
		;
		; Output:
		; es:di-> CCB Header
		; cx = offset from start of data
locateCCBPHeader:

	les di, [ ss:_RxDOS_BufferList ]

locateCCBPHeader_04:
	mov cx, si
	sub cx, di					; how far from start of buffer

	jb locateCCBPHeader_08				; go to next -->
	cmp cx, sizeCCB					; within a CCB buffer ?
	ja locateCCBPHeader_08				; go to next -->

	clc
	retn

locateCCBPHeader_08:
	mov di, word [ es:di + ccbNext ]
	cmp di, byte -1
	jnz locateCCBPHeader_04

	stc
	retn


		; Read Buffer
		;
		; Input:
		; ax	drive
		; cx:dx	sector to read
		;
		; Output:
		; es:di	pointer to selected buffer
readBuffer:

	call SelBuffer					; find a buffer
	jnz readBuffer_08				; if buffer is valid -->

	call readSelBuffer				; else read buffer

readBuffer_08:
	retn


		; Read FAT Buffer
		;
		; Input:
		; ax = drive
		; cx:dx = sector to read
		;
		; Output:
		; es:di-> selected buffer
readFATBuffer:

	call SelBuffer					; find a buffer
	jnz readFATBuffer_08				; if buffer is valid -->
	call readSelBuffer				; else read buffer

readFATBuffer_08:
	retn


		; Read Selected Buffer
		;
		; Input:
		; es:di-> selected buffer
		; cx:dx = sector to read
		; ax = drive
		;
		; Output:
		; es:di-> selected buffer
		; cx:dx = sector to read
readSelBuffer:

	SaveAllRegisters

	push di
	push es
	mov byte [ es:di + ccbDrive ], al		; set drive
	mov word [ es:di + ccbLBN + _high ], cx		; set logical block number
	mov word [ es:di + ccbLBN + _low ], dx		; set logical block number
	mov byte [ es:di + ccbStatus ], 00		; kill entry's value, validity

	mov bx, 0001
	lea di, [ byte ccbData + di ]			; buffer address
	call DevRead					; read buffer

	pop es
	pop di
	jc readSelBuffer_08				; if error -->
	mov byte [ es:di + ccbStatus ], (ccb_isVALID)

readSelBuffer_08:
	RestoreAllRegisters
	retn


		; Update CCB buffer, always
		;
		; es:di-> selected buffer
		; All Registers Preserved
updateCCB:

	test byte [ es:di + ccbStatus ], ( ccb_isVALID )
	jz updateCCB_08					; data not valid -->
	test byte [ es:di + ccbStatus ], ( ccb_isDIRTY )
	jnz updateChangedCCB				; data valid and changed -->

updateCCB_08:
	retn


		; Update Changed CCB buffer.
		;
		; es:di	pointer to selected buffer
		; All Registers Preserved
		;
		; CY returned in fail in write
 updateChangedCCB:

	entry
	ddef	buffer, es, di

	SaveAllRegisters

	mov bx, 0001
	mov dx, word [ es:di + ccbLBN + _low ]		; get sector
	mov cx, word [ es:di + ccbLBN + _high ]
	mov al, byte [ es:di + ccbDrive ]		; get drive number
	cbw						;  make ah = 0
	lea di, [ byte ccbData + di ]			; buffer address
	call DevWrite					; write to disk 
	jc updateCCB_12					; if error/ fail -->

	les di, [ _buffer + bp ]
	test byte [ es:di + ccbStatus ], ( ccb_isFAT )
	jz updateCCB_12					; not a FAT buffer -->
	call updateAlternateFATTables			; update FAT tables
	; jc updateCCB_12				; if error/ fail -->

updateCCB_12:
	pushf
	les di, [ _buffer + bp ]
	and byte [ es:di + ccbStatus ], ~ ( ccb_isDIRTY + ccb_isONHOLD )
	popf						; keep flag, but kill error buffer

	RestoreAllRegisters
	return


		; Update Alternate FAT Table
		;
		; Given a FAT sector address, copies the sector to the
		; alternate FAT Table.
		;
		; Input:
		; es:di-> FAT CCB Buffer
updateAlternateFATTables:

	entry
	ddef	ccb, es, di
	def	dpbNumberFat
	ddef	dpbFATSectors

	test byte [ es:di + ccbStatus ], ( ccb_isFAT )
	jz updateAlternateFATTables_22			; not a FAT designated sector -->

	xor dx, dx
	les bx, [ es:di + ccbDPB ]			; get assigned DPB
	mov ax, word [ es:bx + _dpbSectorsPerFat ]
	or ax, ax
	jnz updateAlternateFATTables_08

	mov dx, word [ es:bx + _dpbxSectorsPerFat + _high ]
	mov ax, word [ es:bx + _dpbxSectorsPerFat + _low ]

updateAlternateFATTables_08:
	stordarg _dpbFATSectors, dx, ax

	mov ah, 0
	mov al, byte [ es:bx + _dpbNumCopiesFAT ]
	storarg _dpbNumberFat, ax

	getdarg es, di, _ccb
	mov dx, word [ es:di + ccbLBN + _low ]		; get original sector
	mov cx, word [ es:di + ccbLBN + _high ]
	mov al, byte [ es:di + ccbDrive ]		; get drive number
	cbw						;  make ah = 0
	lea di, [ byte ccbData + di ]			; buffer address

updateAlternateFATTables_12:
	dec word [ _dpbNumberFat + bp ]
	jle updateAlternateFATTables_22			; if not more than 1 -->

	mov bx, 0001
	add dx, word [ _dpbFATSectors + _low + bp ]	; adjust for fat size
	adc cx, word [ _dpbFATSectors + _high + bp ]
	SaveRegisters es, di, dx, cx, ax
	call DevWrite
	RestoreRegisters ax, cx, dx, di, es
	jnc updateAlternateFATTables_12

updateAlternateFATTables_22:
	return


		; Update All Drive Buffers
		;
		; Input:
		; ax = drive
updateDriveBuffers:

	les di, [ ss:_RxDOS_BufferList ]

updDriveBuffer_04:
	test byte [ es:di + ccbStatus ], ( ccb_isVALID )
	jz updDriveBuffer_16				; not a valid block -->
	cmp byte [ es:di + ccbDrive ], al		; compare drives
	jnz updDriveBuffer_16				; not this block, try next -->
	call updateCCB					; update block if changed

updDriveBuffer_16:
	mov di, word [ es:di + ccbNext ]
	cmp di, byte -1
	jnz updDriveBuffer_04

	retn


		; Update All Changed Buffers
updateAllChangedCCBBuffers:

	pushf
	SaveAllRegisters
	les di, [ ss:_RxDOS_BufferList ]

updateAllChanged_04:
	test byte [ es:di + ccbStatus ], ( ccb_isVALID )
	jz updateAllChanged_16				; not a valid buffer -->
	call updateCCB					; updated buffer if req'd

updateAllChanged_16:
	mov di, word [ es:di + ccbNext ]
	cmp di, byte -1
	jnz updateAllChanged_04
	
	RestoreAllRegisters
	popf
	retn


		; Invalidate Buffers for Specific Drive
		;
		; Input:
		; ax = drive
invalidateBuffers:

	les di, [ ss:_RxDOS_BufferList ]

invBuffer_04:
	test byte [ es:di + ccbStatus ], ( ccb_isVALID )
	jz invBuffer_16					; not a valid buffer -->
	cmp al, byte [ es:di + ccbDrive ]		; same drive ?
	jnz invBuffer_16				; if not --> 

	and byte [ es:di + ccbStatus ], ~ ( ccb_isVALID )

invBuffer_16:
	mov di, word [ es:di + ccbNext ]
	cmp di, byte -1
	jnz invBuffer_04

	retn

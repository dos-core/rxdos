
%if 0

RxDOSSFT - RxDOS System File Table functions

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

	global createSFTEntry
	global FindAvailableSFTHandle
	global findmatchingFCBSFT
	global FindSFTbyHandle
	global initSFTfromDirEntry
	global InitSFTEntry

	global MapAppToSFTHandle
	global MapSFTToAppHandle
	global releaseSFT
	global VerifyAvailableHandle
	global TestIfMoveHandleTable

	global _SFTCloseAllFiles
	global _SFTCloseFile
	global _SFTCommitFile
	global _SFTCreateFile
	global _SFTOpenFile
	global _SFTReadFile
	global _SFTWriteFile
	global _SFTReadLine
	global invalidateOpenSFTs

	extern CCBChanged
	extern convFilenametoFCBString
	extern devCharRead
	extern devCharWrite
	extern devCharReadLine
	extern devCharWriteLine

	extern fillLogicalBuffer
	extern getDPB
	extern getAddrDPB
	extern getNextClusterDskAccess
	extern getSysDateinDirFormat
	extern initdiskAccess
	extern locateCCBPHeader
	extern LocateFile
	extern LocateFreeDirSlot
	extern readBuffer
	extern readLine
	extern readLogicalBuffer
	extern ReleaseClusterChain
	extern ReleaseClusterChainDskAccess
	extern AllocateCluster
	extern UpdateFreeSpace

	extern incorrectDiskMedia
	extern updateChangedCCB
	extern updateAllChangedCCBBuffers
	extern writeLogicalBuffer
	extern _div32
	extern pspSysHandleTable
	extern sizepspSysHandleTable
	extern _RxDOS_CurrentPSP
	extern _RxDOS_TabPosition
	extern _RxDOS_pFT

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

		; Map SFT handle to application handle
		;
		; INP:	al = SFT handle
		; OUT:	NC if free table entry found,
		;	 ax = application handle
		;	CY if no free table entry found
		;	 ax = extended error pointer
MapSFTToAppHandle:

	SaveRegisters es, si, cx, bx

	call GetProcessHandleTable	; es:si-> PHT, cx = number of entries

	mov bx, si

	jcxz .no_handles
.12:
	cmp byte [ es:si ], -1		; empty slot ?
	jz .16				; yes, allocate -->

	inc si				; next
	loop .12			; continue looping

.no_handles:
	stc
	mov ax, pexterrNoHandlesAvailable	; problem, no application handles left
	jmp short .22			; exit -->

		; allocate process handle
.16:
	mov byte [ es:si ], al		; place SFT handle into PHT entry
	mov ax, si			; PHT entry offset
	sub ax, bx			; calculate PHT index
	clc

		; return
.22:
	RestoreRegisters bx, cx, si, es
	retn


		; Map application handle to SFT handle
		;
		; INP:	ax = application handle
		; OUT:	NC if table entry found and holds valid SFT handle,
		;	 ax = SFT handle
		;	CY if table entry not found or unused,
		;	 ax = 00FFh
	doscode_insure_low_byte_not_0CCh
MapAppToSFTHandle:
	push si
	push es
	push cx
	call GetProcessHandleTable
	add si, ax			; es:si-> selected application handle, if valid
	cmp ax, cx			; compare given handle to maximal
	mov ax, 00FFh			; in case of error
	jae .16				; if given handle too high -->
	mov ah, 0
	mov al, byte [ es:si ]		; get selected application handle

.16:
	pop cx
	pop es
	pop si
	cmp al, 0FFh			; see if it's unused (valid handles are < 0FFh, so they set CY)
	cmc				; invert CF: NC if valid, CY if invalid
	retn


		; Get current application handle table
		;
		; OUT:	es:si-> Application handle table
		;	cx = number of entries in the table
		;	NC if PSP loaded, es:si points to PSP's handle table
		;	CY if no PSP loaded, es:si points to internal handle table
GetProcessHandleTable:
	xor cx, cx			; initialise to empty table
	cmp word [ ss:_RxDOS_CurrentPSP ], byte 1
	jb .ret				; if no PSP found --> (CY)
					; here, NC
	mov es, [ ss:_RxDOS_CurrentPSP ]; get PSP
	mov cx, [ es:pspPHTEntries ]	; get number of PHT entries
	les si, [ es:pspPHTAddress ]	; get PHT address
.ret:
	retn


		; Find available file handle
		;
		; File handles are stored in a dynamic file handles area created
		; on initialization by the RXCONFIG.SYS FILES= command.
		;
		; OUT:	NC if available SFT entry found,
		;	 ax = SFT handle
		;	 es:bx-> available SFT entry
		;	CY if no available SFT entry found,
		;	 ax = extended error pointer
		; CHG:	es, bx, cx
		;
		; The SFT entry is automatically reserved and must be cleared
		; if it won't be used.
FindAvailableSFTHandle:

	Entry
	ddef	currentFT
	def	handle, 0

	les bx, [ ss:_RxDOS_pFT ]			; points to first FT

		; look for available handle
findSFTHandle_08:
	cmp bx, -1
	jz findSFTHandle_22				; no next FT, set error -->

	stordarg _currentFT, es, bx

	mov cx, word [ es:bx + numberSFTEntries ]	; get number of SFT entries in this FT

	lea bx, [ bx + sizeFT ]				; skip FT header
	jcxz findSFTHandle_14.next			; no more SFT entries in this FT?

		; is handle available ?
findSFTHandle_12:
	pushf
	cli
	cmp word [ es:bx + sftRefCount ], byte 0	; entry available ?
	jnz findSFTHandle_14				; no -->
	inc word [ es:bx + sftRefCount ]		; RESERVE ENTRY
	popf

	mov ax, word [ _handle + bp ]			; counted SFT handle number
	clc
	jmp short findSFTHandle_30			; exit -->

findSFTHandle_14:
	popf

	inc word [ _handle + bp ]			; starts with 0. Counts SFT entries
	add bx, byte sizeSFT				; next SFT entry
	loop findSFTHandle_12				; if more in this FT -->

.next:
	les bx, [ _currentFT + bp ]
	les bx, [ es:bx + nextFTPointer ]
	jmp short findSFTHandle_08			; go to next FT -->

		; if out of handles system wide
findSFTHandle_22:
	stc
	mov ax, pexterrNoHandlesAvailable

		; return
findSFTHandle_30:
	Return


		; Find SFT by handle
		;
		; INP:	ax = SFT handle
		; OUT:	NC if SFT handle valid,
		;	 es:di-> SFT entry
		;	CY if SFT handle invalid,
		;	 ax = extended error pointer
		;	 di modified
	doscode_insure_low_byte_not_0CCh
FindSFTbyHandle:

	push ax
	push es
	les di, [ ss:_RxDOS_pFT ]			; point to first FT
	cmp ax, 00FFh					; if not assigned (>= 00FF indicates invalid)
	jae FindSFTbyHandle_12

FindSFTbyHandle_08:
	cmp di, -1					; any next SFTC ?
	je FindSFTbyHandle_12				; no -->

	cmp ax, word [ es:di + numberSFTEntries ]	; number of SFT entries in this FT
	jb FindSFTbyHandle_16				; if within this FT -->

	sub ax, word [ es:di + numberSFTEntries ]
	les di, [ es:di + nextFTPointer ]
	jmp short FindSFTbyHandle_08

		; if error
FindSFTbyHandle_12:
	pop es						; restore es
	pop ax						; throw away ax
	mov ax, pexterrInvalidHandle			; set illegal handle error
	stc
	retn

		; if located handle space
FindSFTbyHandle_16:
	push cx
	mov cl, sizeSFT
	mul cl						; get offset
	add di, byte sizeFT				; point past FT header
	add di, ax					; plus offset

	pop cx						; restore cx
	pop ax						; throw away es
	pop ax						; restore ax
	clc
	retn


		; Release SFT
		;
		; INP:	es:di-> SFT entry
		; OUT:	ZR if reference count already zero or decreased to zero
		;	NZ if reference count decreased but still non-zero or SFT entry protected
releaseSFT:

	cmp word [ es:di + sftRefCount ], byte 0
	jz releaseSFT_14				; already released -->
	cmp word [ es:di + sftRefCount ], byte 1	; is it at one count ?
	jnz releaseSFT_12				; no, decrement count anyway -->
	test word [ es:di + sftDevInfo ], sftProtected	; is the SFT entry protected ?
	jnz releaseSFT_14				; yes, don't decrease reference count to zero -->

releaseSFT_12:
	dec word [ es:di + sftRefCount ]		; decrease reference count by one

releaseSFT_14:
	retn


		; Find matching FCB SFT
		;
		; Input:
		; es:di	FCB address
		;
		; Output:
		; es:di	pointer to matching SFT entry
		;
		; INP:	es:di-> FCB
		; OUT:	NC if suggested SFT still available or new allocated,
		;	 es:di-> Matching SFT entry
		;	 ax = SFT handle
		;	 ZR if suggested SFT was still available and is used
		;	 NZ if new SFT allocated
		;	CY if suggested SFT used otherwise and no new available
		;	 ax = extended error pointer (no handles available)
		; CHG:	dx, cx, bx
		;
		; If the suggested SFN handle inside the FCB doesn't reference
		; the correct file this function tries to allocate a new SFT.
		;
		; Releases <= RxDOS 7.20N don't return ZF
findmatchingFCBSFT:

	Entry
	ddef	fcbaddress, es, di			; FCB pointer
%if 1
	ddef	sftPointer				; SFT pointer
	def	sftHandle				; SFT handle
%endif

	xor ax, ax
%if 0
	mov dx, word [ es:di + fcbDPB + _pointer ]
	push dx
	mov dx, word [ es:di + fcbDPB + _segment ]	; DPB/Device header address
	push dx
%endif
	mov dx, word [ es:di + fcbBegClusterNo ]	; Beginning cluster if file, else 0
	mov al, byte [ es:di + fcbSFT ]			; suggested SFT handle

	call FindSFTbyHandle				; locate matching SFT
	jc findmatchingFCBSFT_08			; if cannot locate SFT -->

	cmp dx, word [ es:di + sftBegCluster + _low ]
%if 1
	ifz findmatchingFCBSFT_26			; if entry matches -->

		; if not found, try to allocate new SFT
findmatchingFCBSFT_08:
%else
		; RxDOS 7.20N:	Check also for matching DPB/Device header. (This
		;		is required for character device FCBs!)
	jnz findmatchingFCBSFT_08			; if beginning cluster doesn't match -->
	pop dx
	cmp dx, word [ es:di + sftDPB + _segment ]
	pop dx
	jnz findmatchingFCBSFT_04			; if DPB/Device header segment doesn't match -->
	cmp dx, word [ es:di + sftDPB + _pointer ]
	ifz findmatchingFCBSFT_26			; if anything matched -->
							;  (flags are ZR and NC)
findmatchingFCBSFT_04:
	push dx
	push dx						; stack up something and fall through

		; if not found, try to allocate new SFT
findmatchingFCBSFT_08:
	pop dx
	pop dx						; throw away stacked values
%endif

	call FindAvailableSFTHandle
	ifc findmatchingFCBSFT_26			; if no SFT entry available -->

%if 1
	storarg	_sftHandle, ax				; SFT handle
	stordarg _sftPointer, es, bx			; SFT pointer
%endif

	push ds

		; clear SFT
%if 1
	xor ax, ax
	mov di, bx					; pointer to SFT
	add di, byte 2					; skip the reference count
	mov cx, (sizeSFT - 2)/ 2			; anything except the reference count
	repe stosw					; must have pointer at es:di

	getdarg ds, si, _fcbAddress			; FCB address
	getdarg es, di, _sftPointer			; SFT pointer
	or word [ es:di + sftMode ], sftENTRY_ISFCB

		; set owner PSP
	mov ax, word [ ss:_RxDOS_CurrentPSP ]		; get owner PSP
	mov word [ es:di + sftPSP ], ax
%else
	call InitSFTEntry				; also sets PSP
	mov di, bx					; es:di-> SFT entry
	or word [ es:di + sftMode ], sftENTRY_ISFCB
	getdarg ds, si, _fcbAddress			; FCB address
%endif	

		; set drive
	mov cl, byte [ fcbDrive + si ]			; get drive
	and cx, byte sftDrivemask				; clear ch
	mov word [ es:di + sftDevInfo ], cx		; include drive

	push word [ fcbTime + si ]			; time last updated
	push word [ fcbDate + si ]			; date last updated
	push word [ fcbBegClusterNo + si ]		; beginning cluster
	push word [ fcbFileSize + _low + si ]		; file size
	push word [ fcbFileSize + _high + si ]		; file size
	push word [ fcbDPB + _pointer + si ]		; DPB/Device header
	push word [ fcbDPB + _segment + si ]

	pop word [ es:di + sftDPB + _segment ]
	pop word [ es:di + sftDPB + _pointer ]
	pop word [ es:di + sftFileSize + _high ]
	pop word [ es:di + sftFileSize + _low ]
	pop word [ es:di + sftBegCluster + _low ]
	mov word [ es:di + sftBegCluster + _high ], 0
	pop word [ es:di + sftDate ]
	pop word [ es:di + sftTime ]

	lea di, [ word sftFileName + di ]		; offset to filename
	lea si, [ word fcbName + si ]			; offset to filename
		; RxDOS 7.20N: force word
	mov cx, sizeFILENAME				; length of name + extension
	repe movsb					; copy name

	pop ds

	getdarg es, di, _fcbAddress			; FCB address
%if 1
	getarg	ax, _sftHandle				; SFT handle
%endif
	mov byte [ es:di + fcbSFN ], al

%if 1
	getdarg es, di, _sftPointer			; SFT pointer
%endif
%if 0
	cmp ax, -1					; set NZ (ax can't be an invalid handle number)
%endif
	clc

		; return
findmatchingFCBSFT_26:
	Return


		; Invalidate SFTs belonging to changed drive
		;
		; INP:	ax = drive
		;	cx:dx = serial number of former media
		; OUT:	NC, ZR if no used SFT entry belongs to this drive
		;	 es, bx unmodified
		;	CY, NZ if at least one SFT entry for the drive left
		;	 es:bx-> found SFT entry that belongs to this drive
		; CHG:	dx
		;
		; NO LONGER USED
invalidateOpenSFTs:

	Entry
	ddef	currentFT
	ddef	PrevSerialNumber, cx, dx
	def	drive, ax

	push es
	push bx
	les bx, [ ss:_RxDOS_pFT ]			; get first FT

		; look for available handle
invOpenSFT_08:
	cmp bx, -1
	je invOpenSFT_26				; no more FTs -->
							; (flags are ZR, NC)

	stordarg _currentFT, es, bx

	mov cx, word [ es:bx + numberSFTEntries ]	; get number of SFT entries in this FT
	lea bx, [ word sizeFT + bx ]			; skip FT header
	jcxz invOpenSFT_16				; none ? go to next -->

		; is SFT available ?
invOpenSFT_12:
	cmp word [ es:bx + sftRefCount ], byte 0	; entry in use ?
	jz invOpenSFT_14				; no, skip to next -->

	mov dx, word [ es:bx + sftDevInfo ]
	test dx, sftIsDevice				; is device ?
	jnz invOpenSFT_14				; yes, skip to next -->

	and dx, byte sftDrivemask
	cmp dx, ax					; same as changed drive ?
	jnz invOpenSFT_14				; no -->

	cmp ax, -1					; set NZ, CY
	jmp short invOpenSFT_30				; we have a problem -->

		; goto next SFT
invOpenSFT_14:
	add bx, byte sizeSFT				; next SFT entry
	loop invOpenSFT_12				; if more -->

invOpenSFT_16:
	les bx, [ _currentFT + bp ]
	les bx, [ es:bx + nextFTPointer ]
	jmp short invOpenSFT_08				; go to next FT -->

		; return
invOpenSFT_26:
	pop bx
	pop es
invOpenSFT_30:
		; Note that the return macro sets sp back to bp, so we
		; don't have to explicitly discard bx and es on stack.
	Return


		; Init Clear SFT Entry
		;
		; INP:	es:bx-> Already reserved SFT entry
InitSFTEntry:

	push di
	push cx
	push ax

	xor ax, ax
%if 1
	push word [ es:bx + sftRefCount ]

	mov di, bx
	mov cx, sizeSFT / 2
	repe stosw					; must have pointer at es:di

	mov ax, word [ ss:_RxDOS_CurrentPSP ]		; get owner PSP
	mov word [ es:bx + sftPSP ], ax
	pop word [ es:bx + sftRefCount ]
%else
	mov di, bx
	add di, 2					; skip reference count
	mov cx, (sizeSFT - 2) / 2
	repe stosw					; must have pointer at es:di

	mov ax, word [ ss:_RxDOS_CurrentPSP ]		; get owner PSP
	mov word [ es:bx + sftPSP ], ax
%endif

	pop ax
	pop cx
	pop di
	retn


		; Verify SFT entry and application handle available
		;
		; OUT:	NC if enough application and SFT handles
		;	CY if either not enough application or SFT handles,
		;	 ax = extended error pointer
		; CHG:	ax
		;
		; Releases <= RxDOS 7.20N abort with ZR, NC if no PSP loaded
VerifyAvailableHandle:

%if 1
	cmp word [ ss:_RxDOS_CurrentPSP ], byte 0
	jz verifyAvailHandles_26			; if no application -->
%endif

	push es
	push si
	push cx

%if 1
	mov es, word [ ss:_RxDOS_CurrentPSP ]		; get PSP
	mov cx, word [ es:pspFileHandleCount ]
	les si, [ es:pspFileHandlePtr ]
%else
	call GetAppHandleTable
%endif

		; search for free application handle
verifyAvailHandles_04:
	cmp byte [ es:si ], -1				; empty slot ?
	jz verifyAvailHandles_08			; yes, look for empty SFT entry -->

	inc si						; next
	loop verifyAvailHandles_04			; continue looping

	stc
	mov ax, pexterrNoHandlesAvailable		; no application handles left
	jmp short verifyAvailHandles_22			; exit -->

		; allocate SFT handle
verifyAvailHandles_08:
	call FindAvailableSFTHandle			; locate available System Handle
	jc verifyAvailHandles_22			; if none left --> (ax already error value)
	dec word [ es:bx + sftRefCount ]		; release reservation count

		; return
verifyAvailHandles_22:
	pop cx
	pop si
	pop es

verifyAvailHandles_26:
	retn


		; Build Directory/SFT Entries
		;
		; Input:
		; ss:di	pointer to diraccess
		; cx	attributes
		;
		; Output:
		; ax	handle to an SFT
		;
		; OUT:	NC if created/truncated ok
		;	 ax = SFT handle
		;	 es:di-> SFT entry
		; 	CY if error,
		;	 ax = extended error pointer
createSFTEntry:

	Entry
	def	drive
	def	handle, -1				; SFT handle
	def	DirEntryAttributes, cx			; directory attributes
	ddef	dirAccess, ss, di
	ddef	dirAddress				; address of empty location found
	ddef	sftPointer				; SFT pointer

		; find an available SFT
	call FindAvailableSFTHandle			; find an available file handle
	ifc _createSFTEntry_42				; if none available -->

	mov word [ _handle + bp ], ax			; handle
	stordarg _sftPointer, es, bx			; SFT pointer
	call InitSFTEntry				; clear entry

		; if file exists, delete file by releasing its clusters
	mov si, word [ _dirAccess + _pointer + bp ]

	mov ax, word [ ss:si + fileAcDrive ]
	storarg _drive, ax				; save drive
	test ax, 8000h					; does not exist flag ?
	jnz _createSFTEntry_20				; if no file -->

	mov si, word [ _dirAccess + _pointer + bp ]
	les di, [ ss:si + fileAcBufferPtr ]
	add di, word [ ss:si + fileAcDirOffset ]	; offset to entry in dir
	stordarg _dirAddress, es, di			; address of empty loc found

	mov ax, word [ ss:si + fileAcDrive ]
	mov cx, word [ ss:si + fileAcCluster + _high ]
	mov dx, word [ ss:si + fileAcCluster + _low ]
	call ReleaseClusterChain
	jmp short _createSFTEntry_24

		; if no file, locate empty slot and populate
_createSFTEntry_20:
	and ax, 7FFFh
	mov word [ ss:si + fileAcDrive ], ax
	mov dx, word [ ss:si + fileAcDirCluster + _low ]
	mov cx, word [ ss:si + fileAcDirCluster + _high ]
	call LocateFreeDirSlot				; can we find a valid empty entry ?
	jc _createSFTEntry_40				; no -->

	stordarg _dirAddress, es, si			; address of empty location found
	mov di, si					; convert name to directory style

	mov si, word [ _dirAccess + _pointer + bp ]
	mov si, word [ ss:si + fileAcNameOffset ]
	call convFilenametoFCBString			; directory style name si -> di

		; update latest entry
_createSFTEntry_24:
	xor ax, ax
	mov cx, sizeDIRENTRY - sizeFILENAME		; remainder of dir entry
	getdarg es, di, _dirAddress			; restore di pointer
	lea di, [ deAttributes + di ]			; starting at attribs
	repe stosb					; clear rest of entry

	mov si, word [ _dirAddress + _pointer + bp ]
	mov cx, word [ _DirEntryAttributes + bp ]	; get attributes
	mov byte [ es:si + deAttributes ], cl		; attribute byte

	call getSysDateinDirFormat
	mov word [ es:si + deTime ], ax			; time created
	mov word [ es:si + deDate ], dx			; date created

	mov word [ es:si + deStartCluster ], 0
	mov word [ es:si + deStartClusterExt ], 0
	mov word [ es:si + deFileSize + _low ], 0
	mov word [ es:si + deFileSize + _high ], 0

	call locateCCBPHeader				; get CCB header into es:di
	call CCBChanged					; mark changes made
	call updateChangedCCB				; updated buffer to disk

	mov ax, errAccessDenied				; problem, access denied
	jc _createSFTEntry_40				; if error, release SFT -->

		; fix-up SFT
	push word [ _dirAddress + _segment + bp ]
	push word [ _dirAddress + _pointer + bp ]	; dir entry
	push word [ _sftPointer + _segment + bp ]
	push word [ _sftPointer + _pointer + bp ]	; SFT pointer
	call initSFTfromDirEntry

	getarg ax, _handle
%if 1
	cmp word [ es:di + sftDevInfo ], sftIsDevice
%else
		; RxDOS 7.20N:	BUG. This should test the device flag and process the sftWritten
		;		code below only if the SFT entry does not refer to a file.
	test byte [ es:di + sftDevInfo ], sftIsDevice
%endif

	clc
	jnz _createSFTEntry_42				; if device -->

	or word [ es:di + sftDevInfo ], byte sftWritten	; is written when created (flag only valid if no device)
	jmp short _createSFTEntry_42

		; if error, release locked sft
_createSFTEntry_40:
	getdarg es, bx, _sftPointer			; get SFT pointer
	dec word [ es:bx + sftRefCount ]		; release completely
	stc

		; return
_createSFTEntry_42:
	Return


		; Build Directory/SFT Entries
		;
		; Input:
		; stack	pointer to directory entry
		; stack	SFT pointer
		;
		; Output:
		; es:di-> SFT entry
		;
		; CHG:	ax, si, cx, dx
initSFTfromDirEntry:

	Entry 4
	darg	dirAddress
	darg	sftPointer				; SFT pointer

		; init SFT
	push ds
%if 1
	xor ax, ax
%endif
	getdarg es, di, _sftPointer			; SFT pointer
%if 1
	add di, byte 2					; skip Count entry
	mov cx, (sizeSFT - 2)/ 2			; effective count
	repe stosw					; must have pointer at es:di
%else
	xchg bx, di
	call InitSFTEntry				; sets also PSP
	xchg bx, di					; restore bx
%endif

		; copy filename
	getdarg ds, si, _dirAddress			; directory
%if 1
	getdarg es, di, _sftPointer			; SFT pointer
%endif
	lea di, [ word sftFileName + di ]		; offset to filename
		; RxDOS 7.20N: force word
	mov cx, sizeFILENAME				; length of name + extension
	repe movsb					; copy name

		; populate sft
	getdarg ds, si, _dirAddress			; directory
	getdarg es, di, _sftPointer			; SFT pointer

	push word [ deAttributes + si ]			; attribute byte
	push word [ deTime + si ]			; time last updated
	push word [ deDate + si ]			; date last updated
	push word [ deStartCluster + si ]		; beginning cluster
	push word [ deStartClusterExt + si ]		; extended beginning cluster
	push word [ deFileSize + _low + si ]		; file size
	push word [ deFileSize + _high + si ]		; file size

	pop word [ es:di + sftFileSize + _high ]
	pop word [ es:di + sftFileSize + _low ]
	pop word [ es:di + sftBegCluster + _high ]	; if not FAT32, should zero this out
	pop word [ es:di + sftBegCluster + _low ]
	pop word [ es:di + sftDate ]
	pop word [ es:di + sftTime ]
	pop ax
	mov byte [ es:di + sftFileAttrib ], al

%if 1
	; set owner PSP

	mov ax, word [ ss:_RxDOS_CurrentPSP ]		; get owner PSP
	mov word [ es:di + sftPSP ], ax
%endif

	; set where in directory

	push es
	push di						; pointer to SFT
	setES ds					; point dir buffer as es:si
	call locateCCBPHeader				; get CCB header into es:di
	mov si, di					; CCB Header at ds:si

	pop di
	pop es						; pointer to SFT
	mov ax, word [ ccbLBN + _low + si ]
	mov dx, word [ ccbLBN + _high + si ]
	mov word [ es:di + sftDirSector + _low ], ax
	mov word [ es:di + sftDirSector + _high ], dx

	mov cl, byte [ ccbDrive + si ]			; get drive
	and cx, byte sftDrivemask				; make ch zero
	or word [ es:di + sftDevInfo ], cx		; include drive

	mov ax, word [ _dirAddress + _pointer + bp ]
	sub ax, si					; distance from start of CCB header
	sub ax, ccbData					; distance from start of dir sector
	mov cl, sizeDIRENTRY				; bytes per entry
	div cl						; remainder should be zero

	mov byte [ es:di + sftDirSectorOffset ], al

		; record drive media volume ID
	mov ax, word [ es:di + sftDevInfo ]		; drive
	and ax, sftDrivemask
	call getDPB					; get DPB address

	mov cx, word [ es:bx + _dpbVolumeId + _high ]
	mov dx, word [ es:bx + _dpbVolumeId + _low ]

	getdarg es, di, _sftPointer			; SFT pointer
	mov word [ es:di + sftVolumeId + _high ], cx
	mov word [ es:di + sftVolumeId + _low ], dx
	clc

		; return
	pop ds
	Return


		; Build Access Area from SFT
		;
		; Input:
		; es:di-> SFT entry
		; ss:bx-> access block
buildAccessRef:

	Entry
	ddef	fileposAtBegCluster
	def	clusterSize

	saveRegisters si, cx
%if 0
	push ds
	setds ss
%endif

	push es
	push di
	push bx

	mov ax, word [ es:di + sftDevInfo ]
	mov dx, word [ es:di + sftBegCluster + _low ]
	mov cx, word [ es:di + sftBegCluster + _high ]
	call initdiskAccess				; ax is drive, cx:dx is cluster
	call getDPB					; gets a guaranteed init drive block

	mov ax, word [ es:bx + _dpbBytesPerSector ]
	mov cl, byte [ es:bx + _dpbClusterSizeShift ]
	shl ax, cl					; bytes per cluster
	storarg _clusterSize, ax

	pop bx
	pop di
	pop es

	xor dx, dx
	mul word [ es:di + sftRelCluster ]
	; mov word [ diskAcOffAtBegCluster + _low + bx ], ax
	; mov word [ diskAcOffAtBegCluster + _high + bx ], dx
	stordarg _fileposAtBegCluster, dx, ax		; save

	mov ax, word [ es:di + sftFileSize + _low ]
	mov dx, word [ es:di + sftFileSize + _high ]
	mov word [ diskAcFileSize + _low + bx ], ax
	mov word [ diskAcFileSize + _high + bx ], dx

	mov ax, word [ es:di + sftCurCluster + _low ]
	mov dx, word [ es:di + sftCurCluster + _high ]
	; mov word [ diskAcCurCluster + _low + bx ], ax
	; mov word [ diskAcCurCluster + _high + bx ], dx

	jmp buildAccessRef_08				; can't use current cluster -->

	mov ax, word [ es:di + sftFilePosition + _low ]
	mov dx, word [ es:di + sftFilePosition + _high ]
	sub ax, word [ _fileposAtBegCluster + _low + bp ]
	sbb dx, word [ _fileposAtBegCluster + _high + bp ]
	jc buildAccessRef_08				; can't use current cluster -->
	or dx, dx					; distance greater than 65k ?
	jnz buildAccessRef_08				; can't use current cluster -->

	cmp ax, word [ _clusterSize + bp ]		; greater than cluster size ?
%if 1
	jge buildAccessRef_08				; can't use current cluster -->
%else
	jae buildAccessRef_08				; can't use current cluster -->
%endif

	; there's a bug here, so we'll just ignore it for now
	; by ALWAYS exiting. This patch could be a problem
	; for larger files, so it needs to be fixed !

	jmp buildAccessRef_08				; can't use current cluster -->

	getdarg dx, ax, _fileposAtBegCluster		; offset at start of cluster
	mov word [ ss:diskAcOffAtBegBuffer + _low + bx ], ax
	mov word [ ss:diskAcOffAtBegBuffer + _high + bx ], dx

buildAccessRef_08:
%if 0
	pop ds
%endif
	restoreRegisters cx, si
	Return


		; Set relative cluster number from SFT file position
		;
		; Input:
		; es:di-> SFT entry
		;
		; Preserved:
		; cx, es, di
		;
		; CHG:	ax, dx
_computeRelativeCluster:

	push cx
	push es
	push di

	mov ax, word [ es:di + sftDevInfo ]
	call getAddrDPB					; es:bx

	mov ax, word [ es:bx + _dpbBytesPerSector ]
	mov cl, byte [ es:bx + _dpbClusterSizeShift ]
	shl ax, cl					; bytes per cluster
	mov cx, ax

	pop di
	pop es
	mov ax, word [ es:di + sftFilePosition + _low ]
	mov dx, word [ es:di + sftFilePosition + _high ]
	call _div32

	; mov word [ es:di + sftRelCluster ], ax
	pop cx
	retn


		; Open SFT
		;
		; Input:
		; ss:di-> dir access block
		; ax	open mode
		;
		; Output:
		; es:di	sft pointer
		; ZR means end of file or wrong address
_SFTOpenFile:

	Entry
	def	handle, -1
	def	openMode, ax
	def	ptrDirAccess, di
	ddef	sftPointer				; SFT reserved pointer

		; name is valid, populate SFT
	call FindAvailableSFTHandle			; find an available file handle
	ifc _SFTOpenFile_50				; if none available -->

	mov word [ _handle + bp ], ax
	stordarg _sftPointer, es, bx			; SFT reserved pointer
	call InitSFTEntry				; clear entry

		; if file opened is a device
	getarg di, _ptrDirAccess			; dir access block
	mov dx, word [ss:di + fileAcDevicePtr + 2]
	mov ax, word [ss:di + fileAcDevicePtr]
	or dx, dx					; _segment
	jz _SFTOpenFile_22				; if not a device -->

	or word [ es:bx + sftDevInfo ], sftIsDevice
	mov word [ es:bx + sftDPB + _segment ], dx
	mov word [ es:bx + sftDPB + _pointer ], ax	; device address

	push ds
	setDS ss
	getarg si, _ptrDirAccess			; dir access block
	mov si, word [ fileAcNameOffset + si ]
	les di, [ _sftPointer + bp ]			; get SFT pointer
	lea di, [ word sftFileName + di ]
		; RxDOS 7.20N: force word
	call convFilenametoFCBString			; convert to a match template
	pop ds

	jmp short _SFTOpenFile_42

		; if open is to file
_SFTOpenFile_22:
	push word [ fileAcBufferPtr + _segment + di ]
	mov ax, word [ fileAcBufferPtr + _pointer + di ]
	add ax, word [ fileAcDirOffset + di ]
	push ax

	push word [ _sftPointer + _segment + bp ]
	push word [ _sftPointer + _pointer + bp ]
	call initSFTfromDirEntry

	mov al, byte [ _openMode + bp ]
	mov byte [ es:di + sftMode ], al		; set mode

	test al, OPEN_ACCESS_NOINHERIT
	jz _SFTOpenFile_42				; if inherit not used -->
	or word [ es:di + sftDevInfo ], sftNoInherit

		; return
_SFTOpenFile_42:
	mov ax, word [ _handle + bp ]
	clc

		; if error, release locked SFT
_SFTOpenFile_50:
	getdarg es, di, _sftPointer			; SFT reserved pointer
	Return


		; Create SFT File
		;
		; Input:
		; ss:di-> dir access block
		; cx	attributes
		;
		; Output:
		; es:di	sft pointer
		; ZR means end of file or wrong address
_SFTCreateFile:

	Entry
	def	attributes, cx				; attributes
	def	ptrDirAccess, di

		; see if path is valid
	getarg di, _ptrDirAccess			; dir access block
	mov cx, word [ _attributes + bp ]		; get attributes
	call createSFTEntry				; create/init SFT entry

		; return
_SFTCreateFile_42:
	Return


		; Read from SFT
		;
		; Input:
		; cx	bytes to read
		; es:di-> SFT entry
		; stack	buffer address
		;
		; Output:
		; cx	bytes actually read
_SFTReadFile:

	Entry 2
	darg	bufPtr

	def	readCount, cx
	def	readActual, cx
	ddef	sftpointer, es, di
	defbytes	diskAccess, sizeDISKACCESS

		; is file redirected to a device ?
	test word [ es:di + sftDevInfo ], sftIsDevice
	jz _SFTReadFile_34				; if file -->

	xor cx, cx					; actually read
	test word [ es:di + sftDevInfo ], sftEof	; is it end of file ?
	ifnz _SFTReadFile_56				; if end of file -->

	xor dx, dx					; echo bytes
	push word [ es:di + sftDPB + _segment ]
	push word [ es:di + sftDPB + _pointer ]
	mov cx, word [ _readCount + bp ]
	getdarg es, di, _bufPtr
	call devCharReadLine				; read till cr or eof.
	storarg _readActual, cx				; actual read
	jz _SFTReadFile_30				; if not end of file -->

	or cx, cx					; any characters returned ?
	jz _SFTReadFile_16				; none, append CR, LF -->
	getdarg es, di, _bufPtr

_SFTReadFile_12:
	cmp byte [ es:di ], ControlZ
	jz _SFTReadFile_26
	inc di						; continue scan for Control-Z
	loop _SFTReadFile_12				; if more -->

_SFTReadFile_16:
	getarg cx, _readActual				; actual read
	getdarg es, di, _bufPtr
	cmp cx, word [ _readCount + bp ]		; at maximum buffer ?
%if 1
	jge _SFTReadFile_18				; yes -->
%else
	jae _SFTReadFile_18				; yes -->
%endif

	add di, cx					; add CR, LF
	mov al, ControlM
	stosb						; store CR

	inc cx						; adjust return count
	cmp cx, word [ _readCount + bp ]		; at maximum buffer ?
%if 1
	jge _SFTReadFile_18				; yes -->
%else
	jae _SFTReadFile_18				; yes -->
%endif

	mov al, ControlJ
	stosb						; store LF
	inc cx

_SFTReadFile_18:
	jmp _SFTReadFile_56

		; device end of file
_SFTReadFile_26:
	mov cx, di
	sub cx, word [ _bufPtr + _pointer + bp ]	; actual read

_SFTReadFile_30:
	getdarg es, di, _sftpointer
	or word [ es:di + sftDevInfo ], byte sftEof	; set end of file flag
	jmp _SFTReadFile_56

		; is file read from stdin ?
_SFTReadFile_34:
	test word [ es:di + sftDevInfo ], sftIsDevice
	jz _SFTReadFile_40				; if file -->
	test word [ es:di + sftDevInfo ], sftIsstdin
	jz _SFTReadFile_40				; if file -->

	push word [ es:di + _bufPtr + _segment ]
	push word [ es:di + _bufPtr + _pointer ]	; buffer address
	call _SFTReadLine				; read line
	jmp _SFTReadFile_56

		; initialize disk access block
_SFTReadFile_40:
	or cx, cx					; reading any ?
	ifz _SFTReadFile_54				; if length is zero -->

	lea bx, [ word _diskAccess + bp ]		; build access control block
	call buildAccessRef				;  from SFT

	mov ax, word [ es:di + sftDevInfo ]		; get drive number
	call insureSFTSameVolume			; insure same volume
	ifc _SFTReadFile_56				; read aborted -->

	xor cx, cx					; bytes read (none yet)
	lea bx, [ word _diskAccess + bp ]		; build access control block
	getdarg es, di, _sftpointer			; restore SFT pointer
	mov ax, word [ es:di + sftFileSize + _low ]
	mov dx, word [ es:di + sftFileSize + _high ]
	mov word [ _diskAccess + diskAcFileSize + _low + bp ], ax
	mov word [ _diskAccess + diskAcFileSize + _high + bp ], dx

	sub ax, word [ es:di + sftFilePosition + _low ]
	sbb dx, word [ es:di + sftFilePosition + _high ]
	jc _SFTReadFile_54				; if past end of file -->

	mov cx, word [ _readCount + bp ]		; count: cx
	or dx, dx					; more than 65 KiB of file left ?
	jnz _SFTReadFile_46				; ok to continue reading -->

	cmp ax, cx					; enough space to absorb read ?
	jnc _SFTReadFile_46				; ok to continue reading -->

	mov cx, ax					; max read just to end of file
	or cx, cx					; if zero, no need to read
	jz _SFTReadFile_54

		; if StdIn, read line even if from a file
_SFTReadFile_46:
	mov ax, word [ es:sftFilePosition + _low + di ]
	mov dx, word [ es:sftFilePosition + _high + di ]
	mov word [ ss:diskAcPosition + _low + bx ], ax
	mov word [ ss:diskAcPosition + _high + bx ], dx

	getdarg es, di, _bufPtr				; buffer es:di
	call readLogicalBuffer				; Access buffer: ds:bx

	getdarg es, di, _sftPointer			; restore pointer to SFT buffer
	add word [ es:sftFilePosition + _low + di ], cx
	adc word [ es:sftFilePosition + _high + di ], byte 0

	mov ax, word [ diskAcCurCluster + _low + bx ]
	mov dx, word [ diskAcCurCluster + _high + bx ]
	mov word [ es:sftCurCluster + _low + di ], ax
	mov word [ es:sftCurCluster + _high + di ], dx
	call _computeRelativeCluster

_SFTReadFile_54:
	clc

_SFTReadFile_56:
	mov ax, cx					; return count
	Return


		; Read Line From SFT
		;
		; Input:
		; cx	max bytes to read
		; es:di-> SFT entry
		; stack	buffer address
		;
		; Output:
		; cx	bytes actually read
		; ZR means end of file or wrong address
_SFTReadLine:

	Entry 2
	darg	bufPtr

	def	readMax, cx
	def	readActual, 0
	ddef	sftpointer, es, di
	defbytes	diskAccess, sizeDISKACCESS

		; is file redirected to a device
	test word [ es:di + sftDevInfo ], sftIsDevice
	jz _SFTReadLine_14				; if file -->

	test word [ es:di + sftDevInfo ], sftEof
	jz _SFTReadLine_36				; if at end of file -->

	xor dx, dx					; echo bytes
	push word [ es:di + sftDPB + _segment ]
	push word [ es:di + sftDPB + _pointer ]
	mov cx, word [ _readMax + bp ]
	getdarg es, di, _bufPtr
	call devCharReadLine				; read till CR or EOF
	jnz _SFTReadLine_10				; if not end of file -->

	getdarg es, di, _sftpointer
	or word [ es:di + sftDevInfo ], byte sftEof	; set end of file flag

_SFTReadLine_10:
	getdarg es, di, _bufPtr
	cmp cx, word [ _readMax + bp ]			; at maximum buffer ?
%if 1
	jge _SFTReadLine_12				; yes -->
%else
	jae _SFTReadLine_12				; yes -->
%endif

	add di, cx					; add CR
	mov al, ControlM
	stosb						; store CR
	inc cx						; adjust return count

_SFTReadLine_12:
	jmp _SFTReadLine_36

		; initialize disk access block
_SFTReadLine_14:
	or cx, cx					; reading any ?
	jz _SFTReadLine_34				; if length is zero -->

	lea bx, [ word _diskAccess + bp ]		; build access control block
	call buildAccessRef				;  from SFT

	mov ax, word [ es:di + sftFileSize + _low ]
	mov dx, word [ es:di + sftFileSize + _high ]
	mov word [ ss:bx + diskAcFileSize + _low ], ax
	mov word [ ss:bx + diskAcFileSize + _high ], dx

	mov ax, word [ es:di + sftFilePosition + _low ]
	mov dx, word [ es:di + sftFilePosition + _high ]
	mov word [ ss:bx + diskAcPosition + _low ], ax
	mov word [ ss:bx + diskAcPosition + _high ], dx

	getdarg es, di, _bufPtr				; buffer es:di
	mov cx, word [ _readMax + bp ]			; max bytes to read
	call readLine					; read line

	getdarg es, di, _sftpointer
	mov word [ es:di + sftFilePosition + _low ], ax
	mov word [ es:di + sftFilePosition + _high ], dx

	mov ax, word [ bx + diskAcCurCluster + _low ]
	mov dx, word [ bx + diskAcCurCluster + _high ]
	mov word [ es:di + sftCurCluster + _low ], ax
	mov word [ es:di + sftCurCluster + _high ], dx
	call _computeRelativeCluster

_SFTReadLine_34:
	clc

_SFTReadLine_36:
	mov ax, cx					; return count
	Return


		; Write To SFT
		;
		; Input:
		; es:di-> SFT entry
		; cx	bytes to write
		; stack	buffer address
		;
		; Output:
		; cx	bytes actually written
		; CY if end of available disk space reached
_SFTWriteFile:

	Entry 2
	darg	bufPtr

	def	actuallyWritten, 0
	def	writeCount, cx
	ddef	sftpointer, es, di
	defbytes	diskAccess, sizeDISKACCESS
	defbytes	expandedBuffer, 128

		; is file redirected to StdOut device
	test word [ es:di + sftDevInfo ], sftIsDevice
	ifz _SFTWriteFile_36				; if file -->
	test word [ es:di + sftDevInfo ], sftIsstdout
	ifz _SFTWriteFile_36				; no -->
	or cx, cx					; none to write ?
	ifz _SFTWriteFile_36				; special case -->

	getdarg es, di, _bufPtr				; get buffer address
	lea si, [ word _expandedBuffer + bp ]
	lea dx, [ word _expandedBuffer + 128 - 7 + bp ]

_SFTWriteFile_06:
	mov al, byte [ es:di ]				; get character
	mov byte [ ss:si ], al				; store character
	inc si						; advance pointer

	cmp al, ControlI				; tab character ?
	jnz _SFTWriteFile_08				; no, go see what it is -->

	mov al, 8
	mov ah, byte [ _RxDOS_TabPosition ]		; current tab position
	and ah, 7					; tab offset
	sub al, ah					; bytes to offset
	add byte [ _RxDOS_TabPosition ], al		; advance position

	cbw						; 16 bit offset
	dec si						; account for byte advance
	mov word [ ss:si ], 2020h			; add to expanded buffer
	mov word [ ss:si + 2 ], 2020h			; add to expanded buffer
	mov word [ ss:si + 4 ], 2020h			; add to expanded buffer
	mov word [ ss:si + 6 ], 2020h			; add to expanded buffer
	add si, ax					; quick fill
	jmp short _SFTWriteFile_16

_SFTWriteFile_08:
	cmp al, ControlJ				; line feed ?
	jz _SFTWriteFile_16				; yes -->
	inc byte [ _RxDOS_TabPosition ]			; else advance tab position

_SFTWriteFile_10:
	cmp al, ControlM				; carriage return ?
	jnz _SFTWriteFile_16				; no -->
	mov word [ _RxDOS_TabPosition ], 0		; set tab position

_SFTWriteFile_16:
	inc di						; advance pointer
	cmp si, dx					; is expand buffer within tab of end ?
%if 1
	jle _SFTWriteFile_20				; ok to continue -->
%else
	jbe _SFTWriteFile_20				; ok to continue -->
%endif

	push es
	push di						; save current pointer into buffer
	push cx						; counter
	push dx						; counter

	lea cx, [ _expandedBuffer + bp ]		; buffer address
	xchg cx, si					;
	sub cx, si					; actual count
	push ss
	push si						; buffer address

	getdarg es, di, _sftpointer			; SFT pointer
	call _SFTWriteWithoutProcessing			; write buffer
	lea si, [ _expandedBuffer + bp ]		; restore pointer

	pop dx						; restore counter
	pop cx						; restore counter
	pop di
	pop es						; restore pointer

_SFTWriteFile_20:
	loop _SFTWriteFile_06				; if nore buffer

	lea cx, [ _expandedBuffer + bp ]		; buffer address
	xchg cx, si					;
	sub cx, si					; actual count
	jz _SFTWriteFile_24				; if nothing to write -->

	push ss
	push si						; buffer address
	getdarg es, di, _sftpointer			; SFT pointer
	call _SFTWriteWithoutProcessing			; write buffer

_SFTWriteFile_24:
	mov ax, word [ _writeCount + bp ]		; return count (StdOut requires this)
	or ax, ax
	Return

		; output
_SFTWriteFile_36:
	push word [ _bufPtr + _segment + bp ]
	push word [ _bufPtr + _pointer + bp ]		; buffer address
	call _SFTWriteWithoutProcessing			; write buffer

	mov ax, cx					; return actual written count
	or ax, ax
	Return


		; Write To SFT Without Character Processing
		;
		; Input:
		; es:di-> SFT entry
		; cx	bytes to write
		; stack	buffer address
		;
		; Output:
		; cx	bytes actually written
		; CY if end of available disk space reached
_SFTWriteWithoutProcessing:

	Entry 2
	darg	bufPtr

	def	actuallyWritten, 0
	def	writeCount, cx
	ddef	sftpointer, es, di
	defbytes	diskAccess, sizeDISKACCESS

		; is file redirected to StdOut device ?
	test word [ es:di + sftDevInfo ], sftIsDevice
	jz _SFTWriteWithout_16

	or cx, cx
	jz _SFTWriteWithout_06				; if nothing to write -->

	push word [ es:di + sftDCB + _segment ]
	push word [ es:di + sftDCB + _pointer ]
	mov cx, word [ _writeCount + bp ]
	getdarg es, di, _bufPtr
	call devCharWrite
	mov word [ _actuallyWritten + bp ], cx

_SFTWriteWithout_06:
	jmp near _SFTWriteWithout_56

		; initialize disk access block
_SFTWriteWithout_16:
	mov ax, word [ es:di + sftDevInfo ]		; get drive number
	or word [ es:di + sftDevInfo ], byte sftWritten	; set written flag
	call insureSFTSameVolume			; insure same volume
	ifc _SFTWriteWithout_Error			; read aborted -->

	getdarg es, di, _sftpointer			; restore SFT pointer
	mov dx, word [ es:di + sftBegCluster + _low ]
	or dx, word [ es:di + sftBegCluster + _high ]	; begin cluster allocated ?
	jnz _SFTWriteWithout_24				; yes -->
	cmp word [ _writeCount + bp ], byte 0		; not attempting to actually write
	jz _SFTWriteWithout_24				; if no write -->

	xor dx, dx
	xor cx, cx
	mov ax, word [ es:di + sftDevInfo ]
	and ax, sftDrivemask
	call AllocateCluster				; allocate cluster
	ifc _SFTWriteWithout_56				; if can't allocate space -->

	getdarg es, di, _sftpointer
	mov word [ es:di + sftBegCluster + _low ], dx	; save beginning cluster
	mov word [ es:di + sftBegCluster + _high ], cx

_SFTWriteWithout_24:
	lea bx, [ word _diskAccess + bp ]		; build access control block
	call buildAccessRef				;  from SFT
	mov word [ _diskAccess + diskAcOptions + bp ], DISKAC_OPTIMIZEDWRITE

	xor cx, cx
	mov ax, word [ es:di + sftFilePosition + _low ]
	mov dx, word [ es:di + sftFilePosition + _high ]
	sub ax, word [ es:di + sftFileSize + _low ]
	sbb dx, word [ es:di + sftFileSize + _high ]
	jc _SFTWriteWithout_32				; if not past end of file -->
	or ax, dx					; positive offset ?
	jz _SFTWriteWithout_32				; if not past end of file -->

		; file pointer past end of file. fill to current pointer.
	push word [ es:di + sftFileSize + _high ]
	push word [ es:di + sftFileSize + _low ]
	call fillLogicalBuffer				; Access buffer: ss:bx
	ifc _SFTWriteWithout_56				; no more room on disk -->

	getdarg es, di, _sftPointer			; restore pointer to SFT buffer
	add word [ es:di + sftFileSize + _low ], ax
	adc word [ es:di + sftFileSize + _high ], dx

		; write cx bytes to file from buffer passed
_SFTWriteWithout_32:
	getarg cx, _writeCount
	mov ax, word [ es:di + sftFilePosition + _low ]
	mov dx, word [ es:di + sftFilePosition + _high ]
	getdarg es, di, _bufPtr				; buffer es:di
	call writeLogicalBuffer				; Access buffer: ss:bx

	getdarg es, di, _sftPointer			; restore pointer to SFT buffer
	add word [ es:di + sftFilePosition + _low ], cx
	adc word [ es:di + sftFilePosition + _high ], byte 0
	add word [ _actuallyWritten + bp ], cx

	mov ax, word [ diskAcCurCluster + _low + bx ]
	mov dx, word [ diskAcCurCluster + _high + bx ]
	mov word [ es:di + sftCurCluster + _low ], ax
	mov word [ es:di + sftCurCluster + _high ], dx
	call _computeRelativeCluster

		; truncate size ?
	cmp word [ _writeCount + bp ], byte 0		; was it truncate special case ?
	jnz _SFTWriteWithout_44				; no, go see if end of file moved -->

	mov cx, word [ es:di + sftFilePosition + _low ]
	or cx, word [ es:di + sftFilePosition + _high ]	; at beg of file ?
	jz _SFTWriteWithout_38				; yes -->

	lea di, [ word _diskAccess + bp ]
	call getNextClusterDskAccess			; get next cluster, if any
	jz _SFTWriteWithout_46				; if already at end -->

_SFTWriteWithout_38:
	lea di, [ word _diskAccess + bp ]
	call ReleaseClusterChainDskAccess		; truncate file to here
	jmp short _SFTWriteWithout_46

		; update file size
_SFTWriteWithout_44:
	mov ax, word [ es:di + sftFilePosition + _low ]
	mov dx, word [ es:di + sftFilePosition + _high ]
	sub ax, word [ es:di + sftFileSize + _low ]
	sbb dx, word [ es:di + sftFileSize + _high ]
	jc _SFTWriteWithout_56				; if not past end of file -->

_SFTWriteWithout_46:
	mov ax, word [ es:di + sftFilePosition + _low ]
	mov dx, word [ es:di + sftFilePosition + _high ]
	mov word [ es:di + sftFileSize + _low ], ax
	mov word [ es:di + sftFileSize + _high ], dx

		; return
_SFTWriteWithout_56:
	mov cx, word [ _actuallyWritten + bp ]
	mov ax, cx					; return count
	or ax, ax
	Return

		; error return
_SFTWriteWithout_Error:
	stc
	mov ax, pexterrInvalidAccess
	mov cx, word [ _actuallyWritten + bp ]
	Return


		; Close SFT File
		;
		; Input:
		; es:di-> SFT entry to close
_SFTCloseFile:
	call _SFTCommitFile
	call releaseSFT
	retn


		; Close all files owned by current PSP
_SFTCloseAllFiles:

%if 1
	cmp word [ ss:_RxDOS_CurrentPSP ], byte 0
	jz _SFTCloseAllFiles_36				; if no app -->

	mov es, word [ ss:_RxDOS_CurrentPSP ]		; get PSP
	mov cx, word [ es:pspFileHandleCount ]
	les si, [ es:pspFileHandlePtr ]
%else
	call GetAppHandleTable
	jc _SFTCloseAllFiles_36				; no PSP loaded -->
%endif

_SFTCloseAllFiles_04:
	cmp byte [ es:si ], -1				; empty slot ?
	jz _SFTCloseAllFiles_14				; yes, skip entry -->

	SaveRegisters es, si, cx
	mov ax, word [ es:pspFileHandleCount ]
	sub ax, cx					; actual handle value
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _SFTCloseAllFiles_12				; if can't resolve handle, skip close
	call _SFTCloseFile				; do a normal close

_SFTCloseAllFiles_12:
	RestoreRegisters cx, si, es
	mov byte [ es:si ], -1				; make slot empty

_SFTCloseAllFiles_14:
	inc si						; next
	loop _SFTCloseAllFiles_04			; continue -->

_SFTCloseAllFiles_36:
	retn


		; Commit SFT File
		;
		; Input:
		; es:di-> SFT entry
		; OUT:	NC
_SFTCommitFile:

	Entry
	ddef	sftPointer, es, di			; save SFT buffer pointer

		; was device ever written to ?
	test word [ es:di + sftDevInfo ], sftIsDevice
	ifnz _SFTCommitFile_36				; if device, no need to update -->
	test word [ es:di + sftDevInfo ], sftWritten
	ifz _SFTCommitFile_36				; if not changed, don't update-->

		; update dir entries from SFT
	mov ax, word [ es:di + sftDevInfo ]		; get drive number
	call insureSFTSameVolume			; checked for changed drive
	ifc _SFTCommitFile_36				; if not changed, don't update-->

	test word [ es:di + sftDevInfo ], sftDateset	; date already set ?
	jnz _SFTCommitFile_16				; if date already set -->

	call getSysDateinDirFormat
	mov word [ es:di + sftTime ], ax		; time last updated
	mov word [ es:di + sftDate ], dx		; date last updated

_SFTCommitFile_16:
	push word [ es:di + sftTime ]			; time last updated
	push word [ es:di + sftDate ]			; date last updated

%ifndef NOARCHIVEATTRIB
	or word [ es:di + sftFileAttrib ], byte ATTR_ARCHIVE
%endif
	push word [ es:di + sftFileAttrib ]
	push word [ es:di + sftBegCluster + _low ]
	push word [ es:di + sftBegCluster + _high ]
	push word [ es:di + sftFileSize + _low ]
	push word [ es:di + sftFileSize + _high ]

		; get directory entry
	mov al, byte [ es:di + sftDirSectorOffset ]	; get offset into directory
	and ax, maskDIRINDEX				; all we need is bottom bits
	mov cl, sizeDIRENTRY
	mul cl						; compute offset into dir entry
	push ax						; save offset into directory sector

	mov dx, word [ es:di + sftDirSector + _low ]
	mov cx, word [ es:di + sftDirSector + _high ]
	mov ax, word [ es:di + sftDevInfo ]
	and ax, sftDrivemask
	call readBuffer					; returns es:di pointer to buffer
	or byte [ es:di + ccbStatus ], ( ccb_isDIR )

		; update dir entry
	pop bx						; dir offset
	pop word [ es:di + ccbData + deFileSize + _high + bx ]
	pop word [ es:di + ccbData + deFileSize + _low + bx ]
	pop word [ es:di + ccbData + deStartClusterExt + bx ]
	pop word [ es:di + ccbData + deStartCluster + bx ]

	pop ax
	mov byte [ es:di + ccbData + deAttributes + bx ], al

	pop word [ es:di + ccbData + deDate + bx ]	; date created
	pop word [ es:di + ccbData + deTime + bx ]	; time created

	call CCBChanged

		; update free space
	getdarg es, di, _sftPointer
	mov ax, word [ es:di + sftDevInfo ]		; get drive number
	and ax, sftDrivemask
	call UpdateFreeSpace
	call updateAllChangedCCBBuffers			; force update of buffer

		; release SFT
_SFTCommitFile_36:
	clc
	Return


		; Test If Handle Table is Relocatable
		;
		; bx = number of file handles to allocate to an application
TestIfMoveHandleTable:

	push es
	push ds

	mov dx, bx					; requested number of handles
	cmp dx, byte sizePSPHandleTable			; more than 20 ?
%if 1
	jg testHandleTbl_20				; can't move if more than 20 ->
%else
	ja testHandleTbl_20				; can't move if more than 20 ->
%endif

	cmp word [ ss:_RxDOS_CurrentPSP ], byte 0
	jz testHandleTbl_20				; can't move without a PSP -->

	mov es, word [ ss:_RxDOS_CurrentPSP ]		; get PSP
	mov cx, word [ es:pspFileHandleCount ]
	sub cx, byte sizePSPHandleTable			; more than 20 ?
%if 1
	jle testHandleTbl_20				; no point to move if < 20 -->
%else
	jbe testHandleTbl_20				; no point to move if < 20 -->
%endif

	mov ax, es
	cmp ax, word [ es:pspFileHandlePtr + _segment ]	; is table outside of PSP ?
	jz testHandleTbl_20				; if not outside of PSP -->

		; scan table
	les bx, [ es:pspFileHandlePtr ]			; get JHT address
	add bx, byte 20					; start searching at handle 20

testHandleTbl_08:
	cmp byte [ es:bx ], -1				; is entry free ?
	jnz testHandleTbl_20				; no, can't relocate -->

	inc bx						; incr pointer
	loop testHandleTbl_08				; if more -->

		; ok, relocate table
	mov es, word [ ss:_RxDOS_CurrentPSP ]		; get PSP
	lds si, [ es:pspFileHandlePtr ]			; get pointer to old table
	mov di, pspHandleTable

	mov cx, dx					; updated count (20 or less)
	mov word [ es:pspFileHandleCount ], cx		; destination count
	mov word [ es:pspFileHandlePtr + _segment ], es
	mov word [ es:pspFileHandlePtr + _pointer ], di

	mov ax, -1
	mov cx, sizePSPHandleTable/2
	repe stosw					; init table to -1

	mov cx, dx
	mov di, pspHandleTable
	repe movsb					; copy table

		; free extra memory block
	xor bx, bx
	mov ax, ds					; points to old memory block
	dec ax
	mov ds, ax					; is this a valid memory block ?
	cmp byte [ _memSignature + bx ], _RxDOS_MEMSIGNATURE
	jz testHandleTbl_14
	cmp byte [ _memSignature + bx ], _RxDOS_ENDSIGNATURE
	jnz testHandleTbl_20

testHandleTbl_14:
	mov word [ _memParent + bx ], 0			; free memory block

testHandleTbl_20:
	pop ds
	pop es
	retn


		; Insure SFT volume ID same as current installed
		;
		; Input:
		; ax	drive
		; es:di-> SFT entry
insureSFTSameVolume:

	Entry
	def	drive
	ddef	dpbpointer
	ddef	sftpointer, es, di

	saveAllRegisters
	and ax, sftDrivemask
	storarg _drive, ax

insureSFTSameVolume_08:
	getarg ax, _drive
	call getDPB					; get current DPB
	stordarg _dpbpointer, es, bx

	mov cx, word [ es:bx + _dpbVolumeId + _High ]
	mov dx, word [ es:bx + _dpbVolumeId + _Low ]

	getdarg es, di, _sftpointer
	cmp cx, word [ es:di + sftVolumeId + _High ]
	jnz insureSFTSameVolume_12			; not same -->
	cmp dx, word [ es:di + sftVolumeId + _Low ]
	jz insureSFTSameVolume_36			; same, exit no carry -->

insureSFTSameVolume_12:
	getarg ax, _drive
	mov cx, word [ es:di + sftVolumeId + _High ]
	mov dx, word [ es:di + sftVolumeId + _Low ]
	call incorrectDiskMedia

	Goto CRITERROR_TERMINATE,	insureSFTSameVolume_16
	Goto CRITERROR_FAIL,		insureSFTSameVolume_16
	Goto CRITERROR_RETRY,		short insureSFTSameVolume_08

	clc
	jmp short insureSFTSameVolume_36		; if CRITERROR_IGNORE or if correct ->

insureSFTSameVolume_16:
	mov ax, pexterrInvalidAccess
	storarg _drive, ax				; return value
	stc

insureSFTSameVolume_36:
	restoreAllRegisters
	getarg ax, _drive
	mov cx, 0
	Return

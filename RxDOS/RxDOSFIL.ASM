
%if 0

RxDOSFIL - RxDOS redirected file system support

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

Copyright (C) 1990-1999 Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

	cpu 8086

	segment RXDOS align=16 class=RXDOS use16 public
	segment RXDOS

%include "RXDMACRO.MAC"
%include "RXDSTRUC.MAC"

	global initdiskAccess
	global readLogicalBuffer
	global writeLogicalBuffer
	global fillLogicalBuffer

	global readLine

	global ExpandFileName
	global LocateFile
	global LocateFileByAttribute
	global LocateFreeDirSlot
	global blankinitDirName
	global scanDirectory
	global compareDirEntries

	global GetActualDrive
	global getCurrDirCluster
	global getDevice
	global getDrive
	global getWhereInDir
	global IsRootExtendable

	extern scanInvalidFilenameChars
	extern ifPathSeparator

	extern convFCBNametoASCIZ
	extern skipToNextName
	extern skipToLast
	extern getAddrDPB
	extern getDPB

	extern _div32
	extern convFilenametoFCBString
	extern locateCCBPHeader
	extern CCBChanged
	extern SelBuffer
	extern updateAllChangedCCBBuffers

	extern AppendCluster
	extern AllocateInitCluster
	extern _FATReadRandom
	extern updateClusterValue
	extern CompareString
	extern StringLength

	extern checkforDeviceName
	extern _RxDOS_pCDS
	extern _RxDOS_bLastDrive
	extern _RxDOS_CurrentDrive

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


		; Init System Access Block
		; 
		; Input:
		; ax	drive
		; cx:dx	cluster of dir to search
		; ss:bx	address of disk access structure
		; 
		; Output:
		; all registers preserved
initdiskAccess:

	push es
	push di
	push cx

	and ax, sftDrivemask
	push ax

	setES ss					; set segment
	mov di, bx					; pointer to di
	clearMemory sizeDISKACCESS

	pop ax
	mov word [ ss:bx + diskAcDrive ], ax

	pop cx
	mov word [ ss:bx + diskAcBegCluster + _low ], dx
	mov word [ ss:bx + diskAcBegCluster + _high ], cx

	pop di
	pop es
	retn


		; Expand File Name
		; 
		; Input:
		; ax	options: FILECANNOT_BEDIRECTORY
		; arg	ptr to filename passed
		; arg	ptr to expanded filename
		; 
		; Output:
		; es:di-> expanded filename
		; cx:dx	current cluster, if search to begin here
		; ax	drive, or error
		; CY if error detected
ExpandFileName:

	Entry 4
	darg	UnexpandedFileName
	darg	ExpandBuffer
	def	options, ax

	xor ax, ax
	def	drive, ax				; initialize to 0
	ddef	currCluster, ax, ax			; initialize to 0
	def	cds_SubstOffset, ax			; initialize to 0
	def	NetworkPathName, ax			; False
	def	startPointer

		; skip through any leading spaces
	push ds
	currSegment ds					; point to default segment
	les si, [ _UnexpandedFileName + bp ]
	call getDrive
	storarg _drive, ax				; save argument
	ifc expandFileName_Error			; invalid drive -->

	call scanInvalidFilenameChars			; make sure filename is ok
	ifc expandFileName_Error			; if error -->

	mov word [ _UnexpandedFileName + _pointer + bp ], si

		; get selected drive current directory
	getarg ax, _drive
	mov cl, sizeCDS
	mul cl						; ax contains offset to current drive

	lds si, [ ss:_RxDOS_pCDS ]			; actual address in CDS
	add si, ax					; from
	add si, byte _cdsActualDirectory		; proper offset
		; RxDOS 7.20N:	_cdsActualDirectory is zero.

	xor cx, cx
	mov cl, byte [ _cdsNonSubstOffset + si ]
	mov word [ _cds_SubstOffset + bp ], cx

	mov cx, word [ _cdsStartClusterDir + _high + si ]
	mov dx, word [ _cdsStartClusterDir + _low + si ]
	mov word [ _currCluster + _low + bp ], dx	; current starting cluster
	mov word [ _currCluster + _high + bp ], cx

	push ds
	push si
	call StringLength				; length of source string

	getdarg es, di, _ExpandBuffer			; address of expanded buffer
	rep movsb					; copy buffer

		; does path end with a \ or / ? 
	cmp byte [ es:di - 1 ], '/'			; ends with trailing \ ?
	jz expandFileName_18				; yes, else add -->
	cmp byte [ es:di - 1 ], '\'			; ends with trailing \ ?
	jz expandFileName_18				; yes, else add -->
	inc di						; add trailing \

expandFileName_18:
	mov byte [ es:di - 1 ], '\'			; insure ends with \ char

		; does path start with root reference ?
	lds si, [ _UnexpandedFileName + bp ]
	cmp byte [ si ], '\'
	jz expandFileName_20
	cmp byte [ si ], '/'
	jz expandFileName_20

	cmp byte [ si ], ' '+1
	ifc expandFileName_Error			; null strings not parsed -->
	jmp short expandFileName_30			; continue -->

expandFileName_20:
	mov di, word [ _ExpandBuffer + _pointer + bp ]
	add di, word [ _cds_SubstOffset + bp ]
	xor ax, ax
	mov byte [ es:di ], al				; append terminator
	mov word [ _currCluster + _low + bp ], ax
	mov word [ _currCluster + _high + bp ], ax	; path name info supplied
	inc si						; skip starting '\'

		; scan for only valid characters
expandFileName_30:
	storarg _startPointer, si

expandFileName_32:
	lodsb
	_upperCase al					; upper case
	stosb						; save at es:di
	cmp al, ' '+1					; end of string ?
	jc expandFileName_36				; yes -->

	call ifPathSeparator				; path separator ?
	jnz expandFileName_32				; not yet -->
;%if 1
	mov byte [ es:di - 1 ], al			; make sure separator is \
;%endif
	mov word [ _currCluster + _low + bp ], 0
	mov word [ _currCluster + _high + bp ], 0	; path name info supplied

		; validate path separator
expandFileName_36:
	mov byte [ es:di ], 0				; null terminate

%if 1
	mov cx, si
	sub cx, word [ _startPointer + bp ]		; length of string
	dec cx						; excluding last \ ...
	jg expandFileName_38				; if more than one character -->
%else
	lea cx, [ word si - 1 ]				; point to last \
	sub cx, word [ _startPointer + bp ]		; length of string
	ja expandFileName_38				; if more than one character -->
		; RxDOS 7.20N:	I'm not sure this bug fix is correct.
%endif
	cmp al, '\'					; terminates with a \ ?
	ifz expandFileName_Error			; \\ combination not permitted ->
	cmp al, '/'					; terminates with a / ?
	ifz expandFileName_Error			; // combination not permitted ->

expandFileName_38:
	cmp cx, byte 2
%if 1
	jg expandFileName_56				; if not . or .., go get next -->
%else
		; RxDOS 7.20N:	Unsigned.
	ja expandFileName_56
%endif

	test word [ _options + bp ], FILECANNOT_BEDIRECTORY
	jz expandFileName_44
	cmp byte [ es:di - 1 ], '\'			; will always be \ in expansion string
	jnz expandFileName_56				; no, don't test for . and .. entries -->

expandFileName_44:
	cmp word [ es:di - 3 ], ".."			; back subdirectory
	jz expandFileName_50				; go backup to previous -->
	cmp word [ es:di - 3 ], "\."			; current subdirectory
	jz expandFileName_48				; all set -->
	cmp word [ es:di - 3 ], "/."			; current subdirectory
	jnz expandFileName_56				; all set -->

expandFileName_48:
	sub di, cx
	dec di						; fix current
	jmp short expandFileName_56			; go process next -->

		; backup to previous directory
expandFileName_50:
	mov word [ _currCluster + _low + bp ], 0
	mov word [ _currCluster + _high + bp ], 0	; no longer current cluster

	sub di, cx
	dec di						; fix to current,

	mov cx, di
	sub cx, word [ _ExpandBuffer + _pointer + bp ]
	sub cx, word [ _cds_SubstOffset + bp ]
%if 1
	jle expandFileName_56
%else
	jbe expandFileName_56
%endif

expandFileName_52:
	dec di
	cmp byte [ es:di - 1 ], '\'
	jz expandFileName_56
	cmp byte [ es:di - 1 ], '/'
	jz expandFileName_56
	loop expandFileName_52

		; more to go ?
expandFileName_56:
	mov cx, di
	sub cx, word [ _ExpandBuffer + _pointer + bp ]
	cmp cx, word [ _cds_SubstOffset + bp ]
%if 1
	jge expandFileName_60
%else
	jae expandFileName_60
%endif

	mov di, word [ _cds_SubstOffset + bp ]
	add di, word [ _ExpandBuffer + _pointer + bp ]

expandFileName_60:
	cmp byte [ si - 1 ], ' '+1			; was null ?
	ifnc expandFileName_30				; no, go get next -->

		; clean up string at end
	xor ax, ax
	mov byte [ es:di ], al				; add terminator

	mov di, word [ _ExpandBuffer + _pointer + bp ]
	mov cx, 128
	repne scasb					; scan for null terminator

	dec di
	mov cx, di
	sub cx, word [ _ExpandBuffer + _pointer + bp ]
	cmp cx, word [ _cds_SubstOffset + bp ]
%if 1
	jle expandFileName_66				; if minimal string -->
%else
	jbe expandFileName_66				; if minimal string -->
%endif

	cmp byte [ es:di - 1 ], '\'			; string ends with \ ?
	jz expandFileName_64				; no, ignore fix up -->
	cmp byte [ es:di - 1 ], '/'			; string ends with / ?
	jnz expandFileName_66				; no, ignore fix up -->

expandFileName_64:
	mov byte [ es:di - 1 ], 0			; kill any terminating (needless) \

expandFileName_66:
	getarg ax, _drive
%if 0
	mov cl, sizeCDS
	mul cl						; ax contains offset to current drive

	lds si, [ ss:_RxDOS_pCDS ]			; actual address in CDS
	add si, ax					; from

	push word [ bp + _ExpandBuffer + _segment ]
	push word [ bp + _ExpandBuffer + _pointer ]
	call StringLength
	inc cx						; also compare the terminating zero
	
	d4bp
	repe cmpsb					; compare expanded path to current directory
	jne expandFileName_68				; no match, ok -->
	
	mov cx, word [ _cdsStartClusterDir + _high + si ]
	mov dx, word [ _cdsStartClusterDir + _low + si ]
	mov word [ _currCluster + _low + bp ], dx
	mov word [ _currCluster + _high + bp ], cx	; use current starting cluster

expandFileName_68:
%endif

%if 1
	or ax, ax					; return drive
%else
	clc
%endif
	jmp short expandFileName_84

		; if error
expandFileName_Error:
	stc
	mov ax, pexterrPathNotFound

		; return
expandFileName_84:
	les di, [ _ExpandBuffer + bp ] 			; set return pointer
	mov dx, word [ _currCluster + _low + bp ]	; where to start search (or zero)
	mov cx, word [ _currCluster + _high + bp ]
	pop ds
	Return


		; Locate/validate file
		; 
		; This function takes a FCB pointer or ASCIZ path name and
		; determines whether the name and path are valid, and whether
		; the file exists. It returns a pointer to the file entry
		; in a directory buffer.
		; 
		; Input:
		; es:si-> input filename or fcb.
		; ss:di-> directory work area.
		; ax	options, as follows:
		; 
		; FILEIS_FCB		name is an FCB
		; FILE_NODEVICENAME	no device name allowed
		; FILEHAS_WILDCHARS	allowed in name
		; FILEHAS_NOFILENAME	no filename expected
		; FILECANNOT_BEDEFINED	filename must not exist
		; FILECANNOT_BEDIRECTORY	filename cannot be directory
		; FILEMAY_EXIST		file may exist (cluster not -1 )
		; FILE_ORDEVICE		file or device must exist
		; 
		; Output:
		; ss:di-> directory work area.
		; cx:dx	cluster address of located file
		; ax	drive
		; cy	means path/filename is not valid.
		; 
		; Assumes ss == ds
LocateFile:

	Entry

	def	drive, 0
	def	terminatingChar
	def	begfilenamePointer
	ddef	endfilenamePointer
	ddef	cluster, 0, 0
	ddef	dirCluster, 0, 0

	def	options, ax
	ddef	filename, es, si
	ddef	dirLocate, ss, di
	defbytes	tempFileName, sizeShortZFILENAME
	defbytes	diskAccess, sizeDISKACCESS

		; clear/init disk access block
	push es
	push ds

	push es
	setES ss
	clearMemory sizeDIRACCESS
	pop es						; restore source segment

		; expand name to a usable form
	setDS ss
	mov di, word [ _dirLocate + _pointer + bp ]
	lea di, [ word fileAcExpandedName + di ]	; expand name to store
	test word [ _options + bp ], FILEIS_FCB
	jz locateFile_12				; if not FCB -->

	push es
	push si
	push ss
	push di						; arguments
	call convFCBNametoASCIZ				; build ASCIZ name

locateFile_12:
	saveRegisters es, si, ss, di			; arguments
	call ExpandFileName				; expanded filename
	stordarg _cluster, cx, dx			; where to start search
	ifc locateFile_PathNotFound			; if path invalid -->
	
		; get disk parameters
locateFile_16:
	les si, [ _dirLocate + bp ]			; point to expanded filename
	lea si, [ word fileAcExpandedName + si ]	; expanded name store
	call getDrive					; extract drive name (es:si)
	storarg _drive, ax				; drive
	stordarg _endfilenamePointer, es, si		; save ptr to working dir
	ifc locateFile_PathNotFound			; if illegal drive -->

	call getDPB					; make sure drive is initialized
	ifc locateFile_PathNotFound			; if illegal drive -->

		; if search only current directory, skip to name
	mov ax, word [ _cluster + _low + bp ] 
	or ax, word [ _cluster + _high + bp ]		; if NOT search in subdirectory	
	jz locateFile_20				; ok as name is -->

	les si, [ _endfilenamePointer + bp ]
	call skipToLast					; skip to starting name
	stordarg _endfilenamePointer, es, si

		; get next name
locateFile_20:
	setES ss
	lea di, [ word _tempFileName + bp ]		; pointer to temp name
	lds si, [ _endfilenamePointer + bp ]
	call skipToNextName				; skip to starting name
	storarg _begfilenamePointer, si			; save starting pointer
	call convFilenametoFCBString			; convert to a match template
	jnz locateFile_24				; if name is not blank -->

	test word [ _options + bp ], FILECANNOT_BEDIRECTORY
	ifnz locateFile_FileNotFound			; if cannot be a directory -->
	jmp locateFile_56				; else return what we have so far -->

		; scan for wild characters
locateFile_24:
	stordarg _endfilenamePointer, ds, si
	mov word [ _terminatingChar + bp ], ax

	setES ss
	lea di, [ word _tempFileName + bp ]		; pointer to temp name
	mov cx, sizeFILENAME				; count
	mov al, '?'
	repne scasb					; scan for wild characters
	jnz locateFile_26				; if no wild chars found -->

	cmp byte [ _terminatingChar + bp ], '\'	
	ife locateFile_PathNotFound			; inside path def, error -->
	cmp byte [ _terminatingChar + bp ], '/'	
	ife locateFile_PathNotFound			; inside path def, error -->
	test word [ _options + bp ], FILEHAS_WILDCHARS
	ifz locateFile_FileNotFound			; if wild chars NOT allowed -->

		; see if entry is a device name
locateFile_26:
	currSegment ds, es				; set to seg address
	lea si, [ word _tempFileName + bp ]		; search es:si
	call getDevice					; determine if it's a device name
	ifc locateFile_32				; if not a device name -->

		; here if device name
	cmp byte [ _terminatingChar + bp ], '\'		; was name part of path ?
	ifz locateFile_PathNotFound			; inside path def, error -->
	cmp byte [ _terminatingChar + bp ], '/'		; was name part of path ?
	ifz locateFile_PathNotFound			; inside path def, error -->
	test word [ _options + bp ], FILE_NODEVICENAME	; else if in filename, it is allowed ?
	ifnz locateFile_FileNotFound			; error if no device names allowed -->

	clc						; if NO error
	mov si, word [ _dirLocate + _pointer + bp ]
	mov word [ ss:si + fileAcDevicePtr + _segment ], es
	mov word [ ss:si + fileAcDevicePtr + _pointer ], bx
	mov ax, 8000h
	jmp locateFile_60

		; scan for path in directory
locateFile_32:
	currSegment ds, es
	lea di, [ word _tempFileName + bp ]		; search es:di

	mov ax, word [ _drive + bp ]			; get drive
	getdarg cx, dx, _cluster			; cluster to search next
	stordarg _dirCluster, cx, dx			; start cluster of directory

locateFile_36:
	call scanDirectory				; scan for name in directory
	jnc locateFile_48				; if an item was found -->

		; here if no filename match found
	cmp byte [ _terminatingChar + bp ], '\'
	jz locateFile_PathNotFound			; inside path def, error -->
	cmp byte [ _terminatingChar + bp ], '/'
	jz locateFile_PathNotFound			; inside path def, error -->

		; entry not found or matched
	or word [ _drive + bp ], 8000h			; not found

	test word [ _options + bp ], (FILECANNOT_BEDEFINED + FILEMAY_EXIST)
	jnz locateFile_56				; if not defined is ok -->
	jmp short locateFile_FileNotFound		; not found -->

		; is FOUND entry a filename ?
locateFile_48:
	stordarg _cluster, cx, dx			; cluster to search next

	test bx, (ATTR_VOLUME + ATTR_DIRECTORY)		; is entry a directory ?
	jnz locateFile_50				; if not a file -->

	cmp byte [ _terminatingChar + bp ], '\'
	jz locateFile_PathNotFound			; if path expected, error -->
	cmp byte [ _terminatingChar + bp ], '/'
	jz locateFile_PathNotFound			; if path expected, error -->

	test word [ _options + bp ], (FILECANNOT_BEDEFINED + FILEHAS_NOFILENAME)
	jnz locateFile_AccessDenied			; if access denied -->
	jmp short locateFile_Return

		; is FOUND entry a directory ?
locateFile_50:
%if 1
	test bx, ATTR_DIRECTORY				; is item a directory ?
%else
	test bl, ATTR_DIRECTORY
%endif
	jz locateFile_FileNotFound			; if not, its an error -->
							;  (actually it's a volume label/LFN)
	cmp byte [ _terminatingChar + bp ], '\'
	ifz locateFile_20				; if path expected, get next -->
	cmp byte [ _terminatingChar + bp ], '/'
	ifz locateFile_20				; if path expected, get next -->

	test word [ _options + bp ], FILECANNOT_BEDIRECTORY
	jnz locateFile_FileNotFound			; if cannot be a directory -->
	test word [ _options + bp ], FILECANNOT_BEDEFINED
	jz locateFile_Return				; if everything is ok -->

		; in case of error
locateFile_FileNotFound:
	SetError pexterrFileNotFound, locateFile_60

locateFile_PathNotFound:
	SetError pexterrPathNotFound, locateFile_60

locateFile_AccessDenied:
	SetError pexterrAccessDenied, locateFile_60

		; return
locateFile_Return:
	call locateCCBPHeader				; si dir pointer/di CCB

	mov bx, word [ _dirLocate + _pointer + bp ]
	mov word [ fileAcBufferPtr + _segment + bx ], es
	mov word [ fileAcBufferPtr + _pointer + bx ], di
	mov word [ fileAcDirOffset + bx ], cx		; offset in dir sector

	mov ax, word [ es:di + ccbLBN + _low ]
	mov dx, word [ es:di + ccbLBN + _high ]
	mov word [ fileAcDirSector + _low + bx ], ax	; which dir sector
	mov word [ fileAcDirSector + _high + bx ], dx

		; exit
locateFile_56:
	mov bx, word [ _dirLocate + _pointer + bp ]	; restore bx

	getdarg cx, dx, _dirCluster			; start cluster of directory
	mov word [ fileAcDirCluster + _low + bx ], dx
	mov word [ fileAcDirCluster + _high + bx ], cx

	getdarg cx, dx, _cluster			; cluster to search next
	mov word [ fileAcCluster + _low + bx ], dx
	mov word [ fileAcCluster + _high + bx ], cx

	getarg ax, _drive				; drive
	mov word [ fileAcDrive + bx ], ax

	clc

		; exit
locateFile_60:
	push ax
	currSegment ds
	mov bx, word [ _dirLocate + _pointer + bp ]
	mov ax, word [ _begfilenamePointer + bp ]
	mov word [ fileAcNameOffset + bx ], ax
	
	getarg ax, _drive				; drive
	mov word [ fileAcDrive + bx ], ax

	pop ax
	pop ds
	pop es
	Return


		; Locate file by attribute
		;
		; Search starts at offset in 'findDirEntry'
		;
		; INP:	es:di-> find access block (DTA area)
LocateFileByAttribute:

	Entry
	def	attributes
	ddef	findAccess, es, di
	defbytes	diskAccess, sizeDISKACCESS

		; init access
	saveSegments
	getdarg es, di, _findAccess			; point to find access

	mov cl, byte [ es:di + findSrchAttributes ]
	and cl, ATTR_MASK
	mov byte [ _attributes + bp ], cl		; save for fast search

	mov al, byte [ es:di + findSrchDrive ]
	mov dx, word [ es:di + findDirBegCluster + _low ]
	mov cx, word [ es:di + findDirBegCluster + _high ]

	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call initdiskAccess				; ax is drive, cx:dx is cluster
	call getAddrDPB					; see if drive initialized

		; lookup entry
	getdarg es, di, _findAccess			; point to find access
	mov cx, sizeDIRENTRY
	mov ax, word [ es:di + findDirEntry ]
	cmp ax, byte -1
	jne locByAttrib_14

	xor ax, ax
	mov word [ es:di + findDirEntry ], ax

locByAttrib_14:
	mul cx

	sub ax, byte sizeDIRENTRY			; (not same as dec ax before sbb)
	sbb dx, byte 0					; just adjust for next loop
	mov word [ _diskAccess + diskAcPosition + _low + bp ], ax
	mov word [ _diskAccess + diskAcPosition + _high + bp ], dx
	mov word [ _diskAccess + diskAcOptions + bp ], (ccb_isDIR)

locByAttrib_18:
	setDS ss					; insure ds == ss

	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	add word [ diskAcPosition + _low + bx ], byte sizeDIRENTRY
	adc word [ diskAcPosition + _high + bx ], byte 0
	call _FATReadRandom				; read into buffer
	ifz locByAttrib_54				; if no more data -->

	lea di, [ word deName + bx ]			; get pointer to name
	cmp byte [ es:di ], DIRENTRY_NEVERUSED
	ifz locByAttrib_54				; if no more data -->

	cmp byte [ es:di ], DIRENTRY_DELETED
	jz locByAttrib_18				; don't bother -->

	lds si, [ _findAccess + bp ]			; pointer to search file name
	lea si, [ word findSrchName + si ]
	call compareDirEntries
	jnz locByAttrib_18				; if item not found -->

	mov cl, byte [ _attributes + bp ]		; template attributes
	mov ch, byte [ es:bx + deAttributes ]
	and ch, ATTR_MASK				; AND (NOT ATTR_READONLY)
	test ch, cl					; test for special cases
	jnz locByAttrib_28				; if bit match -->

	or cl, cl					; which files ?
	jz locByAttrib_22				; just normal files -->

	test cl, (ATTR_HIDDEN + ATTR_SYSTEM + ATTR_DIRECTORY)
	jz locByAttrib_18				; skip normal files -->

locByAttrib_22:
	and ch, ~ (ATTR_READONLY)			; is file a normal file ?
	jnz locByAttrib_18				; normal file filter -->

		; item found
locByAttrib_28:
	setDS es					; ds:bx points to dir entry
	getdarg es, di, _findAccess			; point to find access entry
	mov word [ es:di + findCCBPointer ], bx		; store CCB pointer

	mov al, byte [ deAttributes + bx ] 
	mov byte [ es:di + findFileAttribute ], al

	mov dx, word [ deDate + bx ]
	mov word [ es:di + findFileDate ], dx
	mov dx, word [ deTime + bx ]
	mov word [ es:di + findFileTime ], dx

	mov dx, word [ deFileSize + _low + bx ]
	mov cx, word [ deFileSize + _high + bx ]
	mov word [ es:di + findFileSize + _high ], cx
	mov word [ es:di + findFileSize + _low ], dx

	lea si, [ word deName + bx ]
	lea di, [ word findFileName + di ]		; resultant filename
	mov cx, sizefnName

locByAttrib_32:
	lodsb						; get character
	cmp al, ' '					; space delimeter ?
	jz locByAttrib_36				; yes -->
	stosb						; store value 
	loop locByAttrib_32

locByAttrib_36:
	lea si, [ word deExtension + bx ]		; point to extension
	cmp byte [ si ], ' '				; extension field blank ?
	jz locByAttrib_46				; yes -->

	mov al, '.'
	stosb						; dot delimeter
	mov cx, sizefnExtension

locByAttrib_42:
	lodsb						; get character
	cmp al, ' '					; space delimeter ?
	jz locByAttrib_46				; yes -->
	stosb						; store value 
	loop locByAttrib_42

locByAttrib_46:
	xor ax, ax
	stosb						; null terminator

	setDS ss
	mov di, word [ _findAccess + _pointer + bp ]
	mov ax, word [ _diskAccess + diskAcPosition + _low + bp ]
	mov dx, word [ _diskAccess + diskAcPosition + _high + bp ]
	mov cx, sizeDIRENTRY
	call _div32
	mov word [ es:di + findDirEntry ], ax

	mov dx, word [ _diskAccess + diskAcBegCluster + _low + bp ]
	mov cx, word [ _diskAccess + diskAcBegCluster + _high + bp ]
	mov word [ es:di + findDirBegCluster + _low ], dx
	mov word [ es:di + findDirBegCluster + _high ], cx

	; // removed to support FAT32
	; mov dx, word [ _diskAccess + diskAcCurCluster + _low + bp ]
	; mov cx, word [ _diskAccess + diskAcCurCluster + _high + bp ]
	; mov word [ es:di + findDirCurrCluster + _low ], dx
	; mov word [ es:di + findDirCurrCluster + _high ], cx

	clc
	jmp short locByAttrib_56

		; error exit
locByAttrib_54:
	mov ax, pexterrNoMoreFiles
	stc

		; return
locByAttrib_56:
	restoreSegments
	Return


		; Return where in directory
		; 
		; Input:
		; ss:di-> dir access block
		; 
		; Output:
		; dx:ax	directory sector
		; cl	offset in items from start of sector
		; 
		; Assumes ss == ds
getWhereInDir:

	mov ax, word [ fileAcDirOffset + di ]
	sub ax, byte ccbData				; adjust for header offset
	mov cl, sizeDIRENTRY				; bytes per entry
	div cl						; remainder should be zero
	mov cx, ax					; return in cl

	mov ax, word [ fileAcDirSector + _low + di ]
	mov dx, word [ fileAcDirSector + _high + di ]
	retn


		; Blank Init Directory Name
		; 
		; Input:
		; es:si-> directory entry in buffer
blankinitDirName:

	push di
	push cx
	push ax

	mov di, si
	clearMemory sizeFILENAME, 2020h

	pop ax
	pop cx 
	pop di
	retn


		; Scan Directory (Exact Search)
		;
		; Note:
		; Subdirectories are implemented as files. That means that
		; after each sector we must search for the next FAT table
		; entry to get the next cluster.
		;
		; Input:
		; ax	drive
		; cx:dx	cluster of dir to search
		; es:di	filename to search
		;
		; Output:
		; if item found:
		; ax	drive
		; bx	attributes
		; cx:dx	cluster
		; es:si-> located directory entry
		;
		; if item NOT found:
		; CY if item not found
scanDirectory:

	Entry
	ddef	cluster, cx, dx
	ddef	filenamePtr, es, di
	defbytes	diskAccess, sizeDISKACCESS

		; init access 
	setES ss
	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call initdiskAccess				; ax is drive, cx:dx is cluster
	call getDPB					; check for media change

		; lookup entry
	setES ss
	mov word [ _diskAccess + diskAcPosition + _low + bp ], -sizeDIRENTRY
	mov word [ _diskAccess + diskAcPosition + _high + bp ], -1
	mov word [ _diskAccess + diskAcOptions + bp ], (ccb_isDIR)

scanDir_36:
	add word [ _diskAccess + diskAcPosition + _low + bp ], byte sizeDIRENTRY
	adc word [ _diskAccess + diskAcPosition + _high + bp ], byte 0
	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call _FATReadRandom				; read into buffer
	stc						; just in case error,
	jz scanDir_56					; if no more data -->

	lea di, [ word deName + bx ]			; get pointer to name
	cmp byte [ es:di ], DIRENTRY_NEVERUSED
	stc						; just in case error,
	jz scanDir_56					; if no more data -->

	test byte [ es:bx + deAttributes ], ATTR_VOLUME
	jnz scanDir_36					; scan skips volume entries (and LFNs) -->

	lds si, [ _filenamePtr + bp ]			; pointer to search file name
	call compareDirEntries
	jnz scanDir_36					; if item not found -->

		; item found
	mov si, bx					; dir entry to si
	mov dx, word [ es:si + deStartCluster ]		; cluster
	mov cx, word [ es:si + deStartClusterExt ]	; ext cluster size
	mov bl, byte [ es:si + deAttributes ]		; attributes
	xor bh, bh					; zero, nc

	mov ax, word [ _diskAccess + diskAcDrive + bp ]

scanDir_56:
	Return


		; Compare Entries
		; 
		; Compare two directory entries. If the Lead character of
		; source string is E5, it is converted to 05 to help search.
		; 
		; Input:
		; ds:si	source string (may contain ? character )
		; es:di	match string (may not contain wild character )
		; 
		; Output:
		; ZR if entry matches
compareDirEntries:

	cmp byte [ si ], DIRENTRY_DELETED		; E5 ?
	jnz compareDirEntries_04
	mov byte [ si ], SPECIAL_CHAR

compareDirEntries_04:
	cmp byte [ es:di ], DIRENTRY_NEVERUSED
	jz compareDirEntries_08
	cmp byte [ es:di ], DIRENTRY_DELETED
	jnz compareDirEntries_12

compareDirEntries_08:
	mov al, byte [ es:di ]
	cmp al, '.'					; force non zero
	ret

compareDirEntries_12:
	push di
	push si
	mov cx, sizeFILENAME
	call CompareString				; source/dest compare
	pop si
	pop di						; restore pointers
	retn


		; Locate Empty Slot in Directory
		; 
		; Note:
		; This will allocate space to any subdirectory except the
		; root directory itself in order to create additional
		; directory entries.
		; 
		; 
		; Input:
		; ax	drive
		; cx:dx	cluster of dir to search
		; 
		; Output:
		; ax	drive
		; es:si-> located directory entry
		; CY if fixed-size root directory and no entries available
LocateFreeDirSlot:

	Entry
	defbytes	diskAccess, sizeDISKACCESS

		; init access 
	setES ds
	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call initdiskAccess				; ax is drive, cx:dx is cluster
	call getAddrDPB					; see if drive initialized

		; search for empty entry
	mov word [ _diskAccess + diskAcPosition + _low + bp ], -sizeDIRENTRY
	mov word [ _diskAccess + diskAcPosition + _high + bp ], -1	
	mov word [ _diskAccess + diskAcOptions + bp ], (ccb_isDIR)

locateFreeDirSlot_12:
	add word [ _diskAccess + diskAcPosition + _low + bp ], byte sizeDIRENTRY
	adc word [ _diskAccess + diskAcPosition + _high + bp ], byte 0
	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call _FATReadRandom				; read into buffer
	stc						; just in case error,
	jz locateFreeDirSlot_18				; if no more data -->

	cmp byte [ es:bx + deName ], DIRENTRY_NEVERUSED
	jz locateFreeDirSlot_16
	cmp byte [ es:bx + deName ], DIRENTRY_DELETED
	jnz locateFreeDirSlot_12			; if item not found -->

		; item found
locateFreeDirSlot_16:
	mov si, bx					; dir entry to si
	or si, si					; no carry
	Return

		; if not root directory, append a cluster
locateFreeDirSlot_18:
	lea bx, [ word _diskAccess + bp ]
	call IsRootExtendable
	jc locateFreeDirSlot_28				; if root dir, can't extend -->

	mov ax, word [ _diskAccess + diskAcDrive + bp ]
	call AllocateInitCluster			; init a cluster
	jc locateFreeDirSlot_28				; if can't append -->

	push cx						; cluster address to update
	push dx
	mov ax, word [ _diskAccess + diskAcDrive + bp ]
	mov dx, word [ _diskAccess + diskAcCurCluster + _low + bp ]
	mov cx, word [ _diskAccess + diskAcCurCluster + _high + bp ]
	call updateClusterValue
	lea si, [ word ccbData + di ]			; dir address to di
	or si, si					; no carry

		; return
locateFreeDirSlot_28:
	Return


		; Get actual drive
		;
		; INP:	wo:stack = byte drive. 0 = Current drive, 1 = A:, ...
		; OUT:	NC if valid drive,
		;	 ax, dx = drive. 0 = A:, ...
		;	CY if invalid drive,
		;	 ax = pexterrInvalidDrive
		;	 dx = drive. 0 = A:, ... (possible above Z:)
GetActualDrive:

	Entry 1
	arg	drive

	push ds
	currSegment ds
%if 1
	mov al, byte [ _drive + bp ]
	and ax, 001fh
%else
		; RxDOS 7.20N:	Above code would accept some invalid drives
	xor ax, ax
	mov al, byte [ _drive + bp ]
%endif
%if 1
	dec al
	jge GetActualDrive_20
%else
		; RxDOS 7.20N:	I think the above is invalid because dec doesn't set CF.
		;		This uses 0FFh if actually the current drive was requested!
		;		(AND always has set NC.)
	sub al, 1
	jae GetActualDrive_20
%endif

	mov al, byte [ _RxDOS_CurrentDrive ]

GetActualDrive_20:
	mov dx, ax
	cmp al, byte [ _RxDOS_bLastDrive ]
	jnc GetActualDrive_Error

%if 1
	cmp al, 1					; B: drive ?
	jnz GetActualDrive_32				; no -->

	push ds
	push bx
	xor bx, bx					; BIOS segment 
	mov ds, bx					; 0040:000E
%if 1
	mov ds, word [ 40Eh + bx ]			; BIOS Extended information
	test byte [ 00E7h + bx ], 80h			; B: present ?
%else
		; RxDOS 7.20N:	Unused bx offset.
	mov ds, word [ 40Eh ]				; BIOS Extended information
	test byte [ 00E7h ], 80h			; B: present ?
%endif

	jnz GetActualDrive_24				; yes -->

	; ... need message ...

%if 0
 cm:	Above code should move into RxBIO. In MS-DOS, IO.SYS will swap the disks
	and display the message. Additionally it won't just force B: the be always
	A: but rather validate the requested drive and invalidate the other if read
	or write attempts are made to the invalidated drive. (This allows to access
	the virtual B: often without always asking to swap the disks.) Before asking
	the user RxBIO should also call Int2F.4A00:

Excerpt from RBIL 61:
	INT 2F CU - DOS 5+ - FLOPPY-DISK LOGICAL DRIVE CHANGE NOTIFICATION
	AX = 4A00h
	CX = 0000h
	DH = new drive number
	DL = current drive number
Return: CX = FFFFh to skip "Insert diskette for drive X:" message
Note:	called by MS-DOS 5.0+ IO.SYS just before displaying the message
	  "Insert diskette for drive X:" on single-floppy systems
%endif

	xor ax, ax					; force B: to A:

GetActualDrive_24:
	pop bx
	pop ds
%endif

GetActualDrive_32:
	clc

GetActualDrive_Return:
	pop ds
	Return

GetActualDrive_Error:
	stc
	mov ax, pexterrInvalidDrive
	jmp short GetActualDrive_Return


		; Get Device from String
		; 
		; Input:
		; es:si	input string
		; 
		; Output:
		; es:bx-> device header
		; cy	device not found
getDevice:

	Entry
	defbytes	devicename, sizeShortZFILENAME

	SaveRegisters ds, di, si

		; get device name, if any
	setDS es
	setES ss
	lea di, [ word _devicename + bp ]
	mov cx, sizeFILENAME
	xor ax, ax

getDevice_08:
	lodsb
	cmp al, ' '+1					; if space or control
	jc getDevice_12
	cmp al, '/'					; if slash
	jz getDevice_12
	cmp al, '\'					; if backslash
	jz getDevice_12
	cmp al, '.'					; if extension separator
	jz getDevice_12
	cmp al, ':'					; if colon break
	jz getDevice_12

	_upperCase al					; upper case
	stosb						; store name
	loop getDevice_08				; continue -->

		; see if name is legitimate
getDevice_12:
	mov byte [ es:di ], 0				; zero terminate string

	currSegment ds					; restore ds:
	lea di, [ word _devicename + bp ]
	call checkforDeviceName				; see if char device name
	jc getDevice_26					; if invalid -->

	mov ax, es
	or ax, ax					; nc/nz character device 
	jmp short getDevice_Return			; exit with bad device error -->

		; if error
getDevice_26:
	mov ax, pexterrIllegalName
	stc

		; return
getDevice_Return:
	RestoreRegisters ds, di, si			; restore these registers
	Return


		; Get Drive from String
		; 
		; Input:
		; es:si	input string
		; 
		; Output:
		; es:si-> past ':' if any
		; ax = current drive or drive named
		; CY if error, invalid drive
getDrive:

	mov ax, word [ es:si ]				; save drive info available
	cmp ah, ':'					; drive break in string ?
	jnz getDrive_14					; no, return current -->

%if 1
	xor ah, ah					; clear carry
	_upperCase al					; upper case
	sub al, 'A'					; convert to a range
%else
	call uppercase
	sub ax, "A:"
%endif
	jc getDrive_12					; if invalid, return valid drive with carry ->

	cmp al, byte [ ss:_RxDOS_bLastDrive ]		; within valid range ?
%if 1
	jge getDrive_12					; yes -->
%else
		; RxDOS 7.20N:	Unsigned.
	jae getDrive_12
%endif

%if 1
	add si, byte 2					; skip drive letter / colon
%else
	inc si						; skip drive letter
	inc si						; and colon
%endif

		; return valid drive.
%if 1
		; RxDOS 7.20N:	Not required.
	cbw						; valid drive
%endif
%if 1
	or ax, ax
%else
	clc
%endif
	retn

		; return invalid drive
getDrive_12:
	stc
%if 1
	mov al, byte [ ss:_RxDOS_CurrentDrive ]
	retn
		; RxDOS 7.20N:	We'll just fall through.
%endif

		; return default drive
getDrive_14:
	xor ax, ax					; clear carry
	mov al, byte [ ss:_RxDOS_CurrentDrive ]
	retn


		; Get Current Directory Cluster
		; 
		; Input:
		; al	drive
		; 
		; Output:
		; es:bx-> CDS for drive
		; cx:dx	starting cluster address
getCurrDirCluster:

	push ax						; drive

	mov cl, sizeCDS
	mul cl						; offset into cds table

	les bx, [ ss:_RxDOS_pCDS ]			; CDS start address
	add bx, ax					; offset to proper drive
	mov dx, word [ es:bx + _cdsStartClusterDir + _low ]
	mov cx, word [ es:bx + _cdsStartClusterDir + _high ]

	pop ax
	retn


		; Read To App Buffer
		; 
		; Input:
		; ss:bx	Access Control Buffer
		; es:di	buffer address
		; dx:ax	file position to start reading
		; cx	bytes to read
		; 
		; Output:
		; ss:bx	Access Control Buffer
		; es:di	buffer address
		; cx	bytes actually read
		; zr	means end of file or wrong address
		; 
		; Preserved:
		; All registers except CX and FLAGS
		; 
readLogicalBuffer:

	Entry
	ddef	accessControl, ss, bx
	ddef	readbuffer
	def	bytestoRead, cx
	def	bytesRead, 0

	SaveSegments di, si, dx, bx, ax
	mov word [ ss:bx + diskAcPosition + _low ], ax
	mov word [ ss:bx + diskAcPosition + _high ], dx

readLogicalBuffer_08:
	NormalizeBuffer es, di				; normalize buffer pointer
	stordarg _readbuffer, es, di			; save read buffer pointer

	and word [ ss:bx + diskAcOptions ], ~ (DISKAC_READBUFFER_ASSIGNED + DISKAC_READ_MULTIPLESECTORS)
	mov cx, word [ _bytestoRead + bp ]		; get length remaining
	cmp cx, sizeSector + 1				; greater than sector size ?
	jc readLogicalBuffer_12				; no -->

		; optimize read setup
	or word [ ss:bx + diskAcOptions ], (DISKAC_READBUFFER_ASSIGNED + DISKAC_READ_MULTIPLESECTORS)
	mov word [ ss:bx + diskAcBytesToRead ], cx

	mov word [ ss:bx + diskAcBufferPtr + _segment ], es
	mov word [ ss:bx + diskAcBufferPtr + _pointer ], di

		; actual read
readLogicalBuffer_12:
	getarg bx, _accessControl			; make sure we point to access block
	or word [ ss:bx + diskAcOptions ], byte (ccb_isDATA)
	call _FATReadRandom				; get buffer, read at position
	or cx, cx					; any bytes read ?
	jz readLogicalBuffer_24				; no -->

	; es:bx, points to position in read buffer 
	; cx, # characters read

	getarg si, _accessControl			; make sure we point to access block
	test word [ ss:si + diskAcOptions ], DISKAC_RESULT_READMULTIPLESECTORS
	jnz readLogicalBuffer_20			; if buffered read -->

	cmp cx, word [ _bytestoRead + bp ]		; compare against length needed
	jc readLogicalBuffer_16				; if less are available -->
	mov cx, word [ _bytestoRead + bp ]		; minimize

readLogicalBuffer_16:
	push ds
	push cx
	setDS es
	mov si, bx					; where data read (ds:si)
	les di, [ _readbuffer + bp ]			; to destination (es:di)
	fastmove si, di					; move buffer

	pop cx
	pop ds

readLogicalBuffer_20:
	getarg bx, _accessControl			; make sure we point to access block
	add word [ ss:bx + diskAcPosition + _low ], cx
	adc word [ ss:bx + diskAcPosition + _high ], byte 0
	getdarg es, di, _readbuffer			; read buffer pointer
	add di, cx					; position beyond buffer

	add word [ _bytesRead + bp ], cx
	sub word [ _bytestoRead + bp ], cx		; compare against length needed
	jc readLogicalBuffer_24				; if no more to read -->
	jz readLogicalBuffer_24				; if no more to read -->
	jmp readLogicalBuffer_08			; continue reading -->

readLogicalBuffer_24:
	mov cx, word [ _bytesRead + bp ]

	RestoreSegments ax, bx, dx, si, di
	Return


		; Read Line To App Buffer
		; 
		; Input:
		; ss:bx	Access Control Buffer
		; es:di	buffer address
		; cx	max bytes to read
		; 
		; Output:
		; ss:bx	Access Control Buffer
		; es:di	buffer address
		; ax:dx	position in file after last byte read
		; cx	bytes returned, excluding trailing cr/lf
		; zr	means end of file or wrong address
readLine:

	Entry
	ddef	accessControl, ss, bx
	ddef	readbuffer, es, di
	def	bytestoRead, cx
	def	bytesRead, 0000
	def	bytesReturned, 0000			; line feeds removed
	ddef	bufferPtr

	SaveSegments di, si, bx

readLine_08:
	currSegment ds
	NormalizeBuffer es, di				; normalize buffer pointer
	stordarg _readbuffer, es, di			; save read buffer pointer

readLine_12:
	getarg bx, _accessControl			; make sure we point to access block
	mov ax, word [ ss:bx + diskAcFileSize + _low ]
	mov dx, word [ ss:bx + diskAcFileSize + _high ]
	sub ax, word [ ss:bx + diskAcPosition + _low ]
	sbb dx, word [ ss:bx + diskAcPosition + _high ]
	jc readLine_14					; if past eof ->
	or dx, ax					; at end of file ?
	jz readLine_14					; or if at end of file ->

	mov word [ ss:bx + diskAcOptions ], (ccb_isDATA)
	call _FATReadRandom				; get buffer, read at position
	stordarg _bufferPtr, es, bx

	or cx, cx					; any bytes left ?
	jnz readLine_16					; yes -->

readLine_14:
	cmp word [ _bytesReturned + bp ], byte 0	; any data returned ?
	jnz readLine_66					; yes, do valid return -->

	xor cx, cx
	jmp readLine_68					; else	return with Zero

		; parse through buffer
readLine_16:
	getarg bx, _accessControl			; make sure we point to access block
	mov ax, word [ ss:bx + diskAcFileSize + _low ]
	mov dx, word [ ss:bx + diskAcFileSize + _high ]
	sub ax, word [ ss:bx + diskAcPosition + _low ]
	sbb dx, word [ ss:bx + diskAcPosition + _high ]
	or dx, dx					; if lots of space left to read 
	jnz readLine_20					; then use all allowable cx -->

	or ax, ax					; any bytes left ?
	jz readLine_14					; no -->

	cmp ax, cx					; space left less than returned ?
	jnc readLine_20					; no -->
	mov cx, ax					; use only till end of file

readLine_20:
	cmp cx, word [ _bytestoRead + bp ]		; returned more than can read ?
	jc readLine_22					; no -->
	mov cx, word [ _bytestoRead + bp ]		; max allowed

readLine_22:
	push cx
	getdarg ds, si, _bufferPtr			; where data read [ds: si]
	getdarg es, di, _readbuffer			; to destination	[es: di]

readLine_36:
	lodsb
	cmp al, 10					; line feed ?
	jz readLine_38					; yes, drop LFs -->
	cmp al, 13					; carriage return ?
	jz readLine_44					; yes -->

	stosb						; save character (neither CR nor LF)
	inc word [ _bytesReturned + bp ]		; how many actually returned

readLine_38:
	loop readLine_36				; continue -->

	pop cx
	add word [ _bytesRead + bp ], cx		; how many actually read
	sub word [ _bytestoRead + bp ], cx		; compare against length needed
	jc readLine_66					; if no more to read -->
	jz readLine_66					; if no more to read -->

	getarg bx, _accessControl			; make sure we point to access block
	add word [ ss:bx + diskAcPosition + _low ], cx
	adc word [ ss:bx + diskAcPosition + _high ], byte 0
	getdarg es, di, _readbuffer			; read buffer pointer
	add di, cx					; position beyond buffer
	jmp readLine_12					; continue reading -->

readLine_44:
	xor al, al
	stosb						; save null terminating character

	dec cx						; account for line feed
	pop ax						; bytes expected
	sub ax, cx					; bytes actually read
	add word [ _bytesRead + bp ], ax		; how many actually read

	getarg bx, _accessControl			; make sure we point to access block
	add word [ ss:bx + diskAcPosition + _low ], ax
	adc word [ ss:bx + diskAcPosition + _high ], byte 0

readLine_66:
	mov al, -1
	or ax, ax					; non-zero retun if data

readLine_68:
	mov cx, word [ _bytesReturned + bp ]		; how many actually returned
	mov ax, word [ ss:bx + diskAcPosition + _low ]
	mov dx, word [ ss:bx + diskAcPosition + _high ]

	RestoreSegments bx, si, di
	Return


		; Write From App Buffer
		; 
		; Note:
		; 
		; Write uses FATRead to compute the correct logical sector
		; from cluster information. If a sector cannot be located,
		; then we attach a new cluster to the end of the file.
		; 
		; 
		; Input:
		; ss:bx	Access Control Buffer
		; es:di	buffer address
		; dx:ax	file position to start writing
		; cx	bytes to write
		; 
		; Output:
		; ss:bx	Access Control Buffer
		; es:di	buffer address
		; cx	bytes actually written
writeLogicalBuffer:

	Entry
	ddef	accessControl, ss, bx
	ddef	appBuffer
	def	bytestoWrite, cx
	def	bytesWritten, 0000

	SaveSegments di, si, dx, bx, ax
	mov word [ ss:bx + diskAcPosition + _low ], ax
	mov word [ ss:bx + diskAcPosition + _high ], dx	
	mov word [ ss:bx + diskAcOptions ], DISKAC_OPTIMIZEDWRITE + ccb_isDATA

writeLogicalBuffer_08:
	NormalizeBuffer es, di				; normalize buffer pointer
	stordarg _appbuffer, es, di			; save app buffer pointer

	cmp word [ _bytestoWrite + bp ], byte 0		; write none ?
	jz writeLogicalBuffer_32			; yes -->

writeLogicalBuffer_10:
	getarg bx, _accessControl			; make sure we point to access block
	call _FATReadRandom				; get buffer, read at position
	or cx, cx					; any bytes left ?
	jnz writeLogicalBuffer_14			; yes, no need to alloc more -->

	getarg bx, _accessControl			; make sure we point to access block
	mov ax, word [ diskAcDrive + bx ]
	mov dx, word [ diskAcCurCluster + _low + bx ]
	mov cx, word [ diskAcCurCluster + _high + bx ]
	call AppendCluster				; append cluster
	jnc writeLogicalBuffer_10			; go try to link to it now -->

	mov word [ _bytesWritten + bp ], 0		; BUG: This is here until we figure something better.
							;  We're here if we could not append a cluster.
							;  However MS-DOS also does it very similar.
	jmp short writeLogicalBuffer_32			; report error -->

writeLogicalBuffer_14:
	cmp cx, word [ _bytestoWrite + bp ]		; compare against length needed
	jc writeLogicalBuffer_16			; if less are available -->
	mov cx, word [ _bytestoWrite + bp ]		; maximize

writeLogicalBuffer_16:
	or cx, cx					; more to write
	jz writeLogicalBuffer_32			; no -->

	push ds
	push cx						; save bytes written in move
	mov di, bx					; where to write data (es:di)
	lds si, [ _appbuffer + bp ]			; data source (ds:si)
	fastmove si, di					; move buffer

	mov si, bx					; where data written
	call locateCCBPHeader				; find CCB header
	call CCBChanged					; mark block changed 

	pop cx
	pop ds
	getarg bx, _accessControl			; make sure we point to access block
	call adjustPositionAndFileSize			; bytes read in cx

	getdarg es, di, _appbuffer			; app buffer pointer
	add di, cx					; position beyond buffer

	add word [ _bytesWritten + bp ], cx
	sub word [ _bytestoWrite + bp ], cx		; compare against length needed
%if 1
	jc writeLogicalBuffer_32			; if no more to write -->
	jz writeLogicalBuffer_32			; if no more to write -->
	jmp writeLogicalBuffer_08			; continue writing -->
%else
	ja writeLogicalBuffer_08			; continue writing -->
%endif

writeLogicalBuffer_32:
	; call updateAllChangedCCBBuffers		; used only in debug mode
	mov cx, word [ _bytesWritten + bp ]

	RestoreSegments ax, bx, dx, si, di
	Return


		; Fill Space Required with NULLS
		; 
		; Input:
		; ss:bx	Access Control Buffer
		; dx:ax	bytes to fill with nulls
		; stack	file position to start writing
		; 
		; Output:
		; ss:bx	Access Control Buffer
		; cx	bytes actually written
		; zr	means end of file or wrong address
fillLogicalBuffer:

	Entry 2
	darg	position

	ddef	accessControl, ss, bx
	ddef	bytestoFill, dx, ax			; bytes to fill
	ddef	bytesFilled				; bytes filled (returned)

	SaveSegments di, si, bx
	xor ax, ax
	stordarg _bytesFilled, ax, ax			; bytes filled (returned)

	getdarg dx, ax, _position
	mov word [ diskAcPosition + _high + bx ], dx	
	mov word [ diskAcPosition + _low + bx ], ax
	mov word [ diskAcOptions + bx ], (ccb_isDATA)

fillLogicalBuffer_08:
	getarg bx, _accessControl			; make sure we point to access block
	call _FATReadRandom				; get buffer, read at position
	or cx, cx					; past end of allocation ?
	jnz fillLogicalBuffer_10			; no, no need to append a cluster -->

	getarg bx, _accessControl			; make sure we point to access block
	mov ax, word [ diskAcDrive + bx ]
	mov dx, word [ diskAcCurCluster + _low + bx ]
	mov cx, word [ diskAcCurCluster + _high + bx ]
	call AppendCluster				; append a cluster
	jnc fillLogicalBuffer_08			; if successful, go access next -->
	jmp short fillLogicalBuffer_34			; else error -->

fillLogicalBuffer_10:
	mov ax, word [ _bytestoFill + _low + bp ]
	mov dx, word [ _bytestoFill + _high + bp ]
	sub ax, cx
	sbb dx, byte 0
	jnc fillLogicalBuffer_12			; if more bytes to fill than available -->
	mov cx, word [ _bytestoFill + _low + bp ]

		; MS-DOS doesn't NULL fill expanded areas, so this code is disabled.
fillLogicalBuffer_12:
%if 0
		; RxDOS 7.20N:	Commented in former releases.
	push ds
	push cx
	mov di, bx					; where to write data (es:di)
	xor ax, ax					; fill with NULLS
	shr cx, 1					; maximize by filling words
	repz stosw
	jnc fillLogicalBuffer_16			; if even fill ->
	stosb						; else last byte
fillLogicalBuffer_16:

	mov si, bx					; where data written
	call locateCCBPHeader				; find CCB header
	call CCBChanged					; mark block changed 

	pop cx
	pop ds
%endif
	add word [ _bytesFilled + _low + bp ], cx
	adc word [ _bytesFilled + _high + bp ], byte 0
	
	mov ax, word [ _bytestoFill + _low + bp ]
	mov dx, word [ _bytestoFill + _high + bp ]
	sub ax, cx
	sbb dx, byte 0
	jc fillLogicalBuffer_32				; if no more to fill -->

	mov word [ _bytestoFill + _low + bp ], ax
	mov word [ _bytestoFill + _high + bp ], dx
	or ax, dx					; at end of write ?
	jz fillLogicalBuffer_32				; if no more to fill -->

	getarg bx, _accessControl			; make sure we point to access block
	call adjustPositionAndFileSize			; bytes moved in cx
	jmp short fillLogicalBuffer_08			; continue filling -->

fillLogicalBuffer_32:
	or ax, ax					; clear error flag

fillLogicalBuffer_34:
	call updateAllChangedCCBBuffers

	getdarg dx, ax, _bytesFilled
	RestoreSegments bx, si, di
	Return


		; Adjust FileSize in Disk Access Block
		; 
		; Input:
		; ss:bx	Access Control Buffer
		; cx	bytes read
		; 
		; Output:
		; dx:ax	Disk Access Position
		; 
adjustPositionAndFileSize:
	
	add word [ ss:bx + diskAcPosition + _low ], cx
	adc word [ ss:bx + diskAcPosition + _high ], byte 0

	mov ax, word [ ss:bx + diskAcPosition + _low ]
	mov dx, word [ ss:bx + diskAcPosition + _high ]
	sub ax, word [ ss:bx + diskAcFileSize + _low ]
	sbb dx, word [ ss:bx + diskAcFileSize + _high ]

	mov ax, word [ ss:bx + diskAcPosition + _low ]
	mov dx, word [ ss:bx + diskAcPosition + _high ]
	jb adjustPositionAndFileSize_08

	mov word [ ss:bx + diskAcFileSize + _low ], ax
	mov word [ ss:bx + diskAcFileSize + _high ], dx

adjustPositionAndFileSize_08:
	retn


		; Is Root Directory Extendable
		; 
		; Input:
		; ss:bx	Access Control Buffer
		; 
		; Output:
		; CY if not extendable
		; ax = drive
		; 
IsRootExtendable:

	setDS ss
	mov ax, word [ _diskAccess + diskAcBegCluster + _low + bx ]
	or ax, word [ _diskAccess + diskAcBegCluster + _high + bx ]
	jnz IsRootExtendable_Return			; not root dir ->

	push es
	push bx
	mov ax, word [ _diskAccess + diskAcDrive + bx ]
	call getDPB

	cmp word [ es:bx + _dpbSectorsPerFat ], byte 0	; FAT32 drive ?
	jz IsRootExtendable_12				; root is extendable -->
	stc

IsRootExtendable_12:
	pop bx
	pop es

IsRootExtendable_Return:
	mov ax, word [ _diskAccess + diskAcDrive + bx ]
	retn

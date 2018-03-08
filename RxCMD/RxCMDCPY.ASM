
%if 0

RxCMDCPY - RxCMD COPY command

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

Copyright (C) 1990-1999 Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

	cpu 8086

	segment RXCMD align=16 class=RXCMD use16 public start=100h
	segment RXCMD

%include "RXDMACRO.MAC"
%include "RXDSTRUC.MAC"
%include "RXCSTRUC.MAC"


	global _Copy
	global allocateCopyBuffer
	global freeCopyBuffer

	extern CmndError_BadSwitch
	extern CmndError_CannotCopyOverSelf
	extern CmndError_CannotCreateFile
	extern CmndError_ContentsLostBeforeCopy
	extern CmndError_InvalidNumberArguments
	extern CmndError_FileNotFound
	extern CmndError_ReadErrorAbort

	extern _Copy_FilesCopied
	extern CountArgs
	extern CRLF
	extern deletearg
	extern insertarg
	extern removeLooseSwitches
	extern DisplayErrorMessage
	extern DisplayLine
	extern RxDOS_AllFiles
	extern RxDOS_TruenameCurrDir
	extern FixUpArguments

	extern CopyString
	extern _endofString
	extern _Copy_FilesCopied
	extern _CmndParse_SeparatorCheck
	extern _SwitchChar
	extern _sprintf

	extern CheckFileClose
	extern BuildFullPathFirstFile
	extern BuildFullPathNextFile
	extern BuildFullPathClose
	extern LFNReturnPreferedFilenamePtr


		; Cluster Record
	struc CLUSTERRECORD
handle			resw 1				; file handle
clusterDrive		resw 1				; drive
clusterValue		resd 1				; value
	endstruc

sizeClusterRecord	equ CLUSTERRECORD_size
FASTREAD_BUFFERSIZE	equ 8192			; 8 Ki


		; RxCMD copy command
		; Syntax: COPY filenameA[+filenameB[+filenameC[...]]] [filenameDest]
		;
		; Usage:
		; ss:di-> argument array
		; ax = Number of arguments in array
_Copy:
	entry
	def	_argarray, di				; argument array
	def	_Mode, 0				; 0 = binary, else text
	def	overide, FALSE				; no automatic overide
	def	_AddMode				; 0 not add mode
	def	_bytesRead				; bytes actually read
	def	sameName, TRUE				; if take names from source
	def	wildChars, FALSE			; if wild char name replacement required
	def	filesCopied, 0
	def	findHandle, -1
	def	ptrName

	def	buffersize, SAFE_ALLOCATION
	ddef	pBuffer, 0, 0

	defbytes	destCluster,	sizeClusterRecord
	defbytes	srcCluster,	sizeClusterRecord

	defbytes	destFilename,	sizeLFNPATH	; destination work area (build path, wild chars)
	defbytes	createFilename,	sizeLFNPATH	; name to create
	defbytes	copyFilename,	sizeLFNPATH	; do I really need this ?????
	defbytes	finddata,	sizeFINDDATA

	defbytes	buffer,		SAFE_ALLOCATION


		; allocate copy buffer
	push es
	lea bx, [ _buffer + bp ]			; default buffer
	call allocateCopyBuffer				; allocate copy buffer
	stordarg _pBuffer, es, bx			; store copy buffer
	storarg	_buffersize, cx				; buffer size
	pop es

	mov bx, -1					; handle not init
	lea di, [ COMPAT_WORD _destCluster + bp ]			; cluster record
	call _initClusterRecord

	lea di, [ _copyFilename + bp ]
	mov word [ di ], '.'				; default to current directory if no destination


		; get/test destination filename
		;
		; destination argument may be:
		; 
		; (blank)		- replace with .
		; d:			- replace with d:.
		; path			- replace with d:\path (current drive, current path if path isn't from root)
		; d:\path[\]		- detect, set same name = TRUE
		; [path\]filename	- detect, set same name = FALSE, set wild chars = FALSE
		; [path\]file*name	- detect, set same name = FALSE, set wild chars = TRUE

	getarg di, __argarray				; args array
	call FixUpArguments				; removes "..." etc...

	getarg di, __argarray				; arguments array
	call removeLooseSwitches			; remove any extra args (switches)

	cmp ax, byte 1					; must have at least one arg
	ifc _copyInvalidNumberArguments			; any less means error -->
	jz _Copy_14					; if only one arg, then same as drive: case ->

	dec ax						; may not have more than two args
%if _COMPAT
	mov cx, sizeArgCmd
%else
	mov cl, sizeArgCmd
%endif
	mul cl						; ignore dx
	add di, ax					; point to last argument

	push word [ argpointer + di ]			; get last argument address
	push word [ arglength + di ]			; length
	call deletearg					; delete

	pop cx
	pop si
	lea di, [ _copyFilename + bp ]
	call _copyArgument				; copy argument


		; see if dest is just a directory name
	lea di, [ _copyFilename + bp ]
	call isitJustDriveLetter			; test for x:
	jz _Copy_14					; if just drive letter -->

	mov dx, di					; _copyFilename
	lea di, [ _finddata + bp ]
	call seeIfDirectoryName				; is it a directory ?
	jc _Copy_20					; if not a directory -->
	jz _Copy_20					; if not a dir entry -->

_Copy_14:
	storarg _sameName, TRUE				; same name
	storarg _wildChars, FALSE			; no wild chars replacement

	lea si, [ _copyFilename + bp ]
	lea di, [ _destFilename + bp ]			; expansion area
	mov byte [ di ], '\'				; (in case no output generated)

	mov cl, LFNEXPAND_GETFULLPATHNAME
	Int21 LFNGetActualFileName			; expand name
	ifc _copyCannotCreateFile			; destination doesn't exist -->

	lea di, [ _destFilename + bp ]			; destination path
	call _endofString				; locate end
%if 1
	cmp byte [ di ], '\'				; already a trailing \ ?
%else
	cmp byte [ di-1 ], '\'				; already a trailing \ ?
%endif
	jz _Copy_30					; yes -->

	mov word [ di ], '\'				; add trailing \ + null char
	jmp short _Copy_30				; start copy -->


		; not a directory
_Copy_20:
	storarg _sameName, FALSE			; same name not true
	storarg _wildChars, FALSE			; no wild chars replacement

	lea si, [ _copyFilename + bp ]
	lea di, [ _destFilename + bp ]			; expansion area
	mov byte [ di ], '\'				; (in case no output generated)

	mov cl, LFNEXPAND_GETFULLPATHNAME
	Int21 LFNGetActualFileName			; expand name
	ifc _copyCannotCreateFile			; destination doesn't exist -->


		; main loop through all args
_Copy_30:
	mov word [ __AddMode +  bp ], 0			; not add mode

_Copy_32:
	setDS ss
	getarg di, __argarray				; get arg pointer to next arg
	add word [ __argarray + bp ], sizeArgCmd	; skip this argument next time

	mov cx, word [ arglength + di ]			; argument length
	mov si, word [ argpointer + di ]		; point to text
	or si, si					; null entry ?
	ifz _Copy_ReturnClose				; yes, return -->

	mov ax, word [ si ]
	call _Copy_TestSwitch				; see if /a, /b ...
	jz _Copy_32
	call _Copy_AddMode				; see if + add
	jz _Copy_32

	fileAttrib ATTR_NORMAL
	lea di, [ _finddata + bp ]
	lea dx, [ _copyFilename + bp ]			; expanded path (sizeLFNPATH)
	call BuildFullPathFirstFile			; filename found for arg ?
	storarg _findHandle, bx				; save find handle
	storarg _ptrName, dx				; present name to next
	jnc _Copy_44					; if file found -->

	mov dx, CmndError_FileNotFound
	call DisplayLine
	jmp _copyErrorCleanUp


		; open source file
_Copy_44:
	lea di, [ _copyFilename + bp ]			; expanded path (sizeLFNPATH)
	ExOpenFile di, OPEN_ACCESS_READONLY		; open read only
	ifc _copyCannotOpenFile				; can't, display error -->

	mov bx, ax
	lea di, [ COMPAT_WORD _srcCluster + bp ]	; cluster record
	call GetClusterValue				; source cluster
	jz _Copy_50					; if not a file -->

	lea si, [ COMPAT_WORD _destCluster + bp ]	; cluster record
	call _compareClusters				; compare source and destination clusters
	jnz _Copy_50					; no -->

	; error: file destroyed

	mov dx, CmndError_ContentsLostBeforeCopy
	call DisplayErrorMessage			; dest file same as source
	jmp _copyErrorCleanUp


		; attempt create file
_Copy_50:
	cmp word [ _destCluster + handle + bp ], -1	; any destination file ?
	jz _Copy_52					; no, MUST create -->
	cmp word [ __AddMode +  bp ], 0			; add mode ?
	ifnz _Copy_68					; yes, append to existing file -->
	COMPAT_NOP

_Copy_52:
	lea si, [ _destFilename + bp ]			; destination filename
	lea di, [ _createFilename + bp ]		; make destination name
	call CopyString					; copy string

	cmp word [ _sameName + bp ], TRUE
	jnz _Copy_54					; different name available -->

	lea di, [ _copyFilename + bp ]
	call _PtrTo_Filename				; get pointer to filename
	push di

	lea di, [ _createFilename + bp ]		; make destination name
	call _PtrTo_Filename				; get pointer to filename

	pop si						; source name
	call CopyString					; copy string

_Copy_54:
	lea si, [ _createFilename + bp ]		; destination filename
	ExOpenFile si, OPEN_ACCESS_READONLY		; open read only
	jc _Copy_62					; MUST create -->

	mov bx, ax
	lea di, [ COMPAT_WORD _destCluster + bp ]	; cluster record
	call GetClusterValue				; cluster of dest
	Int21 CloseFile					; release file

	lea si, [ COMPAT_WORD _srcCluster + bp ]	; cluster record
	call _compareClusters				; compare source and destionation clusters
	ifz _copyCannotCopyOverSelf			; cannot copy over self -->


		; create file
_Copy_62:
	getarg ax, _overide				; previous overide
	lea si, [ _createFilename + bp ]		; destination filename
	; call _copyOverideCheck			; see if overide is ok
	; storarg _overide, ax				; store for future reference

	ExCreateFile si, ATTR_NORMAL
	ifc _copyCannotCreateFile			; if cannot be created or nulled -->

	mov bx, ax
	lea di, [ COMPAT_WORD _destCluster + bp ]	; cluster record
	call GetClusterValue				; cluster of dest

	lea si, [ COMPAT_WORD _srcCluster + bp ]	; cluster record
	call _compareClusters				; compare src and dest Clusters
	ifz _copyCannotCopyOverSelf			; camnnot copy over self -->


		; display filename
_Copy_68:
	mov bx, word [ _srcCluster + handle + bp ]
	Int21 IoControl, 00h				; is source a character device ?
	test dx, sftIsDevice				; test device flag
	jnz _Copy_74					; if device, skip display filename -->

	lea di, [ _finddata + bp ]
	call LFNReturnPreferedFilenamePtr
	call DisplayLine				; display line
	call CRLF					; CR, LF


		; copy loop
_Copy_74:
	push ds
	getarg	cx, _buffersize				; buffer size
	getdarg ds, dx, _pBuffer			; allocated buffer
	mov bx, word [ _srcCluster + handle + bp ]
	Int21 ReadFile					; read
	pop ds
	ifc _copyReadErrorAbort				; if error -->

	mov cx, ax					; bytes read
%if 1
	or cx, cx					; null chars returned ?
	jz _Copy_82					; must be end of file -->
%else
	jcxz _Copy_82					; if zero, end of file -->
%endif

	push ds
	getdarg ds, dx, _pBuffer			; allocated buffer
	mov bx, word [ _destCluster + handle + bp ]
	Int21 WriteFile					; write
	pop ds
	jmp short _Copy_74				; read more -->


		; close source file
_Copy_82:
	mov bx, word [ _srcCluster + handle + bp ]
	call _CopyCloseFile
	mov word [ _srcCluster + handle + bp ], -1	; change handle to reflect this

	setDS ss
	getarg di, __argarray				; get arg pointer to next arg
	mov si, word [ argpointer + di ]		; point to text
	jnz _Copy_92					; yes, go to next -->

	mov bx, word [ _destCluster + handle + bp ]
	call _CopyCloseFile				; if no adds left ...
	mov word [ _destCluster + handle + bp ], -1
	inc word [ _filesCopied + bp ]			; number of files copied.

	getarg dx, _ptrName				; name field
	getarg bx, _findHandle				; find handle
	lea di, [ _finddata + bp ]			; name area
	call BuildFullPathNextFile			; filename found for arg ?
	ifnc _Copy_44					; if file found -->

_Copy_92:
	getarg bx, _findHandle				; find handle
	call BuildFullPathClose				; close find search
	storarg _findHandle, -1				; clear find handle
	jmp _Copy_30


		; return
_Copy_ReturnClose:
	mov bx, word [ _destCluster + handle + bp ]
	cmp bx, -1					; destination still open ?
	jz _Copy_ReturnClose_08				; no, don't close -->
	call _CopyCloseFile
	mov word [ _destCluster + handle + bp ], -1
	inc word [ _filesCopied + bp ]			; number of files copied.

_Copy_ReturnClose_08:
	lea di, [ COMPAT_WORD _filesCopied + bp ]
	push di						; first arg encountered
	mov di, _Copy_FilesCopied
	push di

	lea di, [ _buffer + bp ]
	push di
	call _sprintf
	add sp, ax					; # args passed
	call DisplayLine

_Copy_Return:
	mov es, word [ _pBuffer + _segment + bp ]
	call freeCopyBuffer				; free copy buffer

	getarg bx, _findHandle				; find handle
	call BuildFullPathClose				; close find search
	Return


		; test switches
_Copy_TestSwitch:
	cmp al, byte [ _SwitchChar ]			; switch ?
	jz _Copy_TestSwitch_08
	retn

_Copy_TestSwitch_08:
	mov al, byte [ si+1 ]
%if 1
	_lowerCase al					; test switch option
%else
	call lowercase
%endif

		; RxDOS 7.20N:	Proper /B, /A, /-Y, /Y, /? switch parsing.
		;		Display and abort on invalid switches.

	storarg __Mode, 01				; ASCII mode
	cmp al, 'a'
	jz _Copy_TestSwitch_12

	storarg __Mode, 00				; binary mode

_Copy_TestSwitch_12:
	xor ax, ax
	retn


		; Add mode
_Copy_AddMode:
	cmp al, '+'
	jnz _Copy_AddMode_08
	mov word [ __AddMode  + bp ], -1		; set add mode

_Copy_AddMode_08:
	retn


		; error in rename command
_copyInvalidNumberArguments:
	mov dx, CmndError_InvalidNumberArguments
	jmp short _copyDisplayError

_copyCannotCopyOverSelf:
	mov dx, CmndError_CannotCopyOverSelf
	jmp short _copyDisplayError

_copyCannotOpenFile:
	mov dx, CmndError_FileNotFound
	jmp short _copyDisplayError

_copyCannotCreateFile:
	mov dx, CmndError_CannotCreateFile
	jmp short _copyDisplayError

_copyReadErrorAbort:
	mov dx, CmndError_ReadErrorAbort
	; jmp short _copyDisplayError

_copyDisplayError:
	call DisplayErrorMessage
	; jmp short _copyErrorCleanUp

_copyErrorCleanUp:
	mov bx, word [ _destCluster + handle + bp ]
%if 1
	cmp bx, -1					; if not assigned,
	jz _copyErrorCleanUp_08				; don't delete -->
		; RxDOS 7.20N:	_CopyCloseFile does that check already.
%endif
	call _CopyCloseFile

_copyErrorCleanUp_08:
	jmp short _Copy_Return


		; Close File
		;
		; Inputs:
		; bx = file Handle
_CopyCloseFile:

%if 1
	cmp bx, byte -1					; if not assigned,
	je _CopyClose_Exit				; exit -->
	or bx, bx
	jz _CopyClose_Exit				; exit -->
%else
	inc bx						; if not assigned,
	jz _CopyClose_Exit				; exit -->
	dec bx
	jz _CopyClose_Exit				; exit -->
%endif

	Int21 IoControl, 00				; is source a char device ?
	test dx, sftIsDevice				; test device flag
	jnz _CopyClose_Exit				; if device, skip close -->
		; RxDOS 7.20N:	Well, if we opened the device we've to close it as well...

	Int21 CloseFile					; close source file

_CopyClose_Exit:
	retn


		; Get ptr to filename after drive and path info
		;
		; Inputs:
		; ss:di-> pointer to null terminated path
		;
		; Outputs:
		; ss:di-> filename within path
		; CY if no path or filename found
_PtrTo_Filename:

	xor ax, ax
	mov cx, -1
	repne scasb					; scan for null terminator
	not cx						; actual size in cx
%if 0
	jz _PtrTo_Filename_10
%endif

_PtrTo_Filename_08:
	cmp byte [ ss:di - 1 ], '\'			; previous char a '\' ?
	jz _PtrTo_Filename_12				; if found --> (ZR, NC)

	dec di						; scan prev
	loop _PtrTo_Filename_08				; continue until start -->

_PtrTo_Filename_10:
	stc

_PtrTo_Filename_12:
	retn


		; Test if input is just a drive
		;
		; Inputs:
		; di	input text string
		;
		; Outputs:
		; zr	input text string contains only drive letter (x:)
		;
isitJustDriveLetter:

	cmp byte [ di ], 00				; null string ?
	jz isitJustDriveLetter_20			; yes, say yes to just drive -->

%if 1
	cmp byte [ di + 1 ], ':'			; only drive/colon entered ?
	jnz isitJustDriveLetter_20			; no -->
	cmp byte [ di + 2 ], 0				; must be followed by null
%else
	cmp word [ di + 1 ], byte ':'			; only colon followed by zero ?
%endif

isitJustDriveLetter_20:
	retn


		; Allocate copy buffer
		;
		; INP:	ss:bx-> default buffer
		; OUT:	es:bx-> actual copy buffer
		;	cx = size of buffer at es:bx
allocateCopyBuffer:

	push ax
	push di
	push bx

	mov bx, FASTREAD_BUFFERSIZE /16
	Int21 AllocateMemory				; 60 k
	jnc allocateCopyBuffer_12			; segment in ax

	setES ss
	pop bx						; use default address
	mov cx, FASTREAD_BUFFERSIZE			; use default size
	jmp short allocateCopyBuffer_20			; return -->

allocateCopyBuffer_12:
	pop bx						; ignore default buffer
	xor bx, bx					; new buffer at es:0000
	mov es, ax					; segment to es
	mov cx, FASTREAD_BUFFERSIZE

allocateCopyBuffer_20:
	pop di
	pop ax
	retn


		; Free copy buffer
		;
		; INP:	es = copy buffer segment
freeCopyBuffer:

	push ax
	push cx
	mov ax, es
	mov cx, ss

	or ax, ax
	jz freeCopyBuffer_18				; if not init -->
	cmp ax, cx
	jz freeCopyBuffer_18				; if allocated on stack -->
	Int21 FreeAllocatedMemory			; free memory block

freeCopyBuffer_18:
	pop cx
	pop ax
	retn


		; Insure OK to overwrite file
		;
		; Inputs:
		; ax	previous overide
		; dx	filename pointer
		; di	find data structure
		;
		; Outputs:
		; dx	filename pointer
		; ax	action code
		; 	'A'	overide all
		; 	0000 no
		; 	0001 yes
		;
_copyOverideCheck:

	cmp al, 'A'					; all ?
	jnz _copyOverideCheck_06			; no -->
	retn

_copyOverideCheck_06:
	push dx
	ExOpenFile dx, OPEN_ACCESS_READONLY		; open read only
	ifc _copyOverideCheck_OK			; doesn't, so exit with OK to overide
	COMPAT_NOP

	mov bx, ax
	Int21 CloseFile

	; display message, get overide ..



_copyOverideCheck_OK:
	mov ax, TRUE

_copyOverideCheck_Exit:
	pop dx
	retn


		; Init cluster value
		;
		; INP:	bx = file handle
		;	ss:di-> cluster record
_initClusterRecord:

	mov word [ ss:di + handle ], bx
	mov word [ ss:di + clusterDrive ], 0
	mov word [ ss:di + clusterValue + _low ], 0
	mov word [ ss:di + clusterValue + _high ], 0
	retn


		; Get starting cluster value for a given handle
		;
		; INP:	bx = file handle
		;	ss:di-> cluster record
		; OUT:	ax = drive
		;	cx:dx = cluster value
		;	ZR if cx|dx zero or if device
		;	NZ if cx|dx non-zero
GetClusterValue:
	entry
	def	handle, bx
	def	pClusterRecord, di

	push es
	push di
	push bx						; file handle
	call _initClusterRecord				; init to zeros
	Int21 GetPSPAddress				; returns bx with segment
	mov es, bx					; set PSP address

	les bx, [ es:pspFileHandlePtr ]			; point to file handles
	add bx, word [ _handle + bp ]			; offset to handle
	mov bl, byte [ es:bx ]				; get SFT number
	xor bh, bh
	push bx						; save SFT number
	Int21 GetDosDataTablePtr			; UNDOCUMENTED DOS CALL

	pop ax						; restore SFT number
	les si, [ es:bx + 4 ]				; get first FT

GetClusterValue_08:
	sub ax, word [ es:si + numberSFTEntries ]
	jc GetClusterValue_14				; if in current FT -->
	cmp word [ es:si + nextFTPointer + _pointer ], byte -1
	jz GetClusterValue_22				; if error -->

	les si, [ es:si + nextFTPointer ]		; get next FT
	jmp short GetClusterValue_08			; try it -->

GetClusterValue_14:
	add ax, word [ es:si + numberSFTEntries ]	; restore offset
	mov cx, sizeSFT
	mul cx						; offset times size of entries

	add si, sizeFT					; move past header
	add si, ax					; position at SFT entry

	test word [ es:si + sftDevInfo ], sftIsDevice
	jz GetClusterValue_18				; if not device, go get values -->
	xor ax, ax					; ZR if device
	jmp short GetClusterValue_26			; exit -->

GetClusterValue_18:
	mov cx, word [ es:si + sftBegCluster + _high ]
	mov dx, word [ es:si + sftBegCluster + _low ]
	mov ax, word [ es:si + sftDevInfo ]
	and ax, sftDrivemask

	getarg di, _pClusterRecord
	mov word [ ss:di + clusterDrive ], ax
	mov word [ ss:di + clusterValue + _low ], dx
	mov word [ ss:di + clusterValue + _high ], cx

	or ax, cx
	or ax, dx					; test for all zeroes
	jmp short GetClusterValue_26			; exit -->

GetClusterValue_22:
	stc

GetClusterValue_26:
	pop bx
	pop di
	pop es
	Return


		; Compare drive/cluster info
		;
		; INP:	ss:si-> cluster record
		;	ss:di-> cluster record
		; OUT:	NZ if not equal
_compareClusters:

	mov ax, word [ ss:si + clusterValue + _low ]
	or ax, word [ ss:si + clusterValue + _high ]	; device ?
%if 1
	jz _compareClusters_NotEqual			; not equal -->
%else
	jz .return_incax				; not equal -->
%endif

	mov ax, word [ ss:di + clusterValue + _low ]
	or ax, word [ ss:di + clusterValue + _high ]	; device ?
%if 1
	jz _compareClusters_NotEqual			; not equal -->
%else
	jz .return_incax				; not equal -->
%endif

	mov ax, word [ ss:si + clusterValue + _high ]
	cmp ax, word [ ss:di + clusterValue + _high ]	; high word of cluster matches ?
%if 1
	jne _compareClusters_NotEqual			; no -->
%else
	jne .return					; no -->
%endif

	mov ax, word [ ss:si + clusterValue + _low ]
	cmp ax, word [ ss:di + clusterValue + _low ]	; full cluster matches ?
%if 1
	jne _compareClusters_NotEqual			; no -->
%else
	jne .return					; no -->
%endif

	mov ax, word [ ss:si + clusterDrive ]
	cmp ax, word [ ss:di + clusterDrive ]		; drive also matches ?
%if 1
	jne _compareClusters_NotEqual			; no -->
%else
	jne .return					; no -->
%endif
	retn

%if 1
_compareClusters_NotEqual:
	or si, si					; say not equal
%else
.return_incax:
	inc ax
.return:
%endif
	retn


		; Copy argument, zero-terminating the destination string
		;
		; INP:	si-> argument start
		;	di-> destination
		;	cx = length
		; CHG:	ax, si
		; OUT:	si-> behind argument
_copyArgument:

	push di
	push cx
	repz movsb					; copy

	xor ax, ax
	stosb						; place null terminator
	pop cx
	pop di
	retn


		; RxDOS 7.20N:	Following code is never called.
%if 1
		; Replace with real name
		;
		; Input:
		; bx	finddata
		; di	full expanded name expected
		;
		; Output:
		; dx	full expanded name expected
_replaceWithRealName:

	push di
	xor ax, ax
	mov cx, -1
	repnz scasb					; length of string to scan
	not cx

_replaceWithRealName_08:
	mov al, byte [ es:di - 1 ]
	cmp al, '\'					; scan back until : or \
	jz _replaceWithRealName_12			; if found -->
	cmp al, ':'					; scan back until : or \
	jz _replaceWithRealName_12			; if found -->
	dec di
	loop _replaceWithRealName_08

_replaceWithRealName_12:
	push di
	mov di, bx
	call LFNReturnPreferedFilenamePtr
	mov si, dx
	pop di

	call CopyString
	pop di
	retn
%endif


		; See if directory name
		;
		; Input:
		; dx	filename
		; di	find data
		;
		; Output:
		; dx	full expanded name expected
seeIfDirectoryName:
	entry
	def	finddata, di

	fileAttrib ATTR_DIRECTORY
	mov si, FINDDATA_MSDOSDATEFORMAT
	Int21 LFNFindFirstFile				; locate file with name
	jc seeIfDirectoryName_24			; if not a directory -->

	mov bx, ax					; search handle

		; handle . or .. special cases
seeIfDirectoryName_16:
	getarg di, _finddata
	test byte [ findDataAttributes + di ], ATTR_DIRECTORY
	jz seeIfDirectoryName_20			; if not a dir entry -->

%if 1
	cmp byte [ findDataLongFilename + di ], '.'
	jne seeIfDirectoryName_20			; if dir and not . or .. -->
%else
	cmp word [ findDataLongFilename + di ], byte '.'
	je seeIfDirectoryName_18			; if dot entry (including zero) -->

	cmp word [ findDataLongFilename + di + 1 ], byte '.'
	jne seeIfDirectoryName_20			; if not dotdot entry (including zero) -->
							; only dot entries end with a dot
		; RxDOS 7.20N:	The former code is incorrect and skips any entry that
		;		starts with a dot. An usual LFN can start with a dot.
%endif
seeIfDirectoryName_18:
	mov si, FINDDATA_MSDOSDATEFORMAT
	lea di, [ _finddata + bp ]
	Int21 LFNFindNextFile				; locate next file
	jnc seeIfDirectoryName_16			; see if also a dir -->

seeIfDirectoryName_20:
	pushf
	Int21 LFNFindClose				; close handle
	popf

seeIfDirectoryName_24:
	Return


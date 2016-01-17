
%if 0

RxDOSLFN - RxDOS long filename mapping services

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

	global _Int21Function71
	global LFNReleaseFindData

	extern initdiskAccess
	extern CtrlC_Check
	extern VerifyAvailableHandle
	extern _RetCallersStackFrame

	extern _SFTOpenFile
	extern releaseSFT
	extern MapSFTToAppHandle
	extern convFCBNametoASCIZ

	extern getCurrDirCluster
	extern scanInvalidFilenameChars
	extern ifPathSeparator
	extern getDrive
	extern GetActualDrive
	extern checkforDeviceName
	extern getAddrDPB
	extern getDPB

	extern _div32
	extern CCBChanged
	extern convFilenametoFCBString
	extern locateCCBPHeader
	extern SetCCBChanged
	extern SelBuffer
	extern updateAllChangedCCBBuffers
	extern IsRootExtendable

	extern RxDOS_LFNTempStoreCount
	extern RxDOS_LFNTempStorage
	extern _RxDOS_CurrentPSP

	extern AllocateInitCluster
	extern updateClusterValue
	extern _FATReadRandom
	extern CompareString
	extern StringLength
	extern convDirEntrytoASCIZ

	extern initSFTfromDirEntry
	extern FindAvailableSFTHandle
	extern InitSFTEntry

	extern _chgErrorToPathNotFound
	extern getSysDateinDirFormat
	extern blankinitDirName
	extern ReleaseClusterChain
	extern updateDriveBuffers

	extern _GetCurrentDirectory
	extern _ExecuteProgram
	extern loadProgram
	extern CopyStringLowercase
	extern CopyString

	extern _RxDOS_pCDS
	extern _RxDOS_pLFNCDS
	extern _RxDOS_bLastDrive
	extern _RxDOS_CurrentDrive
	extern _bitShiftTable
	extern _invalidFnCharacters
	extern RxDOS_Heap

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


		; Macro. Pointer to Entry
		;
		; %1 = word reg, points to canonical list structure (not ax)
		; %2 = word reg, contains offset (di, si, bx, bp)
	%imacro _canptrtoentry 2.nolist
		mov ax, sizeCANONICALPOINTER
		mul %2
		lea %1, [ word _canpArray + %1 ]		; offset to next entry to store
		add %1, ax					; offset to next entry to store
	%endmacro

		; %1 = word reg, ??? (di, si, bx, bp)
		; %2 = ignored
	%imacro _canappendentry 1-2.nolist
		mov ax, sizeCANONICALPOINTER
		mul word [ _canpNumEntries + %1]		; get current entries
		lea %1, [ word _canpArray + %1 ]		; offset to next entry to store
		add %1, ax					; offset to next entry to store
	%endmacro


		; Offsets in LFN directory entry for match/copy purposes
_DefaultAll:		db '*', 0
LFN_DirEntry_MatchTable:db 1, 3, 5, 7, 9, 14, 16, 18, 20, 22, 24, 28, 30, -1


		; 71xxh Long Filename Services
		;
		; Dispatch on function code services
_Int21Function71:

	Goto DiskReset,			updateAllChangedCCBBuffers	; 0Dh
	Goto CreateSubdirectory,	Int71LFNCreateSubdirectory	; 39h
	Goto RemoveSubdirectory,	Int71LFNRemoveSubdirectory	; 3Ah
	Goto ChangeSubdirectory,	Int71LFNChangeSubdirectory	; 3Bh
	Goto DeleteFile,		Int71LFNDeleteFile		; 41h

	Goto ChangeFileMode,		Int71LFNChangeFileMode		; 43h
	Goto GetCurrentDirectory,	Int71LFNGetCurrentDirectory	; 47h
	Goto ExecuteProgram,		Int71LFNExecuteProgram		; 4Bh
	Goto FindFirstFile,		Int71LFNFindFirstFile		; 4Eh
	Goto FindNextFile,		Int71LFNFindNextFile		; 4Fh
	Goto RenameFile,		Int71LFNRenameFile		; 56h
	Goto GetActualFileName,		Int71LFNGetActualFileName	; 60h
	Goto ExtendedOpenCreate,	Int71LFNExtendedOpenCreate	; 6Ch

	Goto GetVolumeInformation,	Int71LFNGetVolumeInformation	; A0h
	Goto FindClose,			Int71LFNFindClose		; A1h
	Goto GetFileInfoByHandle,	Int71LFNGetFileInfoByHandle	; A6h
	Goto FileTime,			Int71LFNFileTime		; A7h
	Goto GenerateShortName,		Int71LFNGenerateShortName	; A8h
	; Goto ServerOpenFile,		__ServerOpenFile		; A9h
	; Goto Subst,			__Subst				; AAh

	seterror pexterrInvalidFunction
	retn


		; 7139h Create Subdirectory
		;
		; ds:dx-> subdirectory
Int71LFNCreateSubdirectory:

	Entry
	ddef	pathname, es, dx				; arg passed internally as es:dx
	ddef	ptrParentDirEntry				; dir reference
	ddef	alloccluster				; allocated cluster
	ddef	datetime

	defbytes	dirAccess, sizeDIRACCESS
	defbytes	structLongFilename, sizeSTRUCTLONGFILENAME


		; does entry already exist ?
	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call initStructLongFilename

	mov ax, (FILE_NODEVICENAME + FILEHAS_NOFILENAME + FILECANNOT_BEDEFINED)
	lea di, [ word _dirAccess + bp ]		; dir access
	getdarg es, si, _pathname			; arg passed internally as es:dx
	call LFNLocateFile				; check file path
	jnc LFNMakeSubDir_12				; if path is valid -->

	call _chgErrorToPathNotFound			; if name referenced path
	jmp LFNMakeSubDir_40				; if path invalid -->

		; find next empty directory entry
LFNMakeSubDir_12:
	and word [ _dirAccess + fileAcDrive + bp ], 7FFFh

	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	mov dx, word [ _dirAccess + fileAcDirCluster + _low + bp ]
	mov cx, word [ _dirAccess + fileAcDirCluster + _high + bp ]
	lea di, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call LFNBuildDirectoryEntry			; valid empty entry ?
	stordarg _ptrParentDirEntry, es, bx		; save ptr to directory reference
	ifc LFNMakeSubDir_40				; if can't find free slot -->

	call getSysDateinDirFormat
	stordarg _datetime, dx, ax			; make sure we get these

		; Allocate cluster for sub-directory
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	call AllocateInitCluster			; init/allocate dir cluster
	stordarg _alloccluster, cx, dx			; save cluster
	ifc LFNMakeSubDir_40				; if error -->

		; init (.) entry
	lea si, [ word ccbData + di ]			; point to data
	call blankinitDirName				; initialize file name
	mov byte [ es:si + deName ], '.'		; set dot entry

	getdarg cx, dx, _alloccluster			; get cluster
	mov word [ es:deStartCluster + si ], dx
	mov word [ es:deStartClusterExt + si ], cx

	getdarg dx, ax, _datetime			; get date/ time
	mov word [ es:deTime + si ], ax			; time created
	mov word [ es:deDate + si ], dx			; date created
	mov byte [ es:deAttributes + si ], ATTR_DIRECTORY

		; init (..) entry
	lea si, [ word ccbData + sizeDIRENTRY + di ]
	call blankinitDirName				; initialize file name
	mov word [ es:si + deName ], '..'		; set double dot entry

	mov dx, word [ _dirAccess + fileAcDirCluster + _low + bp ]
	mov cx, word [ _dirAccess + fileAcDirCluster + _high + bp ]
	mov word [ es:deStartCluster + si ], dx
	mov word [ es:deStartClusterExt + si ], cx

	getdarg dx, ax, _datetime			; get date time
	mov word [ es:deTime + si ], ax			; time created
	mov word [ es:deDate + si ], dx			; date created
	mov byte [ es:deAttributes + si ], ATTR_DIRECTORY

	mov bx, si
	call SetCCBChanged				; say buffer changed

		; in parent directory, build entry
	getdarg es, si, _ptrParentDirEntry		; restore si pointer
	getdarg cx, dx, _alloccluster			; get cluster
	mov word [ es:deStartCluster + si ], dx
	mov word [ es:deStartClusterExt + si ], cx
	mov byte [ es:deAttributes + si ], ATTR_DIRECTORY

	getdarg dx, ax, _datetime			; get date time
	mov word [ es:deTime + si ], ax			; time created
	mov word [ es:deDate + si ], dx			; date created

	mov bx, si					; identify dir entry
	call SetCCBChanged				; say buffer changed

	xor ax, ax					; clear carry

		; normal exit
LFNMakeSubDir_40:
	Return


		; 713Ah Remove Subdirectory
		;
		; ds:dx pointer to subdirectory
Int71LFNRemoveSubdirectory:

	Entry
	ddef	cluster
	ddef	pathname, es, dx				; arg passed internally as es:dx
	defbytes	dirAccess, sizeDIRACCESS
	defbytes	diskAccess, sizeDISKACCESS
	defbytes	structLongFilename, sizeSTRUCTLONGFILENAME


		; parse file name
	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call initStructLongFilename

	mov ax, (FILE_NODEVICENAME + FILEHAS_NOFILENAME)
	lea di, [ word _dirAccess + bp ]		; dir access
	getdarg es, si, _pathname			; arg passed internally as es:dx
	call LFNLocateFile				; check file path
	stordarg _cluster, cx, dx			; save cluster address
	jnc LFNRemoveSubDir_12				; if path valid -->

	call _chgErrorToPathNotFound			; if name referenced path
	jmp LFNRemoveSubDir_40				; if path invalid -->

		; trying to remove current directory ?
LFNRemoveSubDir_12:
	call getCurrDirCluster				; get cluster of curr directory

	sub dx, word [ _cluster + _low + bp ]
	sbb cx, word [ _cluster + _high + bp ]		; compare
	or cx, dx					; same directory as current ?
	jnz LFNRemoveSubDir_16				; dir is ok -->
	SetError pexterrCurrentDirectory, LFNRemoveSubDir_40

		; see if directory is empty (contains other than . and .. )
LFNRemoveSubDir_16:
	setES ds
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	mov dx, word [ _dirAccess + fileAcCluster + _low + bp ]
	mov cx, word [ _dirAccess + fileAcCluster + _high + bp ]
	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call initdiskAccess				; ax is drive, cx:dx is cluster

		; make sure entire directory is empty
	mov word [ _diskAccess + diskAcOptions + bp ], (ccb_isDIR)
	mov word [ _diskAccess + diskAcPosition + _low + bp ], sizeDIRENTRY

LFNRemoveSubDir_22:
	add word [ _diskAccess + diskAcPosition + _low + bp ], byte sizeDIRENTRY
	adc word [ _diskAccess + diskAcPosition + _high + bp ], byte 0
	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call _FATReadRandom				; read into buffer
	jz LFNRemoveSubDir_32				; if no more data, ok to delete -->

	cmp byte [ es:bx ], DIRENTRY_NEVERUSED
	jz LFNRemoveSubDir_32				; if no more data, ok to delete -->
	cmp byte [ es:bx ], DIRENTRY_DELETED		; entry deleted ?
	jz LFNRemoveSubDir_22				; yes, keep searching -->

	SetError pexterrIllegalName, LFNRemoveSubDir_40

		; ok to remove this entry.
LFNRemoveSubDir_32:
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	mov cx, word [ _dirAccess + fileAcCluster + _high + bp ]
	mov dx, word [ _dirAccess + fileAcCluster + _low + bp ]
	call ReleaseClusterChain

	les di, [ _dirAccess + fileAcBufferPtr + bp ]
	mov bx, word [ _dirAccess + fileAcDirOffset + bp ]
	mov byte [ es:di + bx ], DIRENTRY_DELETED
	call SetCCBChanged				; say buffer changed

	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	call updateDriveBuffers
	clc						; return no error

		; normal exit
LFNRemoveSubDir_40:
	Return


		; 713Bh Change Subdirectory
		;
		; ds:dx pointer to subdirectory
Int71LFNChangeSubdirectory:

	Entry
	def	drive
	ddef	cluster
	ddef	pathname, es, dx				; arg passed internally as es:dx
	defbytes	dirAccess, sizeDIRACCESS
	defbytes	structLongFilename, sizeSTRUCTLONGFILENAME


		; parse file name
	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call initStructLongFilename

	mov ax, (FILE_NODEVICENAME + FILEHAS_NOFILENAME)
	lea di, [ word _dirAccess + bp ]		; dir access
	getdarg es, si, _pathname			; arg passed internally as es:dx
	call LFNLocateFile				; check file path
	jnc LFNChangeSubDir_12				; if path valid -->

	call _chgErrorToPathNotFound			; if name referenced path
	jmp LFNChangeSubDir_40				; if path invalid -->

		; copy path to CDS table.
LFNChangeSubDir_12:
	push ds						; save current segment
	push dx						; cluster address
	push cx

	les di, [ _RxDOS_pLFNCDS ]			; actual address of LFNCDS
	mov ax, word [ _structLongFilename + _lfnDrive + bp ]
	mov cx, sizeLFNCDS
	mul cx						; ax contains current drive
	add di, ax					; pointer to LFNCDS

	setDS ss					; copy from stack
	lea bx, [ word _structLongFilename + bp ]
	call LFNBuildFullyFormedPATH			; copy fully formed path name

	setDS ss					; copy from stack
	les si, [ _RxDOS_pCDS ]				; actual address of CDS
	mov ax, word [ _structLongFilename + _lfnDrive + bp ]
	mov cx, sizeCDS
	mul cx						; ax contains current drive
	add si, ax

	pop word [ es:_cdsStartClusterDir + _high + si ]
	pop word [ es:_cdsStartClusterDir + _low + si ]
	pop ds						; restore ds
	clc						; no error

		; normal exit
LFNChangeSubDir_40:
	Return


		; 7141h Delete File
		;
		; ds:dx pointer to subdirectory
Int71LFNDeleteFile:

	Entry
	def	numentries
	ddef	filename, es, dx				; arg passed internally as es:dx

	defbytes	diskAccess, sizeDISKACCESS
	defbytes	dirAccess, sizeDIRACCESS
	defbytes	structLongFilename, sizeSTRUCTLONGFILENAME


		; parse file name
	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call initStructLongFilename

	mov si, dx					; name from caller
	lea di, [ word _dirAccess + bp ]		; dir access
	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDIRECTORY)
	call LFNLocateFile
	jc LFNDeleteFile_32				; if file/path valid -->

		; Release cluster chain
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	mov cx, word [ _dirAccess + fileAcCluster + _high + bp ]
	mov dx, word [ _dirAccess + fileAcCluster + _low + bp ]
	call ReleaseClusterChain

		; mark found entry in directory as deleted
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	mov dx, word [ _dirAccess + fileAcDirCluster + _low + bp ]
	mov cx, word [ _dirAccess + fileAcDirCluster + _high + bp ]
	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call initdiskAccess				; ax is drive, cx:dx is cluster

	mov ax, word [ _structLongFilename + _lfnOffsetShortEntry + _low + bp ]
	mov dx, word [ _structLongFilename + _lfnOffsetShortEntry + _high + bp ]
	sub ax, word [ _structLongFilename + _lfnOffsetLongEntry + _low + bp ]
	sbb dx, word [ _structLongFilename + _lfnOffsetLongEntry + _high + bp ]
	mov cx, sizeDIRENTRY
	div cx						; number of entries - 1
	inc ax
	storarg _numentries, ax

	mov ax, word [ _structLongFilename + _lfnOffsetLongEntry + _low + bp ]
	mov dx, word [ _structLongFilename + _lfnOffsetLongEntry + _high + bp ]
	sub ax, byte sizeDIRENTRY
	sbb dx, byte 0

	lea di, [ word _diskAccess + bp ]		; dir access
	mov word [ diskAcPosition + _low + di ], ax
	mov word [ diskAcPosition + _high + di ], dx

LFNDeleteFile_22:
	call _ReadNextDirEntry				; read entry
	jc LFNDeleteFile_28				; if error -->

	mov byte [ es:bx ], DIRENTRY_DELETED
	call SetCCBChanged				; say buffer changed

	dec word [ _numentries + bp ]			; more to go ?
	jnz LFNDeleteFile_22				; yes -->

		; make persitent
LFNDeleteFile_28:
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	call updateDriveBuffers
	or ax, ax					; return no error

LFNDeleteFile_32:
	Return


		; 7143h Change File mode
		;
		; ds:dx pointer to subdirectory
		;
		; bl	action
		; 00	return file attributes in CX
		; 01	set file attributes
		;  (all functions below not supported by RxDOS)
		; 02	get physical size of compressed file
		; 03	set last read/write time
		;	di	last write date
		;	cx	last write time
		; 04	get last read/write time
		;	di	last write date
		;	cx	last write time
		; 05	set last access date
		;	di	last access date
		;	cx	last access time
		; 06	get last access date
		;	di	last access date
		;	cx	last access time
		; 07	set creation date/time
		;	di	last access date
		;	cx	last access time
		; 08	get creation date/time
		;	di	last access date
		;	cx	last access time
		;	si	hundredths (10-millisecond units past time in cx, 0-199)
		;
		; STUB
Int71LFNChangeFileMode:

	Entry
	def	action, bx					; action to take
	def	filedate, di					; file date (if to set)
	def	filetime, cx					; file time (if to set)
	ddef	pathname, es, dx				; arg passed internally as es:dx
	ddef	cluster
	defbytes	dirAccess, sizeDIRACCESS
	defbytes	structLongFilename, sizeSTRUCTLONGFILENAME


		; parse file name
	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call initStructLongFilename

	mov ax, (FILE_NODEVICENAME)
	lea di, [ word _dirAccess + bp ]		; dir access
	getdarg es, si, _pathname			; arg passed internally as es:dx
	call LFNLocateFile				; check file path
	stordarg _cluster, cx, dx			; save cluster address
	jc LFNChangeFileMode_18				; if file/path not valid -->

		; if found, either get or set the attribute
	les di, [ _dirAccess + fileAcBufferPtr + bp ]
	mov bx, word [ _dirAccess + fileAcDirOffset + bp ]

	getarg ax, _action				; action to take
	Goto 00, LFNChangeFileMode_GetAttrib		; get
	Goto 01, LFNChangeFileMode_SetAttrib		; set

	SetError pexterrInvalidFunction, LFNChangeFileMode_18	; else -->

		; if get file attributes
LFNChangeFileMode_GetAttrib:
	RetCallersStackFrame ds, si
	mov cx, ATTR_DIRECTORY
	mov ax, es
	or ax, ax					; if no dir entry,
	jz LFNChangeFileMode_GetAttrib_08		; then it must be root dir ->
	mov cl, byte [ es:deAttributes + di + bx ]

LFNChangeFileMode_GetAttrib_08:
	mov word [ _CX + si ], cx
	Return

		; if set file attributes
LFNChangeFileMode_SetAttrib:
	mov ax, es
	or ax, ax					; root dir ?
	jnz LFNChangeFileMode_SetAttrib_08		; anything but root -->
	SetError pexterrPathNotFound, LFNChangeFileMode_18

LFNChangeFileMode_SetAttrib_08:
	mov cx, word [ _filetime + bp ]
	test cx, ~ ATTR_SETTABLE
	jz LFNChangeFileMode_12
	SetError pexterrAccessDenied, LFNChangeFileMode_18

LFNChangeFileMode_12:
	mov al, byte [ es:deAttributes + di + bx ]
	and al, ATTR_SETTABLE
	cmp al, cl
	jz LFNChangeFileMode_16				; if no change -->

	and byte [ es:deAttributes + di + bx ], ~ ATTR_SETTABLE
	or byte [ es:deAttributes + di + bx ], cl
	call CCBChanged					; update changed buffer

LFNChangeFileMode_16:
	clc

LFNChangeFileMode_18:
	Return


		; 7147h Get Current Directory
		;
		; dl	drive
		; ds:si pointer to path name
Int71LFNGetCurrentDirectory:

	Entry
	def	drive, dx
	def	actualdrive

	push dx						; argument to drive
	call GetActualDrive				; actual drive (in ax)
	storarg _actualdrive, ax			; actual drive
	jc LFNGetCurrDir_36				; if error -->

	call ptrLFNCurrentDirectory			; es:si-> current directory
	push es						; source is at es:

	RetCallersStackFrame ds, bx
	mov es, word [ _DS + bx ]
	mov di, word [ _SI + bx ]
	pop ds						; copy source segment to ds:

LFNGetCurrDir_22:
	lodsb						; copy buffer
	stosb
	or al, al
	jnz LFNGetCurrDir_22

LFNGetCurrDir_36:
	Return						; ds:si will be returned.


		; 714Bh Execute Program
		;
		; ds:dx pointer to path name
		; es:bx address of LOADEXEC structure
		; assumes mode 00h
		;
		; This function is an RxDOS extension.
		;
		; RxDOS 7.30+:
		; ds:dx-> program name
		; es:bx-> LOADEXEC structure
		; cl = mode
		;
		; INP:	es = user ds
Int71LFNExecuteProgram:

	entry
	ddef	filename, es, dx			; arg passed internally as es:dx
	def	mode, cx

	defbytes	dirAccess, sizeDIRACCESS
	defbytes	structLongFilename, sizeSTRUCTLONGFILENAME

		; lookup
	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call initStructLongFilename

	mov si, dx					; name from caller
	lea di, [ word _dirAccess + bp ]		; dir access
	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDIRECTORY)
	call LFNLocateFile				; locate file
	jc LFNExecuteProgram_18				; if file/path invalid -->

	setDS ss
	setES ss
	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	lea di, [ word _dirAccess + fileAcExpandedName + bp ]
	call LFNBuildFullyFormedPATH			; copy fully formed path name
	mov word [ _dirAccess + fileAcNameOffset + bp ], dx

		; pass dir access pointer
	push ds
	RetCallersStackFrame ds, si
	mov bx, word [ _BX + si ]			; get es:bx from caller
	mov es, word [ _ES + si ]
	pop ds

	mov ax, [ _mode + bp ]
	lea di, [ word _dirAccess + bp ]		; work dir access block
	call loadProgram

LFNExecuteProgram_18:
	Return


		; 714Eh Find First File
		;
		; Usage:
		; cl allowable attributes
		; ch required attributes
		; si date/time format
		;  0000 use 64-bit extended date time format
		;  0001 use MS-DOS date time format
		; ds:dx search spec (* and *.* are the same)
		; es:di finddata record
		;
		; Returns:
		; ax search file handle
		; cx 0000
		;
		; The first locate file call is designed to validate drive and
		; path. It returns a pointer to the correct directory.
		;
		; This information is used to build a pseudo SFT entry. The
		; entry contains the last search term, and drive/directory/dir
		; offset entries.
		;
		; The pseudo SFT entry is passed to LFNLocateFile and LFNLocate-
		; FileNext to filter entries by the same text search pattern
		; and attributes.
		;
		; Last name in search must not exceed MAX_PATH entries.
		; A pool of possible names is available at PathsPool.
		;
		; The application MUST close the file handle with function
		; 71A1h as soon as it has completed its search
Int71LFNFindFirstFile:

	Entry
	def	mustMatchAttributes, 0000
	def	searchAttributes, 0000
	def	datetimeformat, si
	def	LFNAllocHandle, 0000
	def	LFNTempStorePtr, 0000

	ddef	pathname, es, dx				; arg passed internally as es:dx
	ddef	finddata, es, di

	and cx, 1f1eh
	mov byte [ _mustMatchAttributes + bp ], ch
	mov byte [ _searchAttributes + bp ], cl

	RetCallersStackFrame ds, bx
	mov dx, word [ _DS + bx ]			; ds:dx ptr to search name
	mov ax, word [ _DX + bx ]			; ds:dx ptr to search name
	stordarg _pathname, dx, ax

	mov es, word [ _ES + bx ]			; es:di find data structure
	mov di, word [ _DI + bx ]			; es:di find data structure
	stordarg _finddata, es, di

	clearMemory sizeFINDDATA_MIN

	getdarg es, di, _pathname
	mov cx, -1
	xor ax, ax
	repnz scasb

	not cx
	dec cx
	cmp cx, sizeLFNPATH				; is name too long ?
	ifnc LFNFindFirst_NoMoreFiles			; yes, abort now -->

		; allocate SFT
	setES ss
	setDS ss

	call LFNAllocateFindDataStore			; allocate a store LFN
	ifc LFNFindFirst_NoHandlesAvailable		; if none available -->
	storarg _LFNAllocHandle, bx
	storarg _LFNTempStorePtr, di

	getdarg ds, si, _pathname			; get source text pointer
	lea di, [ word _lfnfindstoreFindText + di ]
	call CopyString					; copy string

	setDS ss
	getarg di, _LFNTempStorePtr
	lea bx, [ word _lfnfindstoreLFNStruc + di ]	; long filename, canonical name struct
	call initStructLongFilename

	mov ax, FILEHAS_WILDCHARS + FILTER_ONATTRIBUTES	; must filter on attributes
	mov cx, word [ _searchAttributes + bp ]
	mov byte [ _lfnSearchAttribs + bx ], cl
	mov cx, word [ _mustMatchAttributes + bp ]
	mov byte [ _lfnMustMatchAttribs + bx ], cl

	getarg di, _LFNTempStorePtr
	lea si, [ word _lfnfindstoreFindText + di ]	; file name
	lea di, [ word _lfnfindstoreDirAccess + di ]
	call LFNLocateFile				; check file path
	ifc LFNFindFirst_NoMoreFiles			; if item not found -->

		; return values in findata argument
	setDS ss
	getdarg es, di, _finddata
	getarg bx, _LFNTempStorePtr			; pointer to find store data
	lea di, [ word findDataShortFilename + di ]
	lea si, [ word _lfnfindstoreDirAccess + fileAcShortName + bx ]
	call CopyString					; copy short filename string

	mov di, word [ _finddata + _pointer + bp ]
	lea di, [ word findDataLongFilename + di ]
	lea si, [ word _lfnfindstoreDirAccess + fileAcExpandedName + bx ]
	cmp byte [ si ], 00				; long name available ?
	jnz LFNFindFirst_12				; no -->
	lea si, [ word _lfnfindstoreDirAccess + fileAcShortName + bx ]

LFNFindFirst_12:
	call CopyStringLowercase			; copy long filename string

	getdarg es, di, _finddata
	and word [ _lfnfindstoreDirAccess + fileAcDrive + bx ], 7FFFh
	mov si, word [ _lfnfindstoreDirAccess + fileAcBufferPtr + _pointer + bx ]
	add si, word [ _lfnfindstoreDirAccess + fileAcDirOffset + bx ]
	mov ds, word [ _lfnfindstoreDirAccess + fileAcBufferPtr + _segment + bx ]

	mov cx, word [ deAttributes + si ]
	mov word [ es:findDataAttributes + di ], cx

	mov dx, word [ deTime + si ]
	mov cx, word [ deDate + si ]
	mov word [ es:findDataCreateTime + finddataTime + di ], dx
	mov word [ es:findDataCreateTime + finddataDate + di ], cx

	mov cx, word [ deFileSize + _high + si ]
	mov dx, word [ deFileSize + _low + si ]
	mov word [ es:findDataFileSizeLow + _high + di ], cx
	mov word [ es:findDataFileSizeLow + _low + di ], dx

	clc
	getarg ax, _LFNAllocHandle			; find handle

		; Return
LFNFindFirst_Return:
	RetCallersStackFrame ds, bx
	mov word [ _AX + bx ], ax			; file handle
	mov word [ _CX + bx ], 0			; no Unicode support issues

	Return

		; Errors
		; RxDOS 7.20N: force near jump
LFNFindFirst_NoHandlesAvailable:
	SetError pexterrNoHandlesAvailable, near LFNFindFirst_ErrorCleanUp

LFNFindFirst_NoMoreFiles:
	SetError pexterrNoMoreFiles, near LFNFindFirst_ErrorCleanUp

		; Errors: Clean up allocations
LFNFindFirst_ErrorCleanUp:
	getarg bx, _LFNAllocHandle
	or bx, bx
	jz LFNFindFirst_Error08
	mov word [ bx ], 0				; item is released

LFNFindFirst_Error08:
	stc
	jmp short LFNFindFirst_Return


		; 714Fh Find Next File
		;
		; Usage:
		; bx	search file handle
		; si	date/time format
		;  0000	use 64-bit extended date time format
		;  0001	use MSDOS date time format
		; es:di-> finddata record
Int71LFNFindNextFile:

	Entry
	def	LFNAllocHandle, bx
	def	LFNTempStorePtr
	def	datetimeformat, si
	ddef	finddata, es, di

	call LFNValidateFindDataHandle			; validate handle in bx
	ifc LFNFindNext_NoMoreFiles			; not valid -->

	mov bx, word [ bx ]				; ptr to find store data
	storarg _LFNTempStorePtr, bx

	push ds
	RetCallersStackFrame ds, bx
	mov es, word [ _ES + bx ]			; es:di find data structure
	mov di, word [ _DI + bx ]			; es:di find data structure
	stordarg _finddata, es, di

	clearMemory sizeFINDDATA_MIN
	pop ds

	getarg di, _LFNTempStorePtr			; pointer to find store data
	lea bx, [ word _lfnfindstoreLFNStruc + di ]	; LFN
	mov dx, word [ _lfnOffsetShortEntry + _low + bx ]
	mov cx, word [ _lfnOffsetShortEntry + _high + bx ]
	add dx, byte sizeDIRENTRY
	adc cx, byte 0

	lea si, [ word _lfnfindstoreFindText + di ]	; file name
	lea di, [ word _lfnfindstoreDirAccess + di ]	; dir access
	call LFNLocateFileNext				; go search
	ifc LFNFindNext_NoMoreFiles			; if item not found -->

		; return values in findata argument
	setDS ss
	getdarg es, di, _finddata
	getarg bx, _LFNTempStorePtr			; pointer to find store data
	lea di, [ word findDataShortFilename + di ]
	lea si, [ word _lfnfindstoreDirAccess + fileAcShortName + bx ]
	call CopyString					; copy short filename string

	mov di, word [ _finddata + _pointer + bp ]
	lea di, [ word findDataLongFilename + di ]
	lea si, [ word _lfnfindstoreDirAccess + fileAcExpandedName + bx ]
	cmp byte [ si ], 00				; long name available ?
	jnz LFNFindNext_12				; no -->
	lea si, [ _lfnfindstoreDirAccess + fileAcShortName + bx ]

LFNFindNext_12:
	call CopyStringLowercase			; copy long filename string

	getdarg es, di, _finddata
	and word [ _lfnfindstoreDirAccess + fileAcDrive + bx ], 7FFFh
	mov si, word [ _lfnfindstoreDirAccess + fileAcBufferPtr + _pointer + bx ]
	add si, word [ _lfnfindstoreDirAccess + fileAcDirOffset + bx ]
	mov ds, word [ _lfnfindstoreDirAccess + fileAcBufferPtr + _segment + bx ]

	mov cx, word [ deAttributes + si ]
	mov word [ es:findDataAttributes + di ], cx

	mov dx, word [ deTime + si ]
	mov cx, word [ deDate + si ]
	mov word [ es:findDataCreateTime + finddataTime + di ], dx
	mov word [ es:findDataCreateTime + finddataDate + di ], cx

	mov cx, word [ deFileSize + _high + si ]
	mov dx, word [ deFileSize + _low + si ]
	mov word [ es:findDataFileSizeLow + _high + di ], cx
	mov word [ es:findDataFileSizeLow + _low + di ], dx

	clc

		; Return
LFNFindNext_Return:
	RetCallersStackFrame ds, bx
	mov word [ _CX + bx ], 0			; no Unicode support issues

	Return

		; Errors
LFNFindNext_NoMoreFiles:
	SetError pexterrNoMoreFiles, short LFNFindNext_Return

LFNFindNext_InvalidHandle:
	SetError pexterrInvalidHandle, short LFNFindNext_Return


		; 7156h Rename File
		;
		; ds:dx ASCIZ old file or directory name
		; es:di ASCIZ new file or directory name
Int71LFNRenameFile:

	Entry
	ddef	oldfilename, es, dx			; old filename
	ddef	oldnameDirOffset
	def	deleteentries

	defbytes	diskAccess, sizeDISKACCESS
	defbytes	existfileAccess, sizeDIRACCESS
	defbytes	renfileAccess, sizeDIRACCESS
	defbytes	OldDirEntry, sizeDIRENTRY
	defbytes	structLongFilename, sizeSTRUCTLONGFILENAME

		; does file exist ?
	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call initStructLongFilename

	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDIRECTORY)
	lea di, [ word _existfileAccess + bp ]		; dir access
	getdarg es, si, _oldfilename			; arg passed internally as es:dx
	call LFNLocateFile				; check file path
	ifc LFNRenameFile_40				; if file does not exist -->

	lea di, [ word _structLongFilename + bp ]
	mov dx, word [ _lfnOffsetLongEntry + _low + di ]
	mov cx, word [ _lfnOffsetLongEntry + _high + di ]
	stordarg _oldnameDirOffset, cx, dx

	mov cx, word [ _lfnDirEntriesReqd + di ]
	storarg _deleteentries, cx

	push ds
	setES ss
	lds si, [ _existfileAccess + fileAcBufferPtr + bp ]
	add si, word [ _existfileAccess + fileAcDirOffset + bp ]

	lea di, [ word _OldDirEntry + bp ]
	mov cx, (sizeDIRENTRY / 2)
	rep movsw

		; does rename file exist ?
	RetCallersStackFrame ds, bx
	mov es, word [ _ES + bx ]
	mov si, word [ _DI + bx ]			; get user's parameter
	pop ds

	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call initStructLongFilename

	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDEFINED + FILECANNOT_BEDIRECTORY)
	lea di, [ word _renfileAccess + bp ]		; dir access
	call LFNLocateFile				; check file path
	ifc LFNRenameFile_40				; if file does not exist -->

	mov al, byte [ _existfileAccess + fileAcDrive + bp ]
	cmp al, byte [ _renfileAccess + fileAcDrive + bp ]
	mov ax, pexterrPathNotFound
	stc
	ifnz LFNRenameFile_40				; cannot move across drives -->

		; both files seem ok. Create new entry
	mov ax, word [ _existfileAccess + fileAcDrive + bp ]
	mov dx, word [ _existfileAccess + fileAcDirCluster + _low + bp ]
	mov cx, word [ _existfileAccess + fileAcDirCluster + _high + bp ]
	lea di, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call LFNBuildDirectoryEntry			; valid empty entry ?
	jc LFNRenameFile_40				; if can't find free slot -->

	mov di, bx
	add di, byte sizeFilename
	lea si, [ word _OldDirEntry + sizeFilename + bp ]
	mov cx, sizeDIRENTRY - sizeFilename
	repe movsb					; copy allocation/date details

		; place delete marks on old name
	mov ax, word [ _existfileAccess + fileAcDrive + bp ]
	mov dx, word [ _existfileAccess + fileAcDirCluster + _low + bp ]
	mov cx, word [ _existfileAccess + fileAcDirCluster + _high + bp ]
	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call initdiskAccess				; ax is drive, cx:dx is cluster

	setES ss
	mov dx, -sizeDIRENTRY
	mov cx, -1
	add dx, word [ _oldnameDirOffset + _low + bp ]
	adc cx, word [ _oldnameDirOffset + _high + bp ]
	mov word [ _diskAccess + diskAcPosition + _low + bp ], dx
	mov word [ _diskAccess + diskAcPosition + _high + bp ], cx

	inc word [ _deleteentries + bp ]

LFNRenameFile_22:
	lea di, [ word _diskAccess + bp ]
	call _ReadNextDirEntry				; read directory sector
	jc LFNRenameFile_38				; if error -->

	mov byte [ es:bx ], DIRENTRY_DELETED
	call SetCCBChanged				; say buffer changed

	dec word [ _deleteentries + bp ]		; more to go ?
	jnz LFNRenameFile_22				; yes -->

		; return
LFNRenameFile_38:
	mov ax, word [ _existfileAccess + fileAcDrive + bp ]
	call updateDriveBuffers
	or ax, ax					; no carry

LFNRenameFile_40:
	Return


		; 7160h Get Actual Filename
		;
		; Input:
		; cl	minor code
		;  0 Get Full Path Name
		;  1 Get Short Path Name
		;  2 Get Long Path Name
		;
		; ch	substexpand
		;  00h Return true path
		;  80h Return subst drive letter
		; (not supported in RxDOS)
		;
		; ds:si-> source path (null terminated)
		; es:di-> destination buffer
		;
		; Output:
		; es:di-> long, short, or full path in destination field
		; CY if error detected
Int71LFNGetActualFileName:

	Entry
	ddef	filename, es, si
	ddef	pOutputString

	defbytes	dirAccess, sizeDIRACCESS
	defbytes	structLongFilename, sizeSTRUCTLONGFILENAME

	RetCallersStackFrame es, bx
	mov dx, word [ es:_ES + bx ]			; expanded filename
	mov ax, word [ es:_DI + bx ]
	stordarg _pOutputString, dx, ax

	mov si, word [ es:_SI + bx ]
	mov es, word [ es:_DS + bx ]			; es:si ptr to unexpanded name

	setDS ss
	mov al, cl
	Goto LFNEXPAND_GETFULLPATHNAME,	LFN_GetFullPathName
	Goto LFNEXPAND_GETSHORTPATHNAME,LFN_GetShortPathName
	Goto LFNEXPAND_GETLONGPATHNAME,	LFN_GetLongPathName

	retn


		; Expand Name and Path
LFN_GetFullPathName:
		; RxDOS 7.20N:	Actually the get full path function should also:
		;		- Use the current path from the SFN CDS (if required)
		;		- Uppercase file names
		;		However RxDOS just returns the long path as for subfunction 02h.

LFN_GetLongPathName:

	mov ax, (FILEHAS_WILDCHARS + FILEMAY_EXIST)
	lea di, [ word _structLongFilename + bp ]
	lea di, [ byte _lfnCanonicalList + di ]
	call BuildCanonicalPointerList			; build canonical pointer list
	jc LFN_GetFullPathName_38			; if path invalid -->

		; set drive letter
	getdarg es, di, _pOutputString
	add al, 'A'					; drive letter in ASCII
	stosb						; store drive letter

	mov ax, ':\'
	stosw						; append ':\'

		; set to copy directories (preserve es:di)
	lea bx, [ word _structLongFilename + bp ]
	mov dx, word [ ss:_lfnCanonicalList + _canpNumEntries + bx ]

	lea bx, [ word _lfnCanonicalList + _canpArray + bx ]

LFN_GetFullPathName_22:
	or dx, dx					; more entries to go ?
	jz LFN_GetFullPathName_26			; no -->

	mov ds, word [ ss:_canpStringPointer + _segment + bx ]
	mov si, word [ ss:_canpStringPointer + _pointer + bx ]
	mov cx, word [ ss:_canpStringLength + bx ]	; string length
	repe movsb					; copy to es:di

	mov al, '\'
	stosb						; if more arguments follow

	add bx, word sizeCANONICALPOINTER		; RxDOS 7.20N
	dec dx
	jnz LFN_GetFullPathName_22

	dec di						; backup over last '\'

LFN_GetFullPathName_26:
	xor ax, ax					; clear carry
	stosb						; store null terminator

LFN_GetFullPathName_38:
	Return


		; Get Short Path Name
LFN_GetShortPathName:

	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call initStructLongFilename

	xor ax, ax
	lea di, [ word _dirAccess + bp ]		; dir access
	call LFNLocateFile				; check file path
	jc LFN_GetShortPathName_38			; if not found, exit -->

	getdarg es, di, _pOutputString
	lea si, [ word _structLongFilename + _lfnShortFCBName + bp ]

LFN_GetShortPathName_12:
	lodsb
	stosb
	or al, al					; copy string
	jnz LFN_GetShortPathName_12

LFN_GetShortPathName_38:
	Return


		; 716Ch Extended Open Create
		;
		; Input:
		; bx	open access mode flags
		; cx	attributes
		; dx	action
		; di	hints
		; ds:si	ASCIZ name of file
		;
		; Output:
		; ax	handle (or error code)
		; cx	action taken
		; cy	if error detected
Int71LFNExtendedOpenCreate:

	Entry
	def	mode, bx
	def	attributes, cx
	def	action, dx
	def	found, FALSE

	ddef	sft
	ddef	filename, es, si
	defbytes	dirAccess, sizeDIRACCESS
	defbytes	structLongFilename, sizeSTRUCTLONGFILENAME

	call VerifyAvailableHandle			; see if handle available
	ifc _LFNExtendedOpenCreate_42			; if error -->

		; determine if file exists
	lea bx, [ word _structLongFilename + bp ]	; long filename, canonical name struct
	call initStructLongFilename

	mov ax, (FILECANNOT_BEDIRECTORY)
	lea di, [ word _dirAccess + bp ]		; dir access
	getdarg es, si, _filename
	call LFNLocateFile				; check file path
	jnc _LFNExtendedOpenCreate_Open			; if file found, open -->

	storarg _found, FALSE
	test word [ _action + bp ], EXTENDEDACTION_CREATE
	jnz _LFNExtendedOpenCreate_Create
	stc						; else set error
	jmp _LFNExtendedOpenCreate_42			; if not create, call fails -->

		; open file
_LFNExtendedOpenCreate_Open:
	storarg _found, TRUE

	test word [ _action + bp ], EXTENDEDACTION_TRUNCATE
	jz _LFNExtendedOpenCreate_30			; ok to create/ truncate -->

	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	mov dx, word [ _dirAccess + fileAcCluster + _low + bp ]
	mov cx, word [ _dirAccess + fileAcCluster + _high + bp ]
	call ReleaseClusterChain

	mov es, word [ _dirAccess + fileAcBufferPtr + _segment + bp ]
	mov bx, word [ _dirAccess + fileAcBufferPtr + _pointer + bp ]
	add bx, word [ _dirAccess + fileAcDirOffset + bp ]

	mov word [ es:bx + deStartCluster ], 0
	mov word [ es:bx + deStartClusterExt ], 0
	mov word [ es:bx + deFileSize + _low ], 0
	mov word [ es:bx + deFileSize + _high ], 0

	mov di, word [ _dirAccess + fileAcBufferPtr + _pointer + bp ]
	call CCBChanged					; mark changes made

_LFNExtendedOpenCreate_30:
	mov ax, word [ _mode + bp ]
	lea di, [ word _dirAccess + bp ]		; work dir access block
	call _SFTOpenFile				; build an SFT
	jc _LFNExtendedOpenCreate_42			; if error -->

	call MapSFTToAppHandle				; record SFT handle into JHT
	mov cx, ACTION_OPENED				; say openned
	jmp short _LFNExtendedOpenCreate_42

		; create file
_LFNExtendedOpenCreate_Create:
	getarg cx, _attributes
	lea di, [ word _dirAccess + bp ]		; work dir access block
	lea si, [ word _structLongFilename + bp ]
	call LFNCreateFile
	jc _LFNExtendedOpenCreate_42			; if error -->

	call MapSFTToAppHandle				; record SFT handle into JHT

	mov cx, ACTION_REPLACED_OPENED			; say replaced
	cmp word [ _found + bp ], byte TRUE
	jz _LFNExtendedOpenCreate_42			; if found, then was truncated ->
	mov cx, ACTION_CREATED_OPENED
	clc						; no carry

		; return
_LFNExtendedOpenCreate_42:
	RetCallersStackFrame es, bx
	mov word [ es:bx + _AX ], AX
	jc _LFNExtendedOpenCreate_Return

	mov word [ es:bx + _CX ], CX

_LFNExtendedOpenCreate_Return:
	Return


		; 71A0h Get Volume Information
		;
		; Input:
		; ds:dx	ASCIZ root name (e.g. "c:\")
		; es:di	buffer for ASCIZ name of file system
		; cx	size of buffer (32 suggested)
		;
		; Output:
		; bx	file system flags
		;  b00	Searches are case sensitive
		;  b01	Preserves case in directory entries
		;  b02	Uses Unicode characters in directory entries
		;  b14	Supports DOS LFN services
		;  b15	Volume is compressed
		;	(Standard FAT with LFN services returns b14 & b02 & b01 == 4006h.
		;	 RxDOS however returns only b14.)
		; cx	maximum length of file name (usually 255)
		; dx	maximum length of path (usually 260)
		; es:di	ASCIZ name of file system ("FAT", "FAT32" or "CDFS" for RxDOS, "NTFS" possible)
		;
		; STUB
Int71LFNGetVolumeInformation:

	RetCallersStackFrame es, bx
	mov word [ es:bx + _BX ], 4000h			; supports long filename
	mov word [ es:bx + _CX ], 255			; max name 255
	mov word [ es:bx + _DX ], 260			; supports long filename

	mov ds, word [ es:bx + _ES ]
	mov di, word [ es:bx + _DI ]
	mov word [ di ], "FA"
	mov word [ di + 2 ], "T"			; FAT
	clc
	retn
		; RxDOS 7.20N:	Better check required, do not always return "supported"!


		; 71A1h Find Close
		;
		; Input:
		; bx	handle
Int71LFNFindClose:

	call LFNValidateFindDataHandle			; validate handle in bx
	jc Int71LFNFindClose_12				; not valid -->

	mov si, word [ bx ]
	mov word [ _lfnfindstoreOwner + si ], 0
	mov word [ bx ], 0				; within range, so close

Int71LFNFindClose_12:
	clc
	retn


		; 71A6h Get File Info By Handle
		;
		; NOP
Int71LFNGetFileInfoByHandle:

	retn


		; 71A7h File Time
		;
		; Input:
		; bl	Subfunction
		;  00  File time to DOS time
		;  01  DOS time to file time
		; ds:si	File time buffer
		; cx	DOS time
		; dx	DOS date
		; bh	DOS time additional milliseconds
		;
		; STUB/NOP
Int71LFNFileTime:

	Entry
	def	DOSMilliseconds
	def	DOSDate, dx
	def	DOSTime, cx
	ddef	pFileTime, es, si

	defbytes	tFileTime, 8

	mov al, bl					; minor code
	xchg bh, bl
	xor bh, bh
	storarg _DOSMilliseconds, bx			; save milliseconds

	Goto 00,	_LFNFileTimeToDOSTime
	Goto 01,	_LFNDOSTimeToFileTime
							; Always NC if here

	RetCallersStackFrame es, bx
	mov word [ es:_AX + bx ], 7100h
	Return

		; File Time to DOS Time
_LFNFileTimeToDOSTime:

	setES ss
	getdarg ds, si, _pFileTime			; ds:si-> user file time buffer
	lea di, [ word _tFileTime + bp ]		; es:di-> file time buffer on stack
	mov cx, 4
	repe movsw					; 8 byte

	mov cx, 10000
	lea di, [ word _tFileTime + bp ]
	call Divide64Bits				; convert FILETIME from nanoseconds to microseconds

	mov cx, 1000
	call Divide64Bits				; convert FILETIME from microseconds to milliseconds

	mov dx, word [ _tFileTime + _low + bp ]
	mov cx, word [ _tFileTime + _high + bp ]

%if 0
	BH	Number of 10 millisecond intervals in 2 seconds to add to the MS-DOS time.
		It can be a value in the range 0 to 199.

	CX	MS-DOS time. The time is a packed 16-bit value with the following form:

		Bits	Contents
		0-4	Second divided by 2
		5-10	Minute (0-59)
		11-15	Hour (0-23 on a 24-hour clock)

	DX	MS-DOS date. The date is a packed 16-bit value with the following form:

		Bits	Contents
		0-4	Day of the month (1-31)
		5-8	Month (1 = January, 2 = February, and so on)
		9-15	Year offset from 1980 (that is, add 1980 to get the actual year)

%endif

		; DOS Time to File Time
_LFNDOSTimeToFileTime:

	mov dx, word [ _tFileTime + _low + bp ]
	mov cx, word [ _tFileTime + _high + bp ]
	; add constant

	mov cx, 10000
	lea di, [ word _tFileTime + bp ]
	; call Multiply64Bits				; convert FILETIME from nanoseconds to microseconds

	mov cx, 1000
	; call Multiply64Bits				; convert FILETIME from microseconds to milliseconds

	getdarg es, di, _pFileTime
	lea si, [ word _tFileTime + bp ]
	mov cx, 4
	repe movsw

	Return


		; Divide 64 Bits
		;
		; Input:
		; di	64 bit value
		; cx	Divisor
Divide64Bits:

	or cx, cx					; protect from zero divisor
	stc						; in case of error
	jz _div64Return					; if so, just return with carry

	xor dx, dx
	mov ax, [ di + 6 ]
	div cx
	mov [ di + 6 ], ax

	mov ax, [ di + 4 ]
	div cx
	mov [ di + 4 ], ax

	mov ax, [ di + 2 ]
	div cx
	mov [ di + 2 ], ax

	mov ax, [ di ]
	div cx
	mov [ di ], ax

_div64Return:
	retn


		; 71A8h Generate ShortName
		;
		; NOP
Int71LFNGenerateShortName:

	retn


		; Locate/Validate File
		;
		; This function takes an ASCIZ path name, which could contain
		; mix of short and long filenames. It determines if the path
		; and filename are valid. If the file exists, it completes the
		; dir access work area.
		;
		; The full expanded path is returned as a canonical pointer
		; list. The last term of the list is the expanded filename.
		; The short name to the file is available in the directory
		; buffer.
		;
		; Input:
		; ss:bx	pointer to Longfilename structure
		; ss:di	pointer to Dir Access area
		; es:si	pointer to input filename
		; ax	options, as follows:
		;
		; FILE_NODEVICENAME	no device name allowed
		; FILEHAS_WILDCHARS	allowed in name
		; FILEHAS_NOFILENAME	no filename expected
		; FILECANNOT_BEDEFINED	filename must not exist
		; FILECANNOT_BEDIRECTORY	filename cannot be directory
		; FILEMAY_EXIST		file may exist (cluster not -1 )
		; FILE_ORDEVICE		file or device must exist
		;
		; Output:
		; ax	drive
		; cx:dx	cluster address of file or directory
		; ss:di	pointer to Dir Access area.
		; cy	means path/filename is not valid.
		;
		; Assumes ss == ds
LFNLocateFile:

	Entry
	def	drive, 0
	ddef	cluster, 0, 0
	def	optSearchOffset, 0
	def	options, ax

	def	ptrstructLongfilename, bx
	def	ptrDirAccess, di
	ddef	ptrfilename, es, si

	SaveSegments di, si, bx
	CurrSegment ds
	CurrSegment es

	getarg di, _ptrDirAccess
	clearMemory sizeDIRACCESS

		; build canonical path tree
	getdarg es, si, _ptrfilename
	getarg bx, _ptrstructLongfilename
	lea di, [ byte _lfnCanonicalList + bx ]
	call BuildCanonicalPointerList			; build canonical pointer list
	ifc LFNLocateFile_PathNotFound			; if path invalid -->

	storarg _drive, ax				; drive
	stordarg _cluster, cx, dx			; cluster
	storarg _optSearchOffset, bx			; opt search entry

	call getDPB					; make sure drive is initialized
	ifc LFNLocateFile_PathNotFound			; if illegal drive -->

		; get last entry, compute number of LFN entries required for name
	mov ax, sizeCANONICALPOINTER
	getarg di, _ptrstructLongfilename
	mul word [ _lfnCanonicalList + _canpNumEntries + di ]

	mov bx, ax
	lea bx, [ word _lfnCanonicalList + _canpArray - sizeCANONICALPOINTER + di + bx ]

	les si, [ _canpStringPointer + bx ]
	mov word [ _lfnSearchLongNameText + _segment + di ], es
	mov word [ _lfnSearchLongNameText + _pointer + di ], si

	mov ax, word [ _canpStringLength + bx ]
	mov word [ _lfnSearchStringLength + di ], ax
	inc ax						; make sure we count null term char as a copy char

	xor dx, dx
	mov cx, LFN_NAMECHARPERENTRY
	div cx						; # entries in ax

	or dx, dx
	jz LFNLocateFile_10
	inc ax						; incr if roundoff

LFNLocateFile_10:
	inc ax						; incr for short entry
	mov word [ _lfnDirEntriesReqd + di ], ax	; required dir entries
	mov word [ _lfnNameRemainder + di ], dx		; name remainder

	getarg ax, _drive				; get drive
	mov word [ _lfnDrive + di ], ax

	getdarg cx, dx, _cluster			; cluster to search next
	mov word [ _lfnCluster + _high + di ], cx
	mov word [ _lfnCluster + _low + di ], dx

	getarg ax, _options
	mov word [ _lfnOptions + di ], ax

		; root directory ?
	mov ax, sizeCANONICALPOINTER
	mul byte [ _optSearchOffset + bp ]		; optimized entry

	mov di, word [ _ptrstructLongfilename + bp ]
	lea di, [ word _lfnCanonicalList + _canpArray + di ]
	add di, ax					; offset to next entry

	cmp word [ _canpStringLength + di ], byte 0	; no entry (empty, ., or ..)
	jnz LFNLocateFile_20				; no, go test -->

	test word [ _options + bp ], FILEHAS_NOFILENAME
	jnz LFNLocateFile_28				; if can't do * name -->

	mov word [ _canpStringLength + di ], 1		; patch default entry
	mov word [ _canpStringPointer + _segment + di ], cs
	mov word [ _canpStringPointer + _pointer + di ], _DefaultAll

	xor cx, cx
	mov word [ sizeCANONICALPOINTER + _canpFlags + di ], cx
	mov word [ sizeCANONICALPOINTER + _canpStringLength + di ], cx
	mov word [ sizeCANONICALPOINTER + _canpStringPointer + _segment + di ], cx
	mov word [ sizeCANONICALPOINTER + _canpStringPointer + _pointer + di ], cx

		; search
LFNLocateFile_20:
	xor cx, cx
	xor dx, dx					; dir offset will be zero
	getarg di, _ptrDirAccess
	getarg bx, _ptrstructLongfilename
	getdarg es, si, _ptrfilename
	call LFNLocateFileNext
	jc LFNLocateFile_38

		; for next entry, update optimized dir search entry
LFNLocateFile_28:
	pushf
	SaveRegisters ax, bx, cx, dx
	getarg bx, _ptrstructLongfilename
	mov dx, word [ _lfnDirCluster + _low + bx ]
	mov cx, word [ _lfnDirCluster + _high + bx ]
	mov word [ _lfnCanonicalList + _canpCluster + _low + bx ], dx
	mov word [ _lfnCanonicalList + _canpCluster + _high + bx ], cx

		; do more: optimized entry and all that !!

	mov cx, word [ _lfnCanonicalList + _canpNumEntries + bx ]
	or cx, cx
	jz LFNLocateFile_34
	dec cx

LFNLocateFile_34:
	mov word [ _lfnCanonicalList + _canpOptSearchEntry + bx ], cx
	RestoreRegisters dx, cx, bx, ax
	popf

LFNLocateFile_38:
	RestoreSegments bx, si, di
	Return

		; Errors
LFNLocateFile_FileNotFound:
	SetError pexterrFileNotFound, short LFNLocateFile_38

LFNLocateFile_PathNotFound:
	SetError pexterrPathNotFound, short LFNLocateFile_38


		; Locate/Validate File
		;
		; This function takes an ASCIZ path name, which could contain
		; mix of short and long filenames. It determines if the path
		; and filename are valid. If the file exists, it completes the
		; dir access work area.
		;
		; The full expanded path is returned as a canonical pointer
		; list. The last term of the list is the expanded filename.
		; The short name to the file is available in the directory
		; buffer.
		;
		; Input:
		; ss:bx	pointer to Longfilename structure
		; ss:di	pointer to Dir Access area
		; es:si	pointer to input filename
		; cx:dx	position in directory where to start search
		; ax	options, as follows:
		;
		; FILE_NODEVICENAME	no device name allowed
		; FILEHAS_WILDCHARS	allowed in name
		; FILEHAS_NOFILENAME	no filename expected
		; FILECANNOT_BEDEFINED	filename must not exist
		; FILECANNOT_BEDIRECTORY	filename cannot be directory
		; FILEMAY_EXIST		file may exist (cluster not -1 )
		; FILE_ORDEVICE		file or device must exist
		;
		; Output:
		; ax	drive
		; cx:dx	cluster address of file or directory
		; ss:di	pointer to Dir Access area.
		; cy	means path/filename is not valid.
		;
		; Assumes ss == ds
LFNLocateFileNext:

	Entry
	def	drive
	ddef	cluster
	def	ptrstructLongfilename, bx
	def	ptrDirAccess, di
	ddef	ptrfilename, es, si
	ddef	dirposition, cx, dx

	def	options
	def	subdirectory_term, FALSE
	def	pCanonicalNextEntry

	ddef	ptrDirEntry
	ddef	dirCluster, 0, 0

	defbytes	scandir, sizeSCANDIR


	SaveSegments di, si, bx
	CurrSegment ds
	CurrSegment es

	mov ax, word [ _lfnCanonicalList + _canpDrive + bx ]
	storarg _drive, ax

	mov dx, word [ _lfnCanonicalList + _canpCluster + _low + bx ]
	mov cx, word [ _lfnCanonicalList + _canpCluster + _high + bx ]
	stordarg _cluster, cx, dx			; start cluster of directory

	mov ax, word [ _lfnOptions + bx ]
	storarg _options, ax

	mov ax, sizeCANONICALPOINTER
	mul byte [ _lfnCanonicalList + _canpOptSearchEntry + bx ]

	lea di, [ byte _lfnCanonicalList + _canpArray + bx ]
	add di, ax					; offset to next entry
	storarg _pCanonicalNextEntry, di		; pointer to next entry

		; Init Scan Directory
	lea di, [ word _scandir + bp ]
	clearMemory sizeSCANDIR				; clear scan dir structure

	getarg di, _ptrDirAccess
	lea cx, [ word fileAcExpandedName + di ]
	mov word [ _scandir + _scandirLongFilenameStr + bp ], cx

	lea cx, [ word fileAcShortName + di ]
	mov word [ _scandir + _scandirShortFilenameStr + bp ], cx

	getdarg cx, dx, _dirposition
	mov word [ _scandir + _scandirFileOffset + _high + bp ], cx
	mov word [ _scandir + _scandirFileOffset + _low + bp ], dx

		; get next name
LFNLocateFileNext_20:
	getarg di, _pCanonicalNextEntry			; get pointer to next entry
	test word [ ss:_canpFlags + di ], CANONICALENTRY_WILDCHARS
	jz LFNLocateFileNext_26				; if no wild chars -->

	test word [ _options + bp ], FILEHAS_WILDCHARS
	ifz LFNLocateFileNext_FileNotFound		; if wild chars NOT allowed -->

	cmp word [ ss:sizeCANONICALPOINTER + _canpStringLength + di ], byte 0
	ifnz LFNLocateFileNext_PathNotFound		; inside path def, wild chars error -->

		; see if entry is a device name
LFNLocateFileNext_26:
	les si, [ ss:_canpStringPointer + di ]		; string pointer
	mov cx, word [ ss:_canpStringLength + di ]	; string length
	call seeIfDeviceName				; determine if it's a device name
	jc LFNLocateFileNext_32				; if not a device name -->

		; here if device name

	cmp word [ ss:sizeCANONICALPOINTER + _canpStringLength + di ], byte 0
	ifnz LFNLocateFileNext_PathNotFound		; inside path def, error -->
	test word [ _options + bp ], FILE_NODEVICENAME	; else if in filename, it is allowed ?
	ifnz LFNLocateFileNext_FileNotFound		; error if no device names allowed -->

	clc						; clear error
	getarg si, _ptrDirAccess
	mov word [ ss:fileAcDevicePtr + _segment + si ], es
	mov word [ ss:fileAcDevicePtr + _pointer + si ], bx
	mov byte [ ss:fileAcExpandedName + si ], 00

	lea bx, [ word fileAcShortName + si ]
	mov cx, word [ ss:_canpStringLength + di ]	; string length
	les si, [ ss:_canpStringPointer + di ]		; string pointer
	mov di, bx
	call CopyString

	mov ax, 8000h
	jmp LFNLocateFileNext_120

		; scan for path in directory
LFNLocateFileNext_32:
	getarg ax, _drive				; drive
	getdarg cx, dx, _cluster			; cluster
	stordarg _dirCluster, cx, dx			; start cluster of directory

	getarg di, _ptrDirAccess
	mov word [ fileAcDirCluster + _low + di ], dx
	mov word [ fileAcDirCluster + _high + di ], cx

	getarg bx, _ptrstructLongfilename
	mov word [ _lfnDirCluster + _low + bx ], dx
	mov word [ _lfnDirCluster + _high + bx ], cx

	getarg si, _pCanonicalNextEntry			; get pointer to next entry
	lea di, [ word _scandir + bp ]
	call LFNScanDirectory				; scan for name in directory
	jnc LFNLocateFileNext_36			; if an item is found -->

		; entry not found or matched.
	getarg di, _pCanonicalNextEntry			; get pointer to next entry
	cmp word [ ss:sizeCANONICALPOINTER + _canpStringLength + di ], byte 0
	ifnz LFNLocateFileNext_PathNotFound		; inside path def, error -->

	or word [ _drive + bp ], 8000h			; say not found
	test word [ _options + bp ], (FILECANNOT_BEDEFINED + FILEMAY_EXIST)
	ifnz LFNLocateFileNext_112			; if not defined is ok -->
	jmp LFNLocateFileNext_FileNotFound		; not found -->

		; is FOUND entry a filename ?
LFNLocateFileNext_36:
	setDS ss
	stordarg _ptrDirEntry, es, si			; item address

	test bx, ATTR_VOLUME
	jnz LFNLocateFileNext_52			; if volume label -->
	test bx, ATTR_DIRECTORY
	jnz LFNLocateFileNext_42			; if directory -->

	getarg di, _pCanonicalNextEntry			; get pointer to next entry
	cmp word [ sizeCANONICALPOINTER + _canpStringLength + di ], byte 0
	ifnz LFNLocateFileNext_PathNotFound		; if path expected, error -->

	test word [ _options + bp ], (FILECANNOT_BEDEFINED + FILEHAS_NOFILENAME)
	ifnz LFNLocateFileNext_AccessDenied		; if access denied -->
	jmp LFNLocateFileNext_100

		; is FOUND entry a directory ?
LFNLocateFileNext_42:
	getarg di, _pCanonicalNextEntry			; get pointer to next entry
	cmp word [ sizeCANONICALPOINTER + _canpStringLength + di ], byte 0
	jz LFNLocateFileNext_48				; if path not expected, determine errors -->

	getdarg es, si, _ptrDirEntry
	mov dx, word [ es:deStartCluster + si ]		; cluster
	mov cx, word [ es:deStartClusterExt + si ]
	stordarg _cluster, cx, dx			; cluster to search next

	xor cx, cx
	mov word [ _scandir + _scandirFileOffset + _low + bp ], cx
	mov word [ _scandir + _scandirFileOffset + _high + bp ], cx

	add word [ _pCanonicalNextEntry + bp ], byte sizeCANONICALPOINTER
	jmp LFNLocateFileNext_20			; else, go get next -->

		; Last term. Check Attributes.
LFNLocateFileNext_48:
	test word [ _options + bp ], FILECANNOT_BEDIRECTORY
	jnz LFNLocateFileNext_FileNotFound		; if cannot be a directory -->
	test word [ _options + bp ], FILECANNOT_BEDEFINED
	jnz LFNLocateFileNext_FileNotFound		; if cannot be a directory -->

LFNLocateFileNext_52:
	setDS ss
	getdarg es, bx, _ptrDirEntry
	getarg di, _ptrstructLongfilename
	mov cl, byte [ es:deAttributes + bx ]
	cmp cl, ATTR_VOLUME
	jnz LFNLocateFileNext_56			; compare attribs if not vol id -->

	cmp cl, byte [ _lfnSearchAttribs + di ]
	ifz LFNLocateFileNext_100			; we are searching for vol id -->

LFNLocateFileNext_Continue:
	add word [ _scandir + _scandirFileOffset + _low + bp ], byte sizeDIRENTRY
	adc word [ _scandir + _scandirFileOffset + _high + bp ], byte 0
	jmp LFNLocateFileNext_32			; continue -->

		; test/ filter on attributes
LFNLocateFileNext_56:
	cmp byte [ _lfnSearchAttribs + di ], -1		; matching on attributes ?
	jz LFNLocateFileNext_100			; no -->

	test cl, byte [ _lfnSearchAttribs + di ]	; filter on search bit
	jnz LFNLocateFileNext_58			; if at least one bit matches -->
	test cl, ATTR_MASK				; test for normal file
	jnz LFNLocateFileNext_Continue			; if not, then no match -->

LFNLocateFileNext_58:
	mov ch, byte [ _lfnMustMatchAttribs + di ]
	or ch, ch
	jz LFNLocateFileNext_100			; if no must match, everything that matches search pattern -->

	and cl, ch
	cmp cl, ch					; remainder must match
	jz LFNLocateFileNext_100			; if matches -->
	jmp short LFNLocateFileNext_Continue

		; in case of error
		; RxDOS 7.20N: force near jumps
LFNLocateFileNext_FileNotFound:
	SetError pexterrFileNotFound, near LFNLocateFileNext_120

LFNLocateFileNext_PathNotFound:
	SetError pexterrPathNotFound, near LFNLocateFileNext_120

LFNLocateFileNext_AccessDenied:
	SetError pexterrAccessDenied, near LFNLocateFileNext_120

		; if dir entry available, copy args
LFNLocateFileNext_100:
	setDS ss
	getdarg es, si, _ptrDirEntry
	mov dx, word [ es:deStartCluster + si ]		; cluster
	mov cx, word [ es:deStartClusterExt + si ]
	stordarg _cluster, cx, dx			; cluster to search next

	getarg di, _ptrstructLongfilename
	mov cx, word [ es:deFileSize + _high + si ]
	mov dx, word [ es:deFileSize + _low + si ]
	mov word [ _lfnFileSize + _high + di ], cx
	mov word [ _lfnFileSize + _low + di ], dx

	mov ax, sizeCANONICALPOINTER
	mul word [ _lfnCanonicalList + _canpNumEntries + di ]

	mov bx, ax
	lea bx, [ word _lfnCanonicalList + _canpArray - sizeCANONICALPOINTER + di + bx ]
	les si, [ _canpStringPointer + bx ]
	mov word [ _lfnSearchLongNameText + _segment + di ], es
	mov word [ _lfnSearchLongNameText + _pointer + di ], si

	mov cx, word [ _canpStringLength + bx ]
	mov word [ _lfnSearchStringLength + di ], cx

	mov dx, word [ _scandir + _scandirFileAcLongEntry + _low + bp ]
	mov cx, word [ _scandir + _scandirFileAcLongEntry + _high + bp ]
	mov word [ _lfnOffsetLongEntry + _low + di ], dx
	mov word [ _lfnOffsetLongEntry + _high + di ], cx

	mov dx, word [ _scandir + _scandirFileAcShortEntry + _low + bp ]
	mov cx, word [ _scandir + _scandirFileAcShortEntry + _high + bp ]
	mov word [ _lfnOffsetShortEntry + _low + di ], dx
	mov word [ _lfnOffsetShortEntry + _high + di ], cx

	getdarg es, si, _ptrDirEntry
	call locateCCBPHeader				; si dir pointer/ di ccb

	getarg bx, _ptrDirAccess
	mov word [ fileAcBufferPtr + _segment + bx ], es
	mov word [ fileAcBufferPtr + _pointer + bx ], di
	mov word [ fileAcDirOffset + bx ], cx		; offset in dir sector

	mov ax, word [ es:ccbLBN + _low + di ]
	mov dx, word [ es:ccbLBN + _high + di ]
	mov word [ fileAcDirSector + _low + bx ], ax	; which dir sector
	mov word [ fileAcDirSector + _high + bx ], dx

		; if dir locate structure has info, return
LFNLocateFileNext_112:
	getarg di, _ptrstructLongfilename

	getarg ax, _drive				; drive
	mov word [ _lfnDrive + di ], ax

	getdarg cx, dx, _cluster			; cluster to search next
	mov word [ _lfnCluster + _low + di ], dx
	mov word [ _lfnCluster + _high + di ], cx

	clc

		; exit
LFNLocateFileNext_120:
	pushf
	push ax
	currSegment ds

	getarg ax, _drive				; drive
	getarg bx, _ptrDirAccess			; dir access
	getarg di, _ptrstructLongfilename		; long filename
	call updateDirAccessBlock

	pop ax
	popf
	RestoreSegments bx, si, di
	Return


		; LFN Create File
		;
		; Name check already performed. It is assumed that the name
		; does not exist. This routine is only responsible for
		; creating a valid directory entry.
		;
		; cx	attributes
		; ss:si struct LongFilename
		; ss:di dir Access
LFNCreateFile:

	Entry
	def	handle
	def	attributes, cx
	def	ptrDirAccess, di
	def	ptrLongFilename, si

	ddef	sftPointer
	defbytes	diskAccess, sizeDISKACCESS

		; find /init available SFT handle
	call FindAvailableSFTHandle			; find an available file handle
	ifc LFNCreateFile_40				; if none available -->

	storarg _handle, ax				; handle
	stordarg _sftPointer, es, bx			; sft pointer
	call InitSFTEntry				; clear entry

		; build long and short directory entries
	mov ax, word [ fileAcDrive + di ]
	mov dx, word [ fileAcDirCluster + _low + di ]
	mov cx, word [ fileAcDirCluster + _high + di ]
	getarg di, _ptrLongFilename			; long filename, canonical name struct
	call LFNBuildDirectoryEntry			; build entry
	jc LFNCreateFile_40				; if can't find free slot -->

	getarg cx, _attributes
	mov byte [ es:deAttributes + bx ], cl		; set updated attributes

	call getSysDateinDirFormat
	mov word [ es:deTime + bx ], ax	; time created
	mov word [ es:deDate + bx ], dx	; date created

	mov word [ es:deStartCluster + bx ], 0
	mov word [ es:deStartClusterExt + bx ], 0
	mov word [ es:deFileSize + _low + bx ], 0
	mov word [ es:deFileSize + _high + bx ], 0

	mov si, bx
	call locateCCBPHeader				; si buffer ptr --> es:di CCB header
	call CCBChanged					; mark changes made

		; populate SFT entry from dir entry
	push es						; es:bxs directory entry
	push bx
	push word [ _sftPointer + _segment + bp ]	; SFT entry
	push word [ _sftPointer + _pointer + bp ]
	call initSFTfromDirEntry

	getarg ax, _handle				; return handle
	clc

LFNCreateFile_40:
	Return


		; Locate Free LFN DirSlot
		;
		; Locate free LFN dirslot and build LFN dir entries
		;
		; Input:
		; ax	drive
		; cx:dx	dir cluster address
		; ss:di	ptr to LongFilename struct
		;
		; Output:
		; ax	drive
		; es:bx	pointer to SHORT dir entry in ccb
		; cy	if item not found
		;
		; Assumes ss == ds
LFNBuildDirectoryEntry:

	Entry
	def	drive, ax
	ddef	dircluster, cx, dx
	def	ptrstructLongFilename, di
	def	numDirEntries
	def	numDirEntriesRemainder
	def	LFNsequence
	def	checksum

	def	numEmptySeq
	ddef	posEmptyEntry
	ddef	copyPointer
	defbytes	diskAccess, sizeDISKACCESS

	setDS ss					; set ds == ss
	mov word [ _lfnDrive + di ], ax			; drive
	mov word [ _lfnDirCluster + _high + di ], cx	; cx:dx
	mov word [ _lfnDirCluster + _low + di ], dx	;

	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call initdiskAccess				; ax is drive, cx:dx is cluster
	call getDPB					; check for media change

		; compute number of directory entries needed from length of text
	getarg di, _ptrstructLongFilename
	call ComputeDirEntries				; ss:di points to LFN structure
	storarg _numDirEntries, ax			; save num entries
	storarg _numDirEntriesRemainder, dx		; save remainder

	call computeShortFileName			; ss:di points to LFN structure
	storarg _checksum, ax

		; scan directory
	setES ss
	mov word [ _diskAccess + diskAcPosition + _low + bp ], -sizeDIRENTRY
	mov word [ _diskAccess + diskAcPosition + _high + bp ], -1
	mov word [ _diskAccess + diskAcOptions + bp ], (ccb_isDIR)

LFNBuildDirEntry_14:
	mov word [ _numEmptySeq + bp ], 0

LFNBuildDirEntry_18:
	setDS ss					; set ds == ss
	lea di, [ word _diskAccess + bp ]		; pointer to access block
	call _ReadNextDirEntry				; read entry
	jz LFNBuildDirEntry_28				; if at end, allocate dir space -->
	cmp byte [ es:deName + bx ], DIRENTRY_NEVERUSED
	jz LFNBuildDirEntry_32				; if at end, space is usable -->

	cmp byte [ es:deName + bx ], DIRENTRY_DELETED
	jnz LFNBuildDirEntry_14				; entry in use, not valid -->

	mov cx, word [ _numEmptySeq + bp ]
	or cx, cx					; location already saved ?
	jnz LFNBuildDirEntry_22				; yes, skip -->
	mov ax, word [ _diskAccess + diskAcPosition + _low + bp ]
	mov dx, word [ _diskAccess + diskAcPosition + _high + bp ]
	stordarg _posEmptyEntry, dx, ax

LFNBuildDirEntry_22:
	inc cx
	storarg _numEmptySeq, cx

	cmp cx, word [ _numDirEntries + bp ]
	jl LFNBuildDirEntry_18
	jmp short LFNBuildDirEntry_32

		; must allocate dir space
LFNBuildDirEntry_28:
	lea bx, [ word _diskAccess + bp ]
	call IsRootExtendable				; is root expandable ?
	ifc LFNBuildDirEntry_Return			; if not, return error -->

	mov ax, word [ _diskAccess + diskAcDrive + bp ]
	call AllocateInitCluster			; init a cluster
	ifc LFNBuildDirEntry_Return			; if can't append -->

	push cx						; cluster address to update
	push dx
	mov ax, word [ _diskAccess + diskAcDrive + bp ]
	mov dx, word [ _diskAccess + diskAcCurCluster + _low + bp ]
	mov cx, word [ _diskAccess + diskAcCurCluster + _high + bp ]
	call updateClusterValue
	lea si, [ word ccbData + di ]			; dir address to di
	or si, si					; no carry

		; create directory entry in empty slot found
LFNBuildDirEntry_32:
	cmp word [ _numEmptySeq + bp ], byte 0		; if NULL count, position valid
	jz LFNBuildDirEntry_34

	getdarg dx, ax, _posEmptyEntry
	mov word [ _diskAccess + diskAcPosition + _low + bp ], ax
	mov word [ _diskAccess + diskAcPosition + _high + bp ], dx

LFNBuildDirEntry_34:
	sub word [ _diskAccess + diskAcPosition + _low + bp ], byte sizeDIRENTRY
	sbb word [ _diskAccess + diskAcPosition + _high + bp ], byte 0

	getarg di, _ptrstructLongFilename
	mov ax, word [ _diskAccess + diskAcPosition + _low + bp ]
	mov dx, word [ _diskAccess + diskAcPosition + _high + bp ]
	mov word [ _lfnOffsetLongEntry + _high + di ], dx
	mov word [ _lfnOffsetLongEntry + _low + di ], ax

	getarg cx, _numDirEntriesRemainder
	les si, [ _lfnSearchLongNameText + di ]
	add si, word [ _lfnSearchStringLength + di ]
	sub si, cx
	inc si						; make room for terminating null char

	or cx, cx
	jnz LFNBuildDirEntry_36
	mov cx, LFN_NAMECHARPERENTRY
	sub si, cx

LFNBuildDirEntry_36:
	stordarg _copyPointer, es, si			; store copy pointer
	dec word [ _numDirEntries + bp ]		; no need to read short entry

	mov ax, word [ _numDirEntries + bp ]		; compute sequence number
	or ax, LFN_START_LFNENTRY
	storarg _LFNsequence, ax

LFNBuildDirEntry_38:
	push cx
	lea di, [ word _diskAccess + bp ]
	call _ReadNextDirEntry				; read entry
	call _ClearDirEntry				; clear entry

	pop cx						; length
	getdarg ds, si, _copyPointer			; source is at ds:si
	call _copyfromStringtoLFN			; copy string to LFN

	getarg ax, _LFNsequence
	mov byte [ es:LFN_SequenceByte + bx ], al	; LFN sequence number

	and ax, LFN_SEQUENCEMASK			; isolate sequence number
	dec ax
	mov word [ _LFNsequence + bp ], ax

	mov dl, byte [ _checksum + bp ]
	mov byte [ es:LFN_Checksum + bx ], dl		; set checksum
	mov byte [ es:LFN_Attributes + bx ], ATTR_LONGFILENAME

	currSegment ds					; point to default segment
	mov cx, LFN_NAMECHARPERENTRY
	sub word [ _copyPointer + _pointer + bp ], cx
	dec word [ _numDirEntries + bp ]
	jnz LFNBuildDirEntry_38

		; write short entry
	lea di, [ word _diskAccess + bp ]
	call _ReadNextDirEntry				; read entry
	call _ClearDirEntry				; clear entry

	getarg di, _ptrstructLongFilename
	mov ax, word [ _diskAccess + diskAcPosition + _low + bp ]
	mov dx, word [ _diskAccess + diskAcPosition + _high + bp ]
	mov word [ _lfnOffsetShortEntry + _high + di ], dx
	mov word [ _lfnOffsetShortEntry + _low + di ], ax

	mov cx, sizeFILENAME
	lea si, [ word _lfnShortFCBName + di ]		; ptr to short name
	mov di, bx					; destination
	rep movsb					; write entry
	clc

		; return
LFNBuildDirEntry_Return:
	getarg ax, _drive
	getdarg cx, dx, _dircluster
	getarg di, _ptrstructLongFilename
	Return


		; Clear Entry, Mark Changed
		;
		; Input:
		; es:bx	dir entry
		;
		; Output:
		; All registers preserved
		;
		; Assumes ss == ds
_ClearDirEntry:

	SaveAllregisters

	xor ax, ax
	mov cx, ( sizeDIRENTRY / 2 )
	mov di, bx
	repe stosw					; clear

	call SetCCBChanged				; buffer will be changed
	restoreAllRegisters
	retn


		; Build Fully Formed PATH String From Canonical String
		;
		; Input:
		; ss:bx	ptr to LongFilename struct
		; es:di	ptr to canonical string buffer
		;
		; Output:
		; dx	offset to last name
		;
		; Assumes ss == ds
LFNBuildFullyFormedPATH:

	Entry
	def	numEntries
	def	offsetLastName
	def	ptrstructLongFilename, bx
	ddef	ptrFullyFormedPath, es, di

	setDS ss
	SaveRegisters di, si, bx

	mov ax, word [ _lfnDrive + bx ]
	add ax, 'A:'
	stosw

	mov al, '\'
	stosb
	storarg _offsetLastName, di

	lea bx, [ word _lfnCanonicalList + bx ]
	mov ax, word [ _canpNumEntries + bx ]
	storarg _numEntries, ax
	or ax, ax
	jz LFNBuildPath_20

	lea bx, [ word _canpArray + bx ]
	dec di

LFNBuildPath_12:
	mov al, '\'
	stosb
	storarg _offsetLastName, di

	mov cx, word [ ss:_canpStringLength + bx ]
	lds si, [ ss:_canpStringPointer + bx ]
	rep movsb

	add bx, byte sizeCANONICALPOINTER
	dec word [ _numEntries + bp ]
	jnz LFNBuildPath_12

LFNBuildPath_20:
	xor ax, ax
	stosb

	setDS ss
	getarg dx, _offsetLastName
	RestoreRegisters bx, si, di
	Return


		; Compute Unique Short Name
		;
		; Input:
		; ss:di	poiter to LongFilename struct
		;
		; Output:
		; al	short name checksum
		;
		; Assumes ss == ds
computeShortFileName:

	Entry
	def	highestHit, 0
	def	ptrstructLongFilename, di

	defbytes	namehitArray, 32
	defbytes	diskAccess, sizeDISKACCESS

	setDS ss					; set ds == ss
	mov ax, word [ _lfnDrive + di ]			; drive
	mov cx, word [ _lfnDirCluster + _high + di ]	; cx:dx
	mov dx, word [ _lfnDirCluster + _low + di ]	;

	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call initdiskAccess				; ax is drive, cx:dx is cluster

		; create a trial short name from long name
	lea bx, [ word _lfnShortFCBName + di ]
	les si, [ _lfnSearchLongNameText + di ]
	mov cx, word [ _lfnSearchStringLength + di ]
	call createFCBNAMEfromLFN
	ifz computeSFN_56

		; scan directory
computeSFN_12:
	setES ss
	lea di, [ word _namehitArray + bp ]
	clearMemory sizeof_namehitArray			; name hit array

	mov word [ _diskAccess + diskAcPosition + _low + bp ], -sizeDIRENTRY
	mov word [ _diskAccess + diskAcPosition + _high + bp ], -1
	mov word [ _diskAccess + diskAcOptions + bp ], (ccb_isDIR)

computeSFN_14:
	setDS ss					; set ds == ss
	lea di, [ word _diskAccess + bp ]		; pointer to access block
	call _ReadNextDirEntry				; read entry
	jz computeSFN_32				; if at end, allocate dir space -->
	cmp byte [ es:deName + bx ], DIRENTRY_NEVERUSED
	jz computeSFN_32				; if at end, space is usable -->

	cmp byte [ es:deName + bx ], DIRENTRY_DELETED
	jz computeSFN_14				; entry in use, not valid -->
	test byte [ es:deAttributes + bx ], ATTR_VOLUME
	jnz computeSFN_14				; skip volume and LFN entries -->

		; see if entry is a match
	mov al, '~'
	mov cx, sizefnName
	mov di, bx					; entry is at
	repnz scasb					; see if name contains '~' mark
	jnz computeSFN_14				; no, not a contender -->

	sub cx, byte sizefnName
	not cx						; actual length that may match

	getarg di, _ptrstructLongFilename
	lea si, [ word _lfnShortFCBName + di ]
	mov di, bx					; entry is at
	repz cmpsb					; continue until not equal
	jnz computeSFN_14				; not equal -->

		; get value past '~' character
	mov cx, sizefnName
	inc di
	sub cx, di
	add cx, bx					; length of number to get
	xor dx, dx
	xor ax, ax

computeSFN_18:
	mov dl, byte [ es:di ]				; grab number past '~' character
	cmp dl, '9' + 1
	jnc computeSFN_14				; if not digit, ignore -->
	sub dl, '0'
	jc computeSFN_14				; if not digit, ignore -->

	mov bx, ax
	add ax, ax
	add ax, ax
	add ax, bx
	add ax, ax
	add ax, dx
	inc di
	loop computeSFN_18

		; set reserve bits
	dec ax						; number count is zero based
	cmp ax, word [ _highestHit + bp ]		; does number exceed max
	jle computeSFN_28				; no -->
	storarg _highestHit, ax				; else save highest value

computeSFN_28:
	cmp ax, 8 * sizeof_namehitArray			; is it within name hit array range ?
	jg computeSFN_14				; if not, continue scan -->

	mov bx, ax
	mov di, ax
	shr di, 1					; / 2
	shr di, 1					; / 4
	shr di, 1					; / 8
	and bx, byte 7
	mov al, byte [ cs:_bitShiftTable + bx ]		; get correct bit
	or byte [ _namehitArray + bp + di ], al
	jmp computeSFN_14

		; determine conflicts, fixup name
computeSFN_32:
	mov cx, sizeof_namehitArray
	lea di, [ word _namehitArray + bp ]		; scan for an empty bit
	mov ax, di

computeSFN_34:
	cmp byte [ di ], 255				; all bits assigned ?
	jnz computeSFN_38				; no, go determine empty slot -->

	inc di
	loop computeSFN_34

	getarg ax, _highestHit				; else, get highest hit
	inc ax						; bump by one
	jmp short computeSFN_44				; assign number -->

computeSFN_38:
	sub ax, di
	neg ax
	add ax, ax					; *2
	add ax, ax					; *4
	add ax, ax					; *8
	mov cl, byte [ di ]				; one of these is unassigned

computeSFN_42:
	inc ax						; free bit is in ax
	ror cl, 1
	jc computeSFN_42

		; compute value to store in short name
computeSFN_44:
	getarg di, _ptrstructLongFilename
	lea si, [ word _lfnShortFCBName + sizefnName - 1 + di ]

computeSFN_46:
	xor dx, dx
	mov cx, 10
	div cx						; extract digit
	or dl, '0'
	mov byte [ si ], dl
	dec si

	or ax, ax					; more to go ?
	jnz computeSFN_46				; yes -->

	mov byte [ si ], '~'				; add the tilde

		; compute checksum
computeSFN_56:
	setES ss
	getarg di, _ptrstructLongFilename
	lea bx, [ word _lfnShortFCBName + di ]
	call ComputeLFNChecksum				; compute checksum

	getarg di, _ptrstructLongFilename
	mov byte [ _lfnChecksum + di ], al
	Return


		; Create SHORT name from LFN
		;
		; Input:
		; es:si	ptr to long filename
		; ss:bx	ptr to short filename
		; cx	length of name
		;
		; Output:
		; ss:bx	short name file filled
		; nz	if name or extension exceeds 8.3 format
		;
		; All registers preserved
		; Assumes ss == ds
createFCBNAMEfromLFN:

	Entry
	def	count, cx
	def	exceedsShortFormat, False
	ddef	ptrLongfilename, es, si
	ddef	ptrShortfilename, ss, bx

	SaveAllRegisters

	setES ss
	mov al, ' '
	mov di, bx
	mov cx, sizeFILENAME
	repe stosb					; clear short name to blanks

	std
	getarg cx, _count
	getdarg es, di, _ptrLongfilename
	add di, cx
	mov al, '.'					; essentially strrchr
	repnz scasb					; scan for last '.' extension
	cld						; restore direction
	jnz _createFCBNAME_16				; skip extension -->

	inc di
	inc di						; point to extension
	mov cx, sizefnExtension
	mov si, word [ _ptrShortfilename + _pointer + bp ]
	add si, byte sizefnName				; point to extension of newly created FCB name

_createFCBNAME_08:
	mov al, byte [ es:di ]
	inc di
	or al, al
	jz _createFCBNAME_16				; end of LFN, extension for SFN ends also -->
	cmp al, '.'
	jz _createFCBNAME_08
	cmp al, ' '
	jz _createFCBNAME_08				; blank and dot in LFN are just ignored -->

	_uppercase al
	mov byte [ si ], al
	inc si
	dec cx
	jnz _createFCBNAME_08

	cmp byte [ es:di ], 00
	jz _createFCBNAME_16
	storarg _exceedsShortFormat, True

_createFCBNAME_16:
	mov cx, sizefnName
	getdarg es, di, _ptrLongfilename
	mov si, word [ _ptrShortfilename + _pointer + bp ]

_createFCBNAME_18:
	mov al, byte [ es:di ]
	inc di
	or al, al
	jz _createFCBNAME_26
	cmp al, '.'
	jz _createFCBNAME_26				; end of LFN or dot mean end of SFN main name -->
	cmp al, ' '
	jz _createFCBNAME_18				; space skipped -->

	_uppercase al
	mov byte [ si ], al
	inc si
	dec cx
	jnz _createFCBNAME_18

	cmp byte [ es:di ], 00
	jz _createFCBNAME_26
	cmp byte [ es:di ], '.'
	jz _createFCBNAME_26
	storarg _exceedsShortFormat, True

_createFCBNAME_26:
	RestoreAllRegisters

	cmp word [ _exceedsShortFormat + bp ], byte False
	Return


		; Return Where in Directory
		;
		; Input:
		; ss:di	pointer to dir access block
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


		; Scan Directory (Exact Search)
		;
		; Note:
		; Subdirectories are allocated in the FAT, just like files.
		; Use _FATReadRandom to position and read correct cluster.
		;
		;
		; Input:
		; ax	drive
		; cx:dx	cluster of dir to search
		; ss:si	ptr to canonical name entry
		; ss:di	ptr scan struct
		;
		; Output:
		; if item found:
		; ax	drive
		; bx	attributes
		; cx:dx	cluster
		; es:si	pointer to located (SHORT) directory entry
		; ss:di	ptr scan struct
		;
		; if item NOT found:
		; cy	if item not found
LFNScanDirectory:

	Entry
	def	longnameSet, FALSE
	def	ptrScanStruct, di
	def	length

	def	drive, ax
	ddef	cluster, cx, dx
	ddef	filenamePtr
	ddef	ptrShortDirEntry
	ddef	offsetDirLongEntry

	defbytes	diskAccess, sizeDISKACCESS
	defbytes	compareListStruct, sizeCompareListStruct

		; init access
	setDS ss					; set ds == ss
	mov cx, word [ _canpStringLength + si ]		; string length
	mov word [ _scandirStringLength + di ], cx
	storarg _length, cx

	les bx, [ _canpStringPointer + si ]		; string pointer
	mov word [ _scandirStringPointer + _segment + di ], es
	mov word [ _scandirStringPointer + _pointer + di ], bx
	stordarg _filenamePtr, es, bx

	getarg ax, _drive				; get drive
	getdarg cx, dx, _cluster			; cluster to search next
	mov word [ _scandirDrive + di ], ax
	mov word [ _scandirCluster + _low + di ], dx
	mov word [ _scandirCluster + _high + di ], cx

	lea bx, [ word _diskAccess + bp ]		; pointer to access block
	call initdiskAccess				; ax is drive, cx:dx is cluster
	call getDPB					; check for media change

	lea di, [ word _compareListStruct + bp ]
	getdarg es, si, _filenamePtr
	call BuildLFNCompareList			; designed to handle * wild characters

		; lookup entry
	setES ss
	getarg di, _ptrScanStruct
	mov cx, word [ _scandirFileOffset + _high + di ]
	mov dx, word [ _scandirFileOffset + _low + di ]
	sub dx, byte sizeDIRENTRY
	sbb cx, byte 0

	mov word [ _diskAccess + diskAcPosition + _high + bp ], cx
	mov word [ _diskAccess + diskAcPosition + _low + bp ], dx
	mov word [ _diskAccess + diskAcOptions + bp ], (ccb_isDIR)

LFN_scanDir_12:
	setDS ss					; set ds == ss
	lea di, [ word _diskAccess + bp ]		; pointer to access block
	call _ReadNextDirEntry
	stc						; just in case error,
	ifz LFN_scanDir_78				; if no more data -->

	cmp byte [ es:bx + deName ], DIRENTRY_DELETED
	jz LFN_scanDir_12				; skip deleted entries -->
	cmp byte [ es:bx + deName ], DIRENTRY_NEVERUSED
	stc						; just in case error,
	ifz LFN_scanDir_78				; if no more data -->

		; compare long filename
	mov dx, word [ _diskAccess + diskAcPosition + _low + bp ]
	mov cx, word [ _diskAccess + diskAcPosition + _high + bp ]
	stordarg _offsetDirLongEntry, cx, dx

	getarg di, _ptrScanStruct
	push word [ _scandirLongFilenameStr + di ]
	push word [ _scandirShortFilenameStr + di ]

	push es
	push bx						; pointer to current dir entry
	lea si, [ word _compareListStruct + bp ]
	lea di, [ word _diskAccess + bp ]		; access block in ss:di
	call _compareDirEntries_LongNames		; compare long names
	jnz LFN_scanDir_12				; if item not found -->

	storarg _longnameSet, ax			; if LFN true

		; item found
	setDS ss
	getarg ax, _drive
	getarg di, _ptrScanStruct			; ptr to scan structure
	mov dx, word [ _diskAccess + diskAcPosition + _low + bp ]
	mov cx, word [ _diskAccess + diskAcPosition + _high + bp ]
	mov word [ _scandirFileAcShortEntry + _low + di ], dx
	mov word [ _scandirFileAcShortEntry + _high + di ], cx
	mov word [ _scandirFileAcLongEntry + _low + di ], dx
	mov word [ _scandirFileAcLongEntry + _high + di ], cx

	cmp word [ _longnameSet + bp ], byte FALSE
	je LFN_scanDir_76
	getdarg cx, dx, _offsetDirLongEntry
	mov word [ _scandirFileAcLongEntry + _low + di ], dx
	mov word [ _scandirFileAcLongEntry + _high + di ], cx

LFN_scanDir_76:
	mov si, bx					; dir entry to si
	mov dx, word [ es:si + deStartCluster ]		; cluster
	mov cx, word [ es:si + deStartClusterExt ]
	mov bl, byte [ es:si + deAttributes ]		; attributes
	xor bh, bh					; zero, nc

LFN_scanDir_78:
	setDS ss					; set ds == ss
	Return


		; Compare Dir Long Filename Entries
		;
		; Input:
		; darg-> long (ASCIZ) filename store
		; darg-> short (ASCIZ) filename store
		; darg-> directory entry
		; ss:di-> disk access block
		; ss:si-> compare list struct
		; cl	search attribute
		; ch	must match attribute
		;
		; Output:
		; es:bx	matching short dir entry
		; ax	True if lfn name
		; zr	entry located
_compareDirEntries_LongNames:

	Entry 4
	arg	ptrLongFilenameAsciz			; assumes ss:
	arg	ptrShortFilenameAsciz			; assumes ss:
	darg	ptrDirEntry

	def	LFNFlag, False
	def	checksum, 0
	def	nLenLongEntry, 0
	def	nLenShortEntry, 0
	ddef	diskAccess, ss, di
	ddef	ptrCompareListStruct, ss, si

	saveRegisters ds, di, si

	getarg di, _ptrLongFilenameAsciz
	mov byte [ di ], 0				; clear long name, in case none
	getarg di, _ptrShortFilenameAsciz
	mov byte [ di ], 0				; clear long name, in case none

_compareDir_LFN_08:
	getdarg es, di, _ptrDirEntry			; get lfn entry
	cmp byte [ es:di + deAttributes ], ATTR_LONGFILENAME
	jnz _compareDir_LFN_24				; if on short entry -->

	storarg _LFNFlag, True
	mov cl, byte [ es:di + LFN_SequenceByte ]	; get sequence byte
	and cx, byte LFN_SEQUENCEMASK			; isolate sequence number
	dec cx						; n - 1

	mov ax, LFN_NAMECHARPERENTRY
	mul cl						; offset to store start in ax

	mov cx, ax
	getarg si, _ptrLongFilenameAsciz
	add si, ax					; offset where to store filename
	call _copyfromLFNtoString			; copy string for compare purposes

	getdarg es, di, _ptrDirEntry			; get lfn entry
	test byte [ es:di + LFN_SequenceByte ], LFN_START_LFNENTRY
	jz _compareDir_LFN_12				; if not end segment -->

	getarg si, _ptrLongFilenameAsciz
	add si, cx					; offset where to store filename
	mov byte [ si ], 0				; insure a nul exists at end
	storarg _nLenLongEntry, cx			; store long name length

	mov al, byte [ es:LFN_Checksum + di ]
	mov byte [ _checksum + bp ], al			; grab checksum

_compareDir_LFN_12:
	mov di, word [ _diskAccess + bp ]
	call _ReadNextDirEntry				; go fetch next entry
	ifz _compareDir_LFN_Return			; end, obviously not this entry -->

	stordarg _ptrDirEntry, es, bx
	jmp short _compareDir_LFN_08

		; compare full names.
_compareDir_LFN_24:
	setES ss
	getdarg ds, si, _ptrDirEntry			; ptr to short dir entry
	getarg di, _ptrShortFilenameAsciz		; make asciz entry
	call convDirEntrytoASCIZ			; have to make short entry in either case
	storarg _nLenShortEntry, cx			; store short name length

	setDS ss
	getarg cx, _nLenLongEntry			; long name available ?
	or cx, cx					; long filename available ?
	jz _compareDir_LFN_32				; none, skip match on lfn entry -->

	getarg si, _ptrLongFilenameAsciz
	mov di, word [ _ptrCompareListStruct + _pointer + bp ]
	test word [ _csFlags + di ], CSMATCHES_ALL	; *.* ?
	jnz _compareDir_LFN_Matches			; if instant match -->
	call matchOnCompareList				; zero if matches
	jz _compareDir_LFN_Matches			; if equal -->

_compareDir_LFN_32:
	getarg cx, _nLenShortEntry			; short name length
	getarg si, _ptrShortFilenameAsciz		; make asciz entry
	mov di, word [ _ptrCompareListStruct + _pointer + bp ]
	test word [ _csFlags + di ], CSMATCHES_ALL
	jnz _compareDir_LFN_Matches			; if instant match -->
	call matchOnCompareList				; zero if matches
	jnz _compareDir_LFN_Return			; if not equal -->

		; Item Matches
_compareDir_LFN_Matches:
	cmp word [ _LFNFlag + bp ], byte False		; LFN ?
	je _compareDir_LFN_Return			; if LFN -->

	getdarg es, bx, _ptrDirEntry			; pointer to short dir entry
	call ComputeLFNChecksum
	cmp al, byte [ _checksum + bp ]			; checksum valid ?
	jz _compareDir_LFN_Return			; yes -->

	xor ax, ax
	storarg _LFNFlag, ax				; flag is FALSE, LFN entry invalid

		; Return
_compareDir_LFN_Return:
	restoreRegisters si, di, ds

	getdarg es, bx, _ptrDirEntry			; pointer to short dir entry
	getarg ax, _LFNFlag
	clc
	Return


		; Get Device from String
		;
		; Input:
		; es:si	input string
		; cx	input string length
		;
		; Output:
		; es:bx	pointer to device header
		; cy	device not found
seeIfDeviceName:

	push di
	mov di, si
	call checkforDeviceName				; see if char device name
	mov ax, pexterrIllegalName			; (in case its an error)
	jc getDevice_Return				; if invalid -->

	mov ax, es
	or ax, ax					; nc character device

getDevice_Return:
	pop di
	retn


		; Build Compare List for Unix Style Long Filename
		;
		; Input:
		; es:si	ptr to filename (ends with null or \)
		; ss:di	ptr to compare list structure
		;
		; Output:
		; cx	entries in compare table
		; zr	if wild characters NOT used
		;
BuildLFNCompareList:

	Entry
	ddef	pSearchTemplateString, es, si
	ddef	pCompareListStruct, ss, di		; compare list structure
	ddef	pCompareList, ss, di			; compare list store items
	def	bWildChars, FALSE				; if wild chars used
	def	CountItems, 0

	SaveRegisters di, si
	call InitCompareListStruct
	mov word [ ss:_cspStartStringSegment + di ], es

	call BuildLFN_CheckAllSpecialCase
	jnz BuildLFNCompareList_08			; if not *.* case, go parse ->

	storarg _bWildChars, True			; else say wild chars used
	or word [ ss:_csFlags + di ], CSMATCHES_ALL
	jmp near BuildLFNCompareList_36
	; RxDOS 7.20N: force near jump

BuildLFNCompareList_08:
	lea bx, [ byte _csCompareList + di ]
	mov word [ _pCompareList + _pointer + bp ], bx	; compare list store items ptr
	; RxDOS 7.20N: unnecessary ss prefix to the address with bp

		; see if string starts with wild character
	call ScanToNextSeparator			; scan over first item
	jz BuildLFNCompareList_12			; if end of string -->
	cmp al, "*"					; wild character at start byte ?
	jz BuildLFNCompareList_24			; if true -->

BuildLFNCompareList_12:
	mov word [ ss:_cspStartString + _pointer + di ], dx	; must start with address
	mov word [ ss:_cspStartString + _csStringLength + di ], cx
	jz BuildLFNCompareList_32			; go set must end with -->

		; skip wild character, store entry
BuildLFNCompareList_24:
	storarg _bWildChars, TRUE			; set wild chars are used
	call ScanToNextSeparator			; skip over wild characters
	jz BuildLFNCompareList_32			; if end string, go set must end with -->

	mov bx, word [ _pCompareList + _pointer + bp ]	; compare list store items ptr
	mov word [ ss:_pointer + bx ], dx		; store pointer
	mov word [ ss:_csStringLength + bx ], cx	; store count
	add word [ _pCompareList + _pointer + bp ], byte sizeCompareListItem

	inc word [ _CountItems + bp ]			; number of entries updated
	cmp word [ _CountItems + bp ], byte maxEntriesCOMPARELIST
	jc BuildLFNCompareList_24			; if room for more -->
	jmp short BuildLFNCompareList_36		; list is incomplete, but exit anyway -->

		; if must end with entry
BuildLFNCompareList_32:
	or cx, cx					; if no end pointer
	jz BuildLFNCompareList_36			; skip -->

	cmp dx, word [ ss:_cspStartString + _pointer + di ]	; end ptr same as start ptr ?
	jz BuildLFNCompareList_36			; skip -->

	sub si, cx					; adjust for end
	mov word [ ss:_cspEndString + _pointer + di ], si	; must end with
	mov word [ ss:_cspEndString + _csStringLength + di ], cx	; string length

		; exit
BuildLFNCompareList_36:
	getarg cx, _CountItems
	mov di, word [ _pCompareListStruct + _pointer + bp ]
	mov word [ ss:_csCountEntries + di ], cx
	or word [ ss:_csFlags + di ], CSNOWILD_CHARS

	getarg ax, _bWildChars
	cmp ax, byte FALSE				; zr if wild characters NOT used
	jz BuildLFNCompareList_38			; if no wild chars
	and word [ ss:_csFlags + di ], ~ CSNOWILD_CHARS

BuildLFNCompareList_38:
	RestoreRegisters si, di
	Return


		; Check For *.* All Special Case
		;
		; Input:
		; es:si	ptr to filename (ends with null or \)
		;
		; Output:
		; ax	True (1)
		; zr	if *.* case
		; destroys cx
BuildLFN_CheckAllSpecialCase:

	mov cx, es
	or cx, si
	jz _CheckAllSpecialCase_08			; if null string

	cmp word [ es:si ], "*."
	jnz _CheckAllSpecialCase_08
	cmp word [ es:si + 2 ], byte "*"

_CheckAllSpecialCase_08:
	retn


		; Match Using Compare List
		;
		; For now, compares are case independent.
		;
		; Input:
		; ss:si	ptr to name to compare (ends with null or \)
		; ss:di	ptr to compare list structure
		; cx	string length
		;
		; Output:
		; zr	if names compare equal
		;
		; (assumes ds == ss)
matchOnCompareList:

	Entry
	ddef	pCompareList, ss, di
	ddef	pFilename, ss, si
	ddef	pFilenameOffset, ss, si

	def	wStringLength, cx
	def	wIfOtherStrings
	def	wCount

		; first, match on start string (null if *abc string)
	setDS ss
	SaveRegisters es
	mov es, word [ _cspStartStringSegment + di ]

	mov ax, word [ _cspEndString + _csStringLength + di ]
	or ax, word [ _csCountEntries + di ]		; other strings to match on
	storarg _wIfOtherStrings, ax			; save if other strings

	mov cx, word [ _cspStartString + _csStringLength + di ]
	or cx, cx
	jz matchOnCompareList_18			; if no start string -->

	test word [ _csFlags + di ], CSNOWILD_CHARS
	jz matchOnCompareList_12			; if wild chars -->
	cmp cx, word [ _wStringLength + bp ]
	ifnz matchOnCompareList_84			; if length's not equal, why compare ?

matchOnCompareList_12:
	mov si, word [ _pFilename + _pointer + bp ]
	mov bx, word [ _cspStartString + _pointer + di ]
	call _CompareNoCaseCheck			; compare strings
	ifnz matchOnCompareList_84			; if not equal -->

	mov word [ _pFilenameOffset + _pointer + bp ], si
	cmp word [ _wIfOtherStrings + bp ], byte 0	; other strings to match on ?
	jz matchOnCompareList_42			; no, so end must also match -->

		; then match on end string (null if 'abc' or 'abc*' string)
matchOnCompareList_18:
	mov cx, word [ _cspEndString + _csStringLength + di ]
	or cx, cx
	jz matchOnCompareList_42			; if no end string -->

	mov si, word [ _pFilename + _pointer + bp ]
	mov bx, word [ _cspEndString + _pointer + di ]
	cmp byte [ bx ], '.'				; *. special case ?
	jnz matchOnCompareList_38			; no -->
	cmp cx, byte 1					; *. special case ?
	jnz matchOnCompareList_38			; no -->

	mov al, '.'
	mov cx, word [ _wStringLength + bp ]

matchOnCompareList_22:
	cmp byte [ si ], '.'				; any extension specs ?
	jz matchOnCompareList_NoMatch			; if no match -->
	inc si
	loop matchOnCompareList_22			; scan entire field -->
	jmp short matchOnCompareList_42			; see if more patterns to match

matchOnCompareList_38:
	add si, word [ _wStringLength + bp ]
	sub si, cx
	call _CompareNoCaseCheck			; compare strings
	jnz matchOnCompareList_84			; if not equal -->

		; then loop and match on segments strings (null if no segments)
matchOnCompareList_42:
	mov cx, word [ _csCountEntries + di ]
	or cx, cx
	jz matchOnCompareList_84			; if no segment strings -->

	storarg _wCount, cx
	lea di, [ word _csCompareList + di ]

matchOnCompareList_46:
	cmp word [ _csStringLength + di ], byte 0
	jz matchOnCompareList_84			; if no more segment strings -->

	mov bx, word [ _pointer + di ]			; get pointer to compare string
	mov al, byte [ es:bx ]				; compare char
	_upperCase al					; upper case

	mov si, word [ _pFilenameOffset + _pointer + bp ]
	dec si

matchOnCompareList_52:
	inc si
	cmp byte [ si ], 00				; if null, no match -->
	jz matchOnCompareList_NoMatch			; no match -->
	cmp al, byte [ si ]				; compare against filename char
	jnz matchOnCompareList_52			; if no match yet -->

	; if here, match may be possible

	push ax
	mov cx, word [ _csStringLength + di ]
	mov word [ _pFilenameOffset + _pointer + bp ], si
	call _CompareNoCaseCheck			; compare strings

	pop ax
	jz matchOnCompareList_58			; if equal -->

	; no match, continue looking down stream

	mov si, word [ _pFilenameOffset + _pointer + bp ]
	jmp short matchOnCompareList_52			; continue -->

	; item matches, see if more segments to compare

matchOnCompareList_58:
	mov word [ _pFilenameOffset + _pointer + bp ], si

	add di, byte sizeCompareListItem
	dec word [ _wCount + bp ]
	jnz matchOnCompareList_46			; if more segments -->

		; return
matchOnCompareList_84:
	RestoreRegisters es
	Return

		; no match
matchOnCompareList_NoMatch:
	mov ax, es
	or ax, ax					; insure non-zero return
	jmp short matchOnCompareList_84			; exit -->


		; Compute LFN Checksum
		;
		; Input:
		; es:bx	pointer to short name in directory or FCB format
		;
		; Output:
		; al	checksum
		;
ComputeLFNChecksum:

	push bx
	xor al, al					; checksum
	mov cx, sizeFILENAME				; length of space to checksum

ComputeLFNChecksum_08:
	ror al, 1					; rotate and add
	add al, byte [ es:bx ]				; rotate and add
	inc bx
	loop ComputeLFNChecksum_08

	pop bx
	retn


		; Compare NoCase Check
		;
		; Input:
		; es:bx	ptr to match pattern (provided by user)
		; ss:si	ptr to name extracted from directory
		; cx	compare length
		;
		; Output:
		; zr	if items are equal
		;
_CompareNoCaseCheck:

	mov al, byte [ es:bx ]				; match pattern
	or al, al					; at end of match string provided ?
	jnz _CompareNoCaseCheck_08			; if not -->
	cmp al, byte [ si ]				; name extracted from directory
	jmp short _CompareNoCaseCheck_24		; must equal null at filename string ->

_CompareNoCaseCheck_08:
	cmp byte [ si ], 00				; end of entry from directory ?
	jnz _CompareNoCaseCheck_12			; no, go compare types -->
	cmp al, byte [ si ]				; name extracted from directory
	jmp short _CompareNoCaseCheck_24		; must equal null at filename string ->

_CompareNoCaseCheck_12:
	inc bx
	cmp al, '"'					; ignore double quotes
	jz _CompareNoCaseCheck_12			; go fetch next -->
	cmp al, '?'					; question mark matches anything except null
	jz _CompareNoCaseCheck_16			; consider equal -->
	cmp al, '*'					; question mark matches anything except null
	jz _CompareNoCaseCheck_16			; consider equal -->

	cmp al, byte [ si ]				; name extracted from directory
	jz _CompareNoCaseCheck_16			; if equal -->

	_upperCase al					; upper case
	cmp al, byte [ si ]				; name extracted from directory
	jnz _CompareNoCaseCheck_24			; if not equal -->

_CompareNoCaseCheck_16:
	inc si
	loop _CompareNoCaseCheck

	xor ax, ax					; insure zero (equal)

_CompareNoCaseCheck_24:
	retn


		; Scan To Next Separator
		;
		; Input:
		; es:si	ptr to string
		;
		; Output:
		; es:si	ptr to char after separator ('*')
		; dx	si value at start
		; zr	if at end of string
		;
ScanToNextSeparator:

	xor cx, cx
	mov dx, si
	mov al, byte [ es:si ]

		; scan within field
ScanToNextSeparator_08:
	cmp byte [ es:si ], 00				; end byte ?
	jz ScanToNextSeparator_32			; yes -->
	cmp byte [ es:si ], '\'				; end byte ?
	jz ScanToNextSeparator_32			; yes -->
	cmp byte [ es:si ], '*'				; wild character ?
	jz ScanToNextSeparator_12			; if yes -->

	inc cx						; inc count
	inc si						; advance pointer
	jmp short ScanToNextSeparator_08		; continue scanning -->

		; scan to next field
ScanToNextSeparator_12:
	cmp byte [ es:si ], '*'
	jz ScanToNextSeparator_14
	cmp byte [ es:si ], '?'				; if *?, treat as part of *
	jnz ScanToNextSeparator_32			; if NOT followed by a wild character -->

ScanToNextSeparator_14:
	inc si						; advance ptr
	jmp short ScanToNextSeparator_12

ScanToNextSeparator_32:
	retn


		; Init Compare List Struct
		;
		; Input:
		; ss:di	compare list structure
		;
		; Output:
		; none.	all registers except ax and cx preserved
		;
InitCompareListStruct:

	push es
	setES ss					; set segment
	clearMemory sizeCompareListStruct

	pop es
	retn


		; Copy From LFN To String
		;
		; Input:
		; es:di	ptr to directory entry
		; ss:si	ptr to String
		; cx	offset into string buffer
		;
		; Output:
		; es:di	ptr to directory entry
		; ds:si	ptr to Search String
		; cx	is actual length
_copyfromLFNtoString:

	xor dx, dx

_copyfromLFNString_08:
	mov bx, dx
	mov bl, byte [ cs:LFN_DirEntry_MatchTable + bx ]
	cmp bl, -1					; end of table ?
	jz _copyfromLFNString_End			; all one -->

	inc dx
	mov ax, word [ es:di + bx ]			; get UTF-16 char

%if 0
At this point we should do the Unicode conversion. This must actually do:

1. Reject the UTF-16 character if it consists of more than one UTF-16 word. Replace it
   with an underscore '_' and set the stack flag that there were unsupported
   Unicode characters.

2. Check if the UTF-16 (single) word is below 128 (0080h). The word is used as ASCII
   character without conversion if it is. It doesn't need step 3 below.

3. Search in the CP dependent table (e.g. CP437UNI.TBL) for the UTF-16 word.
 3.1. If the character is not found, store an underscore '_' in the buffer and set the
      stack flag to remember there was a unsupported Unicode character.
 3.2. If the character is found, use the character from the conversion table.

After all characters were moved, report to caller if there were unsupported Unicode
characters (that got replaced by an underscore '_').
%endif

	_upperCase al					; upper case character

	mov byte [ ss:si ], al
	or al, al					; end of string ?
	jz _copyfromLFNString_End			; yes -->

	inc si
	inc cx
	jmp short _copyfromLFNString_08

_copyfromLFNString_End:
	retn


		; Copy from String to LFN
		;
		; Input:
		; ds:si	ptr to String
		; es:bx	ptr to directory entry
		; cx	chars to copy
		;
		; Output:
		; all registers reserved
_copyfromStringtoLFN:

	SaveRegisters si, cx, bx, ax

	mov di, bx
	push di
	xor dx, dx
	xor ax, ax
	clearMemory sizeDIRENTRY			; init to zeroes

	pop di
	mov byte [ es:LFN_Attributes + di ], ATTR_LONGFILENAME

_copyfromStringtoLFN_08:
	lodsb						; get characters

	mov bx, dx
	mov bl, byte [ cs:LFN_DirEntry_MatchTable + bx ]

%if 0
At this point we should do the reverse Unicode conversion. This must actually do:

1. Check if the character byte is below 128 (0080h). The ASCII byte is zero-extended
   and used as an UTF-16 (single) word without conversion if it is. It doesn't need
   step 2 below.

2. Search in the CP dependent table (e.g. CP437UNI.TBL) for the character byte. Fetch
   the associated UTF-16 word. (This should _always_ find an associated UTF-16 word.)
%endif

	mov word [ es:di + bx ], ax		; set UNICODE char

	inc dx
	loop _copyfromStringtoLFN_08

_copyfromStringtoLFN_12:
	mov bx, dx
	mov bl, byte [ cs:LFN_DirEntry_MatchTable + bx ]
	cmp bl, -1
	jz _copyfromStringtoLFN_24

	inc dx
	mov word [ es:di + bx ], -1		; pad fill with -1 entries
	jmp short _copyfromStringtoLFN_12

_copyfromStringtoLFN_24:
	RestoreRegisters ax, bx, cx, si
	retn


		; Compare String
		;
		; Input:
		; cx	is max length to compare
		; ss:si	ptr to Search String
		; es:di	ptr to UNICODE name in directory
		;
		; Output:
		; zr	entries compare equal
_compareLFN_String:

	lodsb						; get character from string
	_upperCase al					; upper case
	or al, al					; null terminator
	jz _compareLFN_String_End			; exit -->
	cmp al, '\'					; string terminator
	jz _compareLFN_String_End			; exit -->

	cmp al, '"'
	jz _compareLFN_String				; skip quotes -->

	cmp al, '?'
	jz _compareLFN_String_Match			; ? always matches -->

	mov ah, byte [ es:di ]				; get UNICODE char
	_upperCase ah					; upper case character
	cmp al, ah					; match ?
	jnz _compareLFN_String_End			; else fail -->

_compareLFN_String_Match:
	inc di
	inc di
	loop _compareLFN_String

_compareLFN_String_End:
	retn


		; Compare LFN String
		;
		; Input:
		; cx	is max length to compare
		; ds:si	ptr to Search String
		; es:di	ptr to UNICODE name in directory
		;
		; Output:
		; zr	entries compare equal
_compareString:

	lodsb						; get character from string
	_upperCase al					; upper case
	or al, al					; null terminator
	jz _compareString_End				; exit -->
	cmp al, '\'					; string terminator
	jz _compareString_End				; exit -->
	cmp al, '.'					; string terminator
	jz _compareString_End				; exit -->

	cmp al, '"'
	jz _compareString				; skip quotes -->

	cmp al, '?'
	jz _compareString_Match				; ? always matches -->

	mov ah, byte [ es:di ]				; get char
	_upperCase ah					; upper case character
	cmp al, ah					; match ?
	jnz _compareString_End				; else fail -->

_compareString_Match:
	inc di
	loop _compareString

	xor cx, cx					; set zero flag if all matched

_compareString_End:
	retn


		; Read Next Entry
		;
		; Input:
		; ss:di	ptr to Disk Access Block
		;
		; Output:
		; es:bx	pointer in block buffer to data
		; cx	remaining bytes in block
		; zr	entry located
_ReadNextDirEntry:

	mov bx, di
	add word [ ss:diskAcPosition + _low + bx ], byte sizeDIRENTRY
	adc word [ ss:diskAcPosition + _high + bx ], byte 0
	call _FATReadRandom				; read into buffer
	retn


		; Init structLongFilename
		;
		; Input:
		; ss:bx	ptr to structLongFilename
		;
initStructLongFilename:

	SaveRegisters es, di

	setES ss
	mov di, bx
	clearMemory sizeSTRUCTLONGFILENAME

	mov word [ _lfnSearchAttribs + bx ], -1
	RestoreRegisters di, es
	retn


		; Compute Direntries for LFN (inc SFN)
		;
		; Input:
		; ss:di	ptr to structLongFilename
		;
		; Output:
		; ax	num directory entries required
		; dx	remainder bytes
		; es:si	ptr to long name
		;
ComputeDirEntries:

	push bx
	mov ax, sizeCANONICALPOINTER
	mul word [ _lfnCanonicalList + _canpNumEntries + di ]

	mov bx, ax
	lea bx, [ word _lfnCanonicalList + _canpArray - sizeCANONICALPOINTER + di + bx ]

	xor dx, dx
	mov cx, LFN_NAMECHARPERENTRY
	mov ax, word [ _canpStringLength + bx ]
	mov word [ _lfnSearchStringLength + di ], ax
	inc ax						; make sure we count null term char as a copy char
	div cx						; # entries in ax

	or dx, dx
	jz ComputeDirEntries_08
	inc ax						; incr if roundoff

ComputeDirEntries_08:
	inc ax						; incr for short entry

	les si, [ _canpStringPointer + bx ]
	mov word [ _lfnSearchLongNameText + _segment + di ], es
	mov word [ _lfnSearchLongNameText + _pointer + di ], si
	mov cx, word [ _canpStringLength + bx ]

	pop bx
	retn


		; Build Canonical Pointer List
		;
		; Expands filenames into their canonical form, replacing and
		; removing any . and .. paths.
		;
		; Input:
		; ax	options: FILECANNOT_BEDIRECTORY
		; es:si	ptr to input filename passed
		; ss:di	ptr to canonical pointer structure
		;
		; Output:
		; ss:di	ptr to pointer structure
		; cx:dx	current cluster, if search to begin here
		; bx	offset to optimized search entry
		; ax	drive, or error
		; cy	if error detected
BuildCanonicalPointerList:

	Entry
	ddef	UnexpandedFileName, es, si
	ddef	pCanonicalList, ss, di
	def	options, ax

	xor ax, ax
	def	drive, ax				; initialize to 0
	def	entries, ax				; entries in list
	def	optSearchEntry, ax			; optimize search entry
	ddef	currCluster, ax, ax			; cluster 0

		; skip through any leading spaces
	SaveSegments
	currSegment ds					; point to default segment
	les di, [ byte _pCanonicalList + bp ]
	clearMemory sizeCANONICALPOINTERLIST		; clear list

	les si, [ byte _UnexpandedFileName + bp ]
	call getDrive					; see if argument has drive
	storarg _drive, ax				; save drive value (either spec'd or default)
	mov word [ byte _UnexpandedFileName + _pointer + bp ], si	; save pointer past drive

	mov ax, pexterrPathNotFound			; error message
	jc buildCanonicalPtrs_Return			; invalid drive -->

		; get selected drive current directory
	getarg ax, _drive
	mov cl, sizeCDS
	mul cl						; ax contains offset to current drive

	les si, [ ss:_RxDOS_pCDS ]			; actual address in CDS
	add si, ax					; from
	add si, byte _cdsActualDirectory		; proper offset

	mov cx, word [ es:_cdsStartClusterDir + _high + si ]
	mov dx, word [ es:_cdsStartClusterDir + _low + si ]
	mov word [ _currCluster + _high + bp ], cx
	mov word [ _currCluster + _low + bp ], dx	; current starting cluster

		; build canonical list
	getarg ax, _drive
	call ptrLFNCurrentDirectory			; es:si ptr to curr directory

	xor dx, dx					; no entries set (yet)
	call _parseCanonicalItems			; build canonical list from CDS
	jc buildCanonicalPtrs_Return			; if error -->
	storarg _optSearchEntry, dx			; optimize search entry

	getdarg es, si, _UnexpandedFileName
	call _parseCanonicalItems			; build canonical list from input string
	jc buildCanonicalPtrs_Return			; if error -->

	or cx, cx					; can optiomize directory search ?
	jnz buildCanonicalPtrs_18			; yes -->
	stordarg _currCluster, 0, 0			; can't optimize for current cluster YET
	storarg _optSearchEntry, 0			; optimize search entry

buildCanonicalPtrs_18:
	mov di, word [ _pCanonicalList + _pointer + bp ]
	_CANPtrToEntry di, dl

	xor cx, cx
	getarg ax, _drive				; return drive

	mov word [ ss:di + _canpStringPointer + _segment ], cx
	mov word [ ss:di + _canpStringPointer + _pointer ], cx
	mov word [ ss:di + _canpStringLength ], cx
	mov word [ ss:di + _canpFlags ], cx

		; return
buildCanonicalPtrs_Return:
	mov di, word [ _pCanonicalList + _pointer + bp ]

	getarg bx, _optSearchEntry			; optimize search entry
	mov word [ di + _canpOptSearchEntry ], bx

	getdarg cx, dx, _currCluster			; where to start search
	mov word [ di + _canpCluster + _low ], dx
	mov word [ di + _canpCluster + _high ], cx
	mov word [ di + _canpDrive ], ax

	RestoreSegments
	Return


		; Parse Canonical List
		;
		; Scans ASCIZ string passed with path and builds a list of
		; pointers to each subdirectory element. Drive is skipped.
		;
		; Input:
		; ss:di	base pointer to canonical table
		; es:si	pointer to input filename ASCIZ
		; dx	entries already in table
		;
		; Output:
		; ss:di	pointer to canonical table
		; dx	entries in table
		; cx	FALSE if can optimize directory search
		;
_parseCanonicalItems:

	Entry

	xor ax, ax
	def	drive, ax				; drive
	def	entries, dx
	def	lowestEntry, dx				; if falls below lowest entry, turn opt off
	def	recoverEntry, 0

	ddef	pCanonicalTable, ss, di
	ddef	pFilename, es, si
	ddef	EntryTextPtr
	ddef	EntryLength

	def	pCanonicalNextEntry			; assumes table is on stack (ss:)
	def	CanOptimize, TRUE

	SaveSegments di, si

		; test first argument
	call _skipLeadingSpaces				; skip leading spaces
	ifz _parseCanonicalItems_56			; if end of string -->
	cmp al, '\'					; initial path designator
	jnz _parseCanonicalItems_12			; no -->

	inc si
	xor dx, dx
	storarg _entries, dx				; cancel all entries
	storarg _CanOptimize, False

		; get arguments
_parseCanonicalItems_12:
	_CANPtrToEntry di, dl
	storarg _pCanonicalNextEntry, di

_parseCanonicalItems_14:
	call _skipLeadingSpaces				; skip leading spaces
	ifz _parseCanonicalItems_56			; if end of string -->

	call _GetLeadingBytes				; ax contains first two bytes
	ifz _parseCanonicalItems_56			; if end of string -->

	cmp ax, '..'					; is .. entry ?
	jz _parseCanonicalItems_38			; yes, backup -->
	cmp al, '.'					; is . entry ?
	ifz _parseCanonicalItems_44			; yes, skip entry -->
	cmp ah, ':'					; is drive (:) entry ?
	ifz _parseCanonicalItems_44			; yes, skip entry -->

	stordarg _EntryTextPtr, es, si
	call _scanForward				; scan forward. cx returns length.

	push es
	push si						; save current pointer

	cmp word [ _CanOptimize + bp ], byte FALSE	; if already false
	je _parseCanonicalItems_32			; no need to optimize search further -->

	getdarg es, si, _EntryTextPtr
	getarg di, _pCanonicalNextEntry
	call _ParseOptimizeCompare			; maybe we can optimize entry
	jnz _parseCanonicalItems_32			; no, save entry -->

	inc word [ _recoverEntry + bp ]
	jmp short _parseCanonicalItems_34

_parseCanonicalItems_32:
	getdarg es, si, _EntryTextPtr
	getarg di, _pCanonicalNextEntry
	mov word [ ss:_canpStringPointer + _segment + di ], es
	mov word [ ss:_canpStringPointer + _pointer + di ], si
	mov word [ ss:_canpStringLength + di ], cx	; string length
	mov word [ ss:_canpFlags + di ], dx		; wild character flags

	cmp word [ _CanOptimize + bp ], byte FALSE	; if already false
	je _parseCanonicalItems_34			; skip test -->

	mov ax, word [ _entries + bp ]
	cmp ax, word [ _lowestEntry + bp ]		; current entry falls below lowest ?
	jge _parseCanonicalItems_34			; not yet -->
	storarg _CanOptimize, FALSE			; cannot optimize search

_parseCanonicalItems_34:
	inc word [ _entries + bp ]

	add di, byte sizeCANONICALPOINTER
	storarg _pCanonicalNextEntry, di

	pop si
	pop es						; restore scan pointer
	jmp short _parseCanonicalItems_14

		; process .. entry
_parseCanonicalItems_38:
	getarg cx, _entries
	or cx, cx					; can we go back ?
	jnz _parseCanonicalItems_40			; yes -->
	SetError pexterrPathNotFound, _parseCanonicalItems_64

_parseCanonicalItems_40:
	dec word [ _entries + bp ]
	sub di, byte sizeCANONICALPOINTER
	storarg _pCanonicalNextEntry, di

	mov word [ ss:_canpStringLength + di ], 0	; string length
	mov word [ ss:_canpStringPointer + _segment + di ], 0
	mov word [ ss:_canpStringPointer + _pointer + di ], 0

	cmp word [ _CanOptimize + bp ], byte FALSE	; if already false
	jz _parseCanonicalItems_44			; skip test -->

	mov ax, word [ _entries + bp ]
	cmp ax, word [ _lowestEntry + bp ]		; current entry falls below lowest ?
	jge _parseCanonicalItems_44			; not yet -->
	storarg _CanOptimize, FALSE			; cannot optimize search

_parseCanonicalItems_44:
	call _scanForward				; scan forward. cx returns length.
	jmp _parseCanonicalItems_14			; get next -->

		; done. can we fully optimize ?
_parseCanonicalItems_56:
	getarg ax, _recoverEntry
	or ax, ax
	jz _parseCanonicalItems_64

	cmp ax, word [ _lowestEntry + bp ]
	je _parseCanonicalItems_64
	storarg _CanOptimize, FALSE			; cannot optimize search
	clc

		; return
_parseCanonicalItems_64:
	getarg dx, _entries
	getarg cx, _CanOptimize

	getdarg ds, di, _pCanonicalTable
	mov word [ _canpNumEntries + di ], dx		; entries

	RestoreSegments si, di
	Return


		; Compare. See If Directory Search can be Optimized.
		;
		; Input:
		; ss:di	canonical table entry
		; es:si	pointer to item in input filename
		; cx	length of item
		;
		; Output:
		; zr	entries are equal
		;
_ParseOptimizeCompare:

	saveAllRegisters
	cmp cx, word [ _canpStringLength + di ]
	jnz _ParseOptimizeCompare_NotEqual		; not be equal -->

	cmp word [ _canpStringPointer + _segment + di ], byte 0
	jz _ParseOptimizeCompare_NotEqual		; not be equal -->

	setDS es
	mov es, word [ ss:_canpStringPointer + _segment + di ]
	mov di, word [ ss:_canpStringPointer + _pointer + di ]

_ParseOptimizeCompare_08:
	lodsb						; get character
	_upperCase al
	mov ah, al

	mov al, byte [ es:di ]
	_upperCase al

	cmp ah, al					; compare
	jnz _ParseOptimizeCompare_NotEqual		; if not equal -->

	inc di
	loop _ParseOptimizeCompare_08			; else compare to end -->

	xor cx, cx
	jmp short _ParseOptimizeCompare_Return

_ParseOptimizeCompare_NotEqual:
	mov ax, es
	or ax, ax					; not zero

_ParseOptimizeCompare_Return:
	restoreAllRegisters
	retn


		; Skip Leading Spaces
		;
		; Input:
		; es:si	pointer to input filename
		;
		; Output:
		; al	character at es:si
		; zr	null character
		;
_skipLeadingSpaces:

	mov al, byte [ es:si ]				; get next byte
	or al, al					; null terminator ?
	jz _skipLeadingSpaces_12			; yes, end of string -->
	cmp al, ' '					; space ?
	jnz _skipLeadingSpaces_12			; no, return -->
	inc si
	jmp short _skipLeadingSpaces

_skipLeadingSpaces_12:
	or al, al					; no carry, zr/nz set
	retn


		; Get Leading Bytes
		;
		; Input:
		; es:si	pointer to input filename
		;
		; Output:
		; es:si	adjusted pointer to input filename
		; ax	characters at es:si
		; zr	null character
		;
_GetLeadingBytes:

	push si
	call _getNextNonQuotedCharacter			; get character
	mov cl, al					; store character

	call _getNextNonQuotedCharacter			; get character
	mov ah, al					; create al/ah pair
	mov al, cl
	or al, al
	pop si
	retn


		; Scan Forward
		;
		; Input:
		; es:si	pointer to input filename
		;
		; Output:
		; es:si	points to just after next \ or end of line
		; al	terminating character
		; cx	length of string without quotes
		; dx	set to CANONICALENTRY_WILDCHARS if wild chars found
		; zr	if string terminator found
		;
_scanForward:

	xor dx, dx
	call _getNextNonQuotedCharacter			; get next character
	mov cx, si					; save base pointer
	dec cx						; account for current character

_scanForward_12:
	cmp al, '?'
	jz _scanForward_18
	cmp al, '*'
	jnz _scanForward_22

_scanForward_18:
	mov dx, CANONICALENTRY_WILDCHARS

_scanForward_22:
	call _getNextNonQuotedCharacter			; get next character
	jz _scanForward_28				; if end of string -->

	cmp al, '\'					; scan until '\'
	jnz _scanForward_12				; keep looking -->
	inc cx						; adjusts sub below to not incl \ char

_scanForward_28:
	sub cx, si					; compute address difference
	neg cx						; actual length
	or al, al					; end of line status
	retn


		; Get Next Non-Quoted Character
		;
		; Input:
		; es:si	pointer to input filename
		;
		; Output:
		; es:si	points to just after next \ or end of line
		; al	character
		; zr	if string terminator found
		;
_getNextNonQuotedCharacter:

	mov al, byte [ es:si ]				; get byte
	or al, al					; null terminator ?
	jz _getNextNonQuoted_12				; yes, end of string -->

	inc si						; point to next byte
	cmp al, '"'					; quote char ?
	jnz _getNextNonQuoted_12
	jmp short _getNextNonQuotedCharacter		; yes, get next -->

_getNextNonQuoted_12:
	or al, al
	retn


		; Get Ptr Current Directory
		;
		; Input:
		; ax	drive
		;
		; Input:
		; ax	drive
		; es:si	current directory (CDS or LFNCDS)
		; NZ	if LFNCDS
		;
ptrLFNCurrentDirectory:

	Entry
	def	actualdrive, ax

	push ax
	mov cx, sizeLFNCDS
	mul cx

	les si, [ _RxDOS_pLFNCDS ]			; LFNCDS base address
	add si, ax					; drive offset
	add si, byte 3
	cmp byte [ es:si + _lfncdsLongDirectory - 3 ], 0
	jnz ptrLFNCurrDir_16				; if name valid -->

	mov ax, sizeCDS
	mul word [ _actualdrive + bp ]			; ax contains offset to current drive

	les si, [ _RxDOS_pCDS ]				; CDS base address
	add si, ax					; drive info
	mov ax, _cdsActualDirectory			; proper offset
	add al, byte [ es:si + _cdsNonSubstOffset ]
	add si, ax
	xor ax, ax

ptrLFNCurrDir_16:
	pop ax
	clc
	Return


		; Update Dir Access Block
		;
		; Input:
		; ax	drive
		; bx	ptr dirAccess block
		; di	ptr longfilename block
		;
updateDirAccessBlock:

	Entry
	def	drive, ax
	ddef	cluster, cx, dx
	def	ptrDirAccess, bx
	def	ptrstructLongfilename, di

	setDS ss
	setES ss
	getarg di, _ptrstructLongfilename
	mov cx, word [ _lfnSearchStringLength + di ]
	les si, [ _lfnSearchLongNameText + di ]
	lea bx, [ word _lfnShortFCBName + di ]
	call createFCBNAMEfromLFN

		; init other values
	setES ss
	getarg bx, _ptrDirAccess
	getarg di, _ptrstructLongfilename
	mov dx, word [ _lfnDirCluster + _low + di ]
	mov cx, word [ _lfnDirCluster + _high + di ]
	mov word [ fileAcDirCluster + _low + bx ], dx
	mov word [ fileAcDirCluster + _high + bx ], cx

	mov dx, word [ _lfnCluster + _low + di ]
	mov cx, word [ _lfnCluster + _high + di ]
	mov word [ fileAcCluster + _low + bx ], dx
	mov word [ fileAcCluster + _high + bx ], cx

	getarg ax, _drive
	mov word [ fileAcDrive + bx ], ax
	Return


		; LFN Allocate FindData Store
		;
		; Output:
		; cy	could not allocate
		; ss:di	ptr to Allocate area (if not cy)
LFNAllocateFindDataStore:

	setDS ss
	mov bx, RxDOS_LFNTempStorage
	mov cx, word [ RxDOS_LFNTempStoreCount ]

LFNAllocFindDataStore_08:
	cmp word [ bx ], byte 0
	jz LFNAllocFindDataStore_14

	add bx, byte 2					; size dd pointer
	loop LFNAllocFindDataStore_08			; see if more -->
	stc
	retn

LFNAllocFindDataStore_14:
	push bx						; handle
	sub bx, RxDOS_LFNTempStorage			; compute offset
	shr bx, 1
	mov ax, sizeLFNTEMPSTORE
	mul bl
	add ax, RxDOS_Heap
	mov di, ax
	clearMemory sizeLFNTEMPSTORE

	pop bx
	mov word [ bx ], di				; allocate item

	clc
	retn


		; LFN Release FindData
LFNReleaseFindData:

	setDS ss
	mov ax, word [ _RxDOS_CurrentPSP ]
	mov bx, RxDOS_LFNTempStorage
	mov cx, word [ RxDOS_LFNTempStoreCount ]

LFNReleaseFindData_08:
	cmp word [ bx ], byte 0				; allocated ?
	jz LFNReleaseFindData_12			; no, skip -->

	mov si, word [ bx ]				; pointer to area
	cmp ax, word [ _lfnfindstoreOwner + si ]	; same as terminating owner ?
	jnz LFNReleaseFindData_12			; no, skip to next -->

	mov word [ bx ], 0
	mov word [ _lfnfindstoreOwner + si ], 0
	jmp short LFNReleaseFindData_14

LFNReleaseFindData_12:
	add bx, byte 2					; size dw pointer
	loop LFNReleaseFindData_08			; see if more -->

LFNReleaseFindData_14:
	retn


		; LFN Release FindData
LFNValidateFindDataHandle:

	cmp bx, RxDOS_LFNTempStorage			; see if find close table range
	jc LFNValidateFindData_12			; not valid -->

	mov cx, word [ RxDOS_LFNTempStoreCount ]
	add cx, cx
	add cx, RxDOS_LFNTempStorage			; see if find close table range
	cmp bx, cx					; is handle out of range ?
	jnc LFNValidateFindData_12			; not valid -->

	cmp word [ bx ], byte 0				; already closed ?
	jz LFNValidateFindData_12			; yes, skip -->

	clc
	retn

LFNValidateFindData_12:
	stc
	retn

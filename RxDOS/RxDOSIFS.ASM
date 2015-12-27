
%if 0

RxDOSIFS - RxDOS Installable File System interface

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

	global Interrupt2F

		; defined in RxDOS
	extern _RetCallersStackFrame
	extern _cmp32
	extern _RxDOS_pCDS
	extern _RxDOS_bLastDrive
	extern _RxDOS_CurrentDrive
	extern SDAFirstName
	extern SDASecondName
	extern SDApCurrentCDS

		; defined in RxDOSERR
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

		; defined in RxDOSCCB
	extern CCBChanged
	extern linkBegCCB
	extern locateCCBPHeader
	extern readBuffer
	extern unlinkCCB
	extern updateAllChangedCCBBuffers

		; defined in RxDOSDEV
	extern checkforDeviceName
	extern checkforDeviceType
	extern DefineDPB
	extern getDPB
	extern getSysDate
	extern setSysDate
	extern getExpandedDateTime
	extern DevRead
	extern DevWrite

		; defined in RxDOSFCB
	extern initFCBfromSFT
	extern buildFindFromFCB
	extern buildDTAfcbFind

		; defined in RxDOSFIL
	extern blankinitDirName
	extern initdiskAccess
	extern ExpandFileName
	extern LocateFile
	extern LocateFreeDirSlot
	extern LocateFileByAttribute

	extern GetActualDrive
	extern getCurrDirCluster
	extern getDevice
	extern getDrive
	extern getWhereInDir

		; defined in RxDOSMEM
	extern _initializeMemoryBlock
	extern _collectMemoryBlocks
	extern _releaseOwnerMemoryBlocks
	extern _allocateUpperMB
	extern _allocateConvMB
	extern _modifyMemBlock

		; defined in RxDOSSFT
	extern createSFTEntry
	extern FindAvailableSFTHandle
	extern findmatchingFCBSFT
	extern FindSFTbyHandle
	extern MapAppToSFTHandle
	extern MapSFTToAppHandle
	extern releaseSFT
	extern VerifyAvailableHandle

	extern _SFTReadFile
	extern _SFTWriteFile
	extern _SFTOpenFile
	extern _SFTCreateFile
	extern _SFTCloseFile
	extern _SFTCloseAllFiles
	extern _SFTCommitFile

		; defined in RxDOSSTR
	extern CopyString
	extern CopyBlock
	extern convFCBNametoASCIZ
	extern convFilenametoFCBString
	extern getSysDateinDirFormat
	extern __ascii_stosb
	extern getMonthDayYear
	extern getDaysSince1980
	extern StringLength
	extern condStringLength


		; Installable File System (Int2F.11) Dispatch Table
IFSServicesTable:

	dw _IFSInstallCheck			; 00h Install Check
	dw _IFSRemoveDirectory			; 01h Remove Directory
	dw _IFSUndefined			; 02h (Unused)
	dw _IFSMakeDirectory			; 03h Make Directory
	dw _IFSUndefined			; 04h (Unused)
	dw _IFSChangeDirectory			; 05h Change Directory
	dw _IFSCloseFile			; 06h Close File
	dw _IFSCommitFile			; 07h Commit File
	dw _IFSReadFile				; 08h Read File
	dw _IFSWriteFile			; 09h Write File
	dw _IFSLockRegion			; 0Ah Lock Region
	dw _IFSUnlockRegion			; 0Bh Unlock Region
	dw _IFSGetDiskSpace			; 0Ch Get Disk Space
	dw _IFSUndefined			; 0Dh (Unused)
	dw _IFSSetFileAttributes		; 0Eh Set File Attributes
	dw _IFSGetFileAttributes		; 0Fh Get File Attributes
	dw _IFSUndefined			; 10h (Unused)
	dw _IFSRenameFile			; 11h Rename File
	dw _IFSUndefined			; 12h (Unused)
	dw _IFSDeleteFile			; 13h Delete File
	dw _IFSUndefined			; 14h (Unused)
	dw _IFSUndefined			; 15h (Unused)
	dw _IFSOpenFile				; 16h Open File
	dw _IFSCreateFile			; 17h Create File
	dw _IFSUnsupported			; 18h Create File without CDS
	dw _IFSUndefined			; 19h (Unused)
	dw _IFSUndefined			; 1Ah (Unused)
	dw _IFSFindFirst			; 1Bh Find First
	dw _IFSFindNext				; 1Ch Find Next
	dw _IFSCloseAllFiles			; 1Dh Close All Files
	dw _IFSSetRedirection			; 1Eh Set Redirection
	dw _IFSPrinterSetup			; 1Fh Printer Setup
	dw _IFSFlushBuffers			; 20h Flush Buffers
	dw _IFSSeekFromEnd			; 21h Seek From End
	dw _IFSTerminateProcess			; 22h Terminate Process
	dw _IFSQualifyFilename			; 23h Qualify Filename
	dw _IFSUndefined			; 24h (Unused)
	dw _IFSPrinterMode			; 25h Printer Mode
	dw _IFSPrinterOnOff			; 26h Printer On/Off
	dw _IFSCopy				; 27h Copy
	dw _IFSUndefined			; 28h (Unused)
	dw _IFSUndefined			; 29h (Unused)
	dw _IFSUndefined			; 2Ah (Unused)
	dw _IFSIOCTL				; 2Bh IOCTL
	dw _IFSUndefined			; 2Ch (Unused)
	dw _IFSUndefined			; 2Dh (Unused)
	dw _IFSExpandedOpen			; 2Eh Expanded Open/Create
	dw _IFSUndefined			; 2Fh (Unused)
	dw _IFSGetSegment			; 30h Get NFS Segment

Max_IFSServices	 equ ( $ - IFSServicesTable ) / 2


		; Extended Interface Functions (Int2F.12) Dispatch Table
EIFServicesTable:

	dw _EIFNotSupported			; 00h
	dw _EIFNotSupported			; 01h
	dw _EIFNotSupported			; 02h
	dw _EIFNotSupported			; 03h
	dw _EIFNotSupported			; 04h
	dw _EIFNotSupported			; 05h
	dw _EIFNotSupported			; 06h
	dw _EIFNotSupported			; 07h
	dw _EIFNotSupported			; 08h
	dw _EIFNotSupported			; 09h
	dw _EIFNotSupported			; 0Ah
	dw _EIFNotSupported			; 0Bh
	dw _EIFNotSupported			; 0Ch
	dw _EIFNotSupported			; 0Dh
	dw _EIFNotSupported			; 0Eh
	dw _EIFNotSupported			; 0Fh
	dw _EIFNotSupported			; 10h
	dw _EIFNotSupported			; 11h
	dw _EIFComputeStringLength		; 12h - Compute String Length
%if 1
	dw _EIFNotSupported			; 13h
	dw _EIFNotSupported			; 14h
	dw _EIFNotSupported			; 15h
	dw _EIFNotSupported			; 16h
	dw _EIFNotSupported			; 17h
	dw _EIFNotSupported			; 18h
	dw _EIFNotSupported			; 19h
	dw _EIFNotSupported			; 1Ah
	dw _EIFNotSupported			; 1Bh
	dw _EIFNotSupported			; 1Ch
	dw _EIFNotSupported			; 1Dh
	dw _EIFNotSupported			; 1Eh
	dw _EIFNotSupported			; 1Fh
%endif

Max_EIFServices	 equ ( $ - EIFServicesTable ) / 2


%if 1
		; RxDOS 7.20N:	Replace table by small dispatcher!
		; Interrupt 2F Services
Int2FServicesTable:

	dw _Int2FNotSupported			; 00h
	dw _Int2FNotSupported			; 01h
	dw _Int2FNotSupported			; 02h
	dw _Int2FNotSupported			; 03h
	dw _Int2FNotSupported			; 04h
	dw _Int2FNotSupported			; 05h
	dw _Int2FNotSupported			; 06h
	dw _Int2FNotSupported			; 07h
	dw _Int2FNotSupported			; 08h
	dw _Int2FNotSupported			; 09h
	dw _Int2FNotSupported			; 0Ah
	dw _Int2FNotSupported			; 0Bh
	dw _Int2FNotSupported			; 0Ch
	dw _Int2FNotSupported			; 0Dh
	dw _Int2FNotSupported			; 0Eh
	dw _Int2FNotSupported			; 0Fh
	dw _Int2FNotSupported			; 10h
	dw _IFSServices				; 11h
	dw _EIFServices				; 12h
%if 1
	dw _Int2FNotSupported			; 13h
	dw _Int2FNotSupported			; 14h
	dw _Int2FNotSupported			; 15h
	dw _Int2FNotSupported			; 16h
	dw _Int2FNotSupported			; 17h
	dw _Int2FNotSupported			; 18h
	dw _Int2FNotSupported			; 19h
	dw _Int2FNotSupported			; 1Ah
	dw _Int2FNotSupported			; 1Bh
	dw _Int2FNotSupported			; 1Ch
	dw _Int2FNotSupported			; 1Dh
	dw _Int2FNotSupported			; 1Eh
	dw _Int2FNotSupported			; 1Fh
%endif

Max_Int2FServices	equ ( $ - Int2FServicesTable ) / 2
%endif


		; Int2F Original Chain
Int2F_OriginalPtr:
	dd Int2F_DummyReturn

Int2F_DummyReturn:
	iret


		; Install 2F Interface
		; 
		; We know that the call is for us because no other redirector
		; interface has claimed this call.
InstallRedirector:

	pushf						; save interrupts

	cli
	xor ax, ax
	mov ds, ax
	mov bx, 002Fh * 4
	push word [ bx + _pointer ]			; address
	push word [ bx + _segment ]			; segment

	mov word [ bx + _pointer ], Interrupt2F
	mov word [ bx + _segment ], ss			; segment

	pop word [ ss:Int2F_OriginalPtr + _segment ]
	pop word [ ss:Int2F_OriginalPtr + _pointer ]	; original

	pop ds
	popf						; restore interrupts
	retn


		; Interrupt 2F
		; 
		; We know that the call is for us because no other redirector
		; interface has claimed this call.
		; 
		; al	contains function request
Interrupt2F:

	FarEntry 1
	arg	returnFlag
	def	FctAddress, ax

	call Int2FSaveRegisters
%if 1
	and word [ _returnFlag + bp ], byte ~ 1		; clear carry bit
%else
	and byte [ _returnFlag + bp ], ~ 1		; clear carry bit
%endif

	sti
	cld

%if 1
	cmp ah, Max_Int2FServices			; supported service ?
	jnc Interrupt2F_26				; if out of range -->

	push ax
	push bx
	xor bx, bx
	mov bl, ah
	add bx, bx
	mov bx, word [ cs:bx + Int2FServicesTable ]
	storarg _FctAddress, bx
	pop bx
	pop ax
	call word [ _FctAddress + bp ]
%else
	cmp ah, 11h
	jne Interrupt2F_20
	call _IFSServices
	jmp short Interrupt2F_26

Interrupt2F_20:
	cmp ah, 12h
	jne Interrupt2F_26
	call _EIFServices
%endif

Interrupt2F_26:
	call Int2FRestoreRegisters
	mov sp, bp					; part of return
	pop bp
	iret


		; Installable File System (Int2F.11) Functions
_IFSServices:

	cmp al, Max_IFSServices
	jnc _IFSServices_26				; if out of range -->

	xchg ax, bx
	xor bh, bh
	add bx, bx					; word offset
	push word [ cs:bx + IFSServicesTable ]

	xchg ax, bx
	shr ax, 1					; restores argument value in ax
%if 1
	retn						; call through stack
		; RxDOS 7.20N:	BUG. Actually the called code does _not_ return to this
		;		position. It'll instead return to the main Int2F dispatcher.
%else
	push bp
	mov bp, sp
	call word [ bp + 2 ]
	pop bp
%endif

	jnc _IFSServices_26				; if carry not set -->
%if 1
	or word [ _returnFlag + bp ], byte 1		;  else set carry bit
%else
	or byte [ _returnFlag + bp ], 1
%endif

_IFSServices_26:
%if 1
	Return
		; RxDOS 7.20N:	BUG. Should return near to the main Int2F dispatcher.
		;		(This one just never executed caused by the above bug.)
%else
	retn
%endif


		; Extended Interface Functions (Int2F.12)
_EIFServices:

	cmp al, Max_EIFServices
	jnc _EIFServices_26				; if out of range -->

	xchg ax, bx
	xor bh, bh
	add bx, bx					; word offset
	push word [ cs:EIFServicesTable + bx ]

	xchg ax, bx
	shr ax, 1					; restores argument value in ax
%if 1
	retn						; call through stack
		; RxDOS 7.20N:	BUG. Actually the called code does _not_ return to this
		;		position. It'll instead return to the main Int2F dispatcher.
%else
	push bp
	mov bp, sp
	call word [ bp + 2 ]
	pop bp
%endif

	jnc _EIFServices_26				; if carry not set -->
%if 1
	or word [ _returnFlag + bp ], byte 1		;  else set carry bit
%else
	or byte [ _returnFlag + bp ], 1
%endif

_EIFServices_26:
%if 1
	Return
		; RxDOS 7.20N:	BUG. Should return near to the main Int2F dispatcher.
		;		(This one just never executed caused by the above bug.)
%else
	retn
%endif


		; Save Registers
Int2FSaveRegisters:

	push cx
	push dx
	push si
	push di
	push ds
	push es

	push bp
	mov bp, sp
	xchg bx, word [ bp + 14 ]			; return address to bx
	push bx
	mov bx, word [ bp + 14 ]			; restore bx
	mov bp, word [ bp ]				; restore bp
	retn						; return


		; Restore Registers
Int2FRestoreRegisters:

	pop bx						; really, its the return address
	pop cx						; really discarded bp
	pop es
	pop ds
	pop di
	pop si
	pop dx
	pop cx

	push bp
	mov bp, sp
	xchg bx, word [ bp + 2 ]			; original bx
	pop bp						; restore bp
	retn						; return


		; IFS
_IFSChangeDirectory:
_IFSCloseAllFiles:
_IFSCloseFile:
_IFSCommitFile:
_IFSCopy:
_IFSDeleteFile:
_IFSExpandedOpen:
_IFSFindFirst:
_IFSFindNext:
_IFSFlushBuffers:
_IFSGetDiskSpace:
_IFSGetFileAttributes:
_IFSGetSegment:
_IFSInstallCheck:
_IFSIOCTL:
_IFSLockRegion:
_IFSMakeDirectory:
_IFSOpenFile:
_IFSPrinterMode:
_IFSPrinterOnOff:
_IFSPrinterSetup:
_IFSQualifyFilename:
_IFSReadFile:
_IFSRemoveDirectory:
_IFSSeekFromEnd:
_IFSSetFileAttributes:
_IFSSetRedirection:
_IFSTerminateProcess:
_IFSUnlockRegion:
_IFSWriteFile:

_IFSUndefined:
_IFSUnsupported:
	stc
	retn


		; Extended Interface Functions
_EIFNotSupported:
	stc
	retn


		; Int 2F Not Supported
_Int2FNotSupported:
	stc
	retn


		; Int 2F.1212 Compute String Length
		; 
		; Input:
		; es:di pointer to null terminated string
		; 
		; Output:
		; cx	length returned
		; 
_EIFComputeStringLength:

	xor al, al
	mov cx, -1
	repnz scasb

	not cx
	dec cx
	or cx, cx
	retn


		; IFS 17h Create File
		; 
		; CX		attributes
		; ES:DI		pointer to unitialized SFT
		; SDAFirstName	pointer to expanded file/path
		; SDApCurrentCDS pointer to CDS
		;
		; NOP
_IFSCreateFile:

	Entry
	def	Attributes, cx

	Return


		; IFS 11h Rename File
		; 
		; SDAFirstName	first name
		; SDASecondName second name
		;
		; This actually seems to be no NOP!
_IFSRenameFile:

	Entry
	ddef	wherePointer
	defbytes	existfileAccess, sizeDIRACCESS
	defbytes	renfileAccess, sizeDIRACCESS

		; does source file exist ?
	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDIRECTORY)
	mov si, SDAFirstName
	lea di, [ _existfileAccess + bp ]		; work dir access block
	call LocateFile					; check file path
	ifc _renameFile_40				; if file does not exist -->

	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDEFINED + FILECANNOT_BEDIRECTORY)
	mov si, SDASecondName
	lea di, [ _renfileAccess + bp ]			; renamed file dir access block
	call LocateFile					; check file path
	ifc _renameFile_40				; if file does not exist -->

		; both files seem ok, so we'll move them
	mov al, byte [ _existfileAccess + fileAcDrive + bp ]
	cmp al, byte [ _renfileAccess + fileAcDrive + bp ]
	mov ax, pexterrPathNotFound
	stc
	ifnz _renameFile_40				; cannot move across drives -->

	mov cx, word [ _existfileAccess + fileAcDirCluster + _high + bp ]
	mov dx, word [ _existfileAccess + fileAcDirCluster + _low + bp ]
	push word [ _renfileAccess + fileAcDirCluster + _high + bp ]
	push word [ _renfileAccess + fileAcDirCluster + _low + bp ]
	call _cmp32
	jnz _renameFile_22				; if must move files across dirs -->

	setDS ss
	mov si,	word [ _renfileAccess + fileAcNameOffset + bp ]
	les di, [ _existfileAccess + fileAcBufferPtr + bp ]
	add di,	word [ _existfileAccess + fileAcDirOffset + bp ]
	call convFilenametoFCBString			; convert name

	les si, [ _existfileAccess + fileAcBufferPtr + bp ]
	call locateCCBPHeader
	call CCBChanged					; update buffer
	jmp short _renameFile_38			; exit -->

		; move entry between directories
_renameFile_22:
	and word [ _renfileAccess + fileAcDrive + bp ], 7FFFh
	mov ax, word [ _renfileAccess + fileAcDrive + bp ]
	mov dx, word [ _renfileAccess + fileAcDirCluster + _low + bp ]
	mov cx, word [ _renfileAccess + fileAcDirCluster + _high + bp ]
	call LocateFreeDirSlot				; can we find a valid empty entry ?
	ifc _renameFile_40				; if can't find free slot -->

	stordarg _wherePointer, es, si
	mov di, si					; where entry must be copied to

	lds si, [ _existfileAccess + fileAcBufferPtr + bp ]
	add si,	word [ _existfileAccess + fileAcDirOffset + bp ]
	mov cx, ( sizeDIRENTRY / 2 )
	repe movsw					; copy entry from source dir

	setDS ss
	getdarg es, di, _wherePointer
	mov si, word [ _renfileAccess + fileAcNameOffset + bp ]
	call convFilenametoFCBString			; rename file

	getdarg es, si, _wherePointer
	call locateCCBPHeader
	call CCBChanged					; update buffer

	les di, [ _existfileAccess + fileAcBufferPtr + bp ]
	mov bx,	word [ _existfileAccess + fileAcDirOffset + bp ]
	mov byte [ es:di + bx ], DIRENTRY_DELETED
	call CCBChanged

		; return
_renameFile_38:
	or ax, ax					; no carry

_renameFile_40:
	Return

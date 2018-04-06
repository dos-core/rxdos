
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

%include "RXDMACRO.NEW"
%include "RXDSTRUC.NEW"

	cpu 8086

%if _BUILD_OBJ
	segment RXDOS align=16 class=RXDOS use16 public
	segment RXDOS

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
%endif

	align 2
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


	align 2
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
%if 0
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
	and byte [ _returnFlag + bp ], ~ 1		; clear carry bit

	sti
	cld

	cmp ah, 11h
	jne Interrupt2F_20
	call _IFSServices
	jmp short Interrupt2F_26

Interrupt2F_20:
	cmp ah, 12h
	jne Interrupt2F_26
	call _EIFServices

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

	push bp
	mov bp, sp
	call word [ bp + 2 ]
	pop bp

	jnc _IFSServices_26				; if carry not set -->
	or byte [ _returnFlag + bp ], 1

_IFSServices_26:
	retn


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

	push bp
	mov bp, sp
	call word [ bp + 2 ]
	pop bp
	jnc _EIFServices_26				; if carry not set -->
	or byte [ _returnFlag + bp ], 1			;  else set carry bit

_EIFServices_26:
	retn


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
_IFSCreateFile: equ _IFSUnsupported


		; IFS 11h Rename File
		; 
		; SDAFirstName	first name
		; SDASecondName second name
_IFSRenameFile: equ _IFSUnsupported


%if 0

RxDOS - RxDOS interface

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

(c) Copyright 1990, 1999. Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

%if 0

DOS file system is divided into the following layers:

Named File System

Uses the handle or FCB for file requests based on file
name and file position. A file pointer navigates thru
file.

Redirector

Passes file requests to a file redirector layer that
handles any proprietary file system requests, special
or networked file calls.

FAT file system

Maps file requests to clusters using the cluster chain
in the FAT (File Allocation Table).

Device Driver

Performs the actual disk (Int13) access.

%endif

	cpu 8086

%include "RXDMACRO.NEW"
%include "RXDSTRUC.NEW"
%include "RXOPTION.MAC"

			jmp strict near $
			db 0

		; DOS Data Segment
_RxDOS_SDALayoutStyle	db DOS5_SDASTYLE	; DOS 4.0+ Style
_RxDOS_data		times 21 db 0		; uninitialized

_RxDOS_ShareRetry	dw 0			; sharing retry count
_RxDOS_ShareDelay	dw 0			; sharing retry delay
_RxDOS_pdiskbuffer	dd 0			; pointer to disk buffer
_RxDOS_UnreadCON	dw 0			; ptr to unread CON input
_RxDOS_pStartMemBlock	dw 0			; seg ptr to start of memory allocation

_RxDOS_pDPB		dd -1			; ptr to Drive Parameter Block (DPB)
_RxDOS_pFT		dd -1			; ptr to File Tables (FT)
_RxDOS_pCLOCKdriver	dd -1			; ptr to CLOCK$ device driver
_RxDOS_pCONdriver	dd -1			; ptr to CON device driver
_RxDOS_wMaxBlock	dw sizeSector		; maximum bytes per block for any/all devices
_RxDOS_BufferList	dd -1			; pointer set for buffer list
_RxDOS_pCDS		dd -1			; ptr to array of current directory structures
_RxDOS_pFCBs		dd -1			; ptr to System FCB table
_RxDOS_nProtFCBs	dw 0			; number of protected FCBs (no longer supported)
_RxDOS_bNumBlockDev	db 0			; number of block devices
_RxDOS_bLastDrive	db 0			; lastdrive from RXCONFIG.SYS, CDS size

		; NULL Device Driver
		devheader _RxDOS_NULLDev, con, 70h, (DEV_CHAR | DEV_NULL), \
			null_strategy, null_interrupt, 'NUL'

		; Installable File System Parameters
_RxDOS_bNumJoinDev	db 0			; number of JOIN'ed drives
_RxDOS_wSpecialNames	dw 0			; pointer to list of special names
_RxDOS_pSETVERList	dd 0			; pointer to SETVER program list
_RxDOS_wDOSHIGHOffset	dw 0			; DOS High offset A20 fix
			dw 0			; DOS High PSP
_RxDOS_Buffers		dw 0			; BUFFERS x
_RxDOS_BuffersY		dw 0			; BUFFERS y (lookahead buffers)
_RxDOS_BootDrive:
bootdrive:		db 0			; Boot Drive (A: = 1, ...)
%if _386
					; RxDOS with _386 option will check for 386+ on startup and fail
					; if the CPU isn't high enough anyway, so we can preset this flag.
_RxDOS_MachineType	db 1			; 1 if 80386+, else 0
%else
_RxDOS_MachineType	db 0			; 1 if 80386+, else 0
%endif
_RxDOS_ExtendedMem	dw 0			; extended memory size in KiBs

		; the remainder of these arguments are not compatible with MS-DOS
_RxDOS_MaxMemory	dw 0			; max memory
_RxDOS_NumFileHandles	dw sizePSPHandleTable	; default
_RxDOS_pLFNCDS		dd -1			; expanded LFN buffer

_RxDOS_pExtErrorCode	dw 0			; Error code.
_RxDOS_ExtErrorFlag	dw 0			; flag if infor set
_RxDOS_ExtErrorInfo	times DOSERROR_size db 0; extended error info
_RxDOS_AbortInProgress	dw 0			; if NZ, skip critical error

		; Current PSP
			align 2,db 0
_RxDOS_CurrentInstance	dw 0			; base address of current stack
_RxDOS_CurrentStackTop	dw (dosdata_stack + 3 * RXDOS_PERCALL_STACKRESERVE)
						; Reserved Stack Top ...
_RxDOS_StackLongJump	dw 0			; long jump

		; UMB Control Status Word
_RxDOS_UMBEnabled	dw 0			; set by init
_RxDOS_UMBAllowed	dw 0			; selectable by user (Int21.5802, .5803)
first_umcb:		dw 0

		; Tab Expansion
_RxDOS_TabPosition	dw 0			; tab position

		; Country, Code Page, and Double Byte Character Set Info
			align 2,db 0
_RxDOS_UserCodePage	dw DEFAULT_CODEPAGE
_RxDOS_SystemCodePage	dw DEFAULT_CODEPAGE	; system code page
_RxDOS_DBCS_Table	dw 0			; DBCS (NULL)

_RxDOS_UserCountryCode	dw DEFAULT_COUNTRYCODE	; user set country
_RxDOS_SysCountryCode	dw DEFAULT_COUNTRYCODE	; system country code
_RxDOS_SegCountryTables dw 0000			; if non-zero, country info table

_RxDOS_CurrCountryInfo	dw DATE_USA
			db '$', 0, 0, 0, 0	; currency symbol (ASCIZ)	5 bytes
			dw ','			; thousands separator		2 bytes
			dw '.'			; decimal separator		2 bytes
			dw '-'			; date separator		2 bytes
			dw ':'			; time separator		2 bytes
			db 0			; currency format (before or after)
			db 2			; places after decimal point
			db TIME_12HOUR		; 12-hour or 24-hour format
			dw casemap, 70h
			dw ','			; data-list ...
			times 10 db 0		; reserved

%if 0
_RxDOS_extendedi18n:				; Int21.7000/.7001 unknown information
						; The following data is contained in MS-DOS 7.10 IO.SYS
			asciz "ENU"
			asciz "USA"
			db "US"			; Set to "GR" by german MS Windows 4.10.2222
						; (but associated german MS-DOS 7.10 starts up with "US")
			db 1,0,2,0,0,0
			asciz "AM"
			asciz "PM"
			db "M/d/yy"
			times 5 db 32
			db "dddd,MMMMdd,yyyy"
			times 9 db 32
%endif

		; RxDOS LFN Temp Storage
RxDOS_LFNTempStoreCount:dw 6				; # allocation buffers
RxDOS_LFNTempStorage:	times 6 dw 0			; allocation pointers (0 means not allocated)

		; RxDOS Stack Frame Recover
_RxDOS_StackFrameLock	dw 0
_RxDOS_StackFramePtr	dw 0
_RxDOS_INDOSRecover	dw 0

			align 2,db 0
_RxDOS_SharedBuffer	times 128 db 0		; shared buffer.


		; Swappable Data Area
		;
		; Variables whose names begin with _RxDOS are used and will
		; contain valid data. The remainder of the arguments are
		; placeholders for compatibility reasons and are not used.
		;
		; RxDOS 7.20N:	RxDOS versions < 7.20N included the comment
		;		"not used by RxDOS" for some of the unused
		;		items. These were removed.
		;
		; cm: Added some SDA... labels with RBIL 61.

		; Pre-SDA data. Not part of the SDA, but software may expect it here.
		;
		; NTVDM 5.1:			Pre-SDA = 300h,	SDA = 322h
		; MS-DOS 7.10 and DOS-C 2036:	Pre-SDA = 2FEh,	SDA = 320h
		; RxDOS 7.30 (estimation):	Pre-SDA = 201h,	SDA = 223h
		;  Only valid if no data will be changed above here until 7.30 release.
		;  (Unlikely because at least the 5 entry SFT at 0CCh should be inserted.)
		; RxDOS 7.20N:			No Pre-SDA,	SDA = 1E4h
		;
		; Check if Pre-SDA data available:
		; 1. Get SDA
		; 2. Save 17 bytes starting at SDA - (SDABeginArea-SDA5E01inc)
%if ($ - $$) > 2FEh
 %warning "Can't pad start of SDA to address 2FEh"
%else
	times (2FEh - ($ - $$)) db 0
%endif

SDAprinterecho:		db 0
_RxDOS_Verify		db 0			; NonZero if Verify
			db 0			; changes often in MS-DOS, possible used by Int21.09 or dev write
_RxDOS_bSwitchChar	db '/'			; Switch Char
_RxDOS_AllocStrategy	dw 0			; Allocation strategy
SDA5E01inc:		db 1			; incremented by Int21.5E01, initial value 1
SDAmachinename:		times 16 db 32		; machine name set by Int21.5E01, initial blanks only
SDApatchoffsets:	times 4 dw SDApatchbyte	; DOS-C 2036 and (according to RBIL) MS-DOS 4.00 = 0D0Ch,
						; MS-DOS 7.10 = 0D65h, NTVDM 5.1 = 0D0Eh (0D0Ch adjusted by 2)
						;  RxDOS 7.30 will most likely not have any of these values.
						; The bytes at this offsets are patched from =00h to <>00h under
						; MS-DOS 4+ or from =0C3h (retn) to 50h (push ax) under 3.x.
						; MS-DOS 4+ usually has 4 times the same offset here.
						; RxDOS 7.30 will most likely use the patched byte as flag (like
						; MS-DOS 4+ does) because that is more likely to work reentrant.
			dw 0			; terminator for the SDApatchoffsets list
%if 1
SDApatchbyte equ 0				; just fill list with terminators if unsupported
%endif
			db 0			; Padding
		; Start of real SDA
SDABeginArea:
_RxDOS_CritErrorFlag	db 0
_RxDOS_INDOSFlag	db 0			; INDOS flag
_RxDOS_CritErrorDrive	db 0			; drive where crit error occurred
_RxDOS_LocusLasterror	db 0
_RxDOS_ExtErrorcode	dw 0
_RxDOS_SuggestedAction	db 0
_RxDOS_ClassOfError	db 0
SDApLastError		dd 0			; pointer for last error
_RxDOS_pDTA		dd 0			; pointer to the current DTA
_RxDOS_CurrentPSP	dw 0			; current PSP
SDASaveSP		dw 0			; SP across int 23h
_RxDOS_ChildReturnCode	dw 0			; Child return code
_RxDOS_CurrentDrive	db 0			; current drive (A: = 0, ...)
_RxDOS_bCtrlBreakCheck	db -1			; check Ctrl-Break

SDAEndArea:

		; Extended Swappable Data Area
_RxDOS_FunctionCall	dw 0			; AX on call
_RxDOS_PSPShare		dw 0
_RxDOS_MachineIDShare	dw 0

SDAFirstUsableAlloc	dw 0
SDABestUsableAlloc	dw 0
SDALastUsableAlloc	dw 0
SDAMemSizeinParas	dw 0
SDALastDirEntryChecked	dw 0

SDAInt24_RetFailStatus	db 0
SDAInt24_AllowedActions db 0			; Abort, Retry, Fail bits
SDADirectoryFlag	db 0
SDATerminatedByCtrlC	db 0

_RxDOS_FCBAllowBlanks	db 0			; RxDOS 7.20N:	Yet unused
			db 0			; Padding
SDADayOfMonth		db 0
SDAMonth		db 0
SDAYear			dw 0			; year since 1980
SDADaysSince		dw 0			; since 1-1-1980
SDADayOfWeek		db 0			; 0 = Sunday

SDASFTValidPointer	db 0
SDAInt28_Safe		db 0
SDAInt24_Fail		db 0

SDADeviceDriverRequest	times 26 db 0
SDADeviceEntryPoint	dd 0
SDADeviceRequest01	times 22 db 0
SDADeviceRequest02	times 14 db 0
			times 8 db 0		; Unknown

SDAPSPCopyType		db 0
			db 0			; Padding
%if 1
_RxDOS_UserSerialNumber db 0, 0, 0		; User serial number
_RxDOS_DOSOEMVersion	db 94			; OEM identification (94 = 5Eh = RxDOS)
%else
_RxDOS_UserSerialNumber dw RXDOS_USERSERIALNUMBER &0FFFFh
			db RXDOS_USERSERIALNUMBER >>16	; 3-byte User serial number
_RxDOS_DOSOEMVersion	db RXDOS_OEMNUMBER	; OEM identification
%endif
SDAInt2526Conversion	dw 0			; pointer to Int25 and 26 error code conversion table

SDAClockTransfer	times 6 db 0
SDATransferWord		dw 0

SDAFirstName		times sizeEXPANDNAME db 0
SDASecondName		times sizeEXPANDNAME db 0
SDAFindBlock		times 21 db 0
SDADirEntry		times 32 db 0
SDACDSCopy		times 81 db 0
SDAFCBName		times 12 db 0
SDAFCBRename		times 12 db 0
			db 0			; Unknown
SDADestinationCluster	dw 0			
			times 5 db 0		; Unknown

SDAExtendedAttrib	db 0
SDAFCBType		db 0
SDADirSearchAttrib	db 0
SDAFileOpenMode		db 0
SDAFileFoundDeletedFlag	db 0
SDAFileNotFoundDevice	db 0
SDAFileAndDirectoryName	db 0
SDAServerCall		db 0
SDASectorWithinCluster	db 0
SDATranslateSector	db 0
SDAReadWriteFlag	db 0
SDADriveType		db 0
SDAClusterFactor	db 0
SDAClusterSplitMode	db 0
SDALineEditInsert	db 0
SDAFileLocated		db 0
SDAVolumeIDFlag		db 0
SDATypeProcessTerm	db 0
SDACreateFile		db 0
SDADeleteCode		db DIRENTRY_DELETED

SDADPBPointer		dd 0
SDAUserStackFrame	dd 0

SDAInt24_SPSave		dw 0
SDAUnknownDPB		dd 0			; points to an unknown DPB
SDALowCluster		dw 0
SDACurrentSector	dw 0
SDAHighCluster		dw 0
			dw 0			; Unknown
SDAMediaID		db 0
			db 0			; Padding
SDApCurrentDevice	dd 0
SDApCurrentSFT		dd 0
SDApCurrentCDS		dd 0
SDApCurrentFCB		dd 0
SDASFTHandle		dw 0
SDAHandleStorage	dw 0
SDApJFTEntryPointer	dd 0
SDAFirstFileName	dw 0
SDASecondFileName	dw 0
SDAPathNameLast		dw 0

		; RxDOS 7.20N:	According to RBIL 61 there is more data inside the SDA.
		;		However, RxDOS doesn't need anything beyond the OEMVersion,
		;		and the data that's missing here is f.e. the MS-DOS internal
		;		stacks for character i/o, disk i/o and error mode that are
		;		not used by RxDOS at all.

SDAExtendedSwapArea:
			align 2

		; System Default Handle Table (used if no PSP loaded)
		; RxDOS 7.20N:	Could be smaller. 5 handles should be enough.
pspSysHandleTable:	db 0, 0, 0
			times 17 db 0FFh
sizepspSysHandleTable equ $-pspSysHandleTable

		; RxDOS Product Identification

_RxDOS_DOSROMStatusFlag:
_RxDOS_DOSLocation	db RXDOS_DOSLOCATION	; DOS in ROM and DOS moved to HMA status
			align 2
_RxDOS_DOSVersion	dw RXDOS_MS_VERSION	; reported MS-DOS version

	align 16
bootname:
.drive:		db " :\"			; "C:\"
.filename:	times (8 + 1 + 3 + 1) db 0	; "FILENAME.EXT",0


	align 4
ptrStartBlockedDeviceTable:	dd -1		; -> first UPB

	align 4
		; Comm LookAhead Buffer
Comm_LookAhead:		times 4 db 0			; COM1, COM2, COM3, COM4

		; CON variables
Con_LookAhead		dw 0
Con_TabPosition		dw 0
Con_ScanCode		db 0


		; Device Assign Table
	align 4
stdDeviceAssignTable:
	STDREDIREC 'CON', stdRedirec_Con, (sftIsDevice + sftIsstdout + sftIsstdin)
	STDREDIREC 'AUX', stdRedirec_Aux, (sftIsDevice)
	STDREDIREC 'PRN', stdRedirec_Prn, (sftIsDevice)
	STDREDIREC -1


	align 2
dosdata_to_diskbuffer_segment:	dw 0
dosdata_to_doscode_segment:	dw 0


		; NULL Device Driver

		; RxDOS 7.20N:	This is actually the way MS-DOS does it, and thinking about it,
		;		this makes even sense. Nobody said you mustn't modify the request
		;		header in the strategy code itself. And there es:bx must be set
		;		correctly, at all.
		;
		;		I discovered DR-DOS has longer and, at all, better code for the
		;		NUL device. It also modifies the request header inside the strategy
		;		code, but it'll check if the function to get some characters was
		;		requested and set the returned count to zero if it was so. (See
		;		header.a86 inside directory IBMBIO/DRBIO of either Caldera DR-DOS
		;		7.01 or any Enhanced DR-DOS release, label is nul_strat.)
		;
		; RxDOS 7.30:	Placing all code in the strategy entry is the design RxDOS 7.30
		;		will implement fully backward compatible reentrant devices!
null_strategy:
		mov word [ byte es:bx + rhStatus ], OP_DONE
null_interrupt:
		retf


		; Stacks
	align 16, db 0

dosdata_stack:
	times 3 * RXDOS_PERCALL_STACKRESERVE db 0
	align 16, db 0

		; Allocatable Heap
RxDOS_Heap		equ $
	times 6 * sizeLFNTEMPSTORE db 0
	align 16, db 0


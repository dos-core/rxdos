
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


RxDOS_start:		jmp near RxDOS_initialize

	; ** ROMABLE BEYOND THIS ADDRESS **

_RxDOS_DOSVersionString:
			db RXDOSLONG_S, " version ", RXDOSVERSIONLONG_S
%ifnidn _REVISIONID, ""
			db " [",_REVISIONID,"]"
%endif
			db " [",__DATE__,"]"
			asciz

_RxDOS_ContrlC_Message	asciz '^C',13,10

dos_msg:
.int0:		db "Interrupt 00h: Divide by zero.", 13, 10, 0
.int6:		db "Interrupt 06h: Invalid opcode.", 13, 10, 0

		; Device Assign Table
			align 4
stdDeviceAssignTable:
	STDREDIREC 'CON', stdRedirec_Con, (sftIsDevice + sftIsstdout + sftIsstdin)
	STDREDIREC 'AUX', stdRedirec_Aux, (sftIsDevice)
	STDREDIREC 'PRN', stdRedirec_Prn, (sftIsDevice)
	STDREDIREC -1


		; Code Segment Data

		; Days In Month Table
DaysInMonthTable:	db 31			; Jan
			db 28			; Feb
			db 31			; Mar
			db 30			; Apr
			db 31			; May
			db 30			; Jun
			db 31			; Jul
			db 31			; Aug
			db 30			; Sep
			db 31			; Oct
			db 30			; Nov
			db 31			; Dec

		; Accumulated Days Per Month Table
AccumDaysPerMonthTable: dw 0			; Jan
			dw 31			; Feb
			dw 59			; Mar
			dw 90			; Apr
			dw 120			; May
			dw 151			; Jun
			dw 181			; Jul
			dw 212			; Aug
			dw 243			; Sep
			dw 273			; Oct
			dw 304			; Nov
			dw 334			; Dec

		; Bit Shift Table
_bitShiftTable:		db 1			; 0
			db 2			; 1
			db 4			; 2
			db 8			; 3
			db 16			; 4
			db 32			; 5
			db 64			; 6
			db 128			; 7

sizeShiftTable		equ ($ - _bitShiftTable)

		; Invalid Characters in Filename

_invalidFnCharacters:	db '[]<>|",;=+:',0
sizeInvFnChars		equ ($ - _invalidFnCharacters)

		; CMDLINE=
RxDOS_CMDLINE:		asciz 'CMDLINE='


	align 2
		; Dispatch table for all DOS Int21 functions
		;
		; Items marked by (*) are undocumented DOS functions
_RxDOS_functions:
	dw _TerminateProcess_00			; 00 -	Terminate program without return code
	dw _KeyboardInput			; 01 -	Keyboard input
	dw _DisplayOutput			; 02 -	Display output
	dw _AuxInput				; 03 -	Aux input
	dw _AuxOutput				; 04 -	Aux output
	dw _PrinterOutput			; 05 -	Printer output
	dw _DirectConsole			; 06 -	Direct console
	dw _DirectConsoleInputNoEcho		; 07 -	Direct console input noecho
	dw _ConsoleInputNoEcho			; 08 -	Console input noecho
	dw _DisplayString			; 09 -	Display string
	dw _BufferedKeyboardInput		; 0A -	Buffered keyboard input
	dw _CheckKeyboardInput			; 0B -	Check keyboard input
	dw _ClearBufferedKeyboardInput		; 0C -	Clear buffer and do i/o function
	dw _DiskReset				; 0D -	Disk reset
	dw _SelectDisk				; 0E -	Select disk
	dw _OpenFileFCB				; 0F -	Open file FCB
	dw _CloseFileFCB			; 10 -	Close file FCB
	dw _SearchFirstFileFCB			; 11 -	Search first file FCB
	dw _SearchNextFileFCB			; 12 -	Search next file FCB
	dw _DeleteFileFCB			; 13 -	Delete file FCB
	dw _SeqReadFileFCB			; 14 -	Seq read file FCB
	dw _SeqWriteFileFCB			; 15 -	Seq write file FCB
	dw _CreateFileFCB			; 16 -	Create file FCB
	dw _RenameFileFCB			; 17 -	Rename file FCB
	dw _UnusedReturnInst			; 18 -	Unused
	dw _CurrentDisk				; 19 -	Current disk
	dw _SetDiskTransferAddress		; 1A -	Set disk transfer address
	dw _GetDefaultDriveData			; 1B -	Get default drive data
	dw _GetDriveData			; 1C -	Get drive data
	dw _UnusedReturnInst			; 1D -	Unused
	dw _UnusedReturnInst			; 1E -	Unused
	dw _GetDefaultDriveParameterBlock	; 1F -	Get default drive parameter block
	dw _UnusedReturnInst			; 20 -	Unused
	dw _ReadFileFCB				; 21 -	Read file FCB
	dw _WriteFileFCB			; 22 -	Write file FCB
	dw _FileSizeFCB				; 23 -	File size FCB
	dw _SetRelativeRecordFCB		; 24 -	Set relative record FCB
	dw _SetInterruptVector			; 25 -	Set interrupt vector
	dw _CreateNewProgramSeg			; 26 -	Create new program seg
	dw _RandomBlockReadFCB			; 27 -	Random block read FCB
	dw _RandomBlockWriteFCB			; 28 -	Random block write FCB
	dw _ParseFilenameFCB			; 29 -	Parse filename FCB
	dw _GetDate				; 2A -	Get date
	dw _SetDate				; 2B -	Set date
	dw _GetTime				; 2C -	Get time
	dw _SetTime				; 2D -	Set time
	dw _SetVerifySwitch			; 2E -	Set verify switch
	dw _GetDiskTransferAddress		; 2F -	Get disk transfer address
	dw _GetDOSVersion			; 30 -	Get DOS version
	dw _TerminateStayResident		; 31 -	Terminate and stay resident
	dw _GetDriveParameterBlock		; 32 -	Get drive parameter block
	dw _CtrlBreakCheck			; 33 -	Ctrl-C check flag, new DOS functions
	dw _GetInDOSFlagAddress			; 34 -	Get InDOS flag address
	dw _GetInterruptVector			; 35 -	Get interrupt vector
	dw _GetFreeDiskSpace			; 36 -	Get free disk space
	dw _GetSetSwitchChar			; 37 -	Get/set switch char
	dw _CountryDependentInfo		; 38 -	Country dependent info
	dw _CreateSubdirectory			; 39 -	Create subdirectory
	dw _RemoveSubdirectory			; 3A -	Remove subdirectory
	dw _ChangeSubdirectory			; 3B -	Change subdirectory
	dw _CreateFile				; 3C -	Create file
	dw _OpenFile				; 3D -	Open file
	dw _CloseFile				; 3E -	Close file
	dw _ReadFile				; 3F -	Read file
	dw _WriteFile				; 40 -	Write file
	dw _DeleteFile				; 41 -	Delete file
	dw _MoveFilePointer			; 42 -	Move file pointer
	dw _ChangeFileMode			; 43 -	Change file mode
	dw _IoControl				; 44 -	IOCTL
	dw _DuplicateFileHandle			; 45 -	Duplicate file handle
	dw _ForceFileHandle			; 46 -	Force file handle
	dw _GetCurrentDirectory			; 47 -	Get current directory
	dw _AllocateMemory			; 48 -	Allocate memory
	dw _FreeAllocatedMemory			; 49 -	Free allocated memory
	dw _ModifyAllocatedMemory		; 4A -	Modify allocated memory
	dw _ExecuteProgram			; 4B -	ExecuteProgram
	dw _TerminateProcess			; 4C -	Terminate program with return code
	dw _GetReturnCode			; 4D -	Get return code
	dw _FindFirstFile			; 4E -	Find first file
	dw _FindNextFile			; 4F -	Find next file
	dw _SetPSPAddress			; 50 -	Set PSP Address
	dw _GetPSPAddress			; 51 -	Get PSP Address
	dw _GetDosDataTablePtr			; 52*-	Get DOS Data Table
	dw _TranslateBIOSParameterBlock		; 53*-	Translate BIOS Parameter Block
	dw _GetVerify				; 54 -	Get verify
	dw _DuplicatePSP			; 55*-	Duplicate PSP block
	dw _RenameFile				; 56 -	Rename file
	dw _SetFileDateTime			; 57 -	Set file date time
	dw _GetAllocationStrategy		; 58 -	Get allocation strategy
	dw _GetExtendedError			; 59 -	Get extended error
	dw _CreateUniqueFile			; 5A -	Create unique file
	dw _CreateNewFile			; 5B -	Create new file
	dw _LockFileAccess			; 5C -	Lock file access
	dw _ServerShareAndSwap			; 5D*-	Server, Share, SDA and extended error information
	dw _GetMachineName			; 5E -	Get machine name, network
	dw _GetRedirectionList			; 5F -	Get redirection list
	dw _GetActualFileName			; 60*-	Get actual filename (truename)
	dw _Unused				; 61 -	Unused
	dw _GetPSPAddress			; 62 -	Get PSP address
	dw _GetDBCSString			; 63*-	Get DBCS string
	dw _Unused				; 64 -	Unused
	dw _ExtCountryDependentFunctions	; 65 -	Extended Country Dependent Functions
	dw _GlobalCodePage			; 66 -	Get/Set Global Code Page
	dw _SetHandlesCount			; 67 -	Set Handles Count
	dw _CommitFile				; 68 -	Commit File
	dw _GetDiskSerialNumber			; 69*-	Get disk serial number
	dw _CommitFile				; 6A*-	Commit File (same as 68)
	dw _Unused				; 6B -	Unused
	dw _ExtendedOpenCreate			; 6C -	Extended open/create
	dw _Unused				; 6D -	ROM DOS: Find first ROM program
	dw _Unused				; 6E -	ROM DOS: Find next ROM program
	dw _Unused				; 6F -	ROM DOS: Get/set searched ROM area
	dw _GetSetCountryInformation		; 70 -	Get/set extended country information
	dw _Int21Function71			; 71 -	Long filename functions
	dw _Unused				; 72 -	Chicago LFNFindClose (beta only)
	dw _Int21Function73			; 73 -	FAT32 extended drive functions
						;   *-	items: undocumented DOS function

_RxDOS_maxFunctionCode equ ($ - _RxDOS_functions)/2


		; Critical Section Patch Area
_RxDOS_CritSectPatches	times 5 dw 0


		; Display Message
		;
		; Uses Int10.0E
		;
		; INP:	cs:si -> 0-terminated message
		; CHG:	ax, bx, si, bp
		; OUT:	-
dos_disp_msg:
.:
	cs lodsb					; get character (cs:si)

	or al, al					; null terminator ?
	jz .end						; yes -->
	push si
	mov ah, 0Eh
	mov bx, 0007h
	int 10h
	pop si
	jmp short .
.end:
	retn


relocated i00:
_Interrupt_00:
	mov si, dos_msg.int0
	call dos_disp_msg
	mov ax, 4C7Fh
	int 21h


relocated i06:
_Interrupt_06:
	mov si, dos_msg.int6
	call dos_disp_msg
	mov ax, 4C7Fh
	int 21h


		; Interrupt 21
		;
		; ah = requested function
		; all other registers possible parameters for function
relocated i21:
_Interrupt_21:

%if 0
		; RxDOS 7.30:	New dispatcher for functions on caller's stack.
	push bx
	mov bx, _RxDOS_functions_css
	jmp short .first
.next:
	push ax
	mov al, byte [cs:bx+1]
	sub al, byte [cs:bx]
	xor ah, ah
	add ax, ax
	add ax, byte 2
	add bx, ax
	pop ax
.first:
	cmp word [cs:bx], 0FFh
	je .popbx
	cmp byte [cs:bx], ah
	jb .next
	cmp byte [cs:bx+1], ah
	ja .next
	push ax
	xor al, al
	xchg al, ah
	add ax, ax
	add ax, byte 2
	add bx, ax
	pop ax

		; functions are called with:
		; ax, cx, dx, di, si, bp, es, ds, ss = user values (changing will modify!)
		; bx = pointer (in cs) of this function's address
		; word [cs:bx] = this function's address
		;
		; stack:
		; word - near return address if no matching function
		; word - user bx
		; word - user ip (int)
		; word - user cs (int)
		; word - user fl (int)
		;
		; If the subfunction doesn't match, the code will do a near return and
		; the main Int21 dispatcher is executed. If the subfunction matches, the
		; code will twice "pop bx" (first time will remove the near return address)
		; and then execute directly on the user stack after the interrupt entry.
	call word [cs:bx]
.popbx:
	pop bx
%endif

	push es
	push ds
	push bp
	push di
	push si
	push dx
	push cx
	push bx
	push ax						; this stack frame is compatible to MS-DOS'

	mov bp, sp
	add bp, byte sizeStackFrame


		; switch to internal stack
	cli
	setes ss					; caller's stack
	mov bx, bp					; caller's stack to es:bx

	mov ds, word [ cs:_RxDOS_CurrentSeg ]		; current segment.
	call _RxDOS_StackFrameRestore

	mov ss, word [ cs:_RxDOS_CurrentSeg ]		; current segment.
	mov sp, word [ ss:_RxDOS_CurrentStackTop ]	; point to current stack.

	push bx						; caller's stack reference
	push es

		; current stack parameters
	entry						; set [ bp ]
	def	FctAddress

	push word [ _RxDOS_CurrentStackTop ]
	sub word [ _RxDOS_CurrentStackTop ], RXDOS_PERCALL_STACKRESERVE	; reserve stack

	push word [ _RxDOS_CurrentInstance ]		; base address of current stack
	mov word [ _RxDOS_CurrentInstance ], bp		; base address of current stack

	push word [ _RxDOS_INDOSFlag ]
	inc word [ _RxDOS_INDOSFlag ]			; InDOS

	push word [ _RxDOS_StackLongJump ]		; long jump

		; save PSP values
	mov dx, word [ _RxDOS_CurrentPSP ]
	or dx, dx					; was PSP zero ?
	jz _Interrupt_21_12				; if no valid PSP -->

	mov ds, dx
	mov word [ pspUserStack + _segment ], es
	mov word [ pspUserStack + _pointer ], bx	; set user stack values if valid PSP

		; determine function address
_Interrupt_21_12:
	sti
	cld
	currSegment ds					; point to current segment
	mov word [ _RxDOS_FunctionCall ], ax		; AX on call

	mov bx, _Unused_al00
	cmp ah, _RxDOS_maxFunctionCode			; max function code ?
	jnc _Interrupt_21_21				; if out of range -->

	xor bh, bh
	mov bl, ah					; offset into functions table
	add bx, bx
	mov bx, word [ _RxDOS_functions + bx ]
_Interrupt_21_21:
	mov word [ byte bp + _FctAddress ], bx		; save dispatch address

	RetCallersStackFrame ds, bx
	mov es, word [ byte bx + _DS ]			; ds on call
	mov dx, word [ byte bx + _DX ]			; restore dx
	mov bx, word [ byte bx + _BX ]			; restore bx
	mov di, dx					; dx also passed in di

	currSegment ds					; point to current segment
	mov word [ _RxDOS_StackLongJump ], sp		; save stack long jump


	cmp ah, 00h					; function 00h ?
	je .checkif					; doesn't always check -->
	cmp ah, 0Ch					; function 01h-0Ch ?
	jbe .checkalways				; always checks -->

.checkif:
	call CtrlC_Check
	jmp short .checkdone

.checkalways:
	call CtrlC_CheckAlways

.checkdone:
	clc

		; es:di is ds:dx from user call
		; dx, ax, bx, cx, si have their values as set from user call
		; ds is changed to current segment
		; ss is also changed to current segment and won't change
		; NC
	call near [ byte bp + _FctAddress ]		; go do function

		; RxDOS 7.30:
		; NC no error, all registers on stack frame set appropriate
		; ---> Set NC in caller's flags
		; CY error,
		;  ax = 0FFFFh if FCB error, set caller's al to 0FFh
		;  ax > 0000h && < 0FFFFh if standard error,
		;	ax = extended error pointer to be used by GetExtErrorCodeValue.
		;	     This will return another ax that's returned to the caller.
		; ---> Set CY in caller's flags
		;  ax = 0000h if custom error, don't modify caller's ax (_Unused needs this)
		; ---> Don't modify CF in caller's flags

		; RxDOS 7.20N:	Releases <= 7.20N always supposed there's no error and set
		;		NC in caller's flags before calling the function code.
		;		However unused DOS functions are reported to return just
		;		al = 00h and CF unchanged, and some actual used functions
		;		also don't touch CF. (A bit ugly.)
		;
		; RxDOS 7.20N:	The current replacement code (for 7.30) has two ways of
		;		setting FCB errors: Return CY, ax=0FFFFh to the Int21
		;		dispatcher (sets CF of caller) or jmp to _Unused_alFF that
		;		sets the framed al and returns with CY, ax=0000h to the
		;		Int21 dispatcher (preserves CF of caller).
	RetCallersStackFrame ds, bx
	jnc _Interrupt_21_40				; go clear CF in caller's flags -->

		; Determine type of returned error
_Interrupt_21_22:
	or ax, ax					; 0000h ?
	jz _Interrupt_21_48				; custom error, skip all handling -->

	mov si, ax					; store actual value in si
	cmp ax, byte -1					; 0FFFFh ?
	mov ah, byte [ byte bx + _AX + _AH ]		; retain ah in case FCB error
	jz _Interrupt_21_32				; if FCB error -->

	mov word [ ss:_RxDOS_pExtErrorCode ], si	; save pointer to error code (unused by RxDOS)
	call GetExtErrorCodeValue			; get user error code in ax (uses si)

_Interrupt_21_32:
	mov word [ byte bx + _AX ], ax			; set user error code (ax|0FFh if FCB error)
	or byte [ byte bx + _FL ], 1			; sets bit0 of the flag word (CF)
	jmp short _Interrupt_21_48			; all done -->

_Interrupt_21_40:
	and byte [ byte bx + _FL ], ~1			; clears bit0 of the flag word (CF)

		; return registers
_Interrupt_21_48:
	cli
	pop word [ ss:_RxDOS_StackLongJump ]		; long jump
	pop word [ ss:_RxDOS_INDOSFlag ]		; restore InDOS
	pop word [ ss:_RxDOS_CurrentInstance ]		; _Instance
	pop word [ ss:_RxDOS_CurrentStackTop ]

	pop bx						; function address (useless)
	pop bx						; caller's sp

	pop ss						; restore caller's ss
	lea sp, [ byte bx-sizeStackFrame ]		; restore caller's sp (with stack frame)

	pop ax
	pop bx
	pop cx
	pop dx

	pop si
	pop di
	pop bp

	pop ds
	pop es						; restore registers from frame
	iret						; restore flags and cs:ip


%if 0
		; Clear saved CF and do iret
iret_nc:
	push bp
	mov bp, sp
	and byte [bp+6], ~1				; clear CF
	pop bp
	iret

		; Set saved CF and do iret
iret_cy:
	push bp
	mov bp, sp
	or byte [bp+6], 1				; set CF
	pop bp
	iret

		; Clear saved CF and fix stack for css functions
css_stackfix_nc:
	push bp
	mov bp, sp
	mov bx, word [bp+6]				; stacked bx
	and byte [bp+12], ~1				; clear CF
	pop bp
	retn 4						; remove bx and retn address from stack
%endif


		; Stack Frame Recover
		; It's not terribly clear to me what this is meant for. ~ ecm
_RxDOS_StackFrameRestore:

	cmp word [ _RxDOS_StackFrameLock ], byte 0
	je _RxDOS_StackFrameRestore_20			; no locked stack there? -->

%if 0
	cmp ah, GetDOSVersion
	je _RxDOS_StackFrameRestore_08
	cmp ah, GetExtendedError
	je _RxDOS_StackFrameRestore_08
		; RxDOS 7.20N:	These values will fall through to _RxDOS_StackFrameRestore_08 anyway
%endif
	cmp ah, ProgramTerminate			; (compares with 00h, not 4Ch!)
	je _RxDOS_StackFrameRestore_08
	cmp ah, ClearBufferedKeyboardInput
	jbe _RxDOS_StackFrameRestore_20

_RxDOS_StackFrameRestore_08:
		; RxDOS 7.20N:	Shouldn't we use ss: for these memory addresses?
	push word [ _RxDOS_StackFramePtr ]
	pop word [ _RxDOS_CurrentStackTop ]
	push word [ _RxDOS_INDOSRecover ]
	pop word [ _RxDOS_INDOSFlag ]
	mov word [ _RxDOS_StackFrameLock ], 0		; Indicate no locked stack stored

_RxDOS_StackFrameRestore_20:
	retn

		; Save Stack Frame for Int24 calls
saveStackFrame:

	cmp word [ ss:_RxDOS_StackFrameLock ], byte 0
	jne saveStackFrame_08				; Already a stack locked here? -->

	saveregisters ds, bx, ax
	setds ss
	inc word [ _RxDOS_StackFrameLock ]		; Indicate storage for locked stack used

	mov bx, word [ _RxDOS_CurrentInstance ]		; base address of current user stack
	mov ax, word [ byte bx - 4 ]			; stack top
	mov word [ _RxDOS_StackFramePtr ], ax
	mov ax, word [ byte bx - 8 ]			; InDOS flag
	mov word [ _RxDOS_INDOSRecover ], ax

	restoreregisters ax, bx, ds

saveStackFrame_08:
	retn


		; Call DOS interface for CP/M compatibility, "CALL 5"
relocated call5:
_CallDOS:
		; The CALL 5 interface isn't just a far call to this address.
		; Rather it's a near call (inside the program's PSP) to address 5, which
		; then calls far to this address. Doing a retf here will screw everything
		; up and return into the PSP data instead of into the actual caller code.
	pushf
	push bp
	mov bp, sp
		; [ bp ] = bp
		; [ bp + 2 ] = flags (that we just pushed)
		; [ bp + 4 ] = call far's ip (will point into PSP so it's garbage)
		; [ bp + 6 ] = call far's cs
		; [ bp + 8 ] = "CALL 5"'s ip
		
	push ax
	xchg ax, word [ byte bp + 2]			; ax		= flags
	xchg ax, word [ byte bp + 8]			; [ bp + 8 ]	= flags
							; ax		= "CALL 5"'s ip
	xchg ax, word [ byte bp + 4]			; [ bp + 4 ]	= "CALL 5"'s ip
	pop ax
	pop bp
	add sp, byte 2					; were the flags we just pushed

		; [ sp ] = "CALL 5"'s IP
		; [ sp + 2 ] = call far's cs
		; [ sp + 4 ] = flags
		;  Surprisingly this really looks like the stack for an interrupt!
	cli						; Real interrupt entries do the same


	cmp cl, 24h					; CP/M function number
	ja .nocpmfunc					;  is it above 24h? Really no CP/M function -->
							;  (I found this behaviour while debugging MS-DOS)

	mov ah,cl					; CP/M compatibility interface uses cl as function
	jmp _Interrupt_21				; Pass it through to our normal Int21 entry

.nocpmfunc:
	xor al,al					; Report "Unused" function
	iret						;  (don't need to care about CY/NC)
		; RxDOS 7.20N:	The above, correct, code requires some space you may want to save.
		;		A short solution for all this CP/M crap is to place "xor al,al",
		;		"retn" at address 5 of the PSP. This will report an error to all CP/M
		;		CALL 5s and it's even shorter than the code used by RxDOS <= 7.20N


%if 0
		; Interrupt 20
		;
		; Terminate program
_Interrupt_20:
	xor ax, ax
	jmp _Interrupt_21
%endif


		; Where Data Segment Relocated
			align 2
_RxDOS_CurrentSeg	dw 0000				; Current Segment

		; System Wide Functions


%if 0
		; Interrupt 23 - Control-Break Exit Address
		;
		; This is a default Int 23 handler.
		;
		; Returns CY to cancel current application.
		;
		; RxDOS 7.20N:	See comment at CtrlC_CheckCallBack
_Interrupt_23:
	stc
	retf						; indicate to terminate current application
%endif


		; Interrupt 24 - Critical Error Handler
		;
		; This is a default Int 24 handler.
		;
		; Usage:
		; bp:si-> driver's header
		; di = error code
		; al = drive code
		; ah = allowed responses, flags
		; 	08h CRITERROR_IGNOREALLOWED
		; 	10h CRITERROR_RETRYALLOWED
		; 	20h CRITERROR_FAILALLOWED
		;
		; Return:
		; al = contains one of these values
		; 	00h CRITERROR_IGNORE
		; 	01h CRITERROR_RETRY
		; 	02h CRITERROR_TERMINATE
		; 	03h CRITERROR_FAIL
		;
		; RxDOS 7.20N:	In MS-DOS, DOS-C and DR-DOS the kernel Int24 handler doesn't ask the user
		;		and will always report fail. The prompt is only inside COMMAND.COM there.
		;
		; RxDOS 7.30:	Will move into resident RxCMD. All changed code moved into RxCMDRES.ASM.
%if 0
_Interrupt_24:
%if 1
	mov al, CRITERROR_FAIL				; default DOS handler always returns fail
	iret
%else
	push ds
	push es

	push cs
	pop ds

	push ax
	xchg ax, di
	mov ah, 0
	xchg di, ax					; upper bits zero
	add di, di
	mov di, word [ di + CriticalErrorMessages ]
	call _CritErrorDisplayNewLine

	pop ax
	push ax
	cmp al, -1					; valid unit ?
	jz _Interrupt_24_08				; invalid -->

	mov di, perr_OnDrive
	call _CritErrorDisplayMessage

	pop ax
	push ax
	add al, 'A'
	int 29h

	mov al, ':'
	int 29h

_Interrupt_24_08:
	pop ax						; abort, retry, fail, ...
	push ax
	mov di, CritError_AbortRetryIgnoreFail		; display "Abort, Retry, Ignore, Fail ?"
	test ah, CRITERROR_FAILALLOWED			; is "Fail" actually allowed?
	jnz _Interrupt_24_12				;  yes -->

	mov di, CritError_AbortRetryIgnore		; display only "Abort, Retry, Ignore ?" if not

_Interrupt_24_12:
	call _CritErrorDisplayNewLine

	xor ax, ax
	int 16h						; Get character from keyboard into al

	push ax
	int 29h						; Display pressed character

	pop cx						; character
	pop ax						; allowed to ah
	push ax

	or cl, 20h					; lower case
	cmp cl, CritError_FailCharacter|20h		; Fail ?
	jnz _Interrupt_24_22				; if not fail -->
	mov dx, CRITERROR_FAIL
	test ah, CRITERROR_FAILALLOWED			; fail allowed ?
	jnz _Interrupt_24_36				; exit with fail -->

_Interrupt_24_22:
	cmp cl, CritError_RetryCharacter|20h		; Retry ?
	jnz _Interrupt_24_26				; if not retry -->
	mov dx, CRITERROR_RETRY
	test ah, CRITERROR_RETRYALLOWED			; retry allowed ?
	jnz _Interrupt_24_36				; exit with retry -->

_Interrupt_24_26:
	cmp cl, CritError_IgnoreCharacter|20h		; Ignore ?
	jnz _Interrupt_24_30				; if not ignore -->
	mov dx, CRITERROR_IGNORE
	test ah, CRITERROR_IGNOREALLOWED		; ignore allowed ?
	jnz _Interrupt_24_36				; exit with ignore -->

_Interrupt_24_30:
	cmp cl, CritError_AbortCharacter|20h		; Abort ?
	jnz _Interrupt_24_08				; if not abort, reprompt -->
	mov dx, CRITERROR_TERMINATE

		; Exit
_Interrupt_24_36:
	mov ax, dx					; return value in ax
	pop dx						; throw away allowed

	pop es
	pop ds

	clc						; no exit flag
	retf 2						; returns to appl (iret without flags)


		; Display new line, then message
_CritErrorDisplayNewLine:

	push di
	mov al, 13
	int 29h
	mov al, 10
	int 29h
	pop di

	; jmp short _CritErrorDisplayMessage

		; Display message
_CritErrorDisplayMessage:

	mov al, byte [ di ]
	or al, al
	jz _CritErrorDisp_08

	int 29h
	inc di
	jmp short _CritErrorDisplayMessage

_CritErrorDisp_08:
	retn

		; the famous Abort, Retry, Ignore messages
CritError_AbortRetryIgnoreFail:
	db "Abort, Retry, Ignore, Fail ?", 0

CritError_AbortRetryIgnore:
	db "Abort, Retry, Ignore ?", 0

CritError_AbortCharacter	equ 'A'
CritError_RetryCharacter	equ 'R'
CritError_IgnoreCharacter	equ 'I'
CritError_FailCharacter		equ 'F'

CriticalErrorMessages:
	dw perr_devErrWriteProtectViol
	dw perr_devErrUnknownUnit
	dw perr_devErrDeviceNotReady
	dw perr_devErrUnknownCommand
	dw perr_devErrCRCerr
	dw perr_devErrBadDriveReq
	dw perr_devErrSeekError
	dw perr_devErrUnknownMedia
	dw perr_devErrSectorNotFound
	dw perr_devErrPrinterOutPaper
	dw perr_devErrWriteFault
	dw perr_devErrReadFault
	dw perr_devErrGeneralFailure
	dw perr_devErrSharingViolation
	dw perr_devErrLockViolation
	dw perr_devErrInvalidDiskChange

		; Critical error messages
perr_devErrWriteProtectViol:	asciz "Error Write Protect"
perr_devErrUnknownUnit:		asciz "Error Unknown Unit"
perr_devErrDeviceNotReady:	asciz "Error Device Not Ready"
perr_devErrUnknownCommand:	asciz "Error Unknown Command"
perr_devErrCRCerr:		asciz "Error CRC Error"
perr_devErrBadDriveReq:		asciz "Error Bad Drive Request"
perr_devErrSeekError:		asciz "Error Seek Error"
perr_devErrUnknownMedia:	asciz "Error Unknown Media"
perr_devErrSectorNotFound:	asciz "Error Sector Not Found"
perr_devErrPrinterOutPaper:	asciz "Error Printer Out Paper"
perr_devErrWriteFault:		asciz "Error Write Fault"
perr_devErrReadFault:		asciz "Error Read Fault"
perr_devErrGeneralFailure:	asciz "Error General Failure"
perr_devErrSharingViolation:	asciz "Error Sharing Violation"
perr_devErrLockViolation:	asciz "Error Lock Violation"
perr_devErrInvalidDiskChange:	asciz "Error Invalid Disk Change"
perr_OnDrive:			asciz " On Drive "
%endif
%endif


		; Interrupt 25 - Read From Disk
		; Interrupt 26 - Write To Disk
		;
		; Like MS-DOS, the default Int25 and 26 functions do not allow
		; 32-bit sector addressing. These functions support only the
		; first 32 MiB of all disks.
		;
		; However, setting the number of sectors to access to 0FFFFh,
		; ds:bx is used as a pointer to an disk access packet instead
		; of to the actual buffer. This allows to access larger drives
		; with the simple Int25 and 26 interface.
		;
		; To access sectors beyond the first 32 MiB of the disks, the
		; program may also use the device driver calls.
		;
		; Usage:
		; al	drive (0 = A:, ...)
		; cx	number of sectors to access (if 0FFFFh, extended access)
		; dx	logical disk sector address
		; ds:bx	buffer address (if cx = 0FFFFh, disk access packet address)
		;
		; Disk access packet:
		; [ 0 ]		Low word of logical disk sector address
		; [ 2 ]		High word of logical disk sector address
		; [ 4 ]		Word number of sectors to access
		; [ 6 ]		Buffer address pointer
		; [ 8 ]		Buffer address segment
relocated i25:
_Interrupt_25:

	saveSegments di, si, bp, dx, cx, bx

	mov si, DevRead
	jmp _Interrupt_26.common

relocated i26:
_Interrupt_26:

	saveSegments di, si, bp, dx, cx, bx

	mov si, DevWrite
.common:
	push ds
	push bx
	pop di
	pop es					; buffer to es:di

		; switch to stack in DOS data segment
		;  -- some of the code we call expects this!
	mov di, ss
	mov bx, sp

	push cs
	pop ss
	mov sp, word [ ss:_RxDOS_CurrentStackTop ]	; point to current stack.

	push di					; ss
	push bx					; sp
	entry
	def	FctAddress			; (unused)

	push word [ ss:_RxDOS_CurrentStackTop ]
	sub word [ ss:_RxDOS_CurrentStackTop ], RXDOS_PERCALL_STACKRESERVE

	push word [ ss:_RxDOS_CurrentInstance ]		; base address of current stack
	mov word [ ss:_RxDOS_CurrentInstance ], bp	; base address of current stack

	push word [ ss:_RxDOS_INDOSFlag ]
	push word [ ss:_RxDOS_StackLongJump ]		; long jump

	mov word [ ss:_RxDOS_StackLongJump ], sp	; save stack long jump

		; call into the common part
	call int_25_26_common

		; restore stack
	cli
	pop word [ ss:_RxDOS_StackLongJump ]		; long jump
	pop word [ ss:_RxDOS_INDOSFlag ]		; restore InDOS
	pop word [ ss:_RxDOS_CurrentInstance ]		; _Instance
	pop word [ ss:_RxDOS_CurrentStackTop ]

	pop bx						; function address (useless)
	pop bx						; caller's bp
	pop bx						; sp

	pop ss						; restore caller's ss
	mov sp, bx					; restore caller's sp
	sti

	restoreSegments bx, cx, dx, bp, si, di
	retf						; Leaves interrupt flags on stack


		; INP, OUT, STT:	as for next function
int_25_26_common:
	push es
	push bx
	call getDPB
	jc @F
	cmp word [ es:bx + _dpbSectorsPerFat ], 0
	clc
@@:
	pop bx
	pop es
	jc int_25_26_217305_common.drive_invalid
	jz int_25_26_217305_common.fat32_invalid

		; INP:	si = DevRead or DevWrite
		;	al = drive (0 = A:)
		;	cx = -1 if packet method,
		;	 ds:di -> disk access packet
		;	else,
		;	 cx = count of sectors
		;	 dx = start sector
		;	 es:di -> buffer
		; OUT:	CF = error status
		; STT:	ss = DOS data
int_25_26_217305_common:
	mov bx, cx					; sectors
	xor cx, cx					; extended sector address
						; sector number in cx:dx,
						; number of sectors in bx
	cmp bx, byte -1					; points to DISKIO struct ?
	jnz .oldint					; no -->

	mov bx, word [ di + diskioSectors ]
	mov cx, word [ di + diskioStartSector + _high ]
	mov dx, word [ di + diskioStartSector + _low ]
	les di, [ di + diskioBuffer ]

	jmp .common
.oldint:

	push es
	push bx
	push cx
	push ax
	push dx
	call getDPB
	jc @FF
	mov ax, [ es:bx + _dpbMaxClusterNumber ]
	dec ax	; -2 = max cluster number 0-based, +1 = number of clusters
	xor dx, dx
	xor cx, cx
	mov cl, [ es:bx + _dpbClusterSizeShift ]
@@:
	shl ax, 1
	rcl dx, 1
	loop @B		; >>= clust size shift, *= cluster size, = data sectors

	add ax, [ es:bx + _dpbFirstDataSector ]
	adc dx, 0	; add in reserved, FAT, root sectors

	test dx, dx	; does it fit in 16 bits?
	clc		; not error
@@:
	pop dx
	pop ax
	pop cx
	pop bx
	pop es
	jc .drive_invalid	; error -->
	jnz .size_invalid	; doesn't fit in 16 bits, old-style invalid -->

.common:
	or bx, bx					; nothing to read ?
	jz .skip					; if none (flags: NC, ZR) -->

	call si
.skip:
	retn

.size_invalid:
.fat32_invalid:
	mov ax, 0207h	; ah = 02h "bad address mark",
			; al = 07h "unknown media type"
	stc
	retn

.drive_invalid:
	mov ax, 0101h		; ah = 01h "bad command",
				; al = 01h "unknown unit for driver"
	stc
	retn


		; Interrupt 27
		;
		; Terminate and stay resident
		;
		; INP:	(cs = PSP)
		;	dx = number of bytes to keep resident
		; OUT:	ax = 3100h
		;	dx = number of paragraphs to keep
		;	jumps to interrupt 21h handler
relocated i27:
_Interrupt_27:
	mov cl, 4
	mov ax, dx
	shr dx, cl			; ignore excess over 10h boundary
	and ax, 0Fh			; isolate excess (if any)
	add ax, 0Fh			; if any excess, ax >= 10h
	shr ax, cl			; if any excess, ax = 1, else 0
	add dx, ax			; add in the excess

	mov ax, 3100h
	jmp _Interrupt_21


		; Interrupt 28
		;
		; DOS idle loop
relocated i28:
_Interrupt_28:
;	iret


		; Interrupt 2A
		;
		; DOS critical sections
relocated i2A:
_Interrupt_2a:
;	iret


		; Interrupt 2F
		;
		; DOS hard-coded multiplex, MS Windows, many services
relocated i2F:
_Interrupt_2f:
;	iret


		; All other interrupts
_IRet:
	iret


		; Get Current Handle Table (Job File Table)
		;
		; OUT:	NC if PSP loaded
		;	 es:bx-> Handle table
		;	CY if no PSP loaded
		;	 es:bx-> internal handle table
		; CHG:	es, bx
getHandleTable:
	call getpsp
	mov es, bx
	les bx, [ es:pspFileHandlePtr ]
	jnc getHandleTable_08

	push ss
	pop es
	mov bx, pspSysHandleTable

getHandleTable_08:
	retn


		; For Directory Functions, Change Error to 'Path Not Found'
		;
		; Usage:
		; INP:	ax = error reference
		;	CF = error flag
		; OUT:	if CY and input ax = pexterrFileNotFound,
		;	 ax = pexterrPathNotFound 
_chgErrorToPathNotFound:
	jnc _chgtoPathError_14				; if no error -->

	pushf						; save carry, status
	cmp ax, pexterrFileNotFound			; file not found ?
	jnz _chgtoPathError_12				; no, ignore change -->
	mov ax, pexterrPathNotFound			; else change error

_chgtoPathError_12:
	popf

_chgtoPathError_14:
	retn


		; Return Pointer to Caller's Stack Frame
		;
		; Output:
		; returns segment and offset on stack
		;
		; Usage:
		; call _RetCallersStackFrame
		; pop reg
		; pop seg
		;  (RXDMACRO.NEW provides the RetCallersStackFrame macro for this)
_retcallersstackframe:
_RetCallersStackFrame:

	push bp
	mov bp, sp
	push word [ bp + 2 ]				; create return stack space
	push word [ bp ]
	push bx

	mov bx, word [ ss:_RxDOS_CurrentInstance ]	; base address of current stack

	push word [ ss:bx + 2 ]
	pop word [ bp + 2 ]
	push word [ ss:bx ]
	pop word [ bp ]

	pop bx						; restore registers
	pop bp
	retn


		; Set FCB Error if Carry
		;
		; if carry, set AL to -1, else set AL to 0.
setFCBErrorIfCarry:

	pushf
	jnc setFCBErrorIfCarry_08			; if no error -->
	mov word [ ss:_RxDOS_pExtErrorCode ], ax	; save ptr to error code

setFCBErrorIfCarry_08:
	sbb ax, ax					; NC -> 0000; CY -> FFFF

	push ds
	push di
	RetCallersStackFrame ds, di
	mov byte [ di + _AX + _AL ], al

	pop di
	pop ds
	popf
	retn


		; 32 Bit Multiply
		;
		; Input:
		; dx:ax	numerator
		; cx	multiplier
_mul32: or dx, dx					; simple multiply ?
	jnz .12						; not really -->

	mul cx
	retn

.12:
	push bx
	mov bx, ax
	mov ax, dx
	mul cx						; result1 = highword_numerator*multiplier
	xchg ax, bx

	mul cx						; result2 = lowword_numerator*multiplier
	add dx, bx					; result3 = (result1 & 0FFFFh)*10000h + result2
	pop bx						; restore bx
	retn


		; 32 Bit Divide
		;
		; Input:
		; dx:ax	numerator
		; cx	divisor
		;
		; Output:
		; dx:ax	result
		; cx	remainder
		; cy	error: divide by zero
_div32:
	or cx, cx					; protect from zero divisor
	stc						; in case of error
	jz .return					; if so, just return with carry

	push bx
	mov bx, dx
	xchg ax, bx
	xor dx, dx
	div cx						; divide high order first
							; result1 = highword_numerator/divisor

	xchg ax, bx
	div cx						; REMAINDER WILL BE IN DX
							; result2 = (result1_remainder+lowword_numerator)/divisor

	mov cx, dx					; last remainder
	mov dx, bx					; full 32-bit answer
							; result3 = result1*10000h + result2
	or bx, ax					; or all 32-bits, set zr flag if zero
	pop bx

.return:
	retn


		; 32 Bit Compare
		; Returns flags for "cmp A, B"
		;
		; Input:
		; cx:dx	argument A
		; stack	argument B
		;
		; Output:
		; returns ZF, CF, SF
		;
		; Cleans the stack
_cmp32: Entry 2

	darg ArgumentB

	cmp cx, word [ bp + _ArgumentB + _high ]	; To set flags correctly, compare high word first
	jnz .Return					; Low word compare (higher precision) only required if
							;  high words were the same
	cmp dx, word [ bp + _ArgumentB + _low ]

.Return:
	return


		; Check if Keyboard Chars Available
		;
		; Returns:
		; ZR	none available
		; NZ	available
		;
		; AL	00 if none, -1 if available
		;
		; di destroyed
CheckKeyboardCharsAvailable:

	entry
	defbytes	reqBlock, sizeMaxReqHeader

	mov al, -1			; character device
	mov ah, NONDESTRREAD
	lea di, [ word bp + _reqBlock ]
	call initReqBlock

	mov ax, word [ _RxDOS_pCONdriver + _segment ]
	or ax, word [ _RxDOS_pCONdriver + _pointer ]
	jz checkKeybd_None		; if no CON driver -->
					;  (al is zero as well if this branches)

	push word [ _RxDOS_pCONdriver + _segment ]
	push word [ _RxDOS_pCONdriver + _pointer ]
	call CharDevRequest		; ask CON for character

	mov al, 00			; set character available
	test word [ bp + _reqBlock + ndrStatus ], OP_DONE
	jz checkKeybd_None		; if no character -->
	test word [ bp + _reqBlock + ndrStatus ], OP_BUSY
	jnz checkKeybd_None		; if no character -->

	dec al				; = -1, set character available

checkKeybd_None:
	or al, al
	return



		; Redirected Input
		;
		; Input:
		; ax	device handle
		;
		; Returns:
		; al	character from device
_RedirectedInput:

	entry
	def	handle, ax
	defbytes	tempbuffer, 8			 ; just need 2, but give a little.

	mov word [ bp + _tempbuffer ], 0		; just place a null in case of error

	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _redirectedInput_22				; if SFT not located -->


		; read from redirected file (SFT pointer at es:di)
	call updateAllChangedCCBBuffers

	mov cx, 0001					; bytes to read
	getarg ax, _handle				; 00 if stdin
	lea bx, [ word bp + _tempbuffer ]

	push ss						; buffer pointer + _segment
	push bx						; buffer pointer + _pointer
	call _SFTReadFile				; read using SFT (at es:di)

		; exit
_redirectedInput_22:
	xor ax, ax
	RetCallersStackFrame es, bx
	mov al, byte [ bp + _tempbuffer ]
	mov word [ es:bx + _AX ], ax
	return



		; Redirected Output
		;
		; Input:
		; ax	device handle
		; dl	character to display to standard output
_RedirectedOutput:

	entry
	defbytes	tempbuffer, 8			; just need 2, but give a little

	mov byte [ bp + _tempbuffer ], dl		; save character to display

	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _redirectedOutput_22				; if SFT not located -->


		; display to redirected file (SFT pointer at es:di)
	mov cx, 1					; bytes to write
	lea bx, [ word bp + _tempbuffer ]

	push ss						; buffer pointer + _segment
	push bx						; buffer pointer + _pointer
	call _SFTWriteFile				; write using SFT (at es:di)

		; exit
_redirectedOutput_22:
	return


		; Control-C check
		;
		; This function must be called before any value on the user
		; stack frame is modified!
		;
		; If Control-C is detected the current interrupt 21 is always
		; canceled and the registers of the original interrupt caller
		; are restored. Then Int23 is invoked. If it sets CY the program
		; is terminated. If it sets NC the interrupt call is restarted
		; and the program will continue.
CtrlC_Check:

	cmp byte [ ss:_RxDOS_bCtrlBreakCheck ], 00	; check for Control-C ?
	jnz CtrlC_CheckAlways				; if perform check -->
	clc						; don't terminate !
	retn						; return

		; Control-C check without checking BREAK setting first
CtrlC_CheckAlways:

	entry
	defbytes	reqBlock, sizeMaxReqHeader
	defbytes	tempBuffer, 8

	mpush ds, es, bx, ax, dx, cx, di

	xor bx, bx
	mov ds, bx

	test byte [ 471h ], 80h				; test Ctrl-Break flag
	jz CtrlC_Check12				; if not set -->
	and byte [ 471h ], ~ 80h			; clear Ctrl-Break flag

	setds ss
	mov al, -1					; character device
	mov ah, INPUTFLUSH
	lea di, [ word bp + _reqBlock ]
	call initReqBlock

	push word [ _RxDOS_pCONdriver + _segment ]
	push word [ _RxDOS_pCONdriver + _pointer ]
	call CharDevRequest				; flush all characters
	jmp short CtrlC_CheckCallBack			; call back current app -->

CtrlC_Check12:
	setds ss
	mov al, -1					; character device
	mov ah, NONDESTRREAD
	lea di, [ word bp + _reqBlock ]
	call initReqBlock

	mov dx, word [ _RxDOS_pCONdriver + _segment ]
	or dx, word [ _RxDOS_pCONdriver + _pointer ]
	jz CtrlC_Check18				; if no CON driver -->

	push word [ _RxDOS_pCONdriver + _segment ]
	push word [ _RxDOS_pCONdriver + _pointer ]
	call CharDevRequest				; test for character

	test word [ bp + _reqBlock + ndrStatus ], OP_DONE
	jz CtrlC_Check18				; if no character -->
	test word [ bp + _reqBlock + ndrStatus ], OP_BUSY
	jnz CtrlC_Check18				; if no character -->

	mov al, byte [ bp + _reqBlock + ndrCharRead]
	cmp al, ControlC				; is it Control-C ?
	jnz CtrlC_Check18

	setds ss
	lea dx, [ word _tempBuffer + bp ]
	mov word [ bp + _reqBlock + rwrBuffer + _segment ], ss
	mov word [ bp + _reqBlock + rwrBuffer + _pointer ], dx
	mov word [ bp + _reqBlock + rwrBytesReq ], 1
	mov byte [ bp + _reqBlock + rwrFunction ], DEVICEREAD

	push word [ _RxDOS_pCONdriver + _segment ]
	push word [ _RxDOS_pCONdriver + _pointer ]
	call CharDevRequest				; eat ^C character
	jmp short CtrlC_CheckCallBack			; call back current app -->


		; exit without terminate
CtrlC_Check18:
	clc						; clear carry

	mpop di, cx, dx, ax, bx, es, ds
	return


		; process Control-C
CtrlC_CheckCallBack:

	setes cs
	mov cx, 4
	mov bx, _RxDOS_ContrlC_Message			; "^C",13,10
	call writeConsoleOut

	cli
	mov bx, word [ _RxDOS_CurrentInstance ]		; base address of current user stack

	mov ax, word [ byte bx - 4 ]			; stack top
	mov word [ _RxDOS_CurrentStackTop ], ax		;  restore stack top from last Int21 entry
	mov ax, word [ byte bx - 6 ]			; current instance
	mov word [ _RxDOS_CurrentInstance ], ax		;  restore instance pointer from last Int21 entry
	mov ax, word [ byte bx - 8 ]			; INDOS flag
	mov word [ _RxDOS_INDOSFlag ], ax		;  Reset InDOS

	mov dx, word [ byte bx + 2 ]			; get ss for user's stack
	mov ax, word [ bx ]				; get sp for user's stack
	sub ax, byte sizeStackFrame			; adjusted stack pointer
	mov sp, ax
	mov ss, dx					; switch stacks
	sti						; restore interrupts
%if _DEBUG | 1
	nop
%endif

	pop ax						; restore registers
	pop bx
	pop cx
	pop dx

	pop si
	pop di
	pop bp

	pop ds
	pop es

%if 0
RxDOS 7.20N:
MS-DOS and DR-DOS behave very strange with Int23:
- If the handler returns with RETF and CY set, both DOS will
  terminate the current program.
- (MS-DOS) If the handler returns with IRET or RETF 2 (which
  both restore the stack like the interrupt should do) NC is
  assumed and the current program is not terminated.
- (DR-DOS) If the handler returns CY it'll adjust SP
  assuming that the handler returned with RETF. (I don't
  know if it will adjust (add sp,2) or restore SP. Probably
  it's a very bad idea to return with CY and RETF 2 in DR-DOS.)

  This is in the file DRDOS/cio.a86 and in fact it always uses the CF
  set by the interrupt. That is, direct CF if it returned using RETF
  or RETF 2, and the CF from the stack if IRET. Now, in EDR-DOS 7.01.08
  it will always check [SDASaveSP] and if SP doesn't match, it executes
  add sp, 2 to restore the stack.

  However, in the original DR-DOS 7.01 release's IBMDOS/CIO.A86, in the
  CY case it assumes that the return was with RETF and it will then
  always adjust the stack by add sp, 2 (even if that's wrong).

RxDOS 7.30+ will:
- assume that SP could be changed and the flags could be left
  on stack. SP is saved in another register across the Int23.
  (MS-DOS and others possible use the word [SDASaveSP] for
  that but for obvious reasons RxDOS won't use a fixed memory
  location.)
- use the strategy described above for MS-DOS. This one is
  in fact less dangerous because it won't screw up stacks.
  However, handlers that do stc, retf 2 will tell DOS it
  should restart the call instead of aborting the program.
  (Important is that the RxDOS <= 7.20N default Int23 handler
  does exactly this but is intended to abort the program.)

  Anyway most applications only set their own Int23 handler
  so they won't get terminated on Ctrl-C, so this should not
  be a big problem.
- hence use the returned CF state only if the Int23 handler
  returned with RETF.

The alternative function will just (always) restore SP from
BP and then use the returned CF state not comparing SP. This
behaves rather like DR-DOS but won't trash stacks when the
handler does stc, retf 2. (To use this, set the defined
CTRLC_MS_STRAT to zero.)

%endif

	numdef CTRLC_MS_STRAT

	push bp
	mov bp, sp
		; remembering SP is always done because application
		; Int23 handlers could use RETF alone
%ifn _CTRLC_MS_STRAT
	; clc						; If application's Int23 is only IRET
							;  we must prepare CF so'll see NC
		; (However flags should already contain NC. See sub ax instruction above.)
%endif
	int intCONTROLC					; invoke Int23

%if _CTRLC_MS_STRAT
	pushf						; remember CF state!
	cmp bp, sp					;  now compare these
%endif
	mov sp, bp					; (if it actually changed)
%if _CTRLC_MS_STRAT
	jne CtrlC_CheckCallBack_04			; it did change, use CF state -->
	popf						; stacked flags back
	clc						; force NC
	pushf						; and restore stack for using the same code
CtrlC_CheckCallBack_04:
	popf
%endif	; _CTRLC_MS_STRAT
	pop bp

	jnc CtrlC_CheckCallBack_08			; if not terminate -->

	mov ax, 4C00h
		; RxDOS 7.20N:	MS-DOS will return on Int21.4D if Ctrl-C was used. However it sets
		;		the byte [SDATerminatedByCtrlC] to FFh to tell the Ctrl-C state to
		;		the termination code. RxDOS 7.30+ must do this different. Possible
		;		a flag inside the PSP which is to be terminated?

CtrlC_CheckCallBack_08:
	jmp _Interrupt_21


		; DOS Functions


		; 01h Keyboard Input, displaying the character (uses StdIn and StdOut)
		;
		; Returns:
		; al	character from standard input
_KeyboardInput:
	mov ax, STDIN					; handle is stdin
	call _RedirectedInput				; byte saved in AL on return

	mov dl, al					; set to echo character
	mov ax, STDOUT					; handle
	jmp _RedirectedOutput


		; 02h Display character (uses StdOut)
		;
		; Usage:
		; dl	character to display to standard output
_DisplayOutput:
	mov ax, STDOUT					; handle
	jmp _RedirectedOutput


		; 03h Aux (Comm Port) Input
		;
		; Returns:
		; al	character read from standard aux
_AuxInput:
	mov ax, STDAUX
	jmp _RedirectedInput


		; 04h Aux (Comm Port) Output
		;
		; Returns:
		; dl	character written to standard aux
_AuxOutput:
	mov ax, STDAUX
	jmp _RedirectedOutput


		; 05h Prn (Printer) Output
		;
		; Returns:
		; dl	character written to standard printer
_PrinterOutput:
	mov ax, STDPRN
	jmp _RedirectedOutput


		; 06h Direct Console I/O
		;
		; Usage:
		; dl	= ff, read
		; 	= anything else, writes dl character
		;
		; Returns:
		; dl	character read or written

_DirectConsole:
	cmp dl, -1					; read ?
	jz _DirectConsoleInput				; yes -->

	mov ax, STDOUT					; else output char in dl
	jmp _RedirectedOutput				; to stdout -->


		; input
_DirectConsoleInput:
	mov ax, STDIN
	jmp _RedirectedInput


		; 07h Unfiltered Console Input No Echo
		;
		; Returns:
		; al	character from keyboard
_DirectConsoleInputNoEcho:
	mov ax, STDIN
	jmp _RedirectedInput


		; 08h Direct Console Input No Echo
		;
		; Returns:
		; al	character from keyboard
_ConsoleInputNoEcho:
	mov ax, STDIN
	jmp _RedirectedInput


		; 09h Display String
		;
		; Usage:
		; ds:dx	pointer to display string, terminated with '$' (36 / 24h)
_DisplayString:

	entry
	ddef	sftPointer
	ddef	buffer, es, dx

	mov ax, STDOUT					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _displayOutput_22				; if SFT not located -->
	stordarg _sftPointer, es, di			; save sft buffer pointer

		; display to redirected file
	mov al, '$'
	mov cx, -1
	les di, [ bp + _buffer ]
	repnz scasb					; compute length of string
	jnz _displayOutput_22				; strange, but exit if none -->

	neg cx
	sub cx, byte 2					; remove $ from output
	push word [ bp + _buffer + _segment ]
	push word [ bp + _buffer + _pointer ]

	getdarg es, di, _sftPointer			; get sft buffer pointer
	call _SFTWriteFile				; write using sft (at es:di)

		; exit
_displayOutput_22:
	return


		; 0Ah Get Buffered Keyboard Input
		;
		; Usage:
		; es:dx	pointer to a buffer
		; 	(lead byte contains max length)
_BufferedKeyboardInput:
	entry
	ddef	buffer, es, dx
	def	needsEcho, FALSE

	mov bx, dx
	xor ah, ah
	mov al, byte [ es:bx ]	; [ byte es:bx + bufMaxLength ]	; max requested
	or ax, ax					; any requested ?
	ifz _buffkbdInput_42				; if none, exit -->

	mov ax, STDIN					; handle is stdin
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _buffkbdInput_38				; if SFT not located -->

		; read from redirected file (SFT pointer at es:di)
	xor cx, cx
	xor dx, dx
	getdarg ds, bx, _buffer
	mov cl, byte [ bx ]	; [ byte bx + bufMaxLength ]	; max bytes
	mov dl, byte [ byte bx + bufActualLength ]	; echo bytes
	lea bx, [ word bx + bufData ]	 		; pointer to actual data

	test word [ es:di + sftDevInfo ], sftIsDevice
	jz _buffkbdInput_14				; if file -->

	call updateAllChangedCCBBuffers			; if stdin input, must flush buffers

	push word [ es:di + sftDCB + _segment ]
	push word [ es:di + sftDCB + _pointer ]
	mov es, word [ bp + _buffer + _segment ]	; return buffer segment
	mov di, bx					; buffer address
	call devCharReadLine				; read till cr or eof
	mov ax, cx
	jmp short _buffkbdInput_16

		; if read from file
_buffkbdInput_14:
	push ds						; buffer pointer + _segment
	push bx						; buffer pointer + _pointer
	call _SFTReadLine				; read using sft (at es:di)
	mov word [ bp + _needsEcho ], TRUE

_buffkbdInput_16:
	getdarg es, bx, _buffer
	mov byte [ byte es:bx + bufActualLength ], al	; actual bytes read
	cmp al, byte [ es:bx ]	; [ es:bx + bufMaxLength ]	; at maximum buffer ?
	jae _buffkbdInput_22				; yes -->

	add bx, ax
	mov byte [ byte es:bx + bufData ], 13		; add cr to end
	inc ax

		; echo line to stdout
_buffkbdInput_22:
	cmp word [ bp + _needsEcho ], byte FALSE
	jz _buffkbdInput_38				; if no echo -->

	push ax						; count
	mov ax, STDOUT					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	pop cx
	jc _buffkbdInput_38				; if SFT not located -->

	push word [ bp + _buffer + _segment ]
	mov bx, word [ bp + _buffer + _pointer ]
	lea bx, [ word bx + bufData ]			; pointer to actual data
	push bx
	call _SFTWriteFile				; write using sft (at es:di)

		; exit
_buffkbdInput_38:
	getdarg es, bx, _buffer
	mov al, byte [ byte es:bx + bufActualLength ]	; actual bytes read
	mov ah, 0

_buffkbdInput_42:
	return


		; 0Bh Check Keyboard Input
		;
		; Usage:
		; AL	= -1 if data available in STDIN
_CheckKeyboardInput:
	mov ax, STDIN					; handle is stdin
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)

	mov al, 0
	jc _checkkbdInput_22				; if SFT not located -->

	test word [ es:di + sftDevInfo ], sftIsDevice
	jz _checkkbdInput_22				; if not a keyboard device -->
	call CheckKeyboardCharsAvailable		; set if character is available

_checkkbdInput_22:
	RetCallersStackFrame es, bx
	mov byte [ es:bx + _AX + _AL ], al		; set chars available
	clc
	retn


		; 0Ch Clear buffered keyboard input
		;
		; Usage:
		; AL	function number
_ClearBufferedKeyboardInput:

	push es
	push dx
	push ax						; save service

	mov ax, STDIN					; handle is stdin
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _ClrBuf_16					; if sft not located -->

	test word [ es:di + sftDevInfo ], sftIsDevice
	jz _ClrBuf_16					; if not a keyboard device -->

		; see if characters are available
_ClrBuf_14:
	call CheckKeyboardCharsAvailable
	jz _ClrBuf_16

	mov ax, STDIN					; handle is stdin
	call _RedirectedInput				; read keyboard
	jmp short _ClrBuf_14				; loop until cleared buffer -->

		; dispatch to follow-up service
_ClrBuf_16:
	pop ax
	pop dx
	pop es						; restore registers

	cmp al, KeyboardInput
	ifz _KeyboardInput				; if function 01 -->
	cmp al, DirectConsole
	ifz _DirectConsole				; if function 06 -->
	cmp al, DirectConsoleInputNoEcho
	ifz _DirectConsoleInputNoEcho			; if function 07 -->
	cmp al, ConsoleInputNoEcho
	ifz _ConsoleInputNoEcho				; if function 08 -->
	cmp al, BufferedKeyboardInput
	ifz _BufferedKeyboardInput			; if function 0A -->

	jmp _Unused_al00				; else return zero


		; 0Dh Reset Disk
		;
		; Update disk buffers.
_DiskReset equ updateAllChangedCCBBuffers


		; 0Eh Select Disk
		;
		; Usage:
		; dl	select drive (0 = A:, 1 = B:, ... )
_SelectDisk:

	RetCallersStackFrame es, bx
	mov al, byte [ _RxDOS_bLastDrive ]		; max logical drives
	mov byte [ es:bx + _AX + _AL ], al		; return max.

	cmp dl, al					; greater than max drives ?
	jae _selectDisk_08				; yes, ignore change -->


	push dx
	xor ah, ah
	mov al, dl					; drive letter
	call getDPB					; see if valid drive
	pop dx						; restore disk select
	jc _selectDisk_08				; if invalid drive -->

	cmp word [ es:bx + _dpbptrDeviceDriver + _segment ], byte 0
	jz _selectDisk_08				; if invalid drive -->

	mov byte [ _RxDOS_CurrentDrive ], dl		; else change drive
	clc
	retn

_selectDisk_08:
	stc
	retn


		; 0Fh Open File with FCB
		;
		; ds:dx pointer to FCB
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_OpenFileFCB:

	entry
	def	openMode
	ddef	fcbPointer, es, dx
	defbytes	dirAccess, sizeDIRACCESS
	defbytes	expandedName, 128		; expanded file name (128 bytes)

		; convert FCB name to name usable by SFT Open
	mov si, dx					; source FCB address
	lea di, [ bp + _expandedName ]			; expand name
	saveRegisters es, si, ss, di			; arguments
	call convFCBNametoASCIZ				; build asciz name

		; does file exist ?
	setes ss					; es:
	mov ax, (FILE_ORDEVICE + FILECANNOT_BEDIRECTORY)
	lea si, [ bp + _expandedName ]			; es:dx filename
	lea di, [ bp + _dirAccess ]			; work dir access block
	call LocateFile					; if can't locate, then
	jc _OpenFileFCB_26				; if error -->

	mov al, DEFAULT_FCBOPENMODE			; mode is default open mode
	lea di, [ bp + _dirAccess ]			; work dir access block
	call _SFTOpenFile				; build an SFT
	jc _OpenFileFCB_26				; if error -->

	getdarg ds, si, _fcbPointer			; fcb address
	call initFCBfromSFT				; [ax] handle, [es:di] ptr to sft
	or ax, ax

		; return
_OpenFileFCB_26:
	call setFCBErrorIfCarry
	return


		; 10h Close FCB
		;
		; ds:dx pointer to FCB
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_CloseFileFCB:
	call findmatchingFCBSFT				; find matching SFT
	jc _CloseFileFCB_Error				; if can't locate, can't close -->

	call _SFTCloseFile
	or bx, bx

		; exit
_CloseFileFCB_Error:
	call setFCBErrorIfCarry
	return


		; 11h Search First File FCB
		;
		; ds:dx pointer to FCB or extended FCB
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_SearchFirstFileFCB:

	entry
	ddef	fcb, es, dx
	defbytes	findEntry, sizeFINDENTRY

		; build find entry
	lea di, [ word bp + _findEntry ]
	push es
	push dx
	push ss
	push di
	xor dx, dx					; begin at start of dir
	call buildFindFromFCB

	call LocateFileByAttribute			; locate item
	jc _SearchFirstFileFCB_20			; if not found -->

		; build a return entry in DTA
	push word [ bp + _fcb + _segment ]		; fcb address
	push word [ bp + _fcb + _pointer ]
	push es						; find block
	push di
	call buildDTAfcbFind

		; all set, return
_SearchFirstFileFCB_20:
	call setFCBErrorIfCarry
	return


		; 12h Search Next File FCB
		;
		; ds:dx pointer to FCB
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_SearchNextFileFCB:

	entry
	ddef	fcb, es, dx
	defbytes	findEntry, sizeFINDENTRY

		; build find entry
	lea di, [ word bp + _findEntry ]
	push es
	push dx
	push ss
	push di

	mov bx, dx
	mov dx, word [ es:bx + fcbCurrRecNo ]
	inc dx						; point to next entry
	call buildFindFromFCB

	call LocateFileByAttribute			; locate item
	jc _SearchNextFileFCB_08			; if none found -->

		; build a return entry in DTA
	push word [ bp + _fcb + _segment ]		; fcb address
	push word [ bp + _fcb + _pointer ]
	push es						; find block
	push di
	call buildDTAfcbFind

		; return
_SearchNextFileFCB_08:
	call setFCBErrorIfCarry
	return


		; 13h Delete File FCB
		;
		; ds:dx pointer to FCB, wild cards allowed
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_DeleteFileFCB:

	entry
	ddef	fcb, es, dx
	def	deleted, 0000
	defbytes	findEntry, sizeFINDENTRY

		; build find entry
	lea di, [ byte bp + _findEntry ]
	push es
	push dx
	push ss
	push di
	xor dx, dx					; begin at start of dir
	call buildFindFromFCB

		; keep looping until all matching are deleted
_deleteFileFCB_08:
	setes ss
	lea di, [ byte bp + _findEntry ]
	call LocateFileByAttribute			; locate item
	jc _deleteFileFCB_20

	mov si, word [ bp + _findEntry + findCCBPointer ]
	call locateCCBPHeader				; get buffer segment

	test byte [ es:si + deAttributes ], ATTR_READONLY
	jnz _deleteFileFCB_08

	xor ax, ax
	mov al, byte [ bp + _findEntry + findSrchDrive ]
	mov byte [ es:si ], DIRENTRY_DELETED

	mov cx, word [ es:si + deStartClusterExt ]	; push cluster address on stack
	mov dx, word [ es:si + deStartCluster ]
	call ReleaseClusterChain			; release cluster chain
	call CCBChanged					; release buffer at [es:di]

	inc word [ bp + _deleted ]			; say some items deleted
	jmp short _deleteFileFCB_08

		; return
_deleteFileFCB_20:
	cmp word [ bp + _deleted ], byte 0		; any deleted ?
	ja _deleteFileFCB_24				; yes -->
	stc						; if none found.

_deleteFileFCB_24:
	call setFCBErrorIfCarry
	return


		; 14h Read Sequential FCB
		;
		; ds:dx pointer to FCB
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_SeqReadFileFCB:

	entry
	def	readCount
	ddef	position
	ddef	fcbPointer, es, dx

		; ok to read if valid FCB
	mov di, dx
	mov cx, word [ es:di + fcbRecordSize ]
	mov word [ bp + _readCount ], cx		; bytes to read to DTA
	or cx, cx
	stc
	jz _SeqReadFileFCB_Return

		; compute byte offset from block/rec numbers
	mov ax, 128
	mul word [ es:di + fcbCurrBlockNo ]		; block number * 128
	add al, byte [ es:di + fcbCurrRecNo ]		; full 23 bit address
	mul cx						; actual byte offset
	stordarg _position, dx, ax

		; find corresponding SFT
	call findmatchingFCBSFT				; find matching SFT
	jc _SeqReadFileFCB_Return			; if no space -->

		; init disk access block
	getdarg cx, dx, _position			; restore position
	mov word [ es:di + sftFilePosition + _low ], dx
	mov word [ es:di + sftFilePosition + _high ], cx
	mov ax, -1					; ! stdin

	mov cx, word [ bp + _readCount ]		; bytes to read to dta
	push word [ _RxDOS_pDTA + _segment ]		; disk transfer address
	push word [ _RxDOS_pDTA + _pointer ]
	call _SFTReadFile				; read using SFT (at es:di)

		; compute return logical position
	getdarg es, di, _fcbPointer
	getdarg dx, ax, _position
	add ax, word [ es:di + fcbRecordSize ]
	adc dx, byte 0
	div word [ es:di + fcbRecordSize ]		; actual byte offset

	xor dx, dx
	mov cx, 128
	div cx
	mov byte [ es:di + fcbCurrRecNo ], dl
	mov word [ es:di + fcbCurrBlockNo ], ax
	or ax, ax

		; return
_SeqReadFileFCB_Return:
	call setFCBErrorIfCarry
	return


		; 15h Write Sequential FCB
		;
		; ds:dx pointer to FCB
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_SeqWriteFileFCB:

	entry
	def	writeCount
	ddef	position
	ddef	fcbPointer, es, dx

		; ok to write if valid fcb
	mov di, dx
	mov cx, word [ es:di + fcbRecordSize ]
	mov word [ _writeCount + bp ], cx		; bytes to write from dta
	or cx, cx					; if bytes are zero
	stc
	jz _SeqWriteFileFCB_Return

		; compute byte offset from block/rec nos
	mov ax, 128
	mul word [ es:fcbCurrBlockNo + di ]		; block # times 128
	add al, byte [ es:fcbCurrRecNo + di ]		; full 23 bit address
	mul cx						; actual byte offset
	stordarg _position, dx, ax

		; find corresponding sft
	call findmatchingFCBSFT				; find matching SFT
	jc _SeqWriteFileFCB_Return			; if no space -->

		; init disk access block
	getdarg cx, dx, _position			; restore position
	mov word [ es:sftFilePosition + _low + di ], dx
	mov word [ es:sftFilePosition + _high + di ], cx

	getarg cx, _writeCount				; bytes to write to dta
	push word [ _RxDOS_pDTA + _segment ]	 	; disk transfer address
	push word [ _RxDOS_pDTA + _pointer ]
	call _SFTWriteFile				; write using sft (at es:di )

		; compute return logical position
	getdarg es, di, _fcbPointer
	inc byte [ es:fcbCurrRecNo + di ]
	test byte [ es:fcbCurrRecNo + di ], 128
	jz _SeqWriteFileFCB_22
	inc word [ es:fcbCurrBlockNo + di ]

_SeqWriteFileFCB_22:
	and byte [ es:fcbCurrRecNo + di ], 127

		; return
_SeqWriteFileFCB_Return:
	call setFCBErrorIfCarry
	return


		; 16h Create File with FCB
		;
		; ds:dx pointer to FCB
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_CreateFileFCB:

	entry
	ddef	fcbPointer, es, dx
	defbytes	dirAccess, sizeDIRACCESS
	defbytes	expandedName, 128		; expanded file name (128 bytes )

		; convert FCB name to name usable by SFT Open
	mov si, dx					; source FCB address
	lea di, [ _expandedName + bp ]			; expand name
	saveRegisters es, si, ss, di			; arguments
	call convFCBNametoASCIZ				; build asciz name

		; try SFT Create
	setes ss
	lea si, [ _expandedName + bp ]			; expand name
	lea di, [ _dirAccess + bp ]			; work dir access block
	mov ax, DEFAULT_FCBOPENMODE
	call LocateFile
	jc _CreateFileFCB_26				; if error -->

	xor cx, cx					; expected attributes
	lea di, [ _dirAccess + bp ]			; work dir access block
	call _SFTCreateFile				; build an SFT
	jc _CreateFileFCB_26				; if error -->

	getdarg ds, si, _fcbPointer			; fcb address
	call initFCBfromSFT				; [ax] handle, [es:di] ptr to sft
	or ax, ax

		; return
_CreateFileFCB_26:
	call setFCBErrorIfCarry
	return


		; 17h Rename File FCB
		;
		; ds:dx pointer to FCB, wild cards allowed
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_RenameFileFCB:

	entry
	ddef	fcb, es, dx
	defbytes	expandedName, 128		; expanded file name (128 bytes)

		; build first name
	mov si, dx					; source FCB address
	lea di, [ bp + _expandedName ]			; expand name
	saveRegisters es, si, ss, di			; arguments
	call convFCBNametoASCIZ				; build asciz name

	push es
	push di						; unexpanded filename

	push ds
	mov di, SDAFirstName
	push di						; where to expand name
	mov ax, FILECANNOT_BEDIRECTORY
	call ExpandFileName				; expand first name

		; build second name
	getdarg es, si, _fcb				; source FCB address
	add si, byte 16					; point to second part of fcb
	lea di, [ bp + _expandedName ]			; expand name
	saveRegisters es, si, ss, di			; arguments
	call convFCBNametoASCIZ				; build asciz name

	push es
	push di						; unexpanded filename

	push ds
	mov di, SDASecondName
	push di						; where to expand name
	mov ax, FILECANNOT_BEDIRECTORY
	call ExpandFileName				; expand second name

		; Use IFS to rename
	IFS IFSRenameFile				; rename file

	call setFCBErrorIfCarry
	return


		; 19h Get current disk
		;
		; Return:
		; al = current disk
_CurrentDisk:

	RetCallersStackFrame es, bx
	mov al, byte [ _RxDOS_CurrentDrive ]
	mov byte [ es:bx + _AX + _AL ], al		; set max for return
	retn


		; 1Ah Set Disk Transfer Address
		;
		; ds:dx-> New DTA
		;
		; (see related function 2Fh - Get Disk Transfer Address)
_SetDiskTransferAddress:

	mov word [ _RxDOS_pDTA + _pointer ], dx
	mov word [ _RxDOS_pDTA + _segment ], es		; Int caller's ds is in es
	retn


		; 1Bh Get Default Drive Data
_GetDefaultDriveData:
	xor dx, dx					; set dx = 0 (current drive)

		; 1Ch Get Drive Data
		;
		; dl	drive
_GetDriveData:

	push ds						; save ds

	push dx						; (argument expected on stack)
	call GetActualDrive				; actual drive (in dx)
	jc _getDriveData_20				; if invalid drive -->

	call getDPB					; get pointer to DPB
	jc _getDriveData_20				; if invalid drive -->

	RetCallersStackFrame ds, si
	mov cx, word [ es:bx + _dpbBytesPerSector ]
	mov dx, word [ es:bx + _dpbMaxClusterNumber ]
	mov al, byte [ es:bx + _dpbClusterSizeMask ]
	inc al

	mov byte [ si + _AX + _AL ], al			; sectors/cluster
	mov word [ si + _CX ], cx			; bytes per sector
	mov word [ si + _DX ], dx			; clusters/drive

	lea di, [ word _dpbMediaDescriptor + bx ]
	mov word [ si + _BX ], di
	mov word [ si + _DS ], es			; where to find media byte
	or ax, ax					; clear carry

_getDriveData_20:
	jnc _getDriveData_22
	mov al, -1

_getDriveData_22:
	pop ds
	retn


		; 1Fh Get DOS Default Drive Device Parameter Block
		;
		; Input:
		; no parameters
		;
		; Returns:
		; ds:bx-> DOS device parameter block
		;
		; (see related function 32 - Get Dos Device Parameter Block)
_GetDefaultDriveParameterBlock:

	xor dx, dx					; select default drive
	jmp _GetDriveParameterBlock


		; 21h Read Sequential FCB
		;
		; ds:dx pointer to FCB
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_ReadFileFCB:

	entry
	def	readCount
	ddef	position
	ddef	fcbPointer, es, dx

		; ok to read if valid fcb
	mov di, dx
	mov cx, word [ es:di + fcbRecordSize ]
	mov word [ bp + _readCount ], cx		; bytes to read to dta
	or cx, cx
	stc
	jz _ReadFileFCB_Return

		; compute byte offset from block/rec nos
	mov ax, word [ es:di + fcbRandomRecNo + _low ]
	mov dx, word [ es:di + fcbRandomRecNo + _high ]
	mov cx, word [ es:di + fcbRecordSize ]
	call _mul32
	stordarg _position, dx, ax

		; find corresponding sft
	call findmatchingFCBSFT				; find matching SFT
	jc _ReadFileFCB_Return				; if no space -->

		; init disk access block
	getdarg cx, dx, _position			; restore position
	mov word [ es:di + sftFilePosition + _low ], dx
	mov word [ es:di + sftFilePosition + _high ], cx
	mov ax, -1					; ! stdin

	mov cx, word [ _readCount + bp ]		; bytes to read to dta
	push word [ _RxDOS_pDTA + _segment ]		; disk transfer address
	push word [ _RxDOS_pDTA + _pointer ]
	call _SFTReadFile				; read using sft (at es:di)

		; compute return logical position
	getdarg es, di, _fcbPointer
	mov ax, word [ es:di + fcbRandomRecNo + _low ]
	mov dx, word [ es:di + fcbRandomRecNo + _high ]
	mov cx, 128
	call _div32
	mov word [ es:di + fcbCurrBlockNo ], ax

	mov dl, byte [ es:di + fcbRandomRecNo + _low ]
	and dl, 127
	mov byte [ es:di + fcbCurrRecNo ], dl

		; return
_ReadFileFCB_Return:
	call setFCBErrorIfCarry
	return


		; 22h Write Sequential FCB
		;
		; ds:dx pointer to FCB
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_WriteFileFCB:

	entry
	def	writeCount
	ddef	position
	ddef	fcbPointer, es, dx

		; ok to Write if valid fcb
	mov di, dx
	mov cx, word [ es:di + fcbRecordSize ]
	mov word [ bp + _writeCount ], cx		; bytes to write to dta
	or cx, cx
	stc
	jz _WriteFileFCB_Return

		; compute byte offset from block/rec nos
	mov ax, word [ es:di + fcbRandomRecNo + _low ]
	mov dx, word [ es:di + fcbRandomRecNo + _high ]
	mov cx, word [ es:di + fcbRecordSize ]
	call _mul32
	stordarg _position, dx, ax

		; compute block/ sector
	mov ax, word [ es:di + fcbRandomRecNo + _low ]
	mov dx, word [ es:di + fcbRandomRecNo + _high ]
	mov cx, 128
	call _div32
	mov word [ es:di + fcbCurrBlockNo ], ax

	mov dl, byte [ es:di + fcbRandomRecNo + _low ]
	and dl, 127
	mov byte [ es:di + fcbCurrRecNo ], dl

		; find corresponding sft
	call findmatchingFCBSFT				; find matching SFT
	jc _WriteFileFCB_Return				; if no space -->

		; init disk access block
	getdarg cx, dx, _position			; restore position
	mov word [ es:di + sftFilePosition + _low ], dx
	mov word [ es:di + sftFilePosition + _high ], cx

	mov cx, word [ bp + _writeCount ]		; bytes to write to dta
	push word [ _RxDOS_pDTA + _segment ]		; disk transfer address
	push word [ _RxDOS_pDTA + _pointer ]
	call _SFTWriteFile				; write using sft (at es:di)

		; return
_WriteFileFCB_Return:
	call setFCBErrorIfCarry
	return


		; 23h Get File Size FCB
		;
		; ds:dx pointer to FCB
_FileSizeFCB:

	mov di, dx
	cmp word [ es:di + fcbRecordSize ], byte 0
	stc
	jz _FileSizeFCB_12

	mov ax, word [ es:di + fcbFileSize + _low ]
	mov dx, word [ es:di + fcbFileSize + _high ]
	mov cx, word [ es:di + fcbRecordSize ]
	call _div32					; ax:dx / cx

	mov word [ es:di + fcbRandomRecNo + _low ], ax
	mov word [ es:di + fcbRandomRecNo + _high ], dx
	or ax, ax

_FileSizeFCB_12:
	call setFCBErrorIfCarry
	retn


		; 24h Set Random Record Number FCB
		;
		; ds:dx pointer to FCB
_SetRelativeRecordFCB:

	mov di, dx
	mov ax, 128					; records/block
	mul word [ es:di + fcbCurrBlockNo ]		; block # times record address
	add al, byte [ es:di + fcbCurrRecNo ]		; full 23 bit address

	mov word [ es:di + fcbRandomRecNo + _low ], ax
	mov word [ es:di + fcbRandomRecNo + _high ], dx

	RetCallersStackFrame es, bx
	mov byte [ es:bx + _AX + _AL ], 00		; al always set to 00
	clc
	retn


		; 25h Set Interrupt Vector
		;
		; al = interrupt number
		; ds:dx-> interrupt routine address
		;
		; Actually uses es:dx as interrupt address
_SetInterruptVector:

	pushf						; save interrupts
	push ds
	push ax
	push bx
	push dx						; address to set
	push es						; user's ds is in es
	mov ah, 0
	mov bx, ax					; int vector to bx
	add bx, bx
	add bx, bx					; now [bx] is entry inside interrupt table
	cli

	xor ax, ax
	mov ds, ax
	pop word [ bx + 2 ]				; segment
	pop word [ bx ]					; address

	pop bx
	pop ax
	pop ds
	popf						; restore interrupts
	retn


		; 26h Create New Program Segment Prefix
		;
		; dx = segment address
		;
		; (see related function 55 - Duplicate PSP )
_CreateNewProgramSeg:

	mov es, dx					; new PSP segment address
	call copyCurrentPSP				; create a new PSP here
	retn


		; 27h Random Read FCB
		;
		; cx	number of blocks to read
		; ds:dx	pointer to FCB
		;
		; Return:
		; al = ff, if cannot locate any matching entry
		; 00, if match located
_RandomBlockReadFCB:

	entry
	def	error, 0
	def	readCount
	def	numBlocks, cx
	ddef	position
	ddef	fcbPointer, es, dx

		; ok to read if valid fcb
	mov di, dx
	mov cx, word [ es:di + fcbRecordSize ]
	mov word [ bp + _readCount ], cx		; bytes to read to dta
	or cx, cx
	stc
	jz _ReadBlockFCB_Return

		; compute byte offset from block/rec nos
	mov ax, word [ es:di + fcbRandomRecNo + _low ]
	mov dx, word [ es:di + fcbRandomRecNo + _high ]
	mov cx, word [ es:di + fcbRecordSize ]
	call _mul32
	stordarg _position, dx, ax

		; find corresponding sft
	call findmatchingFCBSFT				; find matching SFT
	jc _ReadBlockFCB_Return				; if no space -->

		; init disk access block
	getdarg cx, dx, _position			; restor position
	mov word [ es:di + sftFilePosition + _low ], dx
	mov word [ es:di + sftFilePosition + _high ], cx

	mov ax, word [ bp + _numBlocks ]		; number of blocks
	mul word [ bp + _readCount ]			; bytes to read to dta
	mov cx, ax					; total bytes to read
	or dx, dx					; over 64k ?
	jz _ReadBlockFCB_12				; if ok -->
	mov word [ bp + _error ], errFCBSizeTooLarge	; too large
	mov cx, 0FFFFh					; read as much as possible

_ReadBlockFCB_12:
	mov ax, -1					; ! stdin
	push word [ _RxDOS_pDTA + _segment ]		; disk transfer address
	push word [ _RxDOS_pDTA + _pointer ]
	call _SFTReadFile				; read using SFT (at es:di)

		; compute return logical position
	getdarg es, di, _fcbPointer
	getdarg dx, ax, _position
	add ax, word [ es:di + fcbRecordSize ]
	adc dx, byte 0
	div word [ es:di + fcbRecordSize ]		; actual byte offset

	xor dx, dx
	mov cx, 128
	div cx
	mov byte [ es:di + fcbCurrRecNo ], dl
	mov word [ es:di + fcbCurrBlockNo ], ax

	mov ax, word [ bp + _numBlocks ]		; number of blocks
	add word [ es:di + fcbRandomRecNo + _low ], ax
	adc word [ es:di + fcbRandomRecNo + _high ], byte 0

		; return
_ReadBlockFCB_Return:
	call setFCBErrorIfCarry
	return


		; 28h Random Write FCB
		;
		; cx = number of blocks to write
		; ds:dx-> FCB
		;
		; Return:
		; al = ff if error
_RandomBlockWriteFCB:

	entry
	def	error, 0
	def	writeCount
	def	numBlocks, cx
	ddef	position
	ddef	fcbPointer, es, dx

		; compute byte offset from block/rec numbers
	mov di, dx
	mov ax, word [ es:di + fcbRandomRecNo + _low ]
	mov dx, word [ es:di + fcbRandomRecNo + _high ]
	mov cx, word [ es:di + fcbRecordSize ]
	call _mul32
	stordarg _position, dx, ax

		; find corresponding sft
	call findmatchingFCBSFT				; find matching SFT
	jc _WriteBlockFCB_Return			; if no space -->

		; init disk access block
	getdarg cx, dx, _position			; restore position
	mov word [ es:di + sftFilePosition + _low ], dx
	mov word [ es:di + sftFilePosition + _high ], cx

	mov ax, word [ bp + _numBlocks ]		; number of blocks
	mul word [ bp + _writeCount ]			; bytes to write to DTA
	mov cx, ax					; total bytes to Write

	or dx, dx					; over 64 KiB ?
	jz _WriteBlockFCB_12				; if ok -->
	mov word [ bp + _error ], errFCBSizeTooLarge	; too large
	mov cx, 0FFFFh					; read as much as possible

_WriteBlockFCB_12:
	push word [ _RxDOS_pDTA + _segment ]		; disk transfer address
	push word [ _RxDOS_pDTA + _pointer ]
	call _SFTWriteFile				; write using SFT (at es:di )

		; compute return logical position
	getdarg es, di, _fcbPointer
	getdarg dx, ax, _position
	add ax, word [ es:fcbRecordSize + di ]
	adc dx, byte 0
	mov cx, word [ es:fcbRecordSize + di ]	; record size
	call _div32

	mov word [ es:fcbRandomRecNo + _low + di ], ax
	mov word [ es:fcbRandomRecNo + _high + di ], dx

	mov cx, 128
	call _div32					; divide by 128
	mov word [ es:fcbCurrBlockNo + di ], ax

	mov dx, word [ es:fcbRandomRecNo + _low + di ]
	and dl, 127
	mov byte [ es:fcbCurrRecNo + di ], dl

		; return
_WriteBlockFCB_Return:
	call setFCBErrorIfCarry
	return


		; 29h Parse Filename
		;
		; Usage:
		; ds:si	points to name to parse
		; es:di	points to uninitialized FCB
		; al	parse control
_ParseFilenameFCB:

	entry
	def	parseControl, ax
	def	wildChars, 0000
	ddef	FCBPointer

	RetCallersStackFrame ds, bx
	mov di, word [ _DI	 + bx ]
	mov es, word [ _ExtraSegment + bx ]
	mov si, word [ _SI	 + bx ]
	mov ds, word [ _DataSegment + bx ]
	stordarg _FCBPointer, es, di

		; initialize FCB
	test word [ _parseControl + bp ], FCBPARSE_LEAVEDRIVEUNCHANGED
	jnz _ParseFilenameFCB_08			; leave drive alone -->
	mov byte [ es:fcbDrive + di ], 00h		; clear drive info

_ParseFilenameFCB_08:
	test word [ _parseControl + bp ], FCBPARSE_LEAVEFILENAMEUNCHANGED
	jnz _ParseFilenameFCB_12			; leave filename alone -->

	getdarg es, di, _FCBPointer
	lea di, [ fcbName + di ]
	mov cx, sizefnName
	mov al, ' '
	rep stosb					; clear filename to blanks

_ParseFilenameFCB_12:
	test word [ _parseControl + bp ], FCBPARSE_LEAVEEXTENSIONUNCHANGED
	jnz _ParseFilenameFCB_14			; leave alone -->

	getdarg es, di, _FCBPointer
	lea di, [ fcbExtension + di ]
	mov cx, sizefnExtension
	mov al, ' '
	rep stosb					; clear filename to blanks

		; skip through any leading garb characters
_ParseFilenameFCB_14:
	lodsb						; get char
	cmp al, ' '					; space ?
	jz _ParseFilenameFCB_14			 ; skip leading white space -->
	ifc _ParseFilenameFCB_86			; if control char, exit -->

	call _ParseFilenameSeparator
	jnz _ParseFilenameFCB_36			; yes, see if skip allowed -->

	test word [ _parseControl + bp ], FCBPARSE_IGNORELEADSEPARATOR
	jnz _ParseFilenameFCB_14

		; test for valid drive
_ParseFilenameFCB_36:
	cmp byte [ si ], ':'			; drive follows ?
	jnz _ParseFilenameFCB_54			; no -->

	_lowerCase al					; convert to lower case
	sub al, 'a'					; range
	jge _ParseFilenameFCB_40			; if ok -->
	mov byte [ _wildChars + bp ], -1

_ParseFilenameFCB_40:
	mov byte [ es:fcbDrive + di ], al		; store drive info

	inc si						; skip over ':'
	lodsb						; get lead character of filename

		; filename
_ParseFilenameFCB_44:
	dec si						; position back at start of filename
	cmp byte [ si ], '.'			; extension follows ?
	jnz _ParseFilenameFCB_48			; no -->

	test word [ _parseControl + bp ], FCBPARSE_LEAVEFILENAMEUNCHANGED
	jnz _ParseFilenameFCB_64			; leave alone -->

_ParseFilenameFCB_48:
	mov al, ' '
	getdarg es, di, _FCBPointer
	lea di, [ fcbName + di ]
	mov cx, sizefnName

	push di
	push cx
	rep stosb					; clear filename to blanks

	pop cx
	pop di

_ParseFilenameFCB_50:
	cmp byte [ si ], '.'
	jz _ParseFilenameFCB_64			 ; extension follows

	lodsb
	call _ParseFilenameSeparator
	jz _ParseFilenameFCB_64

	cmp al, '*'
	jz _ParseFilenameFCB_58
	cmp al, '?'
	jnz _ParseFilenameFCB_52
	or byte [ _wildChars + bp ], 01h

_ParseFilenameFCB_52:
	_upperCase al					; upper case
	stosb						; save updated character
	loop _ParseFilenameFCB_50			; continue -->

		; continue to skip until '.' or end of field
_ParseFilenameFCB_54:
	cmp byte [ si ], '.'
	jz _ParseFilenameFCB_64			 ; extension follows

	lodsb						; skip rest until '.'
	call _ParseFilenameSeparator			; if end of field
	jz _ParseFilenameFCB_64
	jmp short _ParseFilenameFCB_54

		; '*' fill filename
_ParseFilenameFCB_58:
	or cx, cx
	jz _ParseFilenameFCB_64
	mov al, '?'
	rep stosb
	or byte [ _wildChars + bp ], 01h
	jmp short _ParseFilenameFCB_54			; make sure we loop for '.'

		; extension
_ParseFilenameFCB_64:
	cmp byte [ si ], '.'			; extension follows ?
	jz _ParseFilenameFCB_66			 ; yes -->

	test word [ _parseControl + bp ], FCBPARSE_LEAVEEXTENSIONUNCHANGED
	jnz _ParseFilenameFCB_86			; leave alone -->

_ParseFilenameFCB_66:
	mov al, ' '
	getdarg es, di, _FCBPointer
	lea di, [ fcbExtension + di ]
	mov cx, sizefnExtension

	push di
	push cx
	rep stosb					; clear filename to blanks

	pop cx
	pop di

	cmp byte [ si ], '.'
	jnz _ParseFilenameFCB_86			; if no extension follows -->

_ParseFilenameFCB_70:
	lodsb
	call _ParseFilenameSeparator
	jz _ParseFilenameFCB_86

	cmp al, '*'
	jz _ParseFilenameFCB_78
	cmp al, '?'
	jnz _ParseFilenameFCB_72
	or byte [ _wildChars + bp ], 01h

_ParseFilenameFCB_72:
	_upperCase al					; upper case
	stosb						; save updated character
	loop _ParseFilenameFCB_70			; continue -->

		; continue to skip until end of field
_ParseFilenameFCB_74:
	lodsb						; skip rest until '.'
	call _ParseFilenameSeparator			; if end of field
	jz _ParseFilenameFCB_86
	jmp short _ParseFilenameFCB_74

		; '*' fill filename
_ParseFilenameFCB_78:
	or cx, cx
	jz _ParseFilenameFCB_86
	mov al, '?'
	rep stosb
	or byte [ _wildChars + bp ], 01h
	jmp short _ParseFilenameFCB_74			; make sure we loop for '.'

		; end of parse
_ParseFilenameFCB_86:
	RetCallersStackFrame ds, bx
	mov word [ _SI + bx ], si

	mov al, byte [ _wildChars + bp ]
	mov byte [ _AX + _AL + bx ], al			; set wild character flag

	return

		; filename separator test
_ParseFilenameSeparator:

	cmp al, '+'					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, '='					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, ','					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, ';'					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, '/'					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, '['					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, ']'					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, '<'					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, '>'					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, '"'					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, '|'					; file name separator ?
	jz _ParseFnSeparator_08				; yes -->
	cmp al, ' '					; file name separator ?
	jge _ParseFnSeparator_08			; yes -->

	xor ax, ax					; space or control is treated as space

_ParseFnSeparator_08:
	retn


		; 2Ah Get Date
		;
		; Returns:
		; al = day of week ( 0 = Sun, 1 = Mon, ...)
		; cx = year (1980 - 2099)
		; dh = month (1 - 12)
		; dl = day (1 - 31)
_GetDate:

	call getExpandedDate

	push cx
	push dx
	call getSystemDateValue

	pop dx
	pop cx
	RetCallersStackFrame ds, si
	mov byte [ si + _AX + _AL ], al
	mov word [ si + _CX ], cx
	mov word [ si + _DX ], dx			; return parameters
	clc
	retn


		; 2Bh Set Date
		;
		; cx = year (1980 - 2099)
		; dh = month (1 - 12)
		; dl = day (1 - 31)
		;
		; Returns:
		; al = 00h, date valid, else al = 0FFh date invalid
_SetDate:

	entry
	defbytes	datedef, sizeCLOCKDATA

	or dh, dh
	jz _setdate_error
	or dl, dl
	jz _setdate_error
	cmp dh, 12 + 1
	jnc _setdate_error
	cmp dl, 31 + 1
	jnc _setdate_error

	cmp cx, 1980
	jb _setdate_error
	cmp cx, 2100
	jae _setdate_error

	push dx
	push cx
	setes ss
	lea di, [ word _datedef + bp ]
	call getSysDate					; get system date

	pop cx
	pop dx						; restore values
	mov byte [ _datedef + cl_day + bp ], dl
	mov byte [ _datedef + cl_month + bp ], dh
	mov word [ _datedef + cl_year + bp ], cx

	call getDaysSince1980
	mov word [ _datedef + cl_daysSince1980 + bp ], ax

	setes ss
	lea di, [ word _datedef + bp ]
	call setSysDate					; set system date

	xor ax, ax
	call setFCBErrorIfCarry				; no error, no carry
	return

		; problem with date
_setdate_error:
	stc
	call setFCBErrorIfCarry				; set carry
	return


		; 2Ch Get Time
		;
		; Returns:
		; ch = hour ( 0 - 23)
		; cl = minutes ( 0 - 59)
		; dh = seconds ( 0 - 59)
		; dl = hundredths ( 0 - 99)
_GetTime:

	call getExpandedDateTime			; get system date

	RetCallersStackFrame ds, si
	mov word [ _DX + si ], dx
	mov word [ _CX + si ], cx
	retn


		; 2Dh Set Time
		;
		; ch = hour ( 0 - 23)
		; cl = minutes ( 0 - 59)
		; dh = seconds ( 0 - 59)
		; dl = hundredths ( 0 - 99)
		;
		; Returns:
		; al = 00h, time valid, else al = 0FFh time invalid
_SetTime:

	entry
	defbytes	datedef, sizeCLOCKDATA

	cmp ch, 24
	jnc _settime_error
	cmp cl, 60
	jnc _settime_error
	cmp dh, 60
	jnc _settime_error
	cmp dl, 100
	jnc _settime_error

	push dx					 ; save time passed
	push cx

	setes ss
	lea di, [ word _datedef + bp ]
	call getSysDate				 ; get system date

	pop word [ _datedef + cl_minutes + bp ]
	pop word [ _datedef + cl_hseconds + bp ]
	call setSysDate				 ; set system date

	clc
	call setFCBErrorIfCarry			 ; no carry
	return

		; problem with time
_settime_error:
	stc
	call setFCBErrorIfCarry			 ; set carry
	return


		; 2E00h Reset DOS write with verify switch
		; 2E01h Set DOS write with verify switch
		;
		; (see related function 54h - Get DOS write with verify switch)
		;
		; RxDOS 7.20N:	MS-DOS preserves CF regardless of al. al&1 is used and returned.
_SetVerifySwitch:
	and al, 01h
	mov byte [ _RxDOS_Verify ], al
	jmp _Unused_al				; return CF unchanged and possible changed al


		; 2Fh Get Disk Transfer Area address
		;
		; Returns:
		; es:bx-> Disk Transfer Area address
		;
		; (see related function 1A - Set Disk Transfer Address)
_GetDiskTransferAddress:

	les bx, [ _RxDOS_pDTA ]

	RetCallersStackFrame ds, si
	mov word [ _ES + si ], es
	mov word [ _BX + si ], bx
	retn


		; 30h Get DOS Version
		;
		; Input:
		; al	00h return OEM version number in bh
		; 01h return version flag in bh
		;
		; Returns:
		; al	major version
		; ah	minor version
		; bl:cx user's serial number
		; bh	OEM identification number
		; 	or version flag
_GetDOSVersion:
	mov cx, word [ ss:_RxDOS_UserSerialNumber ]
	mov bx, word [ ss:_RxDOS_UserSerialNumber + 2 ]	; (_UserSerialNumber + 3) is _DOSOEMVersion

	cmp al, 1					; ROM version status ?
	jnz _GetDOSVersion_08				; no -->

	mov bh, byte [ ss:_RxDOS_DOSLocation ]

_GetDOSVersion_08:
	mov ax, word [ ss:_RxDOS_DOSVersion ]		; pre-DOS 5 (see 3306h)

	xchg bx, dx
	call getpsp					; get PSP
	xchg bx, dx
	jc _GetDOSVersion_12				; invalid -->

	mov es, dx					; current PSP
	mov ax, word [ es:pspVersion ]			; SETVER version (or same as DOSVersion)
_GetDOSVersion_12:


	or ax, ax					; zero ?
	jnz _GetDOSVersion_16				; no -->
	mov ax, RXDOS_MS_VERSION			; means to use true reported version
_GetDOSVersion_16:

	RetCallersStackFrame ds, si
	mov word [ _AX + si ], ax
	mov word [ _BX + si ], bx
	mov word [ _CX + si ], cx
	clc
	retn


		; 31h Terminate but stay resident
		;
		; INP:	al = return value
		;	dx = memory size to keep (in paragraphs)
_TerminateStayResident:

	entry
	def	parentPSP, 0
	ddef	returnVector

	mov ah, TERMINATE_TSR
	mov word [ _RxDOS_ChildReturnCode ], ax		; save return status code

		; fix size of current PSP block
	mov es, word [ _RxDOS_CurrentPSP ]
	mov bx, dx					; keep size
	call _modifyMemBlock				; fix size

		; see if there is a parent process
	mov es, word [ ss:_RxDOS_CurrentPSP ]
	mov dx, word [ es:pspParentId ]			; get parent PSP
	storarg _parentPSP, dx				; save for later

	mov word [ es:pspParentId ], 0000		; kill parent for next time.
	or dx, dx					; no parent ?
	jz _TerminateStayResident_20			; can't terminate -->

		; restore interrupts
	cli
	push ds
	xor ax, ax
	mov ds, ax
	mov es, word [ ss:_RxDOS_CurrentPSP ]

	mov ax, word [ es:pspTerminateVect + _pointer ]
	mov dx, word [ es:pspTerminateVect + _segment ]
	stordarg _returnVector, dx, ax

	mov bx, ( intCONTROLC * 4 )			; Int23 control-C vector
	mov ax, word [ es:pspControlCVect + _pointer ]
	mov dx, word [ es:pspControlCVect + _segment ]
	mov word [ _pointer + bx ], ax
	mov word [ _segment + bx ], dx

	mov bx, ( intCRITICALERROR * 4 )		; Int24 criterror vector
	mov ax, word [ es:pspCritErrorVect + _pointer ]
	mov dx, word [ es:pspCritErrorVect + _segment ]
	mov word [ _pointer + bx ], ax
	mov word [ _segment + bx ], dx

	pop ds
	sti

		; return to parent process
	getarg es, _parentPSP				; get PSP
	mov word [ ss:_RxDOS_CurrentPSP ], es		; restore

	mov dx, word [ es:pspUserStack + _segment ]
	mov ax, word [ es:pspUserStack + _pointer ]	; parent user's stack

	mov bx, word [ ss:_RxDOS_CurrentInstance ]	; base address of current stack
	mov word [ ss:_segment + bx ], dx
	mov word [ ss:_pointer + bx ], ax

	RetCallersStackFrame es, bx
	getdarg dx, ax, _returnVector
	mov word [ es:_CS + bx ], dx
	mov word [ es:_IP + bx ], ax

_TerminateStayResident_20:
	return


		; 32h Get DOS Device Parameter Block
		;
		; Input:
		; dl	0= default,
		; 	1= a:, 2 = b:, ...
		;
		; Returns:
		; al	0ffh if invalid drive
		; ds:bx	returns pointer to dos device parameter block
		;
		; (see related function 1F - Get Default Drive DPB )
_GetDriveParameterBlock:

	push dx
	call GetActualDrive				; actual drive (in ax)
	jnc _GetDriveParameterBlock_08			; if valid drive -->
	call setFCBErrorIfCarry				; else set error
	retn

_GetDriveParameterBlock_08:
	mov cx, sizeDPB
	mul cx						; create DPB offset

	les bx, [ ss:_RxDOS_pDPB ]
	add bx, ax

	RetCallersStackFrame ds, si
	mov word [ _DS + si ], es
	mov word [ _BX + si ], bx
	retn

		; 33h Extended Ctrl-C flag, boot drive, DOS version, extensions
		; al = subfunction,
		;  00h = Get extended Ctrl-C flag
		;  01h = Set extended Ctrl-C flag
		;  03h = Unknown
		;  05h = Get boot drive
		;  06h = Get DOS Version
		;  07h = Unknown
		; (RxDOS extension) 5Eh = Get extended DOS version
		; (RxDOS extension) 5Fh = Get boot drive and filename
		; (RxDOS extension) 60h = Get DOS capabilities
		; (DOS-C extension) FCh = Set returned DOS version (get with Int21.30)
		; (DOS-C extension) FDh = Toggle disk access debug dump flag*
		; (DOS-C extension) FEh = Toggle DOS system call debug dump flag*
		; (DOS-C extension) FFh = Get zero-terminated DOS version string
		;
		; Unsupported functions return FCB error (al = 0FFh).
		;
		; RxDOS 7.20N:	Functions 03h, 07h and >= 5Eh aren't supported by RxDOS <= 7.20N.
		;
		; * Function is only supported in special debugging versions.
_CtrlBreakCheck:
	RetCallersStackFrame ds, si

	Gotos GetControlC,	.getctrlc
	Gotos SetControlC,	.setctrlc
	Gotos 02h,		.getsetctrlc
	Gotos 03h,		.unknown		; Get CPSW (Code Page Switching) flag
	Gotos 04h,		.unknown		; Set CPSW flag
	Gotos GetStartupDrive,	.getbootdrive
	Gotos GetExtDosVersion,	.gettrueversion
	Gotos 07h,		.unknown		; Set bit5 of DOS_FLAG
	Gotos 5Eh,		.getextendedversion
	Gotos 5Fh,		.getbootname
	Gotos 60h,		.capabilities
	Gotos 0FCh,		.setversion		; DOS-C
	Gotos 0FFh,		.getversionstring	; DOS-C

	stc
	call setFCBErrorIfCarry				; Sets FCB error (al = 0FFh)

.unknown:
	retn


		; Set extended Ctrl-C flag
.setctrlc:
	mov dl, byte [ si + _DX + _DL ]
	call .setctrlc_dl
							; fall through
							;  (MS-DOS handles it exactly that way)
		; Get extended Ctrl-C flag
.getctrlc:
	mov dl, byte [ ss:_RxDOS_bCtrlBreakCheck ]
	mov byte [ si + _DX + _DL ], dl
	retn

		; Get and set extended Ctrl-C flag
.getsetctrlc:
	push word [ si + _DX ]
	call .getctrlc
	pop dx

.setctrlc_dl:
	and dl, 01h					; NC
	mov byte [ ss:_RxDOS_bCtrlBreakCheck ], dl
	retn

		; Get boot drive
.getbootdrive:
	mov dl, byte [ ss:_RxDOS_BootDrive ]
	mov byte [ si + _DX + _DL ], dl
	retn


		; Get true DOS version
.gettrueversion:
	mov word [ si + _BX ], RXDOS_MS_TRUEVERSION
	mov byte [ si + _DX + _DL ], RXDOS_MS_REVISION
	mov dh, byte [ ss:_RxDOS_DOSLocation ]
	mov byte [ si + _DX + _DH ], dh
	retn

.getextendedversion:
		; ax = 7852h ("Rx")
		; cx:dx = Build, >>16 == year, >>8&0FFh == month, &0FFh == day
		; bx = RxDOS version
		; di = RxBIO compatibility level
		;
		; Both versions hold a binary major version in the high byte (displayed as decimal
		; digit without padding) and a binary minor version in the low byte (displayed as
		; decimal digit with padding to two digits). 0701h == "7.01", 140Ah == "20.10"

	mov word [ si + _AX ], "Rx"			; 7852h
	mov word [ si + _CX ], 2018
	mov word [ si + _DX ], 04<<8|03			; cx:dx = build (2018-04-03)
	mov word [ si + _BX ], RXDOS_VERP		; bx = version
	mov word [ si + _DI ], RXDOS_VERP
		; RxBIO compatibility level (can no longer differ)
	retn

.capabilities:
		; ax = DOS capability flags (refer to RXDSTRUC.NEW)
		; bh = bytes per SFT entry
		; bl = bytes per CDS entry
		; dh = bytes per DPB
		; dl = reserved
		; cx = reserved
	mov word [ si + _AX ], DOSCAP_FAT32 | DOSCAP_REENTRANT
	mov word [ si + _CX ], 0
	mov word [ si + _DX ], sizeDPB<<8|0
	mov word [ si + _BX ], sizeSFT<<8|sizeCDS
	retn

.setversion:
	mov word [ ss:_RxDOS_DOSVersion ], bx
	retn

.getversionstring:
	mov word [ si + _DX ], ss
	mov word [ si + _AX ], _RxDOS_DOSVersionString
	retn

.getbootname:
	mov word [ si + _DX ], ss
	mov word [ si + _AX ], bootname
	retn


		; 34h Get InDOS Flag Address
		;
		; Returns:
		; es:bx-> InDOS flag
_GetInDOSFlagAddress:
	RetCallersStackFrame ds, bx

	mov word [ byte bx + _BX ], _RxDOS_INDOSFlag
	mov word [ byte bx + _ES ], ss
	retn


		; 35h Get Interrupt Vector
		;
		; al	interrupt number
		; es:bx	interrupt routine address
_GetInterruptVector:
	pushf						; save interrupts
	mov ah, 0
	mov si, ax
	add si, si
	add si, si

	cli
	xor ax, ax
	mov ds, ax
	mov es, word [ si + 2 ]				; segment
	mov bx, word [ si ]				; pointer

	RetCallersStackFrame ds, si
	mov word [ si + _BX ], bx
	mov word [ si + _ES ], es

	popf						; restore interrupts
	retn


		; 36h Get Free Disk Space
		;
		; Input:
		; dl	drive (A:=1, ...)
		;
		; Output:
		; ax	sectors per cluster
		; bx	number of free clusters
		; cx	bytes per sector
		; dx	clusters on drive
		;
		; (See also Int21.7303 - Extended Free Space)
_GetFreeDiskSpace:

	RetCallersStackFrame es, bx
	mov word [ es:bx + _AX ], -1			; in case of error, -1

	push dx
	call GetActualDrive				; actual drive (in dx)
	jc _getFreeDiskSpace_20				; arg returend in ax

	call AmountFreeSpace				; get amount free space

	RetCallersStackFrame ds, si
	mov cx, word [ es:bx + _dpbFreeCount + _low ]
	mov word [ _BX + si ], cx			; # free clusters

	mov cx, word [ es:bx + _dpbBytesPerSector ]
	mov dx, word [ es:bx + _dpbMaxClusterNumber ]

	mov al, byte [ es:_dpbClusterSizeMask + bx ]
	cbw
	inc ax

	mov word [ _AX + si ], ax			; sectors/ cluster
	mov word [ _CX + si ], cx			; bytes per sector
	mov word [ _DX + si ], dx			; clusters/ drive
	clc

_getFreeDiskSpace_20:
	retn


		; 3700h Get switch character
		; 3701h Set switch character
		;
		; dl	switch character
		;
		; Obsoleted. This function isn't supported in MS-DOS 5.00+
		; and returns always '/' on Get Switch Char. (Anyway RxDOS
		; still supports it.)
_GetSetSwitchChar:
	cmp al, 01h
	jb _GetSetSwitchChar_Get
	je _GetSetSwitchChar_Set
	seterror 0FFFFh
	retn

_GetSetSwitchChar_Get:
	mov dl, byte [ _RxDOS_bSwitchChar ]
	RetCallersStackFrame es, bx
	mov byte [ es:bx + _DX + _DL ], dl		; return value
	retn

_GetSetSwitchChar_Set:
	mov byte [ _RxDOS_bSwitchChar ], dl
	retn

		; 38h Country dependent info
		;
		; ds:dx-> points to country info buffer
		; 
		; al = country code if not 00h or 0FFh
		; al = 00h to get current country's info
		; al = 0FFh,
		;  bx = country code
		;
		; dx = FFFFh to set country code
_CountryDependentInfo:

%if 1
	cmp dx, byte -1					; set or return country code ?
	jz _SetCountryInfo				; if set country info -->

		; get country info
	mov di, dx					; destination address
	mov si, _RxDOS_CurrCountryInfo			; current country info
	mov cx, sizeCOUNTRYINFO				; size
	repz movsb					; copy

	RetCallersStackFrame es, bx
	mov ax, word [ _RxDOS_UserCountryCode ]
	mov word [ es:bx + _BX ], ax			; CC returned in BX
	mov byte [ es:bx + _AX + _AL ], al		; ... and AL
	cmp ax, 254
	jc _GetCountryInfo_08
	mov byte [ es:bx + _AX + _AL ], -1		; ... and AL

_GetCountryInfo_08:
	clc
	retn

		; set country info
_SetCountryInfo:
	cmp al, -1					; country < 254 ?
	jz _SetCountryInfo_08				; no -->
	mov bx, ax
	xor bh, bh					; country code to bx

_SetCountryInfo_08:
	mov word [ _RxDOS_UserCountryCode ], bx		; should check values
	clc
	retn
%else
	cmp dx, byte -1					; set country code ?
	jz _SetCountryInfo				; yes -->

		; get country info
	call _parsecountrycode
	jz _GetCountryInfo_04				; 0 means current -->
	cmp ax, word [ _RxDOS_UserCountryCode ]		; current ?
	je _GetCountryInfo_04				; yes -->

	call _GetCountryInfo_10				; set framed bx to current
	seterror pexterrInvalidFunction
	retn

_GetCountryInfo_04:
	mov si, _RxDOS_CurrCountryInfo			; current country info
	mov cx, sizeCOUNTRYINFO				; size
	repz movsb					; copy

_GetCountryInfo_10:
	mov ax, word [ _RxDOS_UserCountryCode ]
	RetCallersStackFrame ds, bx
	mov word [ bx + _BX ], ax			; code returned in bx
	mov word [ bx + _AX ], ax			; and also in ax
	clc
	retn

		; set country info
_SetCountryInfo:
	call _parsecountrycode
	jnz _SetCountryInfo_08
	seterror pexterrInvalidFunction			; trying to set code 0000h
	retn

_SetCountryInfo_08:
	mov word [ _RxDOS_UserCountryCode ], ax		; should check values
	clc
	retn

		; INP:	al, bx as for Int21.38
		; OUT:	ax = actual value
		;	ZR if ax = 0 (ax still 0!)
		; CHG:	-
_parsecountrycode:
	mov ah, 0
	cmp al, 0FFh					; 0FFh special code ?
	jne _parsecountrycode_02			; no, use value of al -->
	mov ax, bx					; else use value of bx (required for >=00FFh)
_parsecountrycode_02:
	cmp ax, byte 0
	retn
%endif

		; 39h Create Subdirectory
		;
		; ds:dx pointer to subdirectory
_CreateSubdirectory:

	entry
	ddef	pathname, es, dx			; arg passed internally as es:dx
	ddef	dirAddress				; dir reference
	ddef	alloccluster				; allocated cluster
	ddef	datetime
	defbytes	dirAccess, sizeDIRACCESS

		; does entry already exist ?
	mov ax, (FILE_NODEVICENAME + FILEHAS_NOFILENAME + FILECANNOT_BEDEFINED)
	getdarg es, si, _pathname			; arg passed internally as es:dx
	lea di, [ word _dirAccess + bp ]			; work dir access block
	call LocateFile					; check file path
	jnc _MakeSubDir_12				; if path is valid -->

	call _chgErrorToPathNotFound			; if name referenced path
	jmp _MakeSubDir_40				; if path invalid -->

		; find next empty directory entry
_MakeSubDir_12:
	and word [ _dirAccess + fileAcDrive + bp ], 7FFFh

	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	mov dx, word [ _dirAccess + fileAcDirCluster + _low + bp ]
	mov cx, word [ _dirAccess + fileAcDirCluster + _high + bp ]
	call LocateFreeDirSlot				; valid empty entry ?
	ifc _MakeSubDir_40				; if can't find free slot -->

	push si
	call locateCCBPHeader				; get ccb header into es:di
	or byte [ es:ccbStatus + di ], ccb_isONHOLD

	pop di						; convert name to dir style
	stordarg _dirAddress, es, di			; address of empty loc found
	clearMemory sizeDIRENTRY			; init to zeroes

	lea si, [ word _dirAccess + bp ]
	mov si, word [ fileAcNameOffset + si ]
	call convFilenametoFCBString			; dir style name

	call getSysDateinDirFormat
	stordarg _datetime, dx, ax			; make sure we get these

		; Allocate cluster for sub-directory
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	call AllocateInitCluster			; init/ allocate
	stordarg _alloccluster, cx, dx			; save cluster
	ifc _MakeSubDir_40				; if error -->

		; init (.) entry
	lea si, [ word ccbData + di ]			; point to data
	call blankinitDirName				; initialize file name
	mov byte [ es:deName + si ], '.'		; set dot entry

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
	mov word [ es:deName + si ], '..'		; set double dot entry

	mov dx, word [ _dirAccess + fileAcDirCluster + _low + bp ]
	mov cx, word [ _dirAccess + fileAcDirCluster + _high + bp ]
	mov word [ es:deStartCluster + si ], dx
	mov word [ es:deStartClusterExt + si ], cx

	getdarg dx, ax, _datetime			; get date time
	mov word [ es:deTime + si ], ax			; time created
	mov word [ es:deDate + si ], dx			; date created
	mov byte [ es:deAttributes + si ], ATTR_DIRECTORY

	call CCBChanged					; mark changes made
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	; call updateDriveBuffers

		; in parent directory, build entry
	getdarg cx, dx, _alloccluster
	getdarg es, si, _dirAddress			; restore si pointer
	mov word [ es:deStartCluster + si ], dx
	mov word [ es:deStartClusterExt + si ], cx
	mov byte [ es:deAttributes + si ], ATTR_DIRECTORY

	getdarg dx, ax, _datetime			; get date time

	mov word [ es:deTime + si ], ax			; time created
	mov word [ es:deDate + si ], dx			; date created

	call locateCCBPHeader				; get ccb header into es:di
	call CCBChanged					; mark changes made
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	; call updateDriveBuffers

	xor ax, ax					; clear carry

		; normal exit
_MakeSubDir_40:
	return

		; 3Ah Remove Subdirectory
		;
		; ds:dx pointer to subdirectory
_RemoveSubdirectory:

	entry
	ddef	cluster
	ddef	pathname, es, dx			; arg passed internally as es:dx
	defbytes	dirAccess, sizeDIRACCESS
	defbytes	diskAccess, sizeDISKACCESS
	defbytes	tempfilename, sizeShortZFILENAME

		; parse file name
	mov ax, (FILE_NODEVICENAME + FILEHAS_NOFILENAME)
	getdarg es, si, _pathname			; arg passed internally as es:dx
	lea di, [ _dirAccess + bp ]			; work dir access block
	call LocateFile					; check file path
	stordarg _cluster, cx, dx			; save cluster address
	jnc _RemoveSubDir_12				; if path valid -->

	call _chgErrorToPathNotFound			; if name referenced path
	jmp _RemoveSubDir_40				; if path invalid -->

		; trying to remove current directory ?
_RemoveSubDir_12:
	call getCurrDirCluster				; get cluster of curr directory

	sub dx, word [ _cluster + _low + bp ]
	sbb cx, word [ _cluster + _high + bp ]		; compare
	or cx, dx					; same directory as current ?
	jnz _RemoveSubDir_16				; dir is ok -->
	SetError pexterrCurrentDirectory, _RemoveSubDir_40

		; see if directory is empty (contains other than . and .. )
_RemoveSubDir_16:
	setes ds
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	mov dx, word [ _dirAccess + fileAcCluster + _low + bp ]
	mov cx, word [ _dirAccess + fileAcCluster + _high + bp ]
	lea bx, [ _diskAccess + bp ]			; pointer to access block
	call initdiskAccess				; [ax] is drive, [dx] is cluster

		; scan directory sectors
	mov word [ _diskAccess + diskAcOptions + bp ], (ccb_isDIR)
	mov word [ _diskAccess + diskAcPosition + _low + bp ], sizeDIRENTRY

_RemoveSubDir_22:
	add word [ _diskAccess + diskAcPosition + _low + bp ], byte sizeDIRENTRY
	adc word [ _diskAccess + diskAcPosition + _high + bp ], byte 0
	lea bx, [ _diskAccess + bp ]			; pointer to access block
	call _FATReadRandom				; read into buffer
	jz _RemoveSubDir_32				; if no more data, ok to delete -->

	cmp byte [ es:bx ], DIRENTRY_NEVERUSED
	jz _RemoveSubDir_32				; if no more data, ok to delete -->
	cmp byte [ es:bx ], DIRENTRY_DELETED		; entry deleted ?
	jz _RemoveSubDir_22				; yes, keep searching -->

	SetError pexterrIllegalName, _RemoveSubDir_40

		; ok to remove this entry.
_RemoveSubDir_32:
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	mov cx, word [ _dirAccess + fileAcCluster + _high + bp ]
	mov dx, word [ _dirAccess + fileAcCluster + _low + bp ]
	call ReleaseClusterChain

	les di, [ _dirAccess + fileAcBufferPtr + bp ]
	mov bx, word [ _dirAccess + fileAcDirOffset + bp ]

	mov byte [ es:di + bx ], DIRENTRY_DELETED
	call CCBChanged
	mov ax, word [ _dirAccess + fileAcDrive + bp ]
	call updateDriveBuffers
	clc						; return no error

		; normal exit
_RemoveSubDir_40:
	return


		; 3Bh Change Subdirectory
		;
		; ds:dx pointer to subdirectory
_ChangeSubdirectory:

	entry
	def	drive
	ddef	pathname, es, dx			; arg passed internally as es:dx
	defbytes	dirAccess, sizeDIRACCESS

		; parse file name
	mov ax, (FILE_NODEVICENAME + FILEHAS_NOFILENAME)
	getdarg es, si, _pathname			; arg passed internally as es:dx
	lea di, [ _dirAccess + bp ]			; work dir access block
	call LocateFile					; check file path
	jnc _ChgSubDir_12				; if path valid -->

	call _chgErrorToPathNotFound			; if name referenced path
	jmp _ChgSubDir_40				; if path invalid -->

		; copy path to CDS table.
_ChgSubDir_12:
	push ds						; save current segment
	getdarg es, si, _pathname			; arg passed internally as es:dx
	call getDrive
	storarg _drive, ax

	setDS ss					; copy from stack
	les di, [ _RxDOS_pLFNCDS ]			; get address of LFNCDS
	mov cx, sizeLFNCDS
	mul cx						; ax contains current drive
	add di, ax					;
	mov byte [ es:_lfncdsLongDirectory + di ], 0
	mov word [ es:_lfncdsLength + di ], 0

	les di, [ _RxDOS_pCDS ]				; actual address in CDS
	mov ax, sizeCDS
	mul byte [ _drive + bp ]
	add di, ax					; from
	push di

	lea si, [ _dirAccess + fileAcExpandedName + bp ]
	lea di, [ word _cdsActualDirectory + di ]

_ChgSubDir_22:
	lodsb						; copy buffer
	stosb
	or al, al
	jnz _ChgSubDir_22

	pop di						; restore CDS pointer
	mov cx, word [ _dirAccess + fileAcCluster + _high + bp ]	; work dir access block
	mov dx, word [ _dirAccess + fileAcCluster + _low + bp ]
	mov word [ es:_cdsStartClusterDir + _low + di ], dx
	mov word [ es:_cdsStartClusterDir + _high + di ], cx

	pop ds						; restore ds
	clc						; no error

		; normal exit
_ChgSubDir_40:
	return


		; 3Ch Create File
		;
		; cx	attributes
		; ds:dx pointer to filename (path included)
_CreateFile:

	entry
	def	attributes, cx
	ddef	filename, es, dx
	defbytes	dirAccess, sizeDIRACCESS
	call VerifyAvailableHandle			; see if handle available
	jc _CreateFile_42				; exit if none -->

	getdarg es, si, _filename
	lea di, [ _dirAccess + bp ]			; work dir access block
	mov ax, (FILE_NODEVICENAME + FILEMAY_EXIST + FILECANNOT_BEDIRECTORY)
	call LocateFile
	jc _CreateFile_42				; exit if fail -->

	getarg cx, _attributes
	lea di, [ bp + _dirAccess ]			; work dir access block
	call _SFTCreateFile
	jc _CreateFile_42				; exit if error -->

	call MapSFTToAppHandle				; if no space, create error

_CreateFile_42:
	RetCallersStackFrame ds, si
	mov word [ si + _AX ], ax			; return handle or error code
	return


		; 3dh Open File
		;
		; al	open mode
		; ds:dx pointer to filename( path included )
_OpenFile:

	entry
	def	mode, ax
	ddef	filename, es, dx
	defbytes	dirAccess, sizeDIRACCESS
	call VerifyAvailableHandle			; see if handle available
	jc _OpenFile_42					; exit if none -->

	getdarg es, si, _filename
	lea di, [ bp + _dirAccess ]			; work dir access block
	mov ax, (FILE_ORDEVICE + FILECANNOT_BEDIRECTORY)
	call LocateFile					; if can't locate, then
	jc _OpenFile_42					; exit if none -->

	getarg ax, _mode
	lea di, [ _dirAccess + bp ]			; work dir access block
	call _SFTOpenFile				; build an SFT
	jc _OpenFile_42					; exit if none -->

	call MapSFTToAppHandle				; record SFT handle into JHT

_OpenFile_42:
	RetCallersStackFrame ds, si
	mov word [ si + _AX ], ax			; return handle or error code
	return


		; 3Eh Close File
		;
		; bx handle to open file
_CloseFile:

	entry
	def	handle, bx
	ddef	sftPointer
	defbytes	diskAccess, sizeDISKACCESS

	mov ax, bx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _CloseFile_error				; if could not find -->

	call _SFTCloseFile				; close SFT Entry
	jc _CloseFile_error				; if error -->

	call getHandleTable				; get handle table
	add bx, word [ bp + _handle ]
	mov byte [ es:bx ], -1				; cancel handle reference in PSP's handle table

	or bx, bx					; no carry

_CloseFile_error:
	return


		; 3Fh Read File
		;
		; bx	handle
		; cx	max bytes to read
		; ds:dx buffer address
_ReadFile:

	entry
	def	handle, bx
	def	readCount, cx
	ddef	sftPointer
	ddef	bufPtr, es, dx				; save buffer pointer

	getarg ax, _handle				; get file handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	stordarg _sftPointer, es, di			; save SFT address
	jc _ReadFile_Return				; if could not find -->

	push word [ bp + _bufPtr + _segment ]
	push word [ bp + _bufPtr + _pointer ]
	getarg cx, _readCount				; bytes to read
	getarg ax, _handle
	call _SFTReadFile				; read using sft (at es:di)

_ReadFile_Return:
	RetCallersStackFrame ds, bx
	mov word [ bx + _AX ], ax
	return


		; 40h Write File
		;
		; bx	handle
		; cx	bytes to write
		; ds:dx buffer address
_WriteFile:

	entry
	def	handle, bx
	def	writeCount, cx
	ddef	sftPointer
	ddef	bufPtr, es, dx				; save buffer pointer

	mov ax, bx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	stordarg _sftPointer, es, di			; save SFT buffer pointer
	jc _WriteFile_error				; if could not find -->

	push word [ bp + _bufPtr + _segment ]
	push word [ bp + _bufPtr + _pointer ]
	getarg cx, _writeCount				; bytes to write
	call _SFTWriteFile				; write using sft (at es:di)

_WriteFile_error:
	RetCallersStackFrame ds, bx
	mov word [ bx + _AX ], ax
	return


		; 41h Delete File
		;
		; ds:dx-> ASCIZ name of file to delete (no wild characters)
_DeleteFile:

	entry
	ddef	filename, es, dx			; arg passed internally as es:dx
	defbytes	dirAccess, sizeDIRACCESS

		; parse file name
	mov si, dx					; name from caller
	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDIRECTORY)
	lea di, [ bp + _dirAccess ]			; work dir access block
	call LocateFile
	jc _DeleteFile_18				; if file/path valid -->

		; mark found entry in directory as deleted
	les di, [ bp + _dirAccess + fileAcBufferPtr ]
	mov bx, word [ bp + _dirAccess + fileAcDirOffset ]
	mov byte [ es:di + bx ], DIRENTRY_DELETED
	call CCBChanged

	mov ax, word [ bp + _dirAccess + fileAcDrive ]
	mov cx, word [ bp + _dirAccess + fileAcCluster + _high ]
	mov dx, word [ bp + _dirAccess + fileAcCluster + _low ]
	call ReleaseClusterChain

	mov ax, word [ bp + _dirAccess + fileAcDrive ]
	call updateDriveBuffers
	or ax, ax					; return no error

_DeleteFile_18:
	return


		; 42h Lseek (Move) file pointer
		;
		; al	move method
		; bx	handle
		; cx:dx	distance to move pointer
_MoveFilePointer:

	entry
	def	method, ax
	def	handle, bx
	ddef	moveDistance, cx, dx
	ddef	newPosition

	mov ax, bx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _moveFilePointer_36				; if could not find -->

	getdarg cx, dx, _moveDistance
	mov ax, word [ bp + _method ]
	Goto SEEK_BEG,	_moveFilePointer_beg
	Goto SEEK_CUR,	_moveFilePointer_cur
	Goto SEEK_END,	_moveFilePointer_end
	SetError -1,	_moveFilePointer_36

		; seek from end
_moveFilePointer_end:
	add dx, word [ es:di + sftFileSize + _low ]
	adc cx, word [ es:di + sftFileSize + _high ]
	jmp short _moveFilePointer_beg

		; seek from current position
_moveFilePointer_cur:
	add dx, word [ es:di + sftFilePosition + _low ]
	adc cx, word [ es:di + sftFilePosition + _high ]
	; jmp short _moveFilePointer_beg

		; seek from beginning
_moveFilePointer_beg:
	mov word [ es:di + sftFilePosition + _low ], dx
	mov word [ es:di + sftFilePosition + _high ], cx
	clc						; no error

		; Return
_moveFilePointer_36:
	RetCallersStackFrame ds, bx
	mov word [ bx + _AX ], dx
	mov word [ bx + _DX ], cx
	return


		; 43h Get/Set File Attributes
		;
		; ds:dx	file name
		; al	get/set flag
		; cx	attributes
_ChangeFileMode:

	entry
	def	mode, ax				; get/set flag.
	def	attributes, cx				; attributes, if change.
	ddef	filename, es, dx			; arg passed internally as es:dx
	defbytes	dirAccess, sizeDIRACCESS

		; parse file name
	mov si, dx					; name from caller
	mov ax, (FILE_NODEVICENAME)
	lea di, [ bp + _dirAccess ]			; work dir access block
	call LocateFile					; locate file
	jc _ChangeFileMode_18				; if file/path valid -->

		; if found, either get or set the attribute
	les di, [ bp + _dirAccess + fileAcBufferPtr ]
	mov bx, word [ bp + _dirAccess + fileAcDirOffset ]

	mov al, byte [ bp + _mode ]
	Goto 00, _ChangeFileMode_GetAttrib		; get
	Goto 01, _ChangeFileMode_SetAttrib		; set

	SetError pexterrInvalidFunction, _ChangeFileMode_18 ; else -->

		; if get file attributes
_ChangeFileMode_GetAttrib:
	RetCallersStackFrame ds, si
	mov cx, ATTR_DIRECTORY
	mov ax, es
	or ax, ax					; if no dir entry,
	jz _ChangeFileMode_GetAttrib_08			; then it must be root dir ->
	mov cl, byte [ es:di + bx + deAttributes ]

_ChangeFileMode_GetAttrib_08:
	mov word [ si + _CX ], cx
	return

		; if set file attributes
_ChangeFileMode_SetAttrib:
	mov ax, es
	or ax, ax					; root dir ?
	jnz _ChangeFileMode_SetAttrib_08		; anything but root -->
	seterror pexterrPathNotFound, _ChangeFileMode_18

_ChangeFileMode_SetAttrib_08:
	mov cx, word [ _attributes + bp ]
	test cx, ~ ATTR_SETTABLE
	jz _ChangeFileMode_12
	SetError pexterrAccessDenied, _ChangeFileMode_18

_ChangeFileMode_12:
	mov al, byte [ es:deAttributes + di + bx ]
	and al, ATTR_SETTABLE
	cmp al, cl
	jz _ChangeFileMode_16				; if no change -->

	and byte [ es:deAttributes + di + bx ], ~ ATTR_SETTABLE
	or byte [ es:deAttributes + di + bx ], cl
	call CCBChanged					; update changed buffer

_ChangeFileMode_16:
	clc

_ChangeFileMode_18:
	return


		; 44h IO Control
		;
		; Input:
		; al	subfunction
		; bx	file handle
		;
		; Output:
		; dx	depends on function
_IoControl:

	entry
	def	drive
	def	handle, bx
	def	count, cx
	ddef	bufPtr, es, dx

	Goto 00h,	_IoControl_GetDeviceData
	Goto 01h,	_IoControl_SetDeviceData
	Goto 02h,	_IoControl_CharDev_ReadControlData
	Goto 03h,	_IoControl_CharDev_WriteControlData

	Goto 08h,	_IoControl_CheckDeviceRemovableMedia
	Goto 09h,	_IoControl_IsDriveRemote
	Goto 0Ah,	_IoControl_GetSFTAttribs
	Goto 0Dh,	_IoControl_GenericIOControl
	Goto 0Eh,	_IoControl_GetLogicalDriveMap

_IoControl_NotSupported:
	mov ax, pexterrInvalidFunction
	stc
	return

		; 4400 - Get Device Data
_IoControl_GetDeviceData:
	mov ax, bx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _IoControl_GetDevData_12			; if error -->

	mov dx, word [ es:sftDevInfo + di ]
	RetCallersStackFrame ds, bx
	mov word [ _DX + bx ], dx
	clc

_IoControl_GetDevData_12:
	return

		; 4401 - Set Device Data
_IoControl_SetDeviceData:
	mov ax, bx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _IoControl_SetDevData_12			; if error -->

	RetCallersStackFrame ds, bx
	mov dx, word [ bx + _DX ]			; get device data bits
	mov word [ es:di + sftDevInfo ], dx		; set data bits
	clc

_IoControl_SetDevData_12:
	return

		; 4402 - Read Control Data
_IoControl_CharDev_ReadControlData:
	mov ax, bx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _IoControl_ReadCharData_22			; if error -->

	test word [ es:di + sftDevInfo ], sftIsDevice
	jnz _IoControl_ReadCharData_14			; if device -->
	SetError pexterrAccessDenied, _IoControl_ReadCharData_22

_IoControl_ReadCharData_14:
	push word [ es:di + sftDCB + _segment ]		; device driver address
	push word [ es:di + sftDCB + _pointer ]
	getarg cx, _count				; count
	getdarg es, di, _bufPtr				; buffer pointer
	call devCharRead				; read data
	mov ax, cx					; characters actually read
	clc						; remove carry

_IoControl_ReadCharData_22:
	RetCallersStackFrame ds, bx
	mov word [ bx + _AX ], ax
	return

		; 4403 - Write Control Data
_IoControl_CharDev_WriteControlData:
	mov ax, bx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _IoControl_WriteCharData_12			; if error -->

	push word [ bp + _bufPtr + _segment ]
	push word [ bp + _bufPtr + _pointer ]
	getarg cx, _count				; bytes to write
	call _SFTWriteFile				; Write using sft (at es:di )

_IoControl_WriteCharData_12:
	RetCallersStackFrame ds, bx
	mov word [ bx + _AX ], ax
	return

		; 4408 - Is Drive Remote
_IoControl_CheckDeviceRemovableMedia:
	call _IoControl_SelectDrive			; get valid drive
	jc _IoControl_CheckRemovable_12		 ; if invalid -->
	call DevRemovableRequest			; determine if removable

	RetCallersStackFrame es, si
	mov word [ es:_AX + si ], cx		; resturn removable status

_IoControl_CheckRemovable_12:
	return

		; 4409 - Is Drive Remote
_IoControl_IsDriveRemote:
	call _IoControl_SelectDrive			; get valid drive
	jc _IoControl_IsDriveRemote_08			; if invalid -->

	les bx, [ es:_dpbptrDeviceDriver + bx ]
	mov dx, word [ es:devAttributes + bx ]

	RetCallersStackFrame es, si
	mov word [ es:_DX + si ], dx		; we don't support anything

_IoControl_IsDriveRemote_08:
	return

		; 440A - Get SFT Attributes Word
_IoControl_GetSFTAttribs:
	mov ax, bx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)

	mov ax, pexterrInvalidHandle		; if invalid handle
	jc _IoControl_GetSFTAttribs_08			; if could not find -->

	mov dx, word [ es:sftDevInfo + di ]	; else get dev info

	RetCallersStackFrame ds, bx
	mov word [ _DX + bx ], dx			; attribute word

_IoControl_GetSFTAttribs_08:
	return

		; 440D - Generic IOControl
_IoControl_GenericIOControl:

	cmp cl, 60h					; fct minor code
	ifnz _IoControl_NotSupported			; if fct not supported -->

_IoControl_GetDeviceParameters:
	def	DeviceAttribs, 0000
	def	DeviceType, DEVICETYPE_FIXEDDISK
	defbytes	reqBlock, sizeMaxReqHeader

	call _IoControl_SelectDrive			; es:bx is DPB address
	jc _IoControl_GetDevPar_22			; if error or wrong dev -->
	storarg _drive, ax				; save drive

	mov ah, BUILDBPB
	lea di, [ word _reqBlock + bp ]
	call initReqBlock				; initialize

	getarg ax, _drive				; restore drive
	call BlockedDevRequest				; call blocked device
	jc _IoControl_GetDevPar_22			; if error or wrong dev -->

	RetCallersStackFrame ds, bx
	mov di, word [ _DX + bx ]			; get ptr to return buffer
	mov es, word [ _DS + bx ]			; get segment

	getarg ax, _drive				; restore drive
	cmp ax, byte 2			; we should have a better mechanism to handle this
	jae _IoControl_GetDevPar_16			; if not a floppy -->

	storarg _DeviceType, DEVICETYPE_144FLOPPY
	storarg _DeviceAttribs, 3

	xor bx, bx					; segment
	mov ds, bx
	mov ds, word [ 40Eh ]				; BIOS Extended information
							; 0040:000E == 0000:040E
	mov cl, byte [ 00E7h ]				; get drive type bits
							; 00E7 inside EBDA!

	or ax, ax					; drive A: ?
	jz _IoControl_GetDevPar_14

	shr cl, 1					; copy drive B: type to bit 0

_IoControl_GetDevPar_14:
	test cl, 1
	jz _IoControl_GetDevPar_16
	storarg _DeviceType, DEVICETYPE_FLOPPY

_IoControl_GetDevPar_16:
	lds si, [ _reqBlock + bbrBPBAddress + bp ]

	getarg cx, _DeviceType
	mov byte [ es:di + devparmDeviceType ], cl

	getarg cx, _DeviceAttribs
	mov word [ es:di + devparmDeviceAttribs ], cx
	mov byte [ es:di + devparmMediaType ], 0

	mov dx, word [ si + _dskCylinders - _dskBPB ]
	mov word [ es:di + devparmNumCylinders ], dx

	lea di, [ word di + devparmBPB ]		; BPB
	mov cx, 25					; size devparmBPB
	repe movsb
	clc

_IoControl_GetDevPar_22:
	return

		; 440E - Get Logical Drive Map
_IoControl_GetLogicalDriveMap:
	RetCallersStackFrame ds, bx
	mov word [ _AX + bx ], 00h			; always return 0
	return


		; IoControl Select Drive
		;
		; Input:
		; bx	drive (00 is current)
		;
		; Output:
		; bx	valid drive (A:=1, B:=2, ...)
		; ax	adj drive (A:=0, B:=1, ...)
		; 	if invalid drive, error message
		; cy	set if invalid drive
_IoControl_SelectDrive:

	push bx
	call GetActualDrive				; actual drive (in ax)
	jc _IoControl_SelectDrive_12			; if not valid -->

	call getAddrDPB					; see if valid
	jnc _IoControl_SelectDrive_12
	mov ax, pexterrInvalidDrive

_IoControl_SelectDrive_12:
	retn


		; 45h Duplicate File Handle
		;
		; Input:
		; bx	existing (old) handle
		;
		; Output:
		; ax	new handle
_DuplicateFileHandle:

	mov es, word [ _RxDOS_CurrentPSP ]
	mov cx, word [ es:pspFileHandleCount ]
	mov dx, cx					; save original count
	cmp bx, cx					; illegal reference ?
	jb _duplFileHandle_12				; if valid ->

_duplFileHandle_InvHandleError:
	seterror pexterrInvalidHandle, _duplFileHandle_Return ; if illegal -->

_duplFileHandle_12:
	les di, [ es:pspFileHandlePtr ]
	mov bl, byte [ es:di + bx ]			; get SFT handle from current
	cmp bl, -1					; unused entry ?
	jz _duplFileHandle_InvHandleError		; if error -->

		; is there an available entry ?
	mov al, -1
	repne scasb					; scan for empty slot
	jne _duplFileHandle_InvHandleError		; if error -->

	sub dx, cx					; get count
	dec dx
	push dx
	mov byte [ es:di - 1 ], bl			; duplicate handle

	xor ax, ax
	mov al, bl					; old handle
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	inc word [ es:di + sftRefCount ]		; bump in use count

	pop ax						; new handle
	clc

		; if error, exit with error code.
_duplFileHandle_Return:
	RetCallersStackFrame ds, bx
	mov word [ _AX + bx ], ax
	retn


		; 46h Force File Handle Duplicate
		;
		; Input:
		; bx	existing open handle
		; cx	duplicate handle
		;
		; Output:
		; ax	new handle
_ForceFileHandle:


		; Close duplicate handle if it is open
	push bx						; save regs
	push cx

	mov ax, cx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _ForceFileHandle_10				; if could not find -->

	call _SFTCloseFile				; close SFT Entry

		; Duplicate Handle
_ForceFileHandle_10:
	pop cx						; restore regs
	pop bx

	mov es, word [ _RxDOS_CurrentPSP ]
	les di, [ es:pspFileHandlePtr ]
	cmp bx, word [ es:pspFileHandleCount ]
	jnc _ForceFileHandle_InvHandleError		; if error value -->
	cmp cx, word [ es:pspFileHandleCount ]
	jnc _ForceFileHandle_InvHandleError		; if error value -->

	xor ah, ah
	mov al, byte [ es:di + bx ]			; SFT handle for duplicate
	xchg cx, bx
	mov byte [ es:di + bx ], al			; duplicate handle

	call FindSFTbyHandle				; get corresponding SFT (es:di)
	inc word [ es:di + sftRefCount ]		; bump in use count
	or ax, ax					; no carry
	retn

_ForceFileHandle_InvHandleError:
	mov ax, pexterrInvalidHandle		; invalid handle
	stc
	retn


		; 47h Get Current Directory
		;
		; dl	drive number
		; ds:si	pointer to max 64 byte user memory area
_GetCurrentDirectory:

	push dx
	call GetActualDrive				; actual drive (in ax)
	jnc getCurrDir_14				; if no error -->

	RetCallersStackFrame ds, bx
	mov word [ _AX + bx ], ax			; else save error code
	retn						; return

getCurrDir_14:
	mov cl, sizeCDS
	mul cl						; ax contains offset to current drive

	lds si, [ _RxDOS_pCDS ]				; actual address in CDS
	add si, ax					; from

	mov ax, _cdsActualDirectory			; proper offset
	add al, byte [ _cdsNonSubstOffset + si ]
	add si, ax

	push ds
	RetCallersStackFrame ds, bx
	mov es, word [ _DataSegment + bx ]
	mov di, word [ _SI + bx ]
	pop ds

getCurrDir_22:
	lodsb						; copy buffer
	stosb
	or al, al
	jnz getCurrDir_22

	clc
	retn						; ds:si will be returned.

		; 48h Allocate Memory

		; bx	number of paragraphs of memory requested

		; Returns:
		; ax	segment address of allocated memory block
		; bx	size of largest block of memory available in
		;	paragraphs, if allocation fails.

_AllocateMemory:

	entry
	def	allocation, bx

	call _allocateUpperMB				; allocate upper mem blocks
	jnc _AllocateMemory_12				; if allocation made -->

	getarg bx, _allocation
	call _allocateConvMB				; allocate lower mem blocks

_AllocateMemory_12:
	RetCallersStackFrame ds, si
	mov word [ _AX + si ], ax			; error or segment allocation
	jnc _AllocateMemory_16				; if not error -->

	mov word [ _BX + si ], dx			; largest block

_AllocateMemory_16:
	return


		; 49h Free Allocated Memory
		;
		; es	paragraph to free
_FreeAllocatedMemory:

	RetCallersStackFrame es, bx
	mov bx, word [ es:_ExtraSegment + bx ]
	dec bx						; preceding seg contains block
	mov es, bx

		; is this a valid memory block ?
	cmp byte [ es:_memSignature ], _RxDOS_MEMSIGNATURE
	je _freeallocateMemory_12
	cmp byte [ es:_memSignature ], _RxDOS_ENDSIGNATURE
	je _freeallocateMemory_12

		; invalid block
	RetCallersStackFrame es, bx
	mov word [ es:_AX + bx ], pexterrInvalidBlock
	stc
	ret

		; block is valid, free it
_freeallocateMemory_12:
	xor ax, ax
	mov word [ es:_memParent ], ax		; free memory block
	; call _collectMemoryBlocks			; save space
	; or ax, ax					; no carry
		; DOS should not collect MBs after freeing. This breaks
		; some software which directly modifies MCBs because the
		; software may think the MCB still exist there.
	retn


		; 4ah Modify Allocated Memory
		;
		; es	paragraph to free
		; bx	new paragraph size
_ModifyAllocatedMemory:

	RetCallersStackFrame es, si
	mov es, word [ es:si + _ExtraSegment ]
	jmp _modifyMemBlock


		; 4Bxxh Load and Execute Program
		;
		; ds:dx	program name
		; es:bx	program arguments
_ExecuteProgram:

	entry
	ddef	filename, es, dx			; arg passed internally as es:dx
	defbytes	dirAccess, sizeDIRACCESS

		; lookup
	mov si, dx					; name from caller
	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDIRECTORY)
	lea di, [ _dirAccess + bp ]			; work dir access block
	call LocateFile					; locate file
	jc ExecuteProgram_18				; if file/path invalid -->

		; execute
	push ds
	RetCallersStackFrame ds, si
	mov ax, word [ _AX + si ]			; get ax (mode)
	mov bx, word [ _BX + si ]			; get es:bx from caller
	mov es, word [ _ES + si ]
	pop ds

	lea di, [ _dirAccess + bp ]			; work dir access block
	call loadProgram

ExecuteProgram_18:
	return


		; 00h Terminate Process
		;
		; Return value (errorlevel) forced to 0
_TerminateProcess_00:
	xor ax, ax

		; 4Ch Terminate Process
		;
		; INP:	al = return value (errorlevel)
_TerminateProcess:

	entry
	def	parentPSP, 0000
	ddef	returnVector

	setds ss
	setes ss
	mov ah, TERMINATE_NORMAL
	mov word [ _RxDOS_ChildReturnCode ], ax		; save return status code
	inc word [ _RxDOS_AbortInProgress ]		; skip critical error if already in here

		; see if there is a parent process
	xor ax, ax
	mov es, ax
	mov bx, ( intTERMINATEAPP * 4 )			; Int22 terminate app
	mov ax, word [ es:bx + _pointer ]
	mov dx, word [ es:bx + _segment ]
	stordarg _returnVector, dx, ax			; default terminate address

	mov es, word [ ss:_RxDOS_CurrentPSP ]
	mov bx, word [ es:pspParentId ]			; get parent PSP
	storarg _parentPSP, bx				; save for later

	or bx, bx					; no parent ?
	jz _TerminateProcess_20				; can't terminate -->

		; restore interrupts/return to parent PSP
	push ds
	xor ax, ax
	mov ds, ax

	mov bx, ( intTERMINATEAPP * 4 )			; Int22 terminate app
	mov ax, word [ es:pspTerminateVect + _pointer ]
	mov dx, word [ es:pspTerminateVect + _segment ]
	mov word [ bx ], ax				; _pointer
	mov word [ bx +2 ], dx				; _segment

	stordarg _returnVector, dx, ax			; actual terminate address

	mov bx, ( intCONTROLC * 4 )			; Int23 Control-C vector
	mov ax, word [ es:pspControlCVect + _pointer ]
	mov dx, word [ es:pspControlCVect + _segment ]
	mov word [ bx ], ax				; _pointer
	mov word [ bx +2 ], dx				; _segment

	mov bx, ( intCRITICALERROR * 4 )		; Int24 criterror vector
	mov ax, word [ es:pspCritErrorVect + _pointer ]
	mov dx, word [ es:pspCritErrorVect + _segment ]
	mov word [ bx ], ax				; _pointer
	mov word [ bx +2 ], dx				; _segment

	pop ds

	getarg ax, _parentPSP
	cmp ax, word [ ss:_RxDOS_CurrentPSP ]		; is its own parent ?
	je _TerminateProcess_16				; yes, don't free memory or release files -->

		; free allocated memory and release files
	call _SFTCloseAllFiles				; close/commit all files
	call LFNReleaseFindData				; release find SFTs

	mov bx, word [ ss:_RxDOS_CurrentPSP ]
	call _releaseOwnerMemoryBlocks			; release memory
	call _collectMemoryBlocks			; collect free blocks

_TerminateProcess_16:
		; return to parent process
	getarg es, _parentPSP				; get PSP
	mov word [ ss:_RxDOS_CurrentPSP ], es		; restore

	mov ax, word [ es:pspUserStack + _pointer ]	; parent user's stack
	mov dx, word [ es:pspUserStack + _segment ]

	mov bx, word [ ss:_RxDOS_CurrentInstance ]	; base address of current stack
	mov word [ ss:bx + _segment ], dx
	mov word [ ss:bx + _pointer ], ax

		; return
_TerminateProcess_20:
	RetCallersStackFrame es, bx
	getdarg dx, ax, _returnVector
	mov word [ es:bx + _CS ], dx
	mov word [ es:bx + _IP ], ax

	dec word [ _RxDOS_AbortInProgress ]		; restore critical error
	return

		; 4Dh Get Return Code
_GetReturnCode:
	; RxDOS 7.30: unclear whether we should 'extend' this interface
%if 1
	mov ax, word [ _RxDOS_ChildReturnCode ]
%else
	xor ax, ax
	xchg ax, word [ _RxDOS_ChildReturnCode ]
%endif
	RetCallersStackFrame ds, bx
	mov word [ bx + _AX ], ax
	retn


		; 4Eh Find First matching file
		;
		; cx = attributes
		; ds:dx-> ASCIZ filename
_FindFirstFile:

	entry
	def	findType, 0
	def	attributes, cx
	ddef	filename, es, dx				; arg passed internally as es:dx
	defbytes	dirAccess, sizeDIRACCESS

		; make sure path is ok, try to match file
	mov ax, (FILEHAS_WILDCHARS)
	mov si, dx					; name from caller (es:si)
	lea di, [ _dirAccess + bp ]			; work dir access block
	call LocateFile					; don't worry about finding a file
	storarg _findType, ax				; find type/drive
	ifc _FindFirstFile_50				; error code already set -->

		; setup find search template
	xor ax, ax
	mov cx, sizeFINDENTRY
	les di, [ _RxDOS_pDTA ]
	push di
	repz stosb					; clear area (0 handle)
	pop di

		; copy template name, search string
	mov al, byte [ _dirAccess + fileAcDrive + bp ]
	mov byte [ es:di + findSrchDrive ], al

	mov si, word [ _dirAccess + fileAcNameOffset + bp ]
	lea di, [ byte di + findSrchName ]
	call convFilenametoFCBString			; convert to a match template

	les di, [ _RxDOS_pDTA ]
	lea si, [ di + findSrchDrive ]
	lea di, [ byte di + findFileName ]

	saveRegisters es, si, es, di			; arguments
	call convFCBNametoASCIZ				; build ASCIZ name

		; start at begining of directory, locate by attribute and name
	mov di, word [ _RxDOS_pDTA + _pointer ]
	mov al, byte [ _dirAccess + fileAcDrive + bp ]
	mov byte [ es:findSrchDrive + di ], al

	mov cl, byte [ _attributes + bp ]
	mov byte [ es:findSrchAttributes + di ], cl
	mov byte [ es:findFileAttribute + di ], cl

	mov cx, word [ _dirAccess + fileAcDirCluster + _high + bp ]
	mov dx, word [ _dirAccess + fileAcDirCluster + _low + bp ]
	mov word [ es:findDirBegCluster + _low + di ], dx
	mov word [ es:findDirBegCluster + _high + di ], cx
	; mov word [ es:findDirCurrCluster + _low + di ], dx
	; mov word [ es:findDirCurrCluster + _high + di ], cx
	mov word [ es:findDirEntry + di ], -1

	mov ax, word [ _dirAccess + fileAcDevicePtr + _segment + bp ]
	or ax, word [ _dirAccess + fileAcDevicePtr + _pointer + bp ]
	jnz _FindFirstFile_50				; if device, item found -->

	mov ax, pexterrNoMoreFiles
	test word [ _findType + bp ], 8000h
	stc						; if error
	jnz _FindFirstFile_50				; no need to search if device -->

		; lookup entry
	cmp byte [ _attributes + bp ], ATTR_DIRECTORY
	jnz _FindFirstFile_46				; if no searching for directories, go do lookup -->

	xor ax, ax
	mov si, word [ _dirAccess + fileAcNameOffset + bp ]
	cmp byte [ ss:si ], 0				; no name supplied ?
	jz _FindFirstFile_50				; entry is a valid directory -->

_FindFirstFile_46:
	call LocateFileByAttribute			; lookup by attribute

		; return
_FindFirstFile_50:
	RetCallersStackFrame ds, bx
	mov word [ _AX + bx ], ax			; return possible error code
	return


		; 4Fh Find Next matching file
		;
		; No parameters, uses find record in DTA.
_FindNextFile:

	les di, [ _RxDOS_pDTA ]

	mov ax, pexterrNoMoreFiles
	cmp word [ es:di + findDirEntry ], byte -1
	stc						; assume not found in previous
	jz _FindNextFile_08				; if not found in find first -->

	inc word [ es:di + findDirEntry ]
	call LocateFileByAttribute			; lookup by attribute

_FindNextFile_08:
	RetCallersStackFrame ds, bx
	mov word [ _AX + bx ], ax			; return possible error code
	retn

		; 50h Set PSP address
		;
		; bx	contains PSP address to use
		;
		; CHG:	-
		;
		; Does not change stack frame and can be called by DOS directly.
_SetPSPAddress:
	mov word [ _RxDOS_CurrentPSP ], bx		; Set current PSP
	retn

		; 51h Get PSP address
		;
		; bx	PSP value returned
_GetPSPAddress:
	call getpsp
	clc

	RetCallersStackFrame ds, si
	mov word [ si + _BX ], bx
	retn


		; Get PSP address
		;
		; OUT:	bx = PSP address
		;	CY if bx = 0 or bx = 0FFFFh
		; CHG:	-
getpsp:
	mov bx, word [ ss:_RxDOS_CurrentPSP ]
	cmp bx, byte -1
	stc
	je .return					; CY if PSP = 0FFFFh
	cmp bx, byte 1					; CY if PSP = 0
.return:
	retn


		; 52h Get DOS list of lists
		;
		; es:bx-> pointer to first DOS parameter block (start of list of lists)
_GetDosDataTablePtr:

	RetCallersStackFrame es, si
	mov word [ es:si + _ES ], ds
	mov word [ es:si + _BX ], _RxDOS_pDPB

	clc
	retn


		; 53h Translate BIOS Parameter Block to DOS Parameter Block
		;
		; Input:
		; ds:si-> BPB
		; es:bp-> Buffer for DPB
_TranslateBIOSParameterBlock:

	RetCallersStackFrame es, bx

	push word [ es:bx + _DS ]
	push word [ es:bx + _SI ]			; BIOS Parameter Block
	push word [ es:bx + _ES ]
	push word [ es:bx + _BP ]			; DOS Parameter Block
	call DefineDPB					; do not replace this call by jmp
	retn


		; 54h Get DOS write with verify switch
		;
		; Returns:
		; al = 00 if verify is off, else 01 verify is on
		;
		; (see related function 2E - Set/Reset DOS write with verify switch)
_GetVerify:

	mov al, byte [ _RxDOS_Verify ]

	RetCallersStackFrame ds, bx
	mov byte [ _AX + _AL + bx ], al
	clc
	retn


		; 55h Duplicate PSP
		;
		; dx	segment where to setup new PSP
		; si	value to place in memory size field
		;
		; (see related function 26 - Create PSP )
_DuplicatePSP:

	push dx						; new seg
	push si						; new size

	mov es, dx					; new PSP segment address
	call copyCurrentPSP				; create a new PSP here

	pop si
	pop es						; new PSP address
	mov word [ es:pspNextParagraph ], si		; set size
	mov word [ _RxDOS_CurrentPSP ], es		; change running PSP

	retn


		; 56h Rename File
		;
		; ds:dx-> ASCIZ existing file/path
		; es:di-> ASCIZ rename file/path
_RenameFile:

	entry
	ddef	wherePointer
	defbytes	existfileAccess, sizeDIRACCESS
	defbytes	renfileAccess, sizeDIRACCESS

		; does existing file exist ?
	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDIRECTORY)
	mov si, dx					; name from caller
	lea di, [ _existfileAccess + bp ]		; work dir access block
	call LocateFile					; check file path
	ifc _renameFile_40				; if file does not exist -->

	push ds
	RetCallersStackFrame ds, bx
	mov es, word [ _ES + bx ]
	mov si, word [ _DI + bx ]			; get user's parameter
	pop ds

	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDEFINED + FILECANNOT_BEDIRECTORY)
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
	rep movsw					; copy entry from source dir

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
	mov ax, word [ _renfileAccess + fileAcDrive + bp ]
	call updateDriveBuffers
	mov ax, word [ _existfileAccess + fileAcDrive + bp ]
	call updateDriveBuffers
	clc

_renameFile_40:
	return


		; 5700h Get File Date Time
		; 5701h Set File Date Time
		;
		; bx	file handle
		; cx	time
		; dx	date
_SetFileDateTime:

	push ax						 ; save mode
	mov ax, bx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	pop ax						; restore mode
	jc _SetFileDateTime_20				; if could not find -->

	Goto 00h, _GetFileDateTime			; get date/time
	Goto 01h, _SetFileDateTime_06			; set date/time

	SetError pexterrInvalidHandle, _SetFileDateTime_20

		; set date/ time
_SetFileDateTime_06:
	RetCallersStackFrame ds, bx
	mov cx, word [ _CX + bx ]			; restore arguments
	mov dx, word [ _DX + bx ]

	mov word [ es:di + sftTime ], cx		; time
	mov word [ es:di + sftDate ], dx		; date

	cmp word [ es:di + sftDevInfo ], sftIsDevice
	jnz _SetFileDateTime_12				; if device -->
	or word [ es:di + sftDevInfo ], sftDateset + sftWritten

_SetFileDateTime_12:
	clc
	retn

		; get date/ time
_GetFileDateTime:
	RetCallersStackFrame ds, bx
	mov cx, word [ es:sftTime + di ]		; time
	mov dx, word [ es:sftDate + di ]		; date
	mov word [ _CX + bx ], cx
	mov word [ _DX + bx ], dx
	clc

_SetFileDateTime_20:
	retn


		; 5800h Get Allocation Strategy
		; 5801h Set Allocation Strategy
		; 5802h Get Upper Memory Link
		; 5803h Set Upper Memory Link
		;
		; al = mode, as shown above
		;
		; bx	allocation strategy on set
		; ax	allocation strategy on get
_GetAllocationStrategy:

	Goto 00, _GetAllocStrategy
	Goto 01, _SetAllocStrategy
	Goto 02, _GetUpperMemLink
	Goto 03, _SetUpperMemLink

	seterror pexterrInvalidFunction
	retn


		; Get allocation strategy
_GetAllocStrategy:
	RetCallersStackFrame es, bx
	mov ax, word [ _RxDOS_AllocStrategy ]
	mov word [ es:bx + _AX ], ax
	retn

		; set allocation strategy
_SetAllocStrategy:
%if 1
		; RxDOS 7.20N:	MS-DOS allows any combination of the high bits. If
		;		both are set, this is the same as if only the "
		;		And that's even shorter.
	test bx, ~0C3h					; bh != 0 or invalid bits in bl set?
	jnz _SetAllocStrategy_22			; error -->
%else
	or bh,bh
	jnz _SetAllocStrategy_22			; Anything with bh != 0 is invalid

	; cmp bl, _MEM_FIRSTFIT_LOWTHENHIGH
	; jb _SetAllocStrategy_08			; _MEM_FIRSTFIT_LOW is zero anyway
	cmp bl, _MEM_LASTFIT_LOWTHENHIGH
	jbe _SetAllocStrategy_08

	cmp bl, _MEM_FIRSTFIT_HIGHONLY
	jb _SetAllocStrategy_22
	cmp bl, _MEM_LASTFIT_HIGHONLY
	jbe _SetAllocStrategy_08

	cmp bl, _MEM_FIRSTFIT_HIGHTHENLOW
	jb _SetAllocStrategy_22
	cmp bl, _MEM_LASTFIT_HIGHTHENLOW
	ja _SetAllocStrategy_22				; Above it is invalid
%endif

_SetAllocStrategy_08:
	clc
	mov word [ _RxDOS_AllocStrategy ], bx		; if valid
	retn

_SetAllocStrategy_22:
	mov ax, pexterrInvalidFunction			; if invalid
	stc
	retn

		; Get allocation strategy
_GetUpperMemLink:
	mov ax, word [ _RxDOS_UMBAllowed ]		; set allow/disallow flag
	RetCallersStackFrame ds, bx
	mov word [ bx + _AX ], ax
	retn

		; Get allocation strategy
_SetUpperMemLink:
	cmp word [ _RxDOS_UMBEnabled ], byte 0		; UMB enabled ?
	jz _SetUpperMemLink_08				; no -->

	cmp bx, byte 1
	ja _SetUpperMemLink_08

_SetUpperMemLink_04:
	clc
	mov word [ _RxDOS_UMBAllowed ], bx		; set allow/disallow flag
	retn

	; always return error until UMB support can be provided

_SetUpperMemLink_08:
	mov ax, pexterrInvalidFunction
	stc
	retn


		; 59h Get Extended Error
		;
		; ax	extended error code
		; bh	error class
		; bl	suggested action
		; ch	locus
_GetExtendedError:

	RetCallersStackFrame es, si

	cmp word [ _RxDOS_ExtErrorFlag ], byte TRUE
	jnz _GetExtendedError_08			; lookup error -->

		; error set by app
	mov word [ _RxDOS_ExtErrorFlag ], FALSE

	mov ax, word [ _RxDOS_ExtErrorInfo + errSI ]
	mov cx, word [ _RxDOS_ExtErrorInfo + errDS ]
	mov dx, word [ _RxDOS_ExtErrorInfo + errES ]

	mov word [ es:_SI + si ], ax
	mov word [ es:_DataSegment + si ], cx
	mov word [ es:_ExtraSegment + si ], dx

	mov ax, word [ _RxDOS_ExtErrorInfo + errAX ]
	mov bx, word [ _RxDOS_ExtErrorInfo + errBX ]
	mov cx, word [ _RxDOS_ExtErrorInfo + errCX ]
	mov dx, word [ _RxDOS_ExtErrorInfo + errDX ]
	mov di, word [ _RxDOS_ExtErrorInfo + errDI ]

	mov word [ es:_AX + si ], ax
	mov word [ es:_BX + si ], bx
	mov word [ es:_CX + si ], cx
	mov word [ es:_DX + si ], dx
	mov word [ es:_DI + si ], di

	clc
	ret


; error set by RxDOS
_GetExtendedError_08:
	xor ax, ax
	xor bx, bx
	xor cx, cx
	xor dx, dx					; if no error
	xchg bx, word [ _RxDOS_pExtErrorCode ]		; no longer need to save error ptr
	or bx, bx					; no actual error saved ?
	jz _GetExtendedError_12				; skip around -->

	call GetAllExtErrorInfo

_GetExtendedError_12:
	mov word [ _RxDOS_ExtErrorcode ], ax
	mov byte [ _RxDOS_LocusLasterror ], ch
	mov byte [ _RxDOS_SuggestedAction ], dl
	mov byte [ _RxDOS_ClassOfError ], dh

	mov word [ es:_AX + si ], ax	 ; return extended error code
	mov byte [ es:_CX + _CH + si ], ch
	mov word [ es:_BX + si ], dx

	clc
	ret

		; 5Ah Create Unique File Name

		; cx	attributes
		; ds:dx	pointer to asciz containing path

_CreateUniqueFile:

	entry
	def	handle, -1
	def	tempnamePointer
	def	bytecount
	def	attributes, cx				; attributes
	ddef	returnnamePointer, es, dx
	defbytes	dirAccess, sizeDIRACCESS
	defbytes	tempname, 128

		; file handle available ?	call VerifyAvailableHandle			; see if handle available
	ifc _CreateUniqueFile_40			; exit if none -->

		; copy buffer
	push word [ _returnnamePointer + _segment + bp ]
	push word [ _returnnamePointer + _pointer + bp ]
	mov cx, 128					; maximum string length
	call condStringLength
	jz _CreateUniqueFile_08

	SetError pexterrIllegalName, _CreateUniqueFile_40

_CreateUniqueFile_08:
	storarg _bytecount, cx				; save byte count
	push ax					 ; character just before null

	push word [ _returnnamePointer + _segment + bp ]
	push word [ _returnnamePointer + _pointer + bp ]
	push ss
	lea di, [ _tempname + bp ]
	push di
	call CopyStringArgs

	pop ax
	cmp al, '\'					; ended with \ ?
	jz _CreateUniqueFile_12			 ; yes -->
	cmp al, '/'					; ended with / ?
	jz _CreateUniqueFile_12			 ; yes -->

	mov al, '\'
	stosb						; we'll make one.

_CreateUniqueFile_12:
	storarg _tempnamePointer, di

		; create a unique filename
	call getExpandedDateTime			; expand time ch:cl dh:dl

	getarg di, _tempnamePointer

	mov al, ch					; hours
	call __ascii_stosb

	mov al, cl					; minutes
	call __ascii_stosb

	mov al, dh					; seconds
	call __ascii_stosb

	mov al, dl					; hundreths of second
	call __ascii_stosb

	xor al, al
	stosb						; null term

		; make sure file does not exist
_CreateUniqueFile_16:
	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDEFINED + FILECANNOT_BEDIRECTORY)
	lea si, [ _tempname + bp ]
	lea di, [ _dirAccess + bp ]		; work dir access block
	call LocateFile				 ; check file path
	jnc _CreateUniqueFile_36			; if path invalid -->

	getarg di, _tempnamePointer
	mov cx, (sizefnName - 1)
	add di, cx

_CreateUniqueFile_18:
	cmp byte [ ss:di ], 'Z'			; already at end of alphabet ?
	jnz _CreateUniqueFile_32			; no -->
	mov byte [ ss:di ], 'A'			; cycle to prev column
	dec di						; adj address
	loop _CreateUniqueFile_18			; and loop -->
	stc						; just in case
	jmp short _CreateUniqueFile_40			; we'll have an error exit -->

_CreateUniqueFile_32:
	inc byte [ ss:di ]
	jmp short _CreateUniqueFile_16

		; it doesn't, so we'll make one.
_CreateUniqueFile_36:
	lea di, [ _dirAccess + bp ]		; work dir access block
	mov cx, word [ _attributes + bp ]		; get attributes
	and cx, byte ~(ATTR_VOLUME| ATTR_DIRECTORY)
	call createSFTEntry				; create SFT entry
	jc _CreateUniqueFile_40			 ; if error -->

	call MapSFTToAppHandle				; if no space, create error

	push ax
	push ss
	push word [ _tempnamePointer + bp ]
	getdarg es, di, _returnnamePointer
	add di, word [ _bytecount + bp ]		; point to null terminator

	push es
	push di
	call CopyStringArgs				; copy name back to user

	pop ax
	clc

		; return
_CreateUniqueFile_40:
	RetCallersStackFrame ds, bx
	mov word [ _AX + bx ], ax
	return

		; 5Bh Create New File

		; cx	attributes
		; ds:dx	pointer to filename( path included )

_CreateNewFile:

	entry
	def	attributes, cx				; attributes
	defbytes	dirAccess, sizeDIRACCESS
	call VerifyAvailableHandle			; see if handle available
	jc _CreateNewFile_40				; exit if none -->

		; make sure file does not exist
	RetCallersStackFrame es, bx
	mov si, word [ es:_DX + bx ]
	mov es, word [ es:_DataSegment + bx ]

	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDEFINED + FILECANNOT_BEDIRECTORY)
	lea di, [ _dirAccess + bp ]			; work dir access block
	call LocateFile				 ; check file path
	jnc _CreateNewFile_16				; if valid -->

	test word [ _dirAccess + fileAcDrive + bp ], 8000h	; not found ?
	jnz _CreateNewFile_14				; ok, error code is fine ->
	mov ax, pexterrFileExists		; upgrade error code

_CreateNewFile_14:
	stc
	jmp short _CreateNewFile_40

		; ok to create new.
_CreateNewFile_16:
	RetCallersStackFrame es, bx
	mov cx, word [ es:_CX + bx ]
	mov dx, word [ es:_DX + bx ]
	mov es, word [ es:_DataSegment + bx ]

	lea di, [ _dirAccess + bp ]			; work dir access block
	mov cx, word [ _attributes + bp ]		; get attributes
	call createSFTEntry				; create SFT entry
	jc _CreateNewFile_40				; exit if none or error -->

	call MapSFTToAppHandle				; if no space, create error

		; return
_CreateNewFile_40:
	RetCallersStackFrame ds, bx
	mov word [ _AX + bx ], ax
	return

		; 5Dxxh Server, Share and Swap
		;
		; Input:
		;
		; Output:
_ServerShareAndSwap:

	RetCallersStackFrame es, bx
	Goto 06h, _GetSwappableDataArea
	Goto 0Ah, _SetExtendedError

_ShareUnimplemented:
	mov ax, pexterrInvalidFunction
	stc
	retn

		; get swappable data area
_GetSwappableDataArea:
	mov word [ es:bx + _DS ], ss
	mov word [ es:bx + _SI ], SDABeginArea
	mov word [ es:bx + _CX ], SDAExtendedSwapArea - SDABeginArea
	mov word [ es:bx + _DX ], SDAEndArea - SDABeginArea
	retn

		; set extended error
_SetExtendedError:
	mov word [ _RxDOS_ExtErrorFlag ], TRUE		; extended error is true

	mov ds, word [ es:bx + _DS ]
	mov si, word [ es:bx + _DX ]			; where extended info available

	push ss
	pop es
	mov di, _RxDOS_ExtErrorInfo
	mov cx, sizeDOSERROR / 2
	repz movsw					; copy words

	clc
	retn


		; 60h Get Actual (Expanded) File Name
		;  (Truename)
		;
		; Input:
		; ds:si pointer to filename (path included)
		; es:di pointer to expanded filename
		;
		; Output:
		; ax	0000	if name is local.
		; ax	005c	if name is networked.
_GetActualFileName:

	RetCallersStackFrame es, bx
	push word [ es:bx + _DS ]			; non-canonical name
	push word [ es:bx + _SI ]
	push word [ es:bx + _ES ]			; expanded filename
	push word [ es:bx + _DI ]

	mov ax, FILECANNOT_BEDIRECTORY			; RxDOS 7.20N:	Is that required? Shouldn't!
	call ExpandFileName
	retn


		; 63h Get DBCS string pointer
		;
		; Output:
		; ds:si-> DBCS string
		; CY if error
		;
		; This function is not supported in RxDOS.
		; Always returns pointer to NULL double bytes.
_GetDBCSString:

	RetCallersStackFrame ds, bx
	mov word [ bx + _SI ], _RxDOS_DBCS_Table
	mov word [ bx + _DS ], cs

	clc
	retn


		; 65h Country Dependent Functions

		; Input:
		; al	function
		;  01h	get extended country info
		;  02h	get uppercase table
		;  04h	get filename uppercase table
		;  05h	get filename character table
		;  06h	get collate sequence table
		;  07h	get double byte character set
		;  20h	character capitalization
		; 	dl = contains character
		; 	dh = 2nd byte in double byte languages
		;  21h	length defined string capitalization
		; 	ds:dx-> string
		; 	cx = length
		;  22h	ASCIZ capitalization
		; 	ds:dx-> ASCIZ string
		;  23h	does character represent Yes/No response
		; 	dl = contains character
		; 	dh = 2nd byte in double byte languages
		; 	returns: ax = 00 if yes
		; 			01 if no
		; 			02 if other
		;  A0h	filename character capitalization
		; 	dl contains character
		;  A1h	filename length defined string capitalization
		; 	ds:dx-> string
		; 	cx = length
		;  A2h	filename ASCIZ capitalization
		; 	ds:dx-> ASCIZ string
		;
		; Output:
		; CY if error
_ExtCountryDependentFunctions:

	mov ah, al					; copy function to ah also
%if 0
;;	Goto 01h,			_GetExtendedCountryInfo
%else
		; RxDOS 7.20N:	Why was that disabled?
	Goto 01h,			_GetExtendedCountryInfo
%endif

%if 0
	Goto 02h,			_GetUpperCaseTable
	Goto 04h,			_GetFilenameUpperCaseTable
	Goto 05h,			_GetFilenameCharacterTable
	Goto 06h,			_GetCollateSequenceTable
	Goto 07h,			_GetDoubleByteCharacterSet
%endif

	Goto _CapCharacter,		_Capitalize_08
	Goto _CapLengthDefString,	_Capitalize_12
	Goto _CapString,		_Capitalize_22
	Goto _CountryDepYesNo,		_Capitalize_30

	Goto _CapFnCharacter,		_Capitalize_08
	Goto _CapFnLengthDefString,	_Capitalize_12
	Goto _CapFnString,		_Capitalize_22

_GetUpperCaseTable:
_GetFilenameUpperCaseTable:
_GetFilenameCharacterTable:
_GetCollateSequenceTable:
_GetDoubleByteCharacterSet:

	mov ax, pexterrInvalidFunction
	stc
	retn

		; Get Extended Country Info
_GetExtendedCountryInfo:
	cmp bx, byte -1					; if get info
	jz _GetExtendedCountryInfo_08			; go do get -->

	mov word [ _RxDOS_UserCodePage ], bx		; should check values
	mov word [ _RxDOS_UserCountryCode ], dx		; should check values
	clc
	retn

_GetExtendedCountryInfo_08:
	mov ax, word [ _RxDOS_UserCodePage ]
	mov dx, word [ _RxDOS_UserCountryCode ]

	RetCallersStackFrame es, bx
	mov word [ es:bx + _BX ], ax			; code page
	mov word [ es:bx + _DX ], dx			; country code
	clc
	retn

		; capitalize character
_Capitalize_08:
	_upperCase dl					; upper case
	RetCallersStackFrame ds, bx
	mov byte [ bx + _DX + _DL ], dl
	clc
	retn

		; capitalize length defined string (was ds:dx, now es:di)
_Capitalize_12:
	or cx, cx
	jz _Capitalize_18

	cld
_Capitalize_14:
	mov al, byte [ es:di ]
	_upperCase al					; upper case
	stosb
	loop _Capitalize_14

_Capitalize_18:
	clc
	retn

		; capitalize ASCIZ string (was ds:dx, now es:di)
_Capitalize_22:
	cld
	mov al, byte [ es:di ]
	or al, al
	jz _Capitalize_28

	_upperCase al					; upper case
	stosb
	jmp short _Capitalize_22

_Capitalize_28:
	clc
	retn

		; return country dependent yes/no answer
_Capitalize_30:
	mov al, dl
	_upperCase al					; upper case

	; Fixed English values for now.

	mov dl, 00h					; if yes
	cmp al, 'Y'
	jz _Capitalize_34

	mov dl, 01h					; if no
	cmp al, 'N'
	jz _Capitalize_34

	mov dl, 02h					; if neither

_Capitalize_34:
	retn


		; 86h Global code page settings
		;
		; Get global code page
		; INP:	al = 01
		; OUT:	bx = user code page
		;	dx = system code page
		;
		; Set global code page
		; INP:	al = 02
		; OUT:	bx = user code page
		;	dx = system code page
_GlobalCodePage:

	RetCallersStackFrame es, bx

	Goto 01,			_GetCodePage
	Goto 02,			_SetCodePage

	mov ax, pexterrInvalidFunction
	stc
	retn

		; Get code page value
_GetCodePage:
	mov ax, word [ _RxDOS_UserCodePage ]
	mov dx, word [ _RxDOS_SystemCodePage ]
	mov word [ es:bx + _BX ], ax
	mov word [ es:bx + _DX ], dx
	retn

		; Set code page value
_SetCodePage:
	mov ax, word [ es:bx + _BX ]
	mov dx, word [ es:bx + _DX ]
	mov word [ _RxDOS_UserCodePage ], ax
	mov word [ _RxDOS_SystemCodePage ], dx
	retn


		; 67h Set Handles Count
		;
		; bx number of file handles to allocate to an application
_SetHandlesCount:
	entry
	def	handles, bx
	def	allocatedseg

	mov es, word [ _RxDOS_CurrentPSP ]
	cmp bx, word [ es:pspFileHandleCount ]		; more than current ?
	jnc _SetHandlesCount_08				; yes, relocate -->
	call TestIfMoveHandleTable			; else, see if can relocate back to PSP
	jmp _SetHandlesCount_26

_SetHandlesCount_08:
	add bx, byte (sizeParagraph - 1)
	shr bx, 1
	shr bx, 1
	shr bx, 1
	shr bx, 1					; compute paragraphs required

	call _allocateUpperMB				; allocate upper memory block
	jnc _SetHandlesCount_12				; if allocation made -->
	call _allocateConvMB				; allocate lower memory block
	jc _SetHandlesCount_30				; if allocation not made -->

_SetHandlesCount_12:
	mov es, ax					; new segment
	storarg _allocatedseg, ax			; save

	getarg cx, _handles				; allocated request
	add cx, byte (sizeParagraph - 1)
	and cx, byte ~(sizeParagraph - 1)		; allocated size
	shr cx, 1					; optimize for words
	xor di, di
	mov ax, -1
	repz stosw					; clear words

	push ds
	push es
	mov es, word [ _RxDOS_CurrentPSP ]		; get PSP
	mov cx, word [ es:pspFileHandleCount ]		; source count
	lds si, [ es:pspFileHandlePtr ]			; source pointer

	pop es
	xor di, di					; where to copy to
	repz movsb					; copy table

	pop ds						; restore current segment
	getarg ax, _allocatedseg			; allocated segment
	mov es, word [ _RxDOS_CurrentPSP ]
	mov word [ es:pspFileHandlePtr + _segment ], ax
	mov word [ es:pspFileHandlePtr + _pointer ], 0

	getarg bx, _handles
	mov word [ es:pspFileHandleCount ], bx

_SetHandlesCount_26:
	clc

_SetHandlesCount_30:
	return


		; 68h Commit File
		;
		; bx = handle to open file
_CommitFile:
	mov ax, bx					; handle
	call MapAppToSFTHandle				; map to internal handle info
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	jc _CommitFile_error				; if could not find -->

	call _SFTCommitFile				; commit SFT Entry
	clc

_CommitFile_error:
	retn


		; 6Ch Extended open/create
		;
		; bx = mode
		; cx = attributes
		; dx = action to take
		; ds:si-> filename
_ExtendedOpenCreate:

	entry
	def	mode, bx
	def	attributes, cx
	def	action, dx
	def	actionTaken, 0
	def	found, FALSE
	ddef	filename, es, si
	defbytes	dirAccess, sizeDIRACCESS

	call VerifyAvailableHandle			; see if handle available
	ifc _ExtendedOpenCreate_42			; if error -->

		; determine if file exists
	RetCallersStackFrame es, bx
	mov si, word [ es:bx + _SI ]
	mov es, word [ es:bx + _DS ]

	mov ax, (FILE_NODEVICENAME + FILECANNOT_BEDIRECTORY)
	lea di, [ bp + _dirAccess ]			; work dir access block
	call LocateFile					; check file path
	jnc _ExtendedOpenCreate_FileFound		; if file found, see if replace -->

	storarg _found, FALSE
	test word [ bp + _action ], EXTENDEDACTION_CREATE
	jnz _ExtendedOpenCreate_Create			; ok to create -->

		; open file
_ExtendedOpenCreate_Open:
	RetCallersStackFrame es, bx
	mov si, word [ es:bx + _SI ]
	mov es, word [ es:bx + _DS ]

	lea di, [ _dirAccess + bp ]			; work dir access block
	mov ax, (FILE_ORDEVICE + FILECANNOT_BEDIRECTORY)
	call LocateFile					; if can't locate, then
	jc _ExtendedOpenCreate_42			; if error -->

	getarg ax, _mode
	lea di, [ _dirAccess + bp ]			; work dir access block
	call _SFTOpenFile				; build an SFT
	jc _ExtendedOpenCreate_42			; if error -->

	call MapSFTToAppHandle				; record SFT handle into JHT
	storarg _actionTaken, ACTION_OPENED
	jmp short _ExtendedOpenCreate_42

		; create file
_ExtendedOpenCreate_Create:
	RetCallersStackFrame es, bx
	mov si, word [ es:bx + _SI ]			; filename in ds:si
	mov es, word [ es:bx + _DS ]

	mov ax, (FILE_NODEVICENAME + FILEMAY_EXIST + FILECANNOT_BEDIRECTORY)
	lea di, [ bp + _dirAccess ]			; work dir access block
	call LocateFile
	jc _ExtendedOpenCreate_42			; if error -->

	getarg cx, _attributes
	lea di, [ bp + _dirAccess ]			; work dir access block
	call _SFTCreateFile
	jc _ExtendedOpenCreate_42			; if error -->

	call MapSFTToAppHandle				; record SFT handle into JHT

	mov cx, ACTION_REPLACED_OPENED
	cmp word [ bp + _found ], byte TRUE
	jz _ExtendedOpenCreate_32			; if found, then was truncated ->
	mov cx, ACTION_CREATED_OPENED

_ExtendedOpenCreate_32:
	clc						; no carry
	storarg _actionTaken, cx
	jmp short _ExtendedOpenCreate_42

		; if file found, determine if truncate
_ExtendedOpenCreate_FileFound:
	storarg _found, TRUE
	test word [ _action + bp ], EXTENDEDACTION_TRUNCATE
	jnz _ExtendedOpenCreate_Create			; ok to create/ truncate -->
	test word [ _action + bp ], EXTENDEDACTION_OPEN
	jnz _ExtendedOpenCreate_Open			; ok to open -->

	stc
	mov ax, pexterrAccessDenied

		; return
_ExtendedOpenCreate_42:
	RetCallersStackFrame es, bx
	mov word [ es:bx + _AX ], AX

	getarg cx, _actionTaken
	mov word [ es:bx + _CX ], CX

	return


%if 0
		; 70h Get/set extended country information
		;
		; al = subfunction,
		;  00h	Get extended i18n information (set with Int21.7001)
		;	cx = buffer size, 3Ah required
		;	es:di-> buffer
		;  01h	Set extended i18n information (get with Int21.7000)
		;	cx = number of bytes set, maximal 3Ah
		;	ds:si-> extended i18n information
		;  02h	Set extended country information (get with Int21.38)
		;	cx = number of bytes set, maximal 26h
		;	ds:si-> extended country information
_GetSetCountryInformation:

		RetCallersStackFrame ds, si
		mov es, word [ _ES + si ]
		mov di, word [ _DI + si ]
		push word [ _DS + si ]
		mov si, word [ _SI + si ]
		pop ds					; preset es:di and ds:si to caller's values

		gotos 00h,	.getexti18n
		gotos 01h,	.setexti18n
		gotos 02h,	.setextcountry
		
		seterror pexterrInvalidFunction
		retn


.getexti18n:
		cmp cx, byte 3Ah
		jb .error_struc

		currSegment ds
		mov si, _RxDOS_extendedi18n
		mov cx, 003Ah/2
		repe movsw

		clc
		retn


.setexti18n:
		mov ax, 003Ah
		mov di, _RxDOS_extendedi18n
		jmp short .copytodos

.setextcountry:
		mov ax, 0026h-3
		mov di, _RxDOS_CurrCountryInfo
		add si, byte 3
		sub cx, byte 3

.copytodos:
		cmp cx, ax
		ja .error_struc

		currSegment es
		repe movsb
		
		clc
		retn


.error_struc:
		seterror pexterrBadReqStruc
		retn
%endif


		; Unused/Unimplemented Functions
_GetSetCountryInformation:
_GetDiskSerialNumber:
_LockFileAccess:
_GetMachineName:
_GetRedirectionList:

_Unused:
_UnusedReturnInst:
_Unused_al00:						; Set caller's al to 00h (DOS unimplemented function)
	xor al, al

_Unused_al:
	RetCallersStackFrame es, bx
	mov byte [ es:bx + _AX + _AL ], al
	xor ax, ax					; tell error type: custom error (registers already set)
	stc						; tell error
	retn

_Unused_alFF:						; Set caller's al to 0FFh (FCB error but preserve CF)
	mov al, 0FFh
	jmp short _Unused_al


%ifn _BUILD_OBJ
align 16, db 0
 %include "RxDOSCCB.ASM"
align 16, db 0
 %include "RxDOSDEV.ASM"
align 16, db 0
 %include "RxDOSEXE.ASM"
align 16, db 0
 %include "RxDOSFAT.ASM"
align 16, db 0
 %include "RxDOSFCB.ASM"
align 16, db 0
 %include "RxDOSFIL.ASM"
align 16, db 0
 %include "RxDOSLFN.ASM"
align 16, db 0
 %include "RxDOSF32.ASM"
align 16, db 0
 %include "RxDOSIFS.ASM"
align 16, db 0
 %include "RxDOSMEM.ASM"
align 16, db 0
 %include "RxDOSSFT.ASM"
align 16, db 0
 %include "RxDOSSTR.ASM"
align 16, db 0
 %include "RxDOSCTB.ASM"
align 16, db 0
 %include "RxDOSERR.ASM"
align 16, db 0
 %include "RxDOSINI.ASM"
%endif

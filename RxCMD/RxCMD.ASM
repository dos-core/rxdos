
%if 0

RxCMD - RxDOS command shell

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

Copyright (C) 1990-1999 Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

%if 0

Programmer's Notes:

The command shell consists of two parts bound together into a
single executable load. There exists a single resident command
shell which is accessible by Int2E.

%endif

%ifnidni __OUTPUT_FORMAT__, obj
 %define _BUILD_OBJ 0
%endif

	cpu 8086

%include "RXDMACRO.MAC"
%include "RXDSTRUC.MAC"
%include "RXCSTRUC.MAC"

%if _BUILD_OBJ
	segment RXCMD align=16 class=RXCMD use16 public start=100h
	segment RXCMD

	global CommandBegin

	global CheckOptOneArg
	global CmndError_BadSwitch
	global CmndError_CannotCopyOverSelf
	global CmndError_CannotCreateFile
	global CmndError_ContentsLostBeforeCopy
	global CmndError_FileAlreadyExists
	global CmndError_FileNotFound
	global CmndError_InvalidDate
	global CmndError_InvalidDrive
	global CmndError_InvalidTime
	global CmndError_NoFilesFound
	global CmndError_SyntaxError
	global CmndError_InvalidNumberArguments
	global CmndError_OutOfEnvironmentSpace
	global CmndError_ReadErrorAbort

	global CRLF
	global CmndLookup
	global _Copy_FilesCopied
	global CountArgs
	global RxDOS_BatchFile

	global insertarg
	global deletearg
	global deleteEnvVariable
	global DisplayErrorCode
	global DisplayErrorMessage
	global DisplayOutEnvSpace
	global DisplayLine
	global insertEnvVariable
	global PreProcessCmndLine
	global ReplaceForVariables
	global returnVolumeName
	global searchEnvVariable
	global setPagingMode
	global FixUpArguments

	global CheckFile
	global CheckFileClose
	global BuildFullPathFirstFile
	global BuildFullPathNextFile
	global BuildFullPathClose
	global LFNReturnPreferedFilenamePtr

	global RxDOSIntl_DateTemplate
	global RxDOSIntl_DayOfWeek
	global RxDOSIntl_TimeTemplate
	global RxDOSIntl_DateTimeTable

	global _div32
	global _mul32

	global RxDOS_AllFiles
	global RxDOS_AllExtensions
	global RxDOS_DefaultPrompt
	global RxDOS_ForArgs
	global RxDOS_Prompt
	global RxDOS_PromptSpec
	global RxDOS_Version

	global CopyString
	global _AppendPathName
	global _CmndParse_SeparatorCheck
	global _DirAttribSwitch
	global _DirBareSwitch
	global _DirLowerCaseSwitch
	global _DirOrderSwitch
	global _DirPauseSwitch
	global _DirSubDirSwitch
	global _DirSwitches
	global _DirWideSwitch
	global removeLooseSwitches
	global _Dir_DirectoryOf
	global _Dir_DirEntry
	global _Dir_FileEntry
	global _Dir_Files_Summary
	global _Dir_Files_MBSummary
	global _Dir_NoVolumeLabel
	global _Dir_VolumeLabel
	global _Dir_VolumeSerialNumber
	global _endofString
	global _EnvSegment
	global _GetNumber
	global _getStdinLine
	global _CommandParser
	global _lowerCaseString
	global _PleaseEnterDate
	global _PleaseEnterTime
	global _ShowCurrentDate
	global _ShowCurrentTime
	global _sprintf
	global _SwitchChar
	global _computeLength
	global _Seeif_WildCharacter
	global RxDOS_TruenameCurrDir

		; in RXCMDCPY
	extern _Copy

		; in RxCMDDIR
	extern _Dir

		; in RxCMDFOR
	extern _For

		; in RxCMDPRM
	extern _Prompt
	extern _Date
	extern _Time

	extern DisplayPrompt
	extern formatCurrentDate
	extern formatCurrentTime

		; in RxCMDREN
	extern _Rename
%else	; not _BUILD_OBJ
			[map all __MAPFILE__]

	section _EXEHEADER align=16 start=0 vstart=0
startheader:
	istruc EXEHEADER
at exeSignature,	dw "MZ"
at exeExtraBytes,	dw (RXDOSLASTADDRESS - firstaddress) % 512
at exePages,		dw (endheader - startheader \
				+ RXDOSLASTADDRESS - firstaddress + 511) >> 9
at exeRelocItems,	dw 0
at exeHeaderSize,	dw (endheader - startheader + 15) >> 4
at exeMinAlloc,		dw (65536 - (RXDOSLASTADDRESS - firstaddress) \
				+ 512 + 15) >> 4
at exeMaxAlloc,		dw -1
at exeInitSS,		dw 0
at exeInitSP,		dw 0
at exeChecksum,		dw 0
at exeInitIP,		dw CommandBegin
at exeInitCS,		dw 0
at exeRelocTable,	dw 1Eh
at exeOverlay,	dw 0
	iend
	times 512 - ($-$$) db 0
endheader:

	section RXCMD align=16 vstart=0 follows=_EXEHEADER
firstaddress:

%include "RxCMDCPY.ASM"
	align 16, db 0
%include "RxCMDDIR.ASM"
	align 16, db 0
%include "RxCMDFOR.ASM"
	align 16, db 0
%include "RxCMDPRM.ASM"
	align 16, db 0
%include "RxCMDREN.ASM"
	align 16, db 0
%endif

		; RxDOS interrupt 2Eh interface
		;
		; Usage:
		; ds:si-> command line beginning with a count (does not rely on CR at end)
_Int2E_CommandParser:

	push ds
	push si
	mov si, ss
	mov ds, si
	mov si, sp					; old stack to ds:si

	cld
	cli
	setSS cs
	mov sp, RxDOS_AltStack				; switch stacks
	sti

	saveRegisters ds, si				; save pointer to other stack
	lds si, [ si ]					; restore old ds:si values
	call _CommandParser				; call command parser

	cli
	pop si
	pop ss
	mov sp, si					; back to old stack
	sti

	pop si
	pop ds						; restore ds:si values

	iret


		; RxDOS command parser/execute
		;
		; Usage:
		; ds:si-> command line beginning with a count (does not rely on CR at end)
		;
		; The command is executed, which may require loading another program.
_CommandParser:

	Entry
	ddef	OriginalCmdLine, ds, si			; argument is copied
	defbytes	commandLine, 256		; argument is copied
	defbytes	_argarray, sizemaxArgArray	; argument array (last arg is null)

	SaveAllRegisters				; save all registers
	cld						; and setup direction

		; get switch character
	Int21 GetSetSwitchChar, 00			; get
	mov byte [ cs:_SwitchChar ], dl			; store switch character


		; copy command line
	getdarg ds, si, _OriginalCmdLine

	lodsb
	mov cl, al					; length
	xor ch, ch
	jcxz _CommandParser_36				; if no command -->

	setES cs
	lea di, [ _commandLine + bp ]
	repe movsb					; copy command line

	xor ax, ax
	stosb						; add a null terminator


		; parse
	setDS cs
	mov cx, maxArgArray - 2				; number of argument array entries
	lea si, [ _commandLine + bp ]
	lea di, [ __argarray + bp ]
	call _BuildArgArray				; break up into arg list
	jz _CommandParser_36				; if no arguments -->

	mov si, word [ __argarray + argpointer + bp ]	; get lead argument
	cmp byte [ si ], ':'				; label line ?
	jz _CommandParser_36				; ignore -->

	lea di, [ __argarray + bp ]
	call _executeCommandArray

%if 0
	cmp word [ RxDOS_BatchFile + batchEchoStatus ], No
	jz _CommandParser_36				; if no echo -->
	call CRLF					; append CR+LF after the command executed
		; RxDOS 7.20N:	A line break isn't displayed after a command executed.
		;		It's displayed before the prompt is displayed.
%endif

		; command completed
_CommandParser_36:
	restoreAllRegisters
	Return


		; Control-C interrupt service routine
_ControlC_ISR:
	push ax
	push bx

	Int21 GetPSPAddress
	cmp bx, word [ cs:_PSPSegment ]			; this instance of RxCMD active ?
	je _ControlC_ISR_12				; yes, accept Ctrl-C -->

	pop bx
	pop ax
	stc
	retf						; cause abort
		; RxDOS 7.20N:	Refer to the comment below CtrlC_CheckCallBack in RxDOS.ASM.


		; abort current command, batch files
_ControlC_ISR_12:
	cli
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax					; return to this RxCMD instance (it's already the active PSP)
	mov sp, word [ RxDOS_PrevStackFrame ]		; current stack frame
	sti

_ControlC_ISR_16:
	cmp word [ RxDOS_BatchFile + batchFileHandle ], byte 0
	jz _ControlC_ISR_24				; if not running a batch file -->

	call _EndCall					; terminate batch file
	jmp short _ControlC_ISR_16			; undo all nested batch calls

_ControlC_ISR_24:
	jmp CommandInput


		; Execute command stored in Arg array
		;
		; Usage:
		; ss:di-> argument array
_executeCommandArray:
	entry
	def	_argarray, di				; argument array
	def	_startCmdLine
	def	_leadAtcommand, false
	def	_stdin					; stdin on entry
	def	_stdout					; stdout on entry

	defbytes	_execCtrlBlock, sizeEXECCONTROL
	defbytes	_pathArg, sizeLFNPATH

	mov cx, STDIN
	call _assignGetCurrHandle			; get current handle
	storarg __stdin, ax				; stdin on entry

	mov cx, STDOUT
	call _assignGetCurrHandle			; get current handle
	storarg __stdout, ax				; stdout on entry


		; scan remainder of command line for pipe and redirection
	xor ax, ax
	lea di, [ __execCtrlBlock + bp ]
	clearMemory sizeEXECCONTROL			; clear exec control block

	mov dx, -1
	lea bx, [ __execCtrlBlock + bp ]
	mov word [ exCtrlStdInHandle + bx ], dx		; no StdIn file
	getarg di, __argarray				; argument array

_executeArray_04:
	mov dx, -1
	lea bx, [ __execCtrlBlock + bp ]
	mov word [ exCtrlStdOutHandle + bx ], dx	; no StdOut file (StdIn may have been piped)

	lea bx, [ __execCtrlBlock + bp ]
	call _assignRedirectedDevices			; arg array in di


		; split leading @ sign
	getarg di, __argarray				; restore pointer to arg array
	mov si, word [ argpointer + di ]		; get argument
	mov cx, word [ arglength + di ]			; arg length

	cmp byte [ si ], "@"				; starts with leading @ sign ?
	jnz _executeArray_08				; no -->

	storarg __leadAtcommand, true
	inc word [ argpointer + di ]			; get argument
	dec word [ arglength + di ]			; arg length
	jnz _executeArray_08				; yes -->
	call deletearg					; delete @ arg


		; see if command is valid
_executeArray_08:
	mov si, word [ argpointer + di ]		; get argument
	mov cx, word [ arglength + di ]			; arg length
	call checkInstallableCommandInterface		; command executed ?
		; RxDOS 7.20N:	The ICI call should move somewhere higher!
	jnz _executeArray_36				; yes -->

	getarg di, __argarray				; restore pointer to arg array
	mov si, word [ argpointer + di ]		; get lead argument
	mov cx, word [ arglength + di ]			; get arg length
	mov di, RxDOS_InternalCommands			; Default internal command ?
	call CmndLookup					; lookup command
	jnc _executeArray_26				; if command found -->

	call checkUnixStyleCommands			; Unix style commands ?
	jnz _executeArray_10				; if no Unix commands -->

	getarg di, __argarray				; restore pointer to arg array
	mov si, word [ argpointer + di ]		; get lead argument
	mov cx, word [ arglength + di ]			; get arg length
	mov di, RxDOS_UNIXStyleCommands
	call CmndLookup					; lookup command
	jnc _executeArray_26				; if command found -->


		; see if valid drive letter
_executeArray_10:
	getarg di, __argarray
	mov si, word [ argpointer + di ]		; get lead argument
	cmp word [ ss:si + 1 ], ':'			; disk select ?
	jnz _executeArray_12				; if unknown -->

		; RxDOS 7.20N:	It's only a disk select if the command is only the letter and
		;		a colon or if it's a (possibly inexistent) path terminated by
		;		a path seperator (/ or \).

	call CountArgs					; count how many arguments
	call _DiskSelect				; process disk select
	jmp short _executeArray_36


		; see if .EXE, .COM, or .BAT (filename in ss:si)
_executeArray_12:
	mov ax, _UNKNOWN
	lea dx, [ __pathArg + bp ]
	call _executeProgram				; try to execute program
	jc _executeArray_36				; if error -->

	call _saveBatchArguments			; if batch file, save arguments
	jmp short _executeArray_36


		; go process internal command
_executeArray_26:
	getarg di, __argarray				; argument pointer
	call SplitArgs					; for cd.. cases

	add di, sizeArgCmd				; skip past lead arg
	mov si, word [ argpointer + di ]		; get lead argument
	call CountArgs					; count how many arguments
	call bx						; go execute commands


		; done. temp input file created ?
_executeArray_36:
	mov byte [ PageLines ], 00			; cancel page lines

	mov bx, STDIN
	mov ax, word [ __execCtrlBlock + exCtrlStdInHandle + bp ]
	call _CloseRedirectedDevice

	getarg di, __argarray
	test word [ __execCtrlBlock + exCtrlFlags + bp ], exTempInputFile
	jz _executeArray_42				; not piped in -->

	lea dx, [ __execCtrlBlock + exCtrlStdInFileName + bp ]
	Int21 LFNDeleteFile				; delete temp stdin


		; is arg piped ?
_executeArray_42:
	getarg di, __argarray
	test word [ __execCtrlBlock + exCtrlFlags + bp ], exCtrlPiped
	jnz _executeArray_46

	mov bx, STDIN
	getarg ax, __stdin				; StdIn on entry
	call _CloseRedirectedDevice			; close device

	mov bx, STDOUT
	getarg ax, __stdout				; StdOut on entry
	call _CloseRedirectedDevice			; close device
	Return


		; arg is piped
_executeArray_46:
	mov ax, word [ di ]
	add di, sizeArgCmd				; skip past lead arg
	or ax, ax					; at end of search ?
	jnz _executeArray_46				; keep loopking -->

	and word [ __execCtrlBlock + exCtrlFlags + bp ], ~ exCtrlPiped
	or word [ __execCtrlBlock + exCtrlFlags + bp ], exTempInputFile
	storarg __argarray, di				; next in arg array

	; must re-open file given by temp...
	; maybe should not have closed it.

	mov cx, STDOUT
	call _assignGetCurrHandle			; get current handle
	mov word [ __execCtrlBlock + exCtrlStdInHandle + bp ], ax

	mov bx, STDOUT
	Int21 CommitFile				; close StdOut

	xor cx, cx
	xor dx, dx
	mov bx, STDOUT
	Int21 MoveFilePointer, SEEK_BEG			; point to start of file

	lea si, [ __execCtrlBlock + exCtrlStdOutFileName + bp ]
	lea di, [ __execCtrlBlock + exCtrlStdInFileName + bp ]
	call CopyString

	lea di, [ __execCtrlBlock + exCtrlStdOutFileName + bp ]
	mov byte [ di ], 0

	mov bx, STDOUT
	mov cx, STDIN
	Int21 ForceFileHandle				; redirect stdout -> stdin

	mov bx, STDOUT
	mov ax, word [ __execCtrlBlock + exCtrlStdOutHandle + bp ]
	call _CloseRedirectedDevice

	getarg di, __argarray				; next in arg array
	jmp _executeArray_04


		; Build Argument Array
		;
		; Usage:
		; ds:si-> zero terminated command line
		; ss:di-> argument array
		;	(returns a pointer into the command line at the
		;	start of each argument.	Multiple switches are
		;	detected by testing the get command switch char).
		; cx = max number of arguments allowed
		;
		; Returns:
		; ZR if no arguments passed
_BuildArgArray:

	Entry
	ddef	commandLine, ds, si
	ddef	_argarray, ss, di				; (maxArgArray) arguments
	def	args, cx

	def	argsStored, 0000
	def	argTableStart, di
	def	insideQuotes, FALSE

	setES ss


		; skip whitespace
_buildArgArray_06:
	lodsb						; get character
	or al, al					; end of line ?
	jz _buildArgArray_36				; yes, end of arg -->
	cmp al, ' '					; leading white space ?
	jz _buildArgArray_06				; yes, skip -->

	dec si


		; record argument
_buildArgArray_14:
	mov word [ argpointer + di ], si		; store argument pointer
	mov word [ arglength + di ], 0			; store argument length
	add di, sizeArgCmd

	inc word [ _argsStored + bp ]
	dec word [ _args + bp ]				; more args allowed ?
	jle _buildArgArray_36				; no -->


		; test lead character
	lodsb						; get next character
	or al, al					; end of line ?
	jz _buildArgArray_36				; yes, end of arg -->

	mov ah, byte [ si ]				; look ahead
	cmp ax, '>>'					; redirect ?
	jnz _buildArgArray_18				; yes, go process -->

	inc si
	mov word [ arglength - sizeArgCmd + di ], 2
	jmp _buildArgArray_06

_buildArgArray_18:
	mov word [ arglength - sizeArgCmd + di ], 1
	call _CmndParse_SeparatorCheck			; parse break ?
	jz _buildArgArray_06				; yes, record argument -->


		; accept all characters until next separator
_buildArgArray_22:
	cmp al, doubleQuote				; quote character ?
	jnz _buildArgArray_24				; no ->
	not word [ _insideQuotes + bp ]			; set inside quotes flag

_buildArgArray_24:
	lodsb						; get next character
	or al, al					; end of line ?
	jz _buildArgArray_30				; yes, end of arg -->

	cmp word [ _insideQuotes + bp ], 0		; inside quotes ?
	jnz _buildArgArray_22				; yes, no break characters -->

	cmp al, ' '					; space break ?
	jz _buildArgArray_30				; yes, skip whitespace -->
	cmp al, byte [ _SwitchChar ]			; switch character ?
	jz _buildArgArray_30				; yes, record argument -->
	call _CmndParse_SeparatorCheck			; parse break ?
	jnz _buildArgArray_22				; no -->


		; accept all characters until next separator
_buildArgArray_30:
	push ax
	dec si						; don't include separator char
	mov ax, si					; compute length of argument
	sub ax, word [ argpointer - sizeArgCmd + di ]
	mov word [ arglength - sizeArgCmd + di ], ax

	pop ax
	cmp al, ' '					; space break ?
	jz _buildArgArray_06				; yes, skip whitespace -->

	or al, al
	jnz _buildArgArray_14


		; return
_buildArgArray_36:
	xor ax, ax
	stosw						; store argument pointer
	stosw						; store argument length
	stosw						; store argument pointer
	stosw						; store argument length

	getarg ax, _argsStored
	getarg di, _argTableStart
	cmp word [ argpointer + di ], 0			; args passed ?
	Return


		; Split arguments
		;
		; This routine detects and corrects concatenated args.
		;
		; Some args are passed in the arg array as a single arg but
		; in fact they need to be split up, as in 'cd..'
		;
		; Usage:
		; ds:di-> argument array
SplitArgs:

	Entry
	def	_argarray, di				; pointer to args
	def	_cmdstarts, di


	mov si, word [ argpointer + di ]		; get argument
	mov cx, word [ arglength + di ]			; arg length
	or si, si					; args passed ?
	jz _SplitArgs_36				; none -->

		; parse command
_SplitArgs_12:
	lodsb
	or al, al					; null ?
	jz _SplitArgs_36				; end of search -->
	cmp al, ' '+1					; space or other break ?
	jc _SplitArgs_36				; end of search -->
	cmp al, '\'					; dir break ?
	jz _SplitArgs_16				; yes, split arg -->
	cmp al, '.'					; period break ?
	jz _SplitArgs_16				; yes, split arg -->
	cmp al, doubleQuote				; double quotes ?
	jz _SplitArgs_16				; yes, split arg -->
	cmp al, singleQuote				; single quotes ?
	jz _SplitArgs_16				; yes, split arg -->

	loop _SplitArgs_12				; continue if none of the above -->
	jmp short _SplitArgs_36


		; insert arg
_SplitArgs_16:
	sub word [ arglength + di ], cx			; subtract from length of current arg

	dec si						; arg pointer
	add di, sizeArgCmd				; insert after current arg
	call insertarg					; insert arg


		; return
_SplitArgs_36:
	getarg di, __cmdstarts				; pointer to args
	Return


		; Command parse separator check
		;
		; Usage:
		; al = character from parser
		;
		; Returns:
		; ZR if al is a separator character
_CmndParse_SeparatorCheck:

	push es
	push di
	push cx

	setES cs
	mov di, _CmndParse_Separators
	mov cx, _CmndParse_SeparatorsLength
	repne scasb

	pop cx
	pop di
	pop es
	retn


		; Scan and assign redirection
		;
		; Usage:
		; ss:di-> argument array
		; ss:bx-> Execution Control Block
_assignRedirectedDevices:

	Entry
	def	_argarray, di				; argument array
	def	_contargarray, di			; continue argument array
	def	_execCtrlBlock, bx			; execution control block


		; scan remainder of command line for pipe and redirection arguments
_assignRedirect_06:
	getarg di, __contargarray			; continue argument array

_assignRedirect_08:
	mov si, word [ argpointer + di ]
	or si, si					; end of args ?
	ifz _assignRedirect_36				; yes -->

	mov ax, word [ si ]				; get argument assignment
	cmp ax, '>>'					; append to StdOut ?
	ifz _assignRedirect_AppendStdOut		; yes -->
	cmp al, '>'					; StdOut ?
	jz _assignRedirect_StdOut			; yes -->
	cmp al, '<'					; StdIn ?
	jz _assignRedirect_StdIn			; yes -->
	cmp al, '|'					; pipe ?
	ifz _assignRedirect_Pipe			; yes -->

	add di, sizeArgCmd				; advance over command index
	jmp short _assignRedirect_08			; go to next -->


		; StdOut
_assignRedirect_StdOut:
	mov byte [ si ], 00				; set a null at terminator
	storarg __contargarray, di			; continue argument array
	call deletearg					; kill '>' arg

	mov bx, word [ __execCtrlBlock + bp ]		; execution control block
	lea dx, [ exCtrlStdOutFileName + bx ]		; offset to filename
	call _asgnGetFileName				; argument to dx

	ExCreateFile dx, ATTR_NORMAL
	ifc _assignRedirect_Error			; just display error -->

	push ax
	mov bx, ax
	mov cx, STDOUT
	call _assignGetCurrHandle

	getarg di, __execCtrlBlock
	mov word [ exCtrlStdOutHandle + di ], ax	; save old handle
	Int21 ForceFileHandle				; redirect stdout

	pop bx						; this close frees file handle after
	Int21 CloseFile					; force replicate handle
	jmp _assignRedirect_06


		; StdIn
_assignRedirect_StdIn:
	mov byte [ si ], 00				; set a null at terminator
	storarg __contargarray, di			; continue argument array
	call deletearg					; kill '<' arg

	mov bx, word [ __execCtrlBlock + bp ]		; execution control block
	lea dx, [ exCtrlStdInFileName + bx ]		; offset to filename
	call _asgnGetFileName				; arg to dx

	ExOpenFile dx, OPEN_ACCESS_READONLY		; open read only
	ifc _assignRedirect_Error			; just display error -->

	mov bx, ax
	mov cx, STDIN
	call _assignGetCurrHandle
	getarg di, __execCtrlBlock
	mov word [ exCtrlStdInHandle + di ], ax		; save old handle
	Int21 ForceFileHandle				; redirect stdout

	jmp _assignRedirect_06


		; pipe
_assignRedirect_Pipe:
	mov byte [ si ], 00				; set a null at terminator
	storarg __contargarray, di			; continue argument array
	mov word [ argpointer + di ], 0			; place an end marker in arg list
	mov word [ arglength + di ], 0			; place an end marker in arg list

	mov bx, word [ __execCtrlBlock + bp ]		; execution control block
	lea bx, [ exCtrlStdOutFileName + bx ]		; offset to filename
	mov byte [ bx ], 0

	mov dx, bx
	mov cx, OPEN_ACCESS_READWRITE			; create read/write
	Int21 CreateUniqueFile				; if not found, create
	ifc _assignRedirect_Error			; just display error -->

	push ax
	mov bx, ax
	mov cx, STDOUT
	call _assignGetCurrHandle

	getarg di, __execCtrlBlock
	mov word [ exCtrlStdOutHandle + di ], ax	; save old handle
	Int21 ForceFileHandle				; redirect stdout

	pop bx						; this close frees file handle after
	Int21 CloseFile					; force replicate handle

	getarg di, __contargarray			; continue argument array
	getarg bx, __execCtrlBlock			; execution control block
	mov word [ exCtrlArgArray + _pointer + bx ], di
	or word [ exCtrlFlags + bx ], exCtrlPiped	; say arg is piped.
	jmp _assignRedirect_36				; exit -->


		; append StdOut
_assignRedirect_AppendStdOut:
	mov byte [ si ], 00				; set a null at terminator
	storarg __contargarray, di			; continue argument array
	call deletearg					; kill first '>' argument
	call deletearg					; kill second '>' argument

	mov bx, word [ __execCtrlBlock + bp ]		; execution control block
	lea dx, [ exCtrlStdOutFileName + bx ]		; offset to filename
	call _asgnGetFileName				; arg to dx

	ExCreateFile dx					; create NORMAL
	jc _assignRedirect_Error			; just display error -->

	push ax
	xor cx, cx
	xor dx, dx
	mov bx, ax
	Int21 MoveFilePointer, SEEK_END			; point to end of file

	mov cx, STDOUT
	call _assignGetCurrHandle
	getarg bx, __execCtrlBlock
	mov word [ exCtrlStdOutHandle + bx ], ax	; save old handle

	pop bx
	push bx
	Int21 ForceFileHandle				; redirect stdout

	pop bx
	Int21 CloseFile

	jmp _assignRedirect_06


		; redirection error
_assignRedirect_Error:
	call DisplayErrorCode
	stc

		; return
_assignRedirect_36:
	getarg di, __argarray				; argument array
	Return


		; Get current file handle
		;
		; INP:	cx = requested handle number
		; OUT:	ax = value of this handle
_assignGetCurrHandle:

	push es
	push si
	push bx
	push cx
	Int21 GetPSPAddress

	pop si						; restore handle offset
	mov es, bx					; PSP address

	mov al, -1					; in case of error
	cmp si, [ es:pspFileHandleCount ]
	jae _assignGetCurrHandle_08			; If handle doesn't point into the PSP handle table -->

	les bx, [ es:pspFileHandlePtr ]			; point to file handles
	mov al, byte [ es:bx + si ]			; recover existing handle

_assignGetCurrHandle_08:
	xor ah, ah

	pop bx
	pop si
	pop es
	retn


		; Get filename from a piped or redirected argument
		;
		; Usage:
		; ds:di-> argument list
		; es:dx-> destination where to copy arg
		;
		; the argument is removed from the argument list (it is deleted) once copied
_asgnGetFileName:

	push ax
	push dx
	push di
	call fixDoubleQuotes				; remove excess double quotes
	mov cx, word [ arglength + di ]			; get length
	mov si, word [ argpointer + di ]		; get current arg

	mov di, dx
	repe movsb					; move string

	xor ax, ax
	stosb						; null terminate

	pop di
	call deletearg					; kill argument

	pop dx
	pop ax
	retn


		; Close redirected Std device
		;
		; Usage:
		; al = value to restore handle to (-1 to skip closing)
		;      (handle is only closed if al<>value in the application table)
		; bx = StdOut or StdIn
_CloseRedirectedDevice:

	Entry
	def	RestoreValue, ax
	def	Handle, bx
	push es

	cmp al, -1					; Std device redirected ?
	jz _closeRedirect_42				; no -->

	Int21 GetPSPAddress
	mov es, bx					; PSP address

	mov bx, word [ _Handle + bp ]
	cmp bx, [ es:pspFileHandleCount ]
	jae _closeRedirect_42				; If handle doesn't point into the PSP handle table -->
	les si, [ es:pspFileHandlePtr ]			; point to file handles
	add si, bx					; add offset

	cmp al, byte [ es:si ]				; same as existing handle ?
	jz _closeRedirect_42				; yes, no need to close -->

	push es
	push si
	mov bx, word [ _Handle + bp ]
	Int21 CloseFile					; close Std device

	pop si
	pop es						; point to file handles
	mov ax, word [ _RestoreValue + bp ]		; restore handle
	mov byte [ es:si ], al

_closeRedirect_42:
	pop es
	Return


		; Lookup command from argument
		;
		; Usage:
		; cs:di-> supported commands
		; ds:si-> argument (term by a null or switch char)
		; cx = length of argument
		;
		; Returns:
		; CY if argument not supported internally
		;  cs:bx-> code that displays "invalid command" message
		; NC if argument is inside the command table
		;  cs:bx-> command execution address
CmndLookup:

	push di
	push si
	push cx
	add di, 4					; point to arg text

	mov al, byte [ si ]				; from command
	cmp al, ' '+1					; out of range ?
	jc cmndLookup_28				; yes -->
	cmp al, 128					; out of range ?
	jnc cmndLookup_28				; yes -->


		; compare argument against table
cmndLookup_12:
	mov al, byte [ si ]				; from command
	_lowerCase al

	cmp al, ' '+1
	jc cmndLookup_22
	cmp al, '\'
	jz cmndLookup_22
	cmp al, '.'
	jz cmndLookup_22
	cmp al, doubleQuote
	jz cmndLookup_22
	cmp al, singleQuote
	jz cmndLookup_22
	call _CmndParse_SeparatorCheck
	jz cmndLookup_22

	cmp al, byte [ cs:di ]				; compare
	jnz cmndLookup_28				; if not this command -->

	inc si
	inc di						; else keep looking
	loop cmndLookup_12

cmndLookup_22:
	cmp byte [ cs:di ], 0				; end of command ?
	jnz cmndLookup_28				; no, so not a match -->

		; argument found
	pop cx
	pop ax						; leave si pointing at end
	pop di
	mov bx, word [ cs:di ]				; where to execute
	clc						; NC
	retn


		; find next entry in table
cmndLookup_28:
	pop cx
	pop si
	pop di
	add di, word [ cs:di + 2 ]			; point to next command
	cmp word [ cs:di ], -1				; end of command table ?
	jnz CmndLookup					; no, lookup next -->

	stc
	mov bx, _NotValidCommand			; default not valid command
	retn


		; Installable Command Interface
		;
		; Usage:
		; ss:di-> argument array
		;
		; Returns:
		; NZ if command executed
		;
		; NOP
checkInstallableCommandInterface:

%if 1
	xor ax, ax
	retn
%else
	entry
	defbytes	commandline, 128+2		; \-
	defbytes	commandname, 128		; /- do not change their order
	mov byte [ bp + _commandline ], 127		; maximal length = 127
	push es
	push ds
	setes ss
	setds ss

	push di
	push si
	push cx
	mov si, di
	mov cx, word [ si + arglength ]
	mov si, word [ si + argpointer ]
	cmp cx, byte 7Fh				; 127/7Fh characters maximal
	ja .dontprocess					; command name too long -->
	lea di, [ bp + _commandname + 1 ]
	mov byte [ di - 1 ], cl				; fill in command name length
	push cx
	push di
	repz movsb					; copy command name
	pop di
	pop cx
.searchpath:
	mov al, byte [ di ]
	cmp al, "\"					; DOS style path seperator
	je .dontprocess					; found at least one, don't pass paths -->
	cmp al, "/"					; Unix style path seperator
	je .dontprocess					; found at least one, don't pass paths -->
	_uppercase al
	stosb
	loop .searchpath				; keep looking for path characters and uppercase -->
	pop cx
	pop si
	pop di
	push di
	push si
	push cx
	xor ax, ax
	lea bx, [ bp + _commandline + 2 ]
.addarguments:
	add di, sizeArgCmd				; point to next argument
	mov si, word [ di + argpointer ]
	mov cx, word [ di + arglength ]
	or si, si
	jz .allarguments				; zero terminator at end -->
	add ax, cx
	jc .dontprocess					; catch overflows
	cmp ax, byte 7Fh-1				; -1 for space
	ja .dontprocess					; too long!
	inc ax						; include space
	push di
	inc bx
	mov di, bx
	add bx, cx
	mov byte [ di - 1 ], 32				; space to seperate the arguments
	repz movsb					; copy this argument
	pop di
	mov byte [ bp + _commandline + 1 ], al		; update actual character counter
	
	jmp short .addarguments				; keep doing for all arguments -->

.allarguments:
	mov byte [ bx ], 13				; terminate command line with CR
	lea bx, [ bp + _commandline ]
	lea si, [ bp + _commandname ]
	mov ax, 0AE00h					; installable command interface: check if command there
	mov dx, 0FFFFh
	mov cx, dx
	xor di, di
	int 2Fh
	or al, al
	jz .dontprocess					; no thanks, no TSR hooked that command name -->

	mov ax, 0AE01h
	int 2Fh						; else we're welcome to execute

	lodsb
	cmp al, 0
	jz .dontrun					; if length byte set to 0, nothing to do -->
	xchg ax, si

	pop cx
	pop si
	pop di
	push di
	push si
	push cx

	xchg ax, si
	push si
	push bx
	xor bx, bx
	mov bl, al
	lea si, [ si + bx ]
	pop bx
	mov byte [ si ], 32
	inc si
	push di
	xchg si, di					; di-> end of command name buffer
	mov si, bx
	xor cx, cx
	inc si
	mov cl, byte [ si ]				; actual characters in command line
	inc si						; si-> start of command line buffer
	repz movsb					; create complete command line at command name buffer
	xor ax, ax
	stosb						; zero terminate
	pop di						; di-> argument array
	pop si						; si-> start of that complete command line

	push di
	mov di, word [ di + argpointer ]		; initial caller's command line buffer
	mov cx, 256					; size of initial caller's buffer
	push di
	repz movsb					; overwrite initial caller's buffer
	pop si						; si-> initial caller's buffer
	pop di						; di-> initial caller's argument array
	mov cx, maxArgArray - 2				; number of argument array entries
	call _BuildArgArray				; re-build array from TSR's returned command line

	


	

	

.dontrun:
	xor ax, ax
	dec ax						; NZ I guess
	jmp short .end

.dontprocess:
	xor ax, ax

.end:
	pop cx
	pop si
	pop di
	pop ds
	pop es
	return
	
	
	return
%endif


		; Count number of arguments
		;
		; Usage:
		; ss:di-> argument array
		;
		; Returns:
		; ax = number of arguments in argument array
CountArgs:
	push es
	push di
	push cx

	mov cx, maxArgArray				; max number of entries

CountArgs_06:
	cmp word [ argpointer + di ], 0			; terminating argument ?
	jz CountArgs_08					; yes, done -->
	add di, sizeArgCmd				; next argument
	loop CountArgs_06				; else, keep looking -->
		; invalid argument array passed if here

CountArgs_08:
	mov ax, maxArgArray
	sub ax, cx					; # arguments

	pop cx
	pop di
	pop es
	retn


		; Check number of arguments
		;
		; Usage:
		; ss:di-> argument array
		;
		; Returns:
		; CY if wrong number of arguments, message displayed

CheckNoArgs:
	xor dx, dx					; no arguments
		; dx zero implies cx zero as well.
	xor bx, bx					; no switches
	jmp short PreProcessCmndLine			; check

CheckOneArg:
	mov cx, 1					; must have one argument
	mov dx, 1					; must have one argument
	xor bx, bx					; no switches
	jmp short PreProcessCmndLine			; check

CheckOptOneArg:
	xor cx, cx					; allowed to have no arguments
	mov dx, 1					; or one argument
	xor bx, bx					; no switches
							; fall through to check

		; Pre-process command line
		;
		; Usage:
		; ss:di-> argument array
		; cx = accepted minimal number of arguments
		; dx = accepted maximal number of arguments
		; if bx<>0, cs:bx-> switches
		;
		; Returns:
		; CY if wrong number of arguments, message displayed
PreProcessCmndLine:

	push di
	push cx
	push dx

	call _GetSwitches				; switches ok ?
	jc _preProcessCmndLine_12			; no -->

	pop dx
	pop cx
	push dx
	push cx
	call ConsolidateArgs				; just in case quotes were missed
	call _TooManyArguments				; too many still left ?

	call FixUpArguments				; null terminate args
	or ax, ax					; how many args passed
		; This actually clears CF always.

_preProcessCmndLine_12:
	pop dx
	pop cx
	pop di
	retn


		; Tests for too many arguments
		;
		; Usage:
		; ss:di-> argument array
		; ax = actual argument count
		; cx = accepted minimal number of arguments
		; dx = accepted maximal number of arguments
		;
		; Returns:
		; CY if wrong number of arguments, message displayed
_TooManyArguments:

	push di
	push ax
	push cx

	cmp ax, dx
	jz _TooManyArguments_16				; if expected number of arguments -->
	ja _TooManyArguments_06				; if greater than expected -->

	cmp ax, cx
	jae _TooManyArguments_16			; if within min/max

	mov dx, CmndError_ParametersMissing		; if not enough, just display message
	jmp short _TooManyArguments_08

_TooManyArguments_06:
	mov dx, CmndError_TooManyParameters		; if too many, display message and unexpected argument
	call DisplayLine

	pop cx
	push cx
	add cx, cx
	add di, cx					; argument pointer that is extra
	mov dx, word [ ss:di ]				; get argument address

_TooManyArguments_08:
	call DisplayLine				; show argument not expected
	stc

_TooManyArguments_16:
	pop cx
	pop ax
	pop di
	retn


		; Consolidate command line arguments
		;
		; Usage:
		; ss:di-> argument array
		; cx = accepted minimal number of arguments
		; dx = accepted maximal number of arguments
		; ax = arguments counted
		;
		; All registers preserved
		;
		; When a command that usually accepts a single argument
		; detects multiple arguments, it will attempt to bundle these
		; arguments together under certain "common-sense" rules:
		;
		; - The previous argument DOES NOT terminate with double quotes
		;
		; - The current argument DOES NOT start with double quotes, \ (or \\), dot or x:
		;
		; Examples where arguments are merged:
		; (the hyphens show which parts are returned as single arguments)
		;
		; >cmd c:\aaa\bbbb ccc\dddd eeee\foo.bat
		;      ---------------------------------
		; >dir aaaa bbb ccc
		;      ------------
		;
		; Examples where arguments are NOT merged:
		;
		; >cmd c:\aaa\bbbb ccc\dddd d:\eeee\foo.bat
		;      -------------------- ---------------
		; >cmd c:\aaa\bbbb ccc\dddd \eeee\foo.bat
		;      -------------------- -------------
		; >cmd "c:\aaa\bbbb ccc\dddd" eeee\foo.bat
		;      ---------------------- ------------
		;
ConsolidateArgs:

	SaveRegisters di, si, dx, cx, bx

	call CountArgs

	cmp dx, 1					; maximal one argument ?
	jne _consolidateArgs_24				; no, skip consolidation -->
	cmp ax, 1					; more than one argument passed ?
	jbe _consolidateArgs_24				; no, nothing to consolidate -->

		; loop through arguments
_consolidateArgs_08:
	add di, sizeArgCmd				; start with next arg

_consolidateArgs_12:
	mov si, word [ argpointer + di ]
	or si, si					; at end ?
	jz _consolidateArgs_24				; return -->

	mov bx, word [ argpointer - sizeArgCmd + di ]
	add bx, word [ arglength - sizeArgCmd + di ]
	cmp byte [ bx - 1 ], doubleQuote		; previous command ended in double quotes ?
	jz _consolidateArgs_08				; do not consolidate -->

	cmp byte [ si ], '\'				; starts with \ ?
	jz _consolidateArgs_08				; do not consolidate -->
	cmp byte [ si ], '.'				; starts with dot ?
	jz _consolidateArgs_08				; do not consolidate -->
	cmp byte [ si ], doubleQuote			; starts with double quotes ?
	jz _consolidateArgs_08				; do not consolidate -->
	cmp byte [ si + 1 ], ':'			; drive specification ?
	jz _consolidateArgs_08				; do not consolidate -->

	add si, word [ arglength + di ]			; point to end of this argument
	sub si, word [ argpointer - sizeArgCmd + di ]	; length of argument that is created by merging
	mov word [ arglength - sizeArgCmd + di ], si	; update length of previous argument
	call deletearg					; delete the current argument
	jmp _consolidateArgs_12				;  and loop to next

_consolidateArgs_24:
	RestoreRegisters bx, cx, dx, si, di

	call CountArgs
	retn


		; Test/Process switches
		;
		; Usage:
		; ss:di-> argument array
		; bx = switches to process (or null)
		;
		; Returns:
		; CY if invalid use of switches
		;
		; Otherwise, switch array passed is filled with info.
		;
		; Switch array consists of a switch letter followed by:
		;
		; 'x'	switch letter
		; flags	type of data value expected
		; min	minimal value expected
		; max	maximal value expected
		; actual	actual value passed in command
		;
		; a flag bit is set if the flag was encountered in command
_GetSwitches:

	Entry
	def	switches, bx

	push di
	push si
	push cx

	or bx, bx					; switches expected ?
	jz _getSwitches_06				; no -->
	call _initSwitchTable				; init switches expected


		; walk through all args
_getSwitches_06:
	mov si, word [ argpointer + di ]		; get arg
	or si, si					; is it a null arg ?
	jz _getSwitches_36				; yes, exit -->

	mov al, byte [ si ]				; get value at arg
	cmp al, byte [ _SwitchChar ]			; switch argument ?
	jnz _getSwitches_12				; no -->

	getarg bx, _switches
	or bx, bx					; any switches allowed ?
	jz _getSwitches_24				; if not allowed, drop from list

	mov ax, word [ si + 1 ]				; get switch characters
	call _matchSwitch				; is this switch valid ?
	jc _getSwitches_24				; not allowed -->

	or word [ swFlags + bx ], SW_SWITCHSET		; switch is set
	call deletearg					; remove this argument
	jz _getSwitches_36				; if no more args -->
	jmp _getSwitches_06

_getSwitches_12:
	add di, sizeArgCmd
	jmp _getSwitches_06


		; switch is illegal
_getSwitches_24:
	push si						; save argument ptr
	mov dx, CmndError_BadSwitch
	call DisplayLine				; error message

	pop dx
	call DisplayLine				; show arg
	stc


		; done
_getSwitches_36:
	pop cx
	pop si
	pop di
	Return


		; Match switch
		;
		; Usage:
		; al = character
		; cs:bx-> switch table
		;
		; Returns:
		; cs:bx-> matching switch entry
		; CY if match not found
_matchSwitch:

	_lowerCase al

_matchSwitch_04:
	cmp byte [ cs:bx ], -1				; end of table ?
	jnz _matchSwitch_06				; not yet -->
	stc
_matchSwitch_08:
	retn

_matchSwitch_06:
	cmp al, byte [ cs:bx ]
	je _matchSwitch_08				; match --> (NC)

	add bx, sizeSWITCHENTRY				; next entry
	jmp short _matchSwitch_04


		; Init switch table
		;
		; Usage:
		; cs:bx-> switch table
_initSwitchTable:

	push bx

_initSwitchTable_04:
	cmp byte [ cs:bx ], -1				; end of table ?
	jz _initSwitchTable_08				; yes, all done -->
	and word [ cs:bx + swFlags ], ~ SW_SWITCHSET	; clear "switch set" flag
	add bx, sizeSWITCHENTRY				; next entry
	jmp _initSwitchTable_04

_initSwitchTable_08:
	pop bx
	retn


		; Remove loose switches
		;
		; Input:
		; ds:di-> command line aguments array
		;
		; Return:
		; ax = updated number of args
		;
		; CHG:	si, cx, ax
removeLooseSwitches:

	Entry
	def	_argarray, di

removeLooseSwitches_08:
	mov si, word [ di + argpointer ]
	mov cx, word [ di + arglength ]
	or si, si					; at end of commands ?
	jz removeLooseSwitches_24			; yes -->

	add di, sizeArgCmd
	mov al, byte [ si ]				; get value at arg
	cmp al, byte [ _SwitchChar ]			; switch arg ?
	jnz removeLooseSwitches_08			; no -->

	sub di, sizeArgCmd				; restore pointer to switch
	call deletearg					; delete it
	jmp removeLooseSwitches_08

removeLooseSwitches_24:
	mov ax, di
	sub ax, word [ __argarray + bp ]		; determine number of arguments
	shr ax, 1
	shr ax, 1

	getarg di, __argarray				; restore argarray
	Return


		; Delete argument
		;
		; Usage:
		; ss:di-> argument list
deletearg:

	push di
	cmp word [ argpointer + di ], 0			; at end of list ?
	jz deletearg_12					; yes --> (this is an error condition)

		; move down all following arguments until two null arguments reached
deletearg_08:
	mov ax, word [ argpointer + sizeArgCmd + di ]
	mov dx, word [ arglength + sizeArgCmd + di ]
	mov word [ argpointer + di ], ax		; move pointer
	mov word [ arglength + di ], dx			; and length
	add di, sizeArgCmd				; next arg
	or ax, ax					; any more ?
	jnz deletearg_08				; yes -->

	cmp word [ argpointer + di ], 0			; two null terminators ?
	jnz deletearg_08				; not yet -->

	mov word [ argpointer + di ], 0
	mov word [ arglength + di ], 0

deletearg_12:
	pop di
	cmp word [ argpointer + di ], 0			; at end of list ?
	retn


		; Insert Argument
		;
		; Usage:
		; ss:di-> argument list (insert at this address)
		; si = address value to insert
		; cx = length to insert
insertarg:

	push di
	push si
	push cx

_insertarg_12:
	xchg si, word [ argpointer + di ]
	xchg cx, word [ arglength + di ]
	add di, sizeArgCmd

	mov ax, cx
	or ax, word [ sizeArgCmd + di ]		; 2nd null follows ?
	jnz _insertarg_12				; no, keep inserting -->

	mov word [ argpointer + di ], ax		; make sure we put two NULLS
	mov word [ arglength + di ], ax
	mov word [ argpointer + di ], ax		; make sure we put two NULLS
	mov word [ arglength + di ], ax

	pop cx
	pop si
	pop di
	retn


		; Fix up arguments
		;
		; Usage:
		; ss:di-> argument list
		;
		; Will place a null terminator at the end of each argument
		; and will remove any embedded double quotes.
FixUpArguments:

	Entry
	def	_argarray, di

	push di
	push ax
	push bx

		; walk through all arguments
fixUpArguments_04:
	getarg di, __argarray
	mov si, word [ argpointer + di ]
	or si, si					; more args ?
	jz fixUpArguments_56				; no -->

	call fixDoubleQuotes				; scan and remove double quotes in arg


		; place a terminating null (even if must make room for it)
fixUpArguments_16:
	xor ax, ax
	getarg di, __argarray
	mov si, word [ argpointer + di ]
	add si, word [ arglength + di ]
	cmp byte [ si ], 0				; already a term null ?
	jz fixUpArguments_42				; yes -->

	cmp byte [ si ], ' '				; can overwrite space ?
	jz fixUpArguments_40				; yes -->
	cmp byte [ si ], ','				; can overwrite comma ?
	jz fixUpArguments_40				; yes -->


		; must insert character
fixUpArguments_22:
	xchg al, byte [ si ]
	inc si
	or al, al
	jnz fixUpArguments_22

	getarg di, __argarray
	mov byte [ si ], 0				; store term null

fixUpArguments_24:
	add di, sizeArgCmd
	cmp word [ argpointer + di ], 0000
	jz fixUpArguments_42

	inc word [ argpointer + di ]			; fix address (inserted value)
	jmp short fixUpArguments_24


		; ok to overwrite character
fixUpArguments_40:
	mov byte [ si ], 0				; set null terminator

fixUpArguments_42:
	add word [ __argarray + bp ], sizeArgCmd
	jmp short fixUpArguments_04			; loop until all arguments done -->


		; done
fixUpArguments_56:
	pop bx
	pop ax
	pop di

	or ax, ax
	Return


		; Fix double quotes in arguments
		;
		; Usage:
		; ss:di-> argument list
fixDoubleQuotes:

	Entry
	def	_argarray, di

	mov si, word [ argpointer + di ]		; pointer
	mov cx, word [ arglength + di ]			; get length
	or cx, cx					; zero length string ?
	jz fixDoubleQuote_16				; yes, no more to scan -->

	mov di, si

fixDoubleQuote_08:
	mov al, doubleQuote
	repne scasb					; double quote in argument ?
	jnz fixDoubleQuote_16				; if no double quotes left -->

	push cx						; length remaining
	push di						; scan pointer

	mov si, di					; copy si --> di
	dec di
	repz movsb

	mov byte [ di ], 0

	getarg di, __argarray
	dec word [ arglength + di ]

	pop di
	pop cx
	dec cx						; cx = (number of characters remaining)-1
							;  if at least one character remains, check it (cx >= 0)

	jns fixDoubleQuote_08				; if !cx&8000h (cx >= 0) -->

fixDoubleQuote_16:
	getarg di, __argarray
	Return


		; Check Unix style commands
		;
		; Returns:
		; ZR if environment string contains RXDOS=UNIX (Unix commands)
		; NZ if environment string not found (no Unix commands)
checkUnixStyleCommands:

	push es
	mov si, RxDOS_RxDOSSpec				; locate RXDOS=
	call searchEnvVariable				; env variable located ?
	jnz _checkUnixEnv_16				; if no unix cmds -->

	mov es, word [ _EnvSegment ]			; point to segment
	add di, dx					; point to value
	mov si, RxDOS_UNIXSpec

_checkUnixEnv_08:
	mov al, byte [ es:di ]				; from env string
	_upperCase al

	cmp al, byte [ si ]				; compare against string
	jnz _checkUnixEnv_16				; if no unix cmds -->

	inc si
	inc di
	cmp byte [ si ], 00				; end of string ?
	jnz _checkUnixEnv_08				; not yet -->

_checkUnixEnv_16:
	pop es
	retn


		; Save batch file arguments
		;
		; Usage:
		; ss:si-> null terminated string
		; ss:di-> argument array
		; ss:dx-> fully expanded pathname
		; ax = type (must be _BAT)
		;
		; Returns:
		; CY if error
_saveBatchArguments:

	Entry
	def	_argarray, di
	def	_pathArg, dx
	def	_type, ax
	def	_tempargptr, di

	cmp ax, _BAT					; is type BATCH
	jnz _saveBatchArguments_Error			; no -->


		; if file accessible ?
_saveBatchArguments_08:
	cmp word [ RxDOS_StackFrameNumEntries ], 0
	ja _saveBatchArguments_10			; don't close if nested call -->

	mov bx, word [ RxDOS_BatchFile + batchFileHandle ]
	or bx, bx					; batch file in progress ?
	jz _saveBatchArguments_10			; no -->
	Int21 CloseFile					; close current batch file
	mov word [ RxDOS_BatchFile + batchFileHandle ], 0

_saveBatchArguments_10:
	getarg si, __pathArg
	ExOpenFile si, OPEN_ACCESS_NOINHERIT+OPEN_ACCESS_READONLY
	jc _saveBatchArguments_Error			; if can't open, quit batch file -->
	mov word [ RxDOS_BatchFile + batchFileHandle ], ax


		; is file accessible ?
	xor bx, bx
	mov word [ RxDOS_BatchFile + batchNumArgs ], bx
	mov di, RxDOS_BatchFile + batchArgStore

_saveBatchArguments_32:
	mov word [ RxDOS_BatchFile + batchArgPtrs + bx ], 0

	getarg si, __tempargptr
	add word [ __tempargptr + bp ], sizeArgCmd
	mov cx, word [ arglength + si ]			; length
	mov si, word [ argpointer + si ]		; argument pointer
	or si, si					; null terminator ?
	jz _saveBatchArguments_Exit			; then all done -->

	inc word [ RxDOS_BatchFile + batchNumArgs ]
	mov word [ RxDOS_BatchFile + batchArgPtrs + bx ], di
	inc bx
	inc bx

	repz movsb					; copy string
	xor ax, ax
	stosb						; terminate with a null
	jmp short _saveBatchArguments_32

_saveBatchArguments_Error:
	stc

_saveBatchArguments_Exit:
	getarg di, __argarray
	getarg dx, __pathArg
	getarg ax, __type
	Return


		; Replace environment variables
		;
		; Usage:
		; ss:si-> null terminated string
		;
		; Returns:
		; cx = length of new string
ReplaceTempVariables:

	Entry
	def	stringPointer, si
	def	deleteFrom
	defbytes	tempVar, 128

	push di
	push si

		; scan for % argument
_replaceTempVar_08:
	lodsb						; scan for % symbol
	or al, al					; null terminator ?
	ifz _replaceTempVar_36				; yes -->
	cmp al, '%'					; percent character ?
	jnz _replaceTempVar_08

	mov al, byte [ si ]				; get character immediately after
	or al, al					; null terminator ?
	ifz _replaceTempVar_36				; yes -->

	cmp al, '%'					; %% case ?
	jz _replaceTempVar_PercentPercent		; yes, replace by single % -->

	dec si						; backup over %
	cmp al, '9'+1					; outside arg values ?
	jnc _replaceTempVar_EnvVariable			; yes -->
	sub al, '0'					; outside argument values ?
	jc _replaceTempVar_EnvVariable			; yes -->


		; numeric argument
	mov cx, 2					; bytes to delete
	call deleteString				; delete cx bytes at si

	xor ah, ah
	cmp ax, word [ RxDOS_BatchFile + batchNumArgs ]	; argument number available ?
	jae _replaceTempVar_16				; just delete argument -->

	add ax, ax					; index pointer
	mov di, ax
	mov di, word [ RxDOS_BatchFile + batchArgPtrs + di ]
	or di, di
	jz _replaceTempVar_16				; if no arg value -->
	call insertString				; insert arg at [ di ]

_replaceTempVar_16:
	jmp short _replaceTempVar_08


		; %% case
_replaceTempVar_PercentPercent:
	mov cx, 1
	call deleteString				; delete cx bytes at [ si ]
	jmp short _replaceTempVar_08


		; environment variable
_replaceTempVar_EnvVariable:
	lea di, [ _tempVar + bp ]
	storarg _deleteFrom, si
	inc si						; skip init %

_replaceEnvVariable08:
	lodsb						; scan for next % symbol
	stosb						; save at _tempvar
	or al, al					; null terminator ?
	jz _replaceTempVar_36				; yes -->
	cmp al, '%'					; percent character ?
	jnz _replaceEnvVariable08			; keep searching -->

	mov word [ di-1 ], '='				; cancel trailing %

	mov cx, si
	sub cx, word [ _deleteFrom + bp ]		; delete from
	push si
	push cx						; delete length

	lea si, [ _tempVar + bp ]
	call searchEnvVariable				; environment string found ?

	pop cx
	push cx						; length to delete
	mov si, word [ _deleteFrom + bp ]		; delete from
	call deleteString				; delete cx bytes at si

	push ds
	mov si, di
	add si, dx					; contents of variable
	mov ds, word [ _EnvSegment ]			; point to segment
	lea di, [ _tempVar + bp ]			; where to copy
	call CopyString					; copy null term string

	pop ds
	mov si, word [ _deleteFrom + bp ]		; delete from
	lea di, [ _tempVar + bp ]			; where to copy
	call insertString				; insert

_replaceEnvVariable36:
	pop cx
	pop si
	jmp _replaceTempVar_08

		; done
_replaceTempVar_36:
	xor ax, ax
	mov cx, -1
	getarg di, _stringPointer
	repne scasb
	neg cx
	sub cx, 2

	pop si
	pop di
	Return


		; Replace FOR variable
		;
		; Usage:
		; ss:si-> null terminated string
		; ss:bx-> null terminated replacement string
		; al = replacement letter
		;
		; Returns:
		; cx = length of new string
ReplaceForVariables:

	Entry
	def	stringPointer, si
	def	replaceText, bx
	_lowercase al
	def	replaceVar, ax
	push di
	push si

		; scan for % argument
_replaceForVar_08:
	lodsb						; scan for % character
	or al, al					; null terminator ?
	ifz _replaceForVar_36				; yes -->
	cmp al, '%'					; percent character ?
	jnz _replaceForVar_08				; no, continue searching -->

	mov al, byte [ si ]				; get character immediately after
	_lowerCase al
	cmp al, byte [ _replaceVar + bp ]		; same as variable requested ?
	jnz _replaceForVar_08				; not yet -->


		; replace found variable
	dec si						; backup over %x
	mov cx, 2					; bytes to delete
	call deleteString				; delete cx bytes at si

	mov di, word [ _replaceText + bp ]		; insert text
	call insertString				; insert [ di ] arg
	jmp short _replaceForVar_08


		; done
_replaceForVar_36:
	xor ax, ax
	mov cx, -1
	getarg di, _stringPointer
	repne scasb
	neg cx
	sub cx, 2

	pop si
	pop di
	Return


		; Delete String
		;
		; Usage:
		; ss:si-> inside string
		; cx = bytes to delete
deleteString:

	push di
	push ax
	push si
	push cx
	jcxz deleteString_36				; nothing to do -->

deleteString_08:
	lodsb						; test for null term
	or al, al
	jz deleteString_36
	loop deleteString_08

	pop cx
	pop si
	push si
	push cx
	mov di, si
	add si, cx					; skip pointer

	call CopyString					; copy string
	dec si						; point to null byte

deleteString_32:
	mov byte [ si ], 0

deleteString_36:
	pop cx
	pop si
	pop ax
	pop di
	retn


		; Insert string
		;
		; Usage:
		; ss:si-> inside string
		; ds:di-> insert string (null terminated)
		;
		; Returns:
		; ss:si-> character past inserted string
insertString:

	push cx
	push ax
	push di


		; compute length of insert string
	xor ax, ax
	mov cx, -1
	repne scasb					; search length of insert string

	neg cx						; make len-1 positive
	sub cx, 2					; kill null terminator
	sub di, 2					; point to last valid byte before null
	push di						; end of insert string pointer
	push cx						; length of insert string

		; compute length of master string
	xor ax, ax
	mov cx, -1
	mov di, si
	repne scasb					; search length of insert string
	neg cx						; make len-1 positive
	dec cx						; kill null terminator
	dec di

		; open string
	std						; copy reverse direction
	pop ax
	push ax						; length of insert string
	mov si, di					;
	add di, ax					; where to copy to
	repz movsb					; copy

	pop cx
	pop si
	push di						; saved end of insert string pointer
	repz movsb					; copy
	cld						; restore direction

		; done
	pop si						; return pointer - 1
	inc si

	pop di
	pop ax
	pop cx
	retn


		; Get length of string
		;
		; Input:
		; dwo:stack-> null terminated string
		;
		; Returns:
		; cx = length of string
_stringLength:

	entry 2
	darg	_string

	push es
	push di
	getdarg es, di, __string
	xor ax, ax
	mov cx, -1
	repne scasb					; search length of insert string

	not cx						; make length positive
	dec cx						; decrease for terminating null
	pop di
	pop es
	return


		; Get decimal number at string
		;
		; Input:
		; ss:si-> string
		;
		; OUT:	CY if value contained text,
		;	 ax = 0
		;	NC if value only contained digits,
		;	 ax = retrieved number
		;	 ZR if number is zero
_GetNumber:
	xor dx, dx

_GetNumber_04:
	lodsb
	cmp al, ' '+1					; end of string ?
	jc _GetNumber_16				; yes, exit ok -->

	cmp al, '9'+1					; valid number ?
	jnc _GetNumber_14				; no, error exit -->
	sub al, '0'					; valid number ?
	jc _GetNumber_14				; no, error exit -->

	and ax, 000Fh					; ah = 0, al = 0..9h (former 30h..39h)
	push ax
	mov ax, dx					; get former value
	add dx, dx					; *2
	add dx, dx					; *4
	add dx, ax					; *5
	add dx, dx					; *10
	pop ax
	add dx, ax					; add current digit
	jmp short _GetNumber_04				; continue -->

_GetNumber_14:
	xor ax, ax
	stc
	retn

_GetNumber_16:
	mov ax, dx
	or ax, ax
	retn


		; Lower case string
		;
		; Usage:
		; dwo:stack -> null terminated string
		;
		; Returns:
		; es:di-> null byte of string
		; cx = characters in string
_lowerCaseString:
	entry 2
	darg	string

	push es
	xor cx, cx
	getdarg es, di, _string

_lowerCaseString_08:
	mov al, byte [ es:di ]
	or al, al
	jz _lowerCaseString_16

	cmp al, 'A'
	jc _lowerCaseString_10
	cmp al, 'Z'+1
	jnc _lowerCaseString_10
	or al, 20h					; lower case

_lowerCaseString_10:
	mov byte [ es:di ], al
	inc di
	inc cx
	jmp short _lowerCaseString_08

_lowerCaseString_16:
	pop es
	Return


		; Compare sub-string
		;
		; Usage:
		; ds:si-> null terminated string
		; ds:di-> longer string
		;
		; Returns:
		; ZR if string at [ds:si] matches sub-string at [ds:di] case-insensitive
_compareSubString:
	lodsb
%if 1
		; Same si returned as with old code.
	dec si
	or al, al
	jz _compareSubString_08
	inc si
%else
	or al, al
	jz _compareSubString_08
%endif	

	mov bl, byte [ di ]
	inc di

	_lowerCase al
	_lowerCase bl

	cmp al, bl
	jz _compareSubString

_compareSubString_08:
	retn


		; Copy string
		;
		; INP:	ds:si-> null terminated string
		;	es:di-> destination
		; OUT:	ds:si-> behind terminator of string
		;	es:di-> behind terminator of string
CopyString:
	lodsb
	stosb						; like movsb, but character in al
	or al, al					; until terminator found
	jnz CopyString

	retn


		; Locate end of string
		;
		; Usage:
		; es:di-> null terminated string
		;
		; Returns:
		; es:di-> null terminator of string
_endofString:

	push ax
	push cx

	xor ax, ax
	mov cx, -1
	repne scasb					; locate null terminator
	dec di						; backup over null byte

	pop cx
	pop ax
	retn


		; Append path name
		;
		; Usage:
		; ds:si-> null terminated string to append
		; es:di-> null terminated string where to append
		; ds = es
_AppendPathName:

	cmp byte [ di ], 0
	jz _AppendPathName_12				; if no path given, don't search -->

	xor ax, ax
	mov cx, -1
	repne scasb					; search for terminating null

	dec di						; backup to null
	mov al, '\'
	cmp byte [ di - 1 ], al				; does path have terminating \ ?
	jz _AppendPathName_12				; yes, no need to add another -->
	stosb						; add terminating '\'

_AppendPathName_12:
	call CopyString
	retn


		; Search environment string
		;
		; INP:	ds:si-> environment variable to search (terminated by equal sign)
		; OUT:	ds:si-> behind equal sign
		;	NZ if environment variable not found,
		;	 environment:di-> zero byte
		;	 environment:di+dx-> zero byte
		;	ZR if environment variable found,
		; 	 environment:di-> keyword value in environment
		;	 environment:di+dx-> value past equal sign in environment
searchEnvVariable:

	Entry
	def	search, si				; search text
	def	envbegpointer, 0000			; located env variable

	push es
	mov es, word [ _EnvSegment ]			; point to segment
	xor di, di


		; search through each item
searchEnvVariable_08:
	storarg _envbegpointer, di			; located env variable
	getarg si, _search				; get search text pointer
	cmp byte [ es:di ], 0				; end of environment ?
	jz searchEnvNotFound				; not found -->

searchEnvVariable_12:
	mov ah, byte [ si ]
	or ah, ah					; if end of string -->
	jz searchEnvVariable_Next			; not equal, skip to next -->

	_upperCase ah

	mov al, byte [ es:di ]				; compare
	_upperCase al

	cmp ah, al					; compare
	jnz searchEnvVariable_Next			; not equal, skip to next -->

	inc si
	inc di
	cmp al, '='					; at equal sign ?
	jz searchEnvVariableFound			; we have search item -->
	cmp byte [ es:di-1 ], 0				; end of environment string ?
	jnz searchEnvVariable_12			; continue -->
	jmp short searchEnvVariable_08


		; skip to next env variable
searchEnvVariable_Next:
	inc di
	cmp byte [ es:di-1 ], 0				; end of environment string ?
	jnz searchEnvVariable_Next			; continue -->
	jmp short searchEnvVariable_08


		; item not found
searchEnvNotFound:
	xor dx, dx
	mov ax, es
	or ax, ax					; not zero means not found
	jmp short searchEnvReturn


		; item found
searchEnvVariableFound:
	mov dx, word [ _envbegpointer + bp ]		; return start pointer
	sub di, dx					; distance from begin pointer
	xchg di, dx					; return offset in dx
	xor ax, ax


		; return
searchEnvReturn:
	pop es
	Return


		; Delete environment variable
		;
		; Usage:
		; envseg:di-> environment variable to delete
		;
		; Returns:
		; envseg:di-> second byte of environment zero terminator word
deleteEnvVariable:

	push es
	mov es, word [ _EnvSegment ]			; point to segment
	cmp byte [ es:di ], 0				; at end of env block ?
	jz deleteEnvVariable_36				; yes, don't delete -->


		; locate start of next string
	mov si, di					; save di pointer

deleteEnvVariable_08:
	inc si
	cmp byte [ es:si-1 ], 0				; locate end of this string
	jnz deleteEnvVariable_08			; continue -->


		; is this end of env block ?
deleteEnvVariable_12:
	mov byte [ es:di ], 0				; put end mark
	cmp byte [ es:si ], 0				; at end of environment block ?
	jz deleteEnvVariable_36				; yes, done -->


		; copy a string
deleteEnvVariable_16:
	mov al, byte [ es:si ]
	stosb						; copy byte
	inc si
	or al, al					; did we copy a null terminator ?
	jnz deleteEnvVariable_16			; not yet -->
	jmp short deleteEnvVariable_12			;


		; return
deleteEnvVariable_36:
	pop es
	retn


		; Insert environment variable
		;
		; Usage:
		; ds:si-> string to insert into environment
		; envseg:di-> second byte of environment zero terminator word
		;
		; OUT:	envseg:di-> second byte of new environment zero terminator word
		;	CY if string didn't fit into environment,
		;	 ax = 0
		;	NC if string fitted into environment,
		;	 ax = bytes remaining in environment
		;
		; RxDOS <= 7.20N also returns random CF and ax, NZ, envseg:di-> first byte of zero terminator;
		; if the saved environment size is invalid (lower than actual used size) or if the environment
		; is filled up to the very last byte.
insertEnvVariable:

	Entry
	def	endPointer, di

	push es
	mov es, word [ ss:_EnvSegment ]			; point to env segment
	mov cx, word [ ss:_EnvSize ]
	sub cx, di					; bytes available
	jbe insertEnvVariable_30			; if not enough -->

insertEnvVariable_08:
	lodsb
	stosb						; copy byte
	or al, al					; all done ?
	jz insertEnvVariable_36				; yes -->

	loop insertEnvVariable_08


		; can't insert (insufficient space)
insertEnvVariable_30:
	stc						; error
	mov ax, 0					; remaining space
	getarg di, _endPointer				; restore pointer to old end
	mov byte [ es:di ], 0				; restore end marker

	pop es
	Return


		; return
insertEnvVariable_36:
	mov ax, word [ ss:_EnvSize ]
	sub ax, di					; space left
	mov byte [ es:di ], 0				; put double end marker
	dec di						; restore pointer

	pop es
	Return


		; Find program or batch file
		;
		; Usage:
		; ss:dx-> storage for path
		; ss:si-> name (not null terminated)
		; cx = length of name
		;
		; OUT:	CY if not found anywhere in path
		;	NC if found,
		;	 ax = type of program found
		;		0000	.BAT file
		;		0001	.COM or .EXE file (treated the same)
		;	 bx = file handle
_findProgram:

	Entry
	def	length, cx
	def	argument, si
	def	_pathArg, dx				; where to store path
	def	extensionsearchorder			; pointer within extension search order
	def	envpathpointer, 0			; PATH=, if any
	def	extensionFlag, False			; if extension in name
	def	execnamelength
	def	endofname

	defbytes	finddata, sizeFINDDATA
	defbytes	execname, sizeLFN


		; isolate name from rest of command line
	getarg di, __pathArg
	repz movsb					; copy program name
	storarg _endofname, di
	mov byte [ di ], 0				; null terminate

	mov al, '*'
	getarg di, _argument
	getarg cx, _length
	repne scasb					; scan name
	ifz _findProgram_Error				; contains wild character * -->

	mov al, '?'
	getarg di, _argument
	getarg cx, _length
	repne scasb					; scan name
	ifz _findProgram_Error				; contains wild character ? -->


		; get PATH= environment variable
	mov si, RxDOS_PathSpec
	call searchEnvVariable				; locate PATH=
	jnz _findProgram_10				; if not found -->

	add di, dx					; address after =
	storarg _envpathpointer, di			; location in path statement


		; extract path, name, and extension components
_findProgram_10:
	getarg cx, _length
	getarg di, _endofname

_findProgram_12:
	dec di
	cmp byte [ di ], '\'				; path character ?
	jz _findProgram_16				; yes, path found -->
	cmp byte [ di ], '/'				; path character ?
	jz _findProgram_16				; yes, path found -->

	dec cx						; more to scan ?
	jz _findProgram_18				; if no extension -->

	cmp byte [ di ], '.'				; possible extension ?
	jnz _findProgram_12				; not yet -->
	storarg _extensionFlag, True			; extension found
	jmp short _findProgram_12			; continue until \ found -->

_findProgram_16:
	inc di
	storarg _envpathpointer, 0			; prevent search if path included

_findProgram_18:
	mov si, di
	lea di, [ _execname + bp ]
	getarg cx, _endofname
	sub cx, si					; isolate file name + any extension
	storarg _execnamelength, cx			; save length
	repz movsb					; save name in _execname
	mov byte [ di ], 0				; null terminate


		; search through current directory first
_findProgram_24:
	cmp word [ _extensionFlag + bp ], False		; extension included ?
	jz _findProgram_30				; no, search for program appending extension -->

	getarg dx, __pathArg				; pointer to path argument
	lea di, [ _finddata + bp ]
	FileAttrib ATTR_NORMAL
	call CheckFile					; find file
	jnc _findProgram_50				; if found -->
	jmp short _findProgram_40			; not found -->

		; search within directory appending different extensions (.BAT, .COM, .EXE)
_findProgram_30:
	cmp word [ _extensionFlag + bp ], True		; extension already in name ?
	jz _findProgram_40				; disable extension search -->

	mov si, RxDOS_ExecOrder				; look for names in order, current dir
	storarg _extensionsearchorder, si

_findProgram_32:
	mov si, word [ si ]				; get extension text entry
	getarg di, _endofname				; point to end of name
	call CopyString					; copy extension

	mov dx, word [ __pathArg + bp ]			; pointer to path arg
	lea di, [ _finddata + bp ]			; finddata workspace
	FileAttrib ATTR_NORMAL
	call CheckFile					; find file
	jnc _findProgram_50				; if located -->

	add word [ _extensionsearchorder + bp ], 2	; pointer to next entry
	getarg si, _extensionsearchorder
	cmp word [ si ], 0				; end of search order list ?
	jnz _findProgram_32				; not yet -->


		; search through all paths
_findProgram_40:
	getarg si, _envpathpointer			; path=
	or si, si					; if no path,
	ifz _findProgram_CantFind			; then can't find -->

	cmp byte [ si ], 0
	ifz _findProgram_CantFind			; then can't find -->

	push ds
	mov ds, word [ _EnvSegment ]
	mov di, word [ __pathArg + bp ]			; pointer to destination path arg

_findProgram_42:
	lodsb
	or al, al					; end of string ?
	jz _findProgram_44				; yes -->
	cmp al, ';'					; end of term ?
	jz _findProgram_44				; yes -->

	stosb
	jmp _findProgram_42

_findProgram_44:
	pop ds						; restore ds
	storarg _envpathpointer, si			; save end of path search

	cmp di, word [ __pathArg + bp ]		; pointer to path arg
	jz _findProgram_40				; if emptry string -->

	mov al, '\'
	cmp al, byte [ di - 1 ]			; pathname terminated by \ ?
	jz _findProgram_46				; yes -->
	stosb						; add \ to pathname

_findProgram_46:
	lea si, [ _execname + bp ]
	getarg cx, _execnamelength			; get name length
	rep movsb					; append program name

	storarg _endofname, di
	mov byte [ di ], 0				; null terminate
	jmp _findProgram_24


		; file found, determine if .exe or .com
_findProgram_50:
	lea di, [ _finddata + bp ]		; name area
	call LFNReturnPreferedFilenamePtr		; point to real name

	mov di, dx
	xor ax, ax
	mov cx, -1
	repnz scasb					; length of string
	not cx						; make len positive
	dec cx						; dec for term null

_findProgram_54:
	cmp byte [ di - 1], '.'			; backup over extension, if any
	jz _findProgram_56				; until found -->

	dec di
	loop _findProgram_54

	mov ax, _UNKNOWN
	jmp short _findProgram_62

_findProgram_56:
	mov dx, word [ di ]				; now we have extension
	or dx, 2020h

	mov ax, _BAT					; _bat
	cmp dx, 'ba'
	jz _findProgram_62

	mov ax, _COM					; _com
	cmp dx, 'co'
	jz _findProgram_62

	mov ax, _EXE					; _exe
	cmp dx, 'ex'
	jz _findProgram_62

	mov ax, _UNKNOWN

_findProgram_62:
	or ax, ax					; no carry (no error)
	getarg si, __pathArg				; expanded argument name
	Return


		; error
_findProgram_CantFind:
_findProgram_Error:
	stc
	Return


		; Load external executable
		;
		; INP:	ss:si-> program to load
		;	ss:di-> argument array
		;
		; Note:
		; Must return error message.
_loadProgram:

	Entry
	ddef	args, ss, di
	ddef	progname, ss, si
	defbytes	ExecBlock, sizeEXEC
	defbytes	CmdLine, 128
	defbytes	FCB1, sizeFCB
	defbytes	FCB2, sizeFCB

	push es
	push di
	setES ss
	lea di, [ _ExecBlock + bp ]
	clearMemory sizeEXEC

	lea di, [ _FCB1 + bp ]
	call _initFCB
	mov word [ _ExecBlock + lexecFCB_1 + _pointer + bp ], di
	mov word [ _ExecBlock + lexecFCB_1 + _segment + bp ], ss

	lea di, [ _FCB2 + bp ]
	call _initFCB
	mov word [ _ExecBlock + lexecFCB_2 + _pointer + bp ], di
	mov word [ _ExecBlock + lexecFCB_2 + _segment + bp ], ss

	lea bx, [ _ExecBlock + bp ]
	mov ax, word [ _EnvSegment ]
	mov word [ _ExecBlock + lexecEnvironment + bp ], ax
		; Usually RxCMD's PSP should be active, so setting this
		; to zero should also copy our current environment.
	; mov word [ _ExecBlock + lexecEnvironment + bp ], 0


		; copy command tail
	lea di, [ _CmdLine + bp ]
	mov word [ ss:di ], 0D00h			; pre-init command line

	mov word [ _ExecBlock + lexecCommandTail + _pointer + bp ], di
	mov word [ _ExecBlock + lexecCommandTail + _segment + bp ], ss

	getdarg	es, si, _args
	add si, sizeArgCmd				; point to next entry
	cmp word [ es:si ], 0000			; any more arguments ?
	jz _loadProgram_20				; if no args -->

	xor ax, ax
	stosb						; start with length term

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
; capture leading spaces
	mov si, word [ es:argpointer + si ]

_loadProgram_08:
	cmp byte [ es:si - 1 ], ' '			; preceeding a space ?
	jnz _loadProgram_12				; no -->
	dec si
	jmp short _loadProgram_08

_loadProgram_12:
	call CopyString					; copy command tail

	dec di
	mov byte [ es:di ], 13				; end with CR

	dec di
	mov cx, di
	lea di, [ _CmdLine + bp ]
	sub cx, di					; actual length
	mov byte [ es:di ], cl				; save starter length


		; get FCB arguments
	mov ax, 2901h					; parse filename into FCB
							; al bit0: skip leading seperators
	lea di, [ _FCB1 + bp ]

	getdarg	es, si, _args
	mov si, word [ es:si + argpointer + sizeArgCmd ]
	int 21h

	mov ax, 2901h					; ok to skip leading sep
	lea di, [ _FCB2 + bp ]
	int 21h


		; go run program
_loadProgram_20:
	setES ss
	lea bx, [ _ExecBlock + bp ]
	getdarg ds, dx, _progname
	mov cl, 0					; mode: execute
	stc
	Int21 LFNExecuteProgram
	mov ax, cs
	mov ds, ax
	mov es, ax					; restore registers
	jc .error

		; get return status when done
	Int21 GetReturnCode				; get return value (errorlevel)
	and ax, 255					; only errorlevel, not type of termination
	mov word [ RxDOS_ExecReturnCode ], ax		; save return code

.return:
	pop di
	pop es
	return

.error:
	mov dx, msg.error_load_program
	call DisplayErrorMessage
	mov word [ RxDOS_ExecReturnCode ], 127
	jmp short .return


		; initialize an FCB data structure
		;
		; Usage:
		; es:di-> storage for FCB
_initFCB:
	push ax
	push di
	clearMemory sizeFCB

	lea di, [ fcbName + di ]
	clearMemory sizeFILENAME, 2020h			; double spaces

	pop di
	pop ax
	retn


		; return volume name
		;
		; Usage:
		; al	is disk to read volume
		; di	pointer to find data struc
		; cy	drive has no volume name
		;
		; Output:
		; di	points to short volum name
		; cy	drive has no volume name
		;
returnVolumeName:

	push bx
	push di
	cmp al, 'Z'-40h
	jnb returnVolumeName_08

	or al, al					; default disk ?
	jnz returnVolumeName_06				; no -->

	Int21 CurrentDisk
	inc al						; a=1, ...

returnVolumeName_06:
	add al, 'a'-1

returnVolumeName_08:
	mov bx, RxDOS_RootDirectoryDriveLetter
	mov byte [ bx ], al
	mov dx, bx

	pop di
	lea bx, [ findDataLongFilename + di ]
	mov byte [ es:bx ], 0

	lea bx, [ findDataShortFilename + di ]
	mov byte [ es:bx ], 0

	FileAttrib ATTR_VOLUME
	call CheckFile					; grab volume label, if any
	mov dx, 0000
	jnc short returnVolumeName_18

	mov dx, 0001					; else assume not found error
	cmp al, errInvalidDrive				; if drive not found,
	jz returnVolumeName_16				; then return error -->
	cmp al, errPathNotFound				; if path not found,
	jz returnVolumeName_16				; then return error -->
	or dx, dx
	jmp short returnVolumeName_18

returnVolumeName_16:
	stc

returnVolumeName_18:
	lea di, [ findDataShortFilename + di ]
	pop bx
	ret


		; Get Error Code
		;
		; Usage:
		; ax	error code
DisplayErrorCode:

	push bx
	cmp ax, CmndError_RefTableEntries
	jae DisplayErrorCode_08

	mov bx, ax
	add bx, bx
	add bx, CmndError_TextReferenceTable
	mov dx, word [ cs:bx ]			; get address of message
	cmp dx, byte 0000			; error not defined ?
	je DisplayErrorCode_08
	call DisplayErrorMessage		; display message

DisplayErrorCode_08:
	pop bx
	ret


		; Display Out of Environment Space Message
		;
		; Only displays message if CY set
		;
DisplayOutEnvSpace:

	jnc DisplayOutEnvSpace_08

	pushf
	push di
	mov dx, CmndError_OutOfEnvironmentSpace
	call DisplayErrorMessage
	pop di
	popf

DisplayOutEnvSpace_08:
	retn


		; Display Error Message
		;
		; INP:	ds = es
		;	es:dx-> error message, ASCIZ
		; OUT:	CY
DisplayErrorMessage:
	call DisplayLine				; print line
	call CRLF					; new line
	stc
	retn


		; Display CR LF
CRLF:
	push es
	push dx

	setES ds
	mov dx, RxDOS_NewLine
	call DisplayLine				; CR LF

	pop dx
	pop es
	retn


		; Display Line
		;
		; Usage:
		; es:dx-> ASCIZ message
DisplayLine:

	SaveRegisters di, cx, ax
	mov di, dx					; scan actual length of string

	xor ax, ax					; null terminator
	cmp al, byte [ es:di ]				; is string null ?
	jz DisplayLine_22				; yes, no need to display -->

	mov cx, -1
	repnz scasb					; scan total length
	not cx						; fixup
	dec cx						;	...length
	call DisplayLine_ByCount

DisplayLine_22:
	RestoreRegisters di, cx, ax
	retn


		; Display Line Count
		;
		; Usage:
		; es:dx	points to message
		; cx	characters
DisplayLine_ByCount:

	saveAllRegisters

	setds es
	cmp byte [ ss:PageLines ], 00			; page lines ?
	jnz _displayPaginate_12				; go paginate -->


		; if not paginate, can output entire stream
_displayPaginate_10:
	setds es
	mov bx, STDOUT
	Int21 WriteFile					; output
	jmp short _displayPaginate_22


		; if paginate, must really test after each line
_displayPaginate_12:
	push cx						; starting length
	mov di, dx					; string address
	mov al, ControlJ				; search for control J
	repnz scasb					; scan total length
	mov ax, cx					; remaining length after ctl-j
	pop cx						; restore original length
	jnz _displayPaginate_10				; output line as is -->

	sub cx, ax					; real length of current string
	push cx
	push ax						; save remaining length
	mov bx, STDOUT
	Int21 WriteFile					; output line
	call _Paginate					; see if pagination requested
	pop cx						; remaining length
	pop ax						; (exchanged registers)
	add dx, ax					; next

	or cx, cx					; more ?
	jnz _displayPaginate_12				; yes -->


		; exit
_displayPaginate_22:
	restoreAllRegisters
	retn


		; Paginate
_Paginate:
	SaveAllRegisters

	setDS ss
	inc word [ LinesDisplayed ]			; incr lines displayed
	cmp byte [ PageLines ], 00			; page lines ?
	jz _Paginate_14					; don't worry about lines

	call GetScreenLines
	dec ax						; # lines on screen - 1
	cmp ax, word [ LinesDisplayed ]			; beyond # screen lines ?
	jg _Paginate_14					; not yet -->

	mov word [ LinesDisplayed ], 0000		; reset screen lines

	call isStdOutAFile
	jz _Paginate_14					; yes, no pause needed -->
	call _Pause

_Paginate_14:
	RestoreAllRegisters
	ret


		; Set Paging Mode
		;
		; INP:	ax
		; If value is 8000 (switch is set), then set Paging Mode.
setPagingMode:

	mov byte [ PageLines ], 00			; paging mode
	test ax, SW_SWITCHSET
	jz setPagingMode_08

	mov byte [ PageLines ], -1			; paging mode
	mov word [ LinesDisplayed ], 0000		; # lines displayed, curr page

setPagingMode_08:
	retn


		; Is StdOut a file ?
		;
		; INP:	-
		; OUT:	ax = 0001h, NZ if StdOut is a device
		;	ax = 0000h, ZR if StdOut is a file
		; CHG:	bx, dx
isStdOutAFile:

	mov bx, STDOUT
	Int21 IoControl, 00h				; get device information
	mov ax, 1					; non-zero value (true)
	jc .no						; not supported, assume device -->

	test dx, sftIsDevice				; bit set ?
	jnz .no						; handle is a device -->

.yes:
	xor ax, ax					; return zero (false)

.no:
	or ax, ax
	retn


		; Scan print buffer
		; 
		; This routine accepts a variable number of arguments and formats
		; an output buffer. It works very similar to C's sprintf function.
		; 
		; The input buffer may contain imbedded formatting codes:
		; 	%c	character
		; 	%s	string
		; 	%d	decimal number
		;	%x	hexadecimal number
		; For each requested data, a pointer to it is expected on stack.
		; The formatting codes are case insensitive.
		;
		; Additional parameters of formatting codes:
		;	f	Use far pointers
		;	z	Zero-fill numerical formatting code (instead of space)
		;	l	Use a "long" number for numerical formatting code (dword, else word)
		;	0-9	Specify field width (zero- or space-filled), may contain more digits
		;		Any characters that exceeds the field width is ignored!
		;	-	Right align string or number in field (else left)
		;	,	Show thousands seperators for numbers
		;
		; INP:	wo:stack = argument(s) (-> data)
		; 	wo:stack-> format buffer, ASCIZ with format commands
		; 	wo:stack-> output buffer
		;	es = ds = ss
		; OUT:	dx-> output buffer, expanded ASCIZ
		;	si = dx
		; 	ax = number of bytes passed on stack (arguments *2)
		; CHG:	di, cx, bx
		; 
		; Note:
		; The number of arguments returned by _sprintf depends on the
		; number of arguments encountered. It will never include the two
		; standard arguments, the format and output buffer addresses.
		; Both standard arguments are popped off the stack when this
		; code returns to the caller.
_sprintf:
	entry 2
	arg	format
	arg	output
	def	args, 0
	def	varg
	def	fieldwidth
	def	fieldflags

		; scan/copy buffer
	lea di, [ _format + bp +2 ]			; point to previous arg
	storarg _varg, di				; save variable argument(s) pointer

	mov si, word [ _format + bp ]
	mov di, word [ _output + bp ]

_sprintf_06:

_sprintf_08:
	lodsb						; get character
_sprintf_10:
	stosb						; copy to output
	or al, al					; all done ?
	ifz _sprintf_86					; yes -->

	cmp al, '%'					; format code ?
	jnz _sprintf_08					; not yet -->

		; format code
	mov word [ _fieldwidth + bp ], 0		; no width
	mov word [ _fieldflags + bp ], 0		; no flags

	dec di						; kill format % in output
	mov byte [ di ], 0				; stick a null code there

_sprintf_12:
	lodsb						; get character that follows
	_lowerCase al
	or al, al					; all done ?
	ifz _sprintf_86					; yes -->

	mov cx, SPRINTF_LONGFLAG
	cmp al, 'l'					; long flag ?
	jz _sprintf_16					; yes -->

	mov cx, SPRINTF_FAR
	cmp al, 'f'
	je _sprintf_16

	mov cx, SPRINTF_IMMEDIATE
	cmp al, 'i'
	je _sprintf_16

	mov cx, SPRINTF_LEFTALIGN
	cmp al, '-'					; left justify
	jz _sprintf_16					; yes -->

	mov cx, SPRINTF_ZEROFIELDFILL
	cmp al, 'z'					; zero fill ?
	jz _sprintf_16					; yes -->

	mov cx, SPRINTF_COMMADELIM
	cmp al, ','					; decimal delimeter ?
	jnz _sprintf_18					; no -->

_sprintf_16:
	or word [ _fieldflags + bp ], cx
	jmp short _sprintf_12


		; is it a field width ?
_sprintf_18:
	cmp al, '9'+1					; number ?
	jae _sprintf_22					; no -->
	cmp al, '0'					; number ?
	jb _sprintf_22					; no -->

	and ax, byte 15					; get number
	mov dx, word [ _fieldwidth + bp ]		; get width
	add dx, dx					; *2
	add dx, dx					; *4
	add dx, word [ _fieldwidth + bp ]		; *5
	add dx, dx					; *10
	add dx, ax					; add new digit
	mov word [ _fieldwidth + bp ], dx
	jmp short _sprintf_12


		; see if it's a valid formatting code
_sprintf_22:
	xor cx, cx
	cmp al, 'd'					; decimal output ?
	je _sprintf_26
	mov cl, 2
	cmp al, 'x'					; hexadecimal output ?
	je _sprintf_26
	cmp al, 'c'					; character ?
	je _sprintf_32
	cmp al, 's'					; string ?
	je _sprintf_36
	cmp al, '%'					; percent percent ?
	je _sprintf_46

	push dx
	mov dx, msg.invalid_sprintf_format
	call DisplayLine
	pop dx

	jmp _sprintf_06
		; Don't store the unknown code itself.


		; numerical, cx = type (0 for decimal, 2 for hexadecimal)
_sprintf_26:
	push si
	getarg si, _varg				; get pointer to next variable argument
	mov bx, word [ si ]				; get argument pointer
	add word [ _varg + bp ], byte 2
	inc word [ _args + bp ]

	test word [ bp + _fieldflags ], SPRINTF_IMMEDIATE
	jz .num_not_imm

	xor dx, dx
	mov ax, bx
	test word [ bp + _fieldflags ], SPRINTF_LONG
	jz _sprintf_28.num_was_imm

	mov dx, word [ si + 2 ]
	add word [ bp + _varg ], byte 2
	inc word [ bp + _args ]
	jmp _sprintf_28.num_was_imm

.num_not_imm:
	push ds
	test word [ bp + _fieldflags ], SPRINTF_FAR
	jz @F

	inc si
	inc si
	add word [ bp + _varg ], 2
	inc word [ bp + _args ]
	mov ds, word [ si ]	

@@:
	xor dx, dx
	mov ax, word [ bx ]				; get number
	test word [ _fieldflags + bp ], SPRINTF_LONGFLAG
	jz _sprintf_28

	mov dx, word [ bx + 2 ]				; get higher word of number

_sprintf_28:
	pop ds
.num_was_imm:
	mov bx, word [ _fieldflags + bp ]		; flags
	or bx, cx
	mov cx, word [ _fieldwidth + bp ]		; width
	call _sprintfNum				; write nummer as ASCII

	pop si
	jmp _sprintf_06


		; character
_sprintf_32:
	push si
	getarg si, _varg				; get pointer to next variable argument
	mov bx, word [ si ]				; get argument pointer
	add word [ _varg + bp ], byte 2
	inc word [ _args + bp ]

	test word [ bp + _fieldflags ], SPRINTF_IMMEDIATE
	jz .char_not_imm

	mov cx, word [ _fieldwidth + bp ]		; width
	call _sprintfInitField
	mov al, bl
	jmp .char_was_imm

.char_not_imm:
	push ds
	test word [ bp + _fieldflags ], SPRINTF_FAR
	jz @F

	inc si
	inc si
	add word [ bp + _varg ], 2
	inc word [ bp + _args ]
	mov ds, word [ si ]	

@@:
	mov cx, word [ _fieldwidth + bp ]		; width
	call _sprintfInitField
		; Not really useful ? (Only to create spaces.)

	mov al, byte [ bx ]
	stosb						; store character

	pop ds
.char_was_imm:
	pop si

	mov cx, word [ _fieldwidth + bp ]		; width
	or cx, cx
	ifz _sprintf_06

	dec cx
	call _sprintfPadField
	jmp _sprintf_06


		; string
_sprintf_36:
	push si
	getarg si, _varg				; get pointer to next variable argument
	mov bx, word [ si ]				; get argument pointer
	add word [ _varg + bp ], byte 2
	inc word [ _args + bp ]

	push ds
	test word [ bp + _fieldflags ], SPRINTF_FAR
	jz @F

	inc si
	inc si
	add word [ bp + _varg ], 2
	inc word [ bp + _args ]
	mov ds, word [ si ]	

@@:
	mov cx, word [ _fieldwidth + bp ]		; width
	call _sprintfInitField

	mov si, bx
_sprintf_38:
	lodsb
	or al, al					; null terminator ?
	jz _sprintf_40					; yes -->
	stosb
	jcxz _sprintf_38				; fixed count ?
	loop _sprintf_38

_sprintf_40:
	add di, cx					; advance field length
	pop ds
	pop si
	jmp _sprintf_06


		; %
_sprintf_46:
	stosb
	jmp _sprintf_06


		; all done
_sprintf_86:
	mov ax, word [ _args + bp ]
	add ax, ax					; # words left on stack
	mov si, word [ _output + bp ]
	mov dx, si
	return


		; Convert number (dx:ax) to ASCII string
		;
		; Usage:
		; dx:ax = number
		; cx = size of field to right justify
		; bx = display option flags:
		; 	8000	insert decimal commas
		;	0002	display hexadecimal
		; RxDOS 7.30+:
		;	0001	display binary
		;	 (if both 0002 and 0001, binary is prefered!)
_sprintfNum:

	entry
	defbytes	decDisplay, 16
	def	_fill
	def	decimalflag, bx
	def	fieldwidth, cx
	def	spacing, 3				; set spacing

	push si
	push di
	lea di, [ _decDisplay + bp ]
	call _sprintfInitField				; init field to spaces
	push di

_sprintfNum_08:
	mov cx, 10
	test byte [ bp + _decimalflag ], 2
	jz .dec_divisor
	mov cl, 16
.dec_divisor:
	call _div32					; divide by base (maximal remainder: 1/9/F)
	add cl, '0'
	cmp cl, '9'
	jbe .dec_digit
	add cl, -('9'+1) + 'A'
.dec_digit:
	mov byte [ di ], cl				; store character
	inc di

	mov cx, dx
	or cx, ax					; more to go ?
	jz _sprintfNum_10				; no -->

	test word [ _decimalflag + bp ], SPRINTF_COMMADELIM
	jz _sprintfNum_08				; no -->
	dec byte [ _spacing + bp ]			; spacing break ?
	jnz _sprintfNum_08				; not yet -->

	mov byte [ _spacing + bp ], 3			; set decimal spacing
	mov byte [ di ], ','				; store comma
	inc di
	jmp short _sprintfNum_08

_sprintfNum_10:
	pop cx
	sub di, cx					; total # chars output
	mov cx, di					; length to cx

	mov dx, word [ _fieldwidth + bp ]
	sub dx, cx					; bytes to fill
	ja _sprintfNum_12

	xor dx, dx

_sprintfNum_12:
	storarg __fill, dx				; bytes to fill

	pop di
	push di						; where to begin right justify
	lea si, [ _decDisplay + bp ]			; where data stored
	cmp word [ _fieldwidth + bp ], byte 0		; left justified output ?
	 push cx
	jnz @F
	mov word [ _fieldwidth + bp ], cx
@@:
		; right justified
	add di, word [ _fieldwidth + bp ]		; blank fill field first

_sprintfNum_16:
	lodsb						; get character
	dec di
	mov byte [ di ], al
	loop _sprintfNum_16

	mov al, ' '
	getarg cx, __fill				; bytes to fill
	jcxz _sprintfNum_32

	test word [ _decimalflag + bp ], SPRINTF_ZEROFIELDFILL
	jz _sprintfNum_18				; if no zero fill -->
	mov al, '0'

_sprintfNum_18:
	dec di
	mov byte [ di ], al
	loop _sprintfNum_18

		; done
_sprintfNum_32:
	 pop cx
	pop di
	mov si, word [ _fieldwidth + bp ]
	test si, si
	jnz @F
	mov si, cx
@@:
	add di, si					; point past field

	pop si
	return


		; Init field to spaces
		;
		; Usage:
		; es:di-> pointer to buffer
		; cx-> width of field
		;
		; CHG:	-
_sprintfInitField:
	jcxz _sprintfInitField_08			; no fixed count -->

	push di
	push cx
	push ax
	mov al, ' '
	repz stosb

	pop ax
	pop cx
	pop di

_sprintfInitField_08:
	retn


		; Pad Field
_sprintfPadField:
	add di, cx					; advance field length

_sprintfPadField_08:
	retn


		; 32-bit divide
		;
		; Input:
		; INP:	dx:ax = numerator
		;	cx = divisor
		; OUT:	CY, cx = 0 if zero divisor, else
		;	cx = remainder
		;	dx:ax = result
_div32:
	stc
	jcxz _div32_return		; in case of zero divisor --> (CY)

	push bx
	mov bx, dx
	xchg ax, bx
	xor dx, dx
	div cx

	xchg ax, bx
	div cx				; remainder will be in dx
	mov cx, dx
	mov dx, bx
	pop bx

_div32_return:
	retn


		; 32-bit multiply
		;
		; Input:
		; dx:ax = numerator
		; cx = multiplier
		;
		; OUT:	dx:ax = result
		;	NC if result fits into 32-bit
		;	CY if result overflowed
_mul32:
	or dx, dx					; simple multiply ?
	jnz _mul32_12					; not really -->

	mul cx
	clc
	retn

_mul32_12:
	push bx
	push di
	mov bx, ax
	mov ax, dx
	mul cx
	xchg ax, bx
	mov di, dx

	mul cx
	add dx, bx
	jc .ret

	cmp di, byte 1
	cmc
.ret:
	pop di
	pop bx						; restore bx
	retn


		; Get screen lines
		;
		; OUT:	al = ax = number of screen lines
		;	ah = 0
		; CHG:	-
GetScreenLines:

	push ds
	push bx
	xor bx, bx
	mov ds, bx

	mov al, byte [ 484h ]				; number of screen lines -1
	xor ah, ah					; extend to full word
	inc ax						; number of screen lines

	pop bx
	pop ds
	retn


		; Physical Screen Clear
PhysClearScreen:

%if 1
	call SetPageZero				; set page 0
%endif
	call GetScreenLines
	mov dh, al
	mov dl, 79

	mov ax, 0600h					; entire screen
%if 1
	mov bx, (black<<4|grey)<<8			; grey on black
	;; mov bx, (grey<<4|blue)<<8			; blue on grey
	mov cx, 0000h					; from home row
%else
	mov bh, black<<4|grey				; grey on black
	;; mov bh, grey<<4|blue				; blue on grey
	xor cx, cx					; frome home row
%endif
	int 10h

	mov ax, 0F00h					; read current mode
	int 10h						; get active page into bh

	mov ax, 0200h
	mov dx, 0100h
	int 10h						; position cursor

	retn


%if 1
		; Set Page Zero
SetPageZero:

	mov ax, 0500h					; set Page zero
	int 10h
	retn
%endif

		; Commands (alphabetical)

		; BREAK [ON|OFF]
		;
		; Sets, clears or reports the Ctrl-C checking on any Int21 call.
_Break:
	entry
	def	_argarray, di
	def	args, ax

	call CheckOptOneArg				; see if 1 arg
	jc _BreakExit					; if error -->

	or ax, ax					; any arguments ?
	jz _BreakDisplayCurrent				; none, print current status -->


		; test for ON/OFF
	mov si, word [ argpointer + di ]		; get arg pointer
	mov cx, word [ arglength + di ]			; get arg length
	mov di, RxDOS_OnOff
	call CmndLookup					; lookup command
	jc _BreakError					; if not ON/OFF -->

	mov dl, bl
	Int21 CtrlBreakCheck, setControlC		; set Ctrl-C check state
	Return


		; must specify ON or OFF
_BreakError:
	mov dx, CmndError_MustSpecifyOnOff
	call DisplayErrorMessage
	jmp short _BreakExit


		; display current state
_BreakDisplayCurrent:
	Int21 CtrlBreakCheck, getControlC		; get Ctrl-C check state

	mov bl, dl
	xor bh, bh
	add bx, bx
	mov dx, word [ _BreakOptions + bx ]
	call DisplayLine

_BreakExit:
	return


		; Call batchfile arguments
		;
		; Usage:
		; ss:di	Arg Array
		; ax	Number of arguments in array
_Call:
	entry
	def	_argarray, di
	def	_tempargptr
	defbytes	_pathArg, 128


		; find and execute program (unless its a batch file)
	mov ax, _BAT					; force type to be bat
		; RxDOS 7.20N:	The CALL command should also execute normal executables.
	lea dx, [ __pathArg + bp ]
	call _executeProgram				; load and execute
	jc _call_22					; if some kind of error -->
	cmp ax, _BAT					; is it a bat program ?
	jz _call_12					; yes -->

	clc						; clear error
	jmp short _call_22


		; execute (call) batch
_call_12:
	xor cx, cx
	xor dx, dx					; leave position unchanged
	mov bx, word [ RxDOS_BatchFile + batchFileHandle ]
	Int21 MoveFilePointer, SEEK_CUR			; get current position

	mov word [ RxDOS_BatchFile + batchFilePosition + _low ], ax
	mov word [ RxDOS_BatchFile + batchFilePosition + _high ], dx

	mov si, RxDOS_BatchFile
	mov di, word [ RxDOS_PrevStackFrame ]
	mov cx, sizeBATCH_ARGS
	repz movsb					; copy current args to save area

		; RxDOS 7.20N:	Move following done.
	sub word [ RxDOS_PrevStackFrame ], sizeBATCH_ARGS
	inc word [ RxDOS_StackFrameNumEntries ]


		; setup batch file arguments
	mov ax, _BAT					; exit must contain _BAT type
	getarg di, __argarray
	lea dx, [ __pathArg + bp ]			; pointer to file name
	call _saveBatchArguments			; if batch file, save arguments
	jnc _call_22					; all done -->

	add word [ RxDOS_PrevStackFrame ], sizeBATCH_ARGS
	dec word [ RxDOS_StackFrameNumEntries ]		; if error
	stc

_call_22:
	getarg di, __argarray
	return


		; Change Directory
		;
		; Changes the default directory for a drive.
		;
		; Usage:
		; ss:di	Arg Array
		; ax	Number of arguments in array
_ChangeDir:

	entry
	def	disk
	def	_argarray, di
	defbytes	tempstring, sizeLFNPATH

	call CheckOptOneArg				; see if 1 arg
	ifc _changeDir_32				; doesn't expect 2 arguments -->
	jnz _changeDir_18				; if argument passed -->


		; display current
	Int21 CurrentDisk				; get current disk

	mov dl, al					; save drive number
	add al, 'A'					; make letter
	lea di, [ _tempstring + 3 + bp ]
	mov byte [ di - 3 ], al
	mov word [ di - 2 ], ":\"

	inc dl
	mov si, di
	Int21 LFNGetCurrentDirectory			; get current directory

%if 0
	push ss
	push si						; where string
	call _lowerCaseString
		; RxDOS 7.20N:	Stop the lower-casing! Especially for LFN pathes.
%endif

	lea dx, [ _tempstring + bp ]
	call DisplayLine
	Return


		; change drive: directory
_changeDir_18:
	getarg di, __argarray
	mov si, word [ ss:di ]				; pointer to lead argument
	lea di, [ _tempstring + bp ]
	mov word [ di ], '\'				; init area

	mov cl, LFNEXPAND_GETFULLPATHNAME
	Int21 LFNGetActualFileName			; expand name

	getarg di, __argarray
	mov si, word [ ss:di ]				; pointer to lead argument
	cmp byte [ si+1 ], ':'				; drive ?
	jnz _changeDir_22				; no -->

	mov dl, byte [ si ]				; get drive letter
	_lowerCase dl
	sub dl, 'a'					; drive maps to 0, ...
	mov byte [ _disk + bp ], dl			; save driver
%if 1
	Int21 CurrentDisk
	mov byte [ _disk + 1 + bp ], al			; save current drive
		; RxDOS 7.20N:	Probably it was intended that CD changes the disk. The
		;		corrospending COMMAND.COM command however doesn't. Hence
		;		a simplier solution to test the drive could be possibly.
		;		(Or is just _not_ testing it what we actually want here?)
%endif
	Int21 SelectDisk				; can we select that drive ?
	Int21 CurrentDisk				; get current drive
%if 1
	push ax
	mov dl, byte [ _disk + 1 + bp ]			; get actual current drive
	Int21 SelectDisk				; restore it
	pop ax
%endif
	inc si
	inc si						; point [si] past drive
	cmp al, byte [ _disk + bp ]			; drive changed to ours ?
	jz _changeDir_22				; yes -->

	mov dx, CmndError_InvalidDrive
	call DisplayErrorMessage			; display message
	jmp short _changeDir_32


		; change directory
_changeDir_22:
	mov dx, si					; points to change string
	Int21 LFNChangeSubdirectory			; try changing dir
	jnc _changeDir_32				; if invalid
	call DisplayErrorCode				; if error

_changeDir_32:
	return


		; Clear Screen
_Cls:
	call isStdOutAFile
	jnz _clsScreen					; its a physical device -->

	mov dl, 'L'-40h					; to a file we'll pipe a top of forms
	Int21 DisplayOutput
	retn


		; see how many lines
_clsScreen:
%if 0
	mov ax, 1A00h
	int 2Fh						; ANSI driver installation check
	cmp al, 0FFh
	jne .noansi
		; RxDOS 7.20N:	Probably we should check whether CTTY is the CON device?
	mov dx, msg.ansicls
	call DisplayLine
	retn
.noansi:

;.ansicls:	asciz 27,"[2J"				; Escape, "Clear screen" sequence
%endif
	call PhysClearScreen
	retn


		; Delete filename
		;
		; Usage:
		; ss:di	Arg Array
		; ax	Number of arguments in array
_Delete:
	entry
	def	_argarray, di
	def	nfiles, 0
	def	allfiles, TRUE
	def	filenameArg
	def	ptrName
	def	findHandle, -1
	defbytes	finddata, sizeFINDDATA
	defbytes	_pathArg, sizeLFNPATH

	call CheckOneArg
	jnc _Delete_06					; arguments wrong -->

	mov dx, CmndError_FileNameMissing
	call DisplayErrorMessage
	return


		; delete all files ?
_Delete_06:
	mov dx, word [ argpointer + di ]		; point to filename arg
	storarg _filenameArg, dx			; save pointer
	lea di, [ _finddata + bp ]			; finddata workspace
	FileAttrib ATTR_NORMAL
	call CheckFile					; does file exist ?
	ifc _Delete_36					; no -->

		; check for * or *.* cases
	xor ax, ax
	mov cx, -1
	getarg di, _filenameArg				; get pointer to filename
	repnz scasb					; scan to end

	not cx						; make length positive
	dec cx						; don't count terminating null

_Delete_12:
	dec di
	cmp byte [ di ], '\'
	jz _Delete_18					; ok to stop searching if \ -->
	cmp byte [ di ], ':'
	jz _Delete_18					; ok to stop searching if : -->
	cmp byte [ di ], 0
	jz _Delete_16					; skip null char -->
	cmp byte [ di ], '.'
	jz _Delete_16					; skip dot -->
	cmp byte [ di ], '*'
	jz _Delete_16					; skip wild char -->
	cmp byte [ di ], '?'
	jnz _Delete_22					; if not wild char, then not *.* case

_Delete_16:
	loop _Delete_12

_Delete_18:
	mov dx, _DeleteAllFiles
	call DisplayLine				; display line

	Int21 ConsoleInputNoEcho			; read keyboard
	_upperCase al

	push ax
	call CRLF
	pop ax
	cmp al, "Y"					; if Yes -->
	jz _Delete_22
	cmp al, "N"					; repeat if not right -->
	jnz _Delete_18
	jmp short _Delete_42				; else, its No -->


		; try to locate file(s)
_Delete_22:
	fileAttrib ATTR_NORMAL
	getarg si, _filenameArg				; get filename pointer
	lea di, [ _finddata + bp ]			; name area
	lea dx, [ __pathArg + bp ]			; expanded path (sizeLFNPATH)
	call BuildFullPathFirstFile			; filename found for arg ?
	storarg _findHandle, bx				; save find handle
	storarg _ptrName, dx				; present name to next
	jc _Delete_36					; no more -->

_Delete_26:
	lea dx, [ __pathArg + bp ]			; expanded path (sizeLFNPATH)
	Int21 LFNDeleteFile				; delete file

	inc word [ _nfiles + bp ]

	getarg dx, _ptrName
	getarg bx, _findHandle
	lea di, [ _finddata + bp ]			; name area
	call BuildFullPathNextFile			; filename found for arg ?
	jnc _Delete_26					; continue deleting -->

	getarg bx, _findHandle
	call BuildFullPathClose


		; no more files
_Delete_36:
	cmp word [ _nfiles + bp ], byte 0		; any files deleted ?
	jnz _Delete_42					; yes -->

	mov dx, CmndError_NoFilesFound
	call DisplayErrorMessage

_Delete_42:
	return


		; Select drive
		;
		; Usage:
		; ss:di	Arg Array
		; ax	Number of arguments in array
_DiskSelect:
	push di
	add di, sizeArgCmd				; check for no arguments
	jc _diskSelect_32				; if error -->
		; RxDOS 7.20N:	If this code isn't disabled, it should really
		;		display an error message if it branches here.

	pop di						; restore pointer to argument 0
		; RxDOS 7.20N:	This check is not done by some COMMAND.COMs.

	push di
	mov si, word [ argpointer + di ]		; point to lead argument
	cmp byte [ si+1 ], ':'				; drive ?
	jnz _diskSelect_32				; no -->

	mov dl, byte [ si ]				; get drive letter
	_lowerCase dl
	sub dl, 'a'					; drive maps to 0, ...
	mov byte [ _disk + bp ], dl			; save disk

	Int21 SelectDisk				; can we select a drive ?
	Int21 CurrentDisk				; get current disk

	cmp al, byte [ _disk + bp ]			; disk changed ?
	jz _diskSelect_32				; yes --> (NC)

	mov dx, CmndError_InvalidDrive
	call DisplayErrorMessage			; display message
	stc

_diskSelect_32:
	pop di
	retn


		; Change ECHO state or display line
		;
		; INP:	ss:di-> argument array
		;	ax = number of arguments in array
_Echo:
	entry
	def	_argarray, di
	def	args, ax

	or ax, ax					; no arguments ?
	jz _echo_printcurrent				; none, print current status -->


		; test special echo case (symbol char immediately following echo keyword)
	mov ax, word [ argpointer + di ]
	sub ax, word [ argpointer -sizeArgCmd + di ]
	cmp ax, 4					; first arg immediately next to echo (echo. case)
	jnz _echo_OnOffTest				; no, go test for ON/OFF special case -->

	mov si, word [ argpointer + di ]
	mov al, byte [ si ]				; get first character

		; RxDOS 7.30N:	Someone tell me what the following code does here.
	setES ss
	mov di, _CmndParse_FileSysReserved
	mov cx, _CmndParse_FileSysReservedLen
	repnz scasb					; char not special
	jnz _echo_printline				; just print line -->

	getarg di, __argarray
	inc word [ argpointer + di ]
	dec word [ arglength + di ]
	jnz _echo_printline				; print remainder of line -->

	call deletearg					; delete @arg
	jnz _echo_printline				; if addtl args follow -->
	jmp short _echo_printCRLF			; if blank line


		; test for ON/OFF
_echo_OnOffTest:
	cmp word [ bp + _args ], byte 1
	ja _echo_printline				; if more than one argument -->

	mov si, word [ argpointer + di ]		; get arg pointer
	mov cx, word [ arglength + di ]			; get arg length
	mov di, RxDOS_OnOff
	call CmndLookup					; lookup command
	jc _echo_printline				; if not on/off, print line -->

	mov byte [ RxDOS_BatchFile + batchEchoStatus ], bl	; set echo status
	return


		; print current line
_echo_printline:
	getarg di, __argarray
	mov dx, word [ argpointer + di ]		; get start of string
	call DisplayLine

_echo_printCRLF:
	call CRLF
	return


		; display ECHO state
_echo_printcurrent:
	mov bx, word [ RxDOS_BatchFile + batchEchoStatus ]
	add bx, bx
	mov dx, word [ _EchoOptions + bx ]
	call DisplayLine
	Return


		; End CALL
		;
		; INP:	ss:di-> argument array
		;	ax = number of arguments in array
_EndCall:

	mov bx, word [ RxDOS_BatchFile + batchFileHandle ]
	Int21 CloseFile					; close file
	mov word [ RxDOS_BatchFile + batchFileHandle ], 0
	mov word [ RxDOS_BatchFile + batchEchoStatus ], ON

	cmp word [ RxDOS_StackFrameNumEntries ], byte 0
	jz _endcall_18					; if no more files to backup to -->

	dec word [ RxDOS_StackFrameNumEntries ]
	add word [ RxDOS_PrevStackFrame ], sizeBATCH_ARGS
	mov si, word [ RxDOS_PrevStackFrame ]
	mov di, RxDOS_BatchFile
	mov cx, sizeBATCH_ARGS
	repz movsb					; copy

	mov si, word [ RxDOS_PrevStackFrame ]
	cmp word [ RxDOS_StackFrameNumEntries ], byte 0

_endcall_18:
	retn


		; Execute external program or batch File
		;
		; INP:	ss:di-> argument array
		;	si-> filename
		;	ax = forced type (_BAT or _UNKNOWN)
_executeProgram:
	entry
	def	_argarray, di
	def	progname, si
	def	_pathArg, dx				; where to return fully qualified path name
	def	requireType, ax				; forced type (_BAT or _UNKNOWN)
	def	_type


		; find program
	getarg dx, __pathArg				; where to return fully qualified path name
	mov si, word [ argpointer + di ]		; argument name
	mov cx, word [ arglength + di ]			; argument length
	call _findProgram				; locate program or bat file
	storarg __type, ax				; arg type
	jc _executeprogram_Error			; if program not found -->
	cmp ax, byte _BAT				; is it a batch program ?
	jz _executeprogram_12				; yes, don't execute -->

	cmp word [ _requireType + bp ], byte _BAT	; batch required ?
	jz _executeprogram_Error			; can't run -->

	getarg dx, __pathArg				; where to return fully qualified path name
	getarg di, __argarray
	call _loadProgram				; else load and execute program

_executeprogram_12:
	clc

_executeprogram_Exit:
	getarg di, __argarray
	getarg si, _progname
	getarg dx, __pathArg
	getarg ax, __type
	Return						; return

_executeprogram_Error:
	getarg di, __argarray				; arg array
	call _NotValidCommand				; not valid (not found)
	stc						; set error exit
	jmp short _executeprogram_Exit


		; Goto label
		;
		; if batch file, locate label
_Goto:
	entry
	def	labelPtr, si
	ddef	filePosition
	defbytes	buffer, sizeCmdLineStruct


		; prep argument
	call CheckOneArg
	jc _goto_36					; error -->

	getarg si, _labelPtr

_goto_06:
	cmp byte [ si ], ':'
	jnz _goto_08
	inc si
	jmp short _goto_06

_goto_08:
	storarg _labelPtr, si


		; running batch file ?
	cmp word [ RxDOS_BatchFile + batchFileHandle ], byte 0
	jz _goto_36					; if not running a batch file -->

	call getBatchPosition				; save current batch file position
	mov word [ _filePosition + _low + bp ], ax
	mov word [ _filePosition + _high + bp ], dx


		; read lines
	xor cx, cx
	xor dx, dx
	mov bx, word [ RxDOS_BatchFile + batchFileHandle ]
	Int21 MoveFilePointer, SEEK_BEG			; start at begin of file

_goto_16:
	xor ax, ax					; no echo searching lines
	mov bx, word [ RxDOS_BatchFile + batchFileHandle ]
	lea si, [ _buffer + bp ]
	call _ReadBatch					; read batch line
	jz _goto_32					; reset position -->


		; compare against search argument
	xor bh, bh
	mov bl, byte [ _buffer + bufActualLength + bp ]
	lea di, [ _buffer + bufData + bp ]
	mov byte [ di + bx ], 0
	mov si, word [ _labelPtr + bp ]

	mov al, 32
	repz scasb					; skip spaces in front of possible label

	cmp byte [ di-1 ], ':'				; first character is colon ?
	jne _goto_16					; no -->

	call _compareSubString				; label matches ?
	jnz _goto_16					; no -->
	jmp short _goto_36				; yes, leave fseek position behind line -->


		; can't find, reset file position to saved value
_goto_32:
	mov dx, word [ _filePosition + _low + bp ]
	mov cx, word [ _filePosition + _high + bp ]
	mov bx, word [ RxDOS_BatchFile + batchFileHandle ]
	Int21 MoveFilePointer, SEEK_BEG			; restore pointer

		; Shouldn't we show an error message here ?
		; COMMAND.COM also aborts that batch file if the label isn't found.


		; return
_goto_36:
	Return


		; IF [NOT] ERRORLEVEL number command
		; IF [NOT] EXIST filename command
		; IF [NOT] string1==string2 command
_If:
	entry
	def	_argarray, di
	def	notflag, 0
	def	usedportion, 0
	defbytes	finddata, sizeFINDDATA
	defwords	argtypeArray, 20		; 5 args (type and text pointers)


		; type first few arguments
	lea di, [ _ARGTYPEArray + bp ]			; pointer to arg store value
	push di

	xor ax, ax
	mov cx, 5 * 4					; words to clear
	repz stosw

	pop bx
	mov cx, 5					; # args to scan
	getarg di, __argarray

_If_08:
	cmp word [ argpointer + di ], byte 0		; any more args ?
	jz _If_16					; quit typing args -->

	push di
	push bx
	push cx

	mov si, word [ argpointer + di ]		; get lead argument
	mov cx, word [ arglength + di ]			; get arg length
	mov word [ bx + _ARGTEXT ], si			; pointer to text

	mov di, RxDOS_IfOptions
	call CmndLookup					; lookup command
	mov ax, bx					; save type

	pop cx
	pop bx
	pop di
	jc _If_12
	mov word [ bx + _ARGTYPE ], ax			; value returned from lookup

_If_12:
	add bx, 4					; lookup first three args
	add di, sizeArgCmd				; lookup first three args
	loop _If_08


		; see if == special case
_If_16:
	lea bx, [ _ARGTYPEArray + bp ]			; pointer to arg
	cmp word [ bx + _ARGTYPE ], IF_NOT		; not argument ?
	jnz _If_20					; no -->
	add bx, 4					; then we'll use next as base
	not word [ _notflag + bp ]			; toggle flag

_If_20:
	cmp word [ bx + _ARGTYPE ], IF_ERRORLEVEL
	ifz _ifErrorLevel
	cmp word [ bx + _ARGTYPE ], IF_EXIST
	ifz _ifExist

	mov si, word [ bx + 4 + _ARGTEXT ]		; next arg
	or si, si					; no text ?
	jz _IfSyntaxError				; syntax error -->

	cmp word [ si ], "=="				; equals case ?
	jz _ifEquals


		; syntax error
_IfSyntaxError:
	mov dx, CmndError_SyntaxError
	call DisplayErrorMessage			; display message
	Return


		; if equals
_ifEquals:
	mov si, word [ bx + _ARGTEXT ]
	or si, si					; arg before =='s
	jz _IfSyntaxError				; if syntax error -->

	mov di, word [ bx + 12 + _ARGTEXT ]
	storarg _usedportion, di
	or di, di					; arg after =='s
	jz _IfSyntaxError				; if syntax error -->

	push si
	call _ifStringlength				; get length of source string
	mov cx, ax

	push di
	call _ifStringlength				; get length of dest string
	cmp cx, ax					; compare lengths
	jnz _ifNotEquals				; if syntax error -->

	repz cmpsb					; strings compare equal ?
	lahf						; ZF to ah
	xor ah, byte [ _notflag + bp ]			; toggle ZF bit
	and ah, 01000000b				; not zero to continue
	jnz _ifTrue

_ifNotEquals:
	Return


		; if errorlevel
_ifErrorLevel:
	mov si, word [ bx + 4 + _ARGTEXT ]		; get text pointer to next arg
	storarg _usedportion, si
	or si, si
	jz _IfSyntaxError				; if syntax error -->

	call _GetNumber					; get expected number
	jc _IfSyntaxError				; if syntax error -->

	dec ax						; need to force carry
	cmp ax, word [ RxDOS_ExecReturnCode ]		; current >= return value ?
	lahf						; CF to ah
	xor ah, byte [ _notflag + bp ]			; toggle CF bit
	and ah, 00000001b				; not zero to continue
	jnz _ifTrue					; do rest of line -->

	Return


		; if exist
_ifExist:
	FileAttrib ATTR_DIRECTORY
	mov dx, word [ bx + 4 + _ARGTEXT ]		; get text pointer to next arg
	storarg _usedportion, dx
	lea di, [ _finddata + bp ]
	call CheckFile					; does this file exist ?

	lahf						; CF to ah
	xor ah, byte [ _notflag + bp ]			; toggle CF bit
	and ah, 00000001b				; not zero to continue
	jz _ifTrue					; do rest of line -->

	Return


		; if cond is true. execute command that follows
_ifTrue:
	getarg di, __argarray
	getarg dx, _usedportion				; used args
	sub di, sizeArgCmd

_ifTrue_08:
	add di, sizeArgCmd
	cmp word [ argpointer + di ], 0
	ifz _IfSyntaxError
	cmp word [ argpointer + di ], dx		; located used part of If ?
	jc _ifTrue_08					; not yet -->

	add di, sizeArgCmd
	call _executeCommandArray
	Return
		; This should jump to executing the next command, or
		; stack overflows can easily occur on deep nested IFs.


		; compute string lengths
_ifStringlength:
	entry 1
	arg	str

	push si
	push di
	getarg si, _str

_ifStringlength_08:
	cmp byte [ si ], ' '
	jz _ifStringlength_12
	cmp byte [ si ], '='
	jz _ifStringlength_12
	cmp byte [ si ], 0
	jz _ifStringlength_12

	inc si
	jmp short _ifStringlength_08

_ifStringlength_12:
	mov ax, si
	sub ax, word [ _str + bp ]

	pop di
	pop si
	Return


		; Make Directory
		;
		; Usage:
		; ss:di	Arg Array
		; ax	Number of arguments in array
_makeDir:

	call CheckOneArg				; see if 1 arg
	jc _makeDir_32					; if error -->

_makeDir_22:
	mov dx, word [ argpointer + di ]		; point to filename arg
	Int21 LFNCreateSubdirectory			; try changing dir
	jnc _makeDir_32					; if valid -->

	cmp ax, errAccessDenied				; access denied ?
	jnz _makeDir_26					; show other errors -->

	mov dx, CmndError_SubDirAlreadyExists
	call DisplayErrorMessage
	jmp short _makeDir_32

_makeDir_26:
	call DisplayErrorCode				; if error

_makeDir_32:
	retn


		; Path
		;
		; Usage:
		; ss:di	Arg Array
		; ax	Number of arguments in array
_Path:
	entry
	def	_argarray, di
	def	pathArgBeg
	def	pathEndPtr, 0
	def	foundflag, TRUE


		; locate current path arg, if any.
	mov si, RxDOS_PathSpec				; locate PATH=
	call searchEnvVariable				; environment variable located ?
	jz _Path_08					; if arg located -->
	storarg _foundflag, FALSE			; if not found
	storarg _pathEndPtr, di				; else this points to end
	xor di, di					; say not found

_Path_08:
	storarg _pathArgBeg, di


		; if no command given, type out current path value
	getarg di, __argarray
	mov si, word [ argpointer + di ]		; point to arg array
	or si, si					; any args passed ?
	jnz _Path_16					; yes, go update path -->

	cmp word [ _foundflag + bp ], TRUE		; path found ?
	jnz _Path_14					; no arg found -->

	push es
	getarg dx, _pathArgBeg				; restore arg to path
	mov es, word [ _EnvSegment ]
	call DisplayLine				; show current path
	call CRLF					; cr/lf
	pop es
	Return

_Path_14:
	mov dx, CmndError_NoPath
	call DisplayLine				; show currently no path
	Return

		; COMMAND.COM shows just "PATH=" in case there is no. NT CMD.EXE
		; shows "PATH=(null)".


		; else, set path
_Path_16:
	cmp byte [ si ], '='				; are we on = sign ?
	jnz _Path_20					; no -->
	mov si, word [ sizeArgCmd + argpointer + di ]	; get next arg
		; RxCMD 7.20N:	BUG. This has to check if the next argpointer is valid and
		;		whether the equal sign is the only character in that argument.

_Path_20:
	push si						; env string to add
	getarg di, _pathEndPtr				; get pointer to end
	getarg dx, _pathArgBeg				; restore arg to path
	cmp word [ _foundflag + bp ], TRUE		; path arg found ?
	jnz _Path_24					; no, no need to delete -->

	mov di, dx
	call deleteEnvVariable

_Path_24:
	mov si, RxDOS_PathSpec				; locate PATH=
	call insertEnvVariable
	call DisplayOutEnvSpace				; if error, display message
	pop si						; path string to insert
	jc _Path_Return

	call insertEnvVariable
	call DisplayOutEnvSpace				; if error, display message

_Path_Return:
	Return


		; Pause
		;
		; Usage:
		; ss:di	Arg Array
		; ax	Number of arguments in array
_Pause:
	mov dx, _PressAnyKeyToContinue
	call DisplayLine
	Int21 ClearBufferedKeyboardInput, KeyboardInput
	call CRLF

		; Remark (Rem)
_Rem:
	retn						; do nothing


		; Remove Directory
		;
		; Usage:
		; ss:di	Arg Array
		; ax	Number of arguments in array
_RemDir:

	call CheckOneArg				; see if 1 arg
	jc _removeDir_32				; if error -->

	mov dx, word [ argpointer + di ]		; point to filename arg
	Int21 LFNRemoveSubdirectory			; try command
	jnc _removeDir_32				; if valid -->

	call DisplayErrorCode				; if error

_removeDir_32:
	retn


		; SET
		; SET variable=
		; SET variable=string
		;
		; Display, set or remove environment variables.
_Set:
	entry
	def	_argarray, di
	def	_deleteFlag

	call CountArgs
	or ax, ax					; if no args
	jnz _SetEnvVariable				; set environment variable -->


		; display environment variables
_SetDisplay:
	xor si, si
	mov es, word [ _EnvSegment ]

_SetDisplay_08:
	cmp byte [ es:si ], 0
	jz _SetDisplayReturn
	cmp byte [ es:si ], ';'				; if comment,
	jz _SetDisplay_12				; skip -->
		; COMMAND.COM doesn't seem to know such comments.

	mov dx, si
	call DisplayLine
	call CRLF

_SetDisplay_12:
	inc si						; scan to end of env string
	cmp byte [ es:si - 1 ], 0
	jnz _SetDisplay_12
	jmp short _SetDisplay_08


		; upper case up to '='
_SetEnvVariable:
	getarg di, __argarray
	mov si, word [ argpointer + di ]		; point to arg array

_SetEnvVariable_08:
	mov al, byte [ si ]				; get character
	_upperCase al
	mov byte [ si ], al				; save it

	inc si
	cmp al, '='					; line contains a break ?
	jz _SetEnvVariable_12				; yes -->
	or al, al					; end of string ?
	jnz _SetEnvVariable_08				; not yet -->

	mov dx, CmndError_SyntaxError
	call DisplayErrorMessage			; display message
	return


		; search/delete
_SetEnvVariable_12:
	xor ax, ax
	mov al, byte [ si ]				; if char that follows is not
	storarg __deleteFlag, ax			; non-zero means insert

	mov si, word [ argpointer + di ]		; point to arg array
	call searchEnvVariable				; env variable located ?
	jnz _SetEnvVariable_18				; not found -->

	call deleteEnvVariable				; delete env variable


		; insert
_SetEnvVariable_18:
	getarg si, __argarray
	mov si, word [ argpointer + si ]		; get lead arg
	cmp word [ __deleteFlag + bp ], byte 0		; non-zero means insert
	jz _SetDisplayReturn				; delete only -->

	call insertEnvVariable				; insert at end
	call DisplayOutEnvSpace				; if error, display message


		; return
_SetDisplayReturn:
	Return


		; Shift
		;
		; No parameters expected
_Shift:

	mov si, ( RxDOS_BatchFile + batchArgPtrs )	; copy args down
	mov cx, word [ RxDOS_BatchFile + batchNumArgs ]
	or cx, cx
	jz _shift_32					; if no arguments -->

_shift_08:
	mov ax, word [ argpointer + sizeArgCmd + si ]
	mov dx, word [ arglength + sizeArgCmd + si ]
	mov word [ argpointer + si ], ax
	mov word [ arglength + si ], dx			; shift arg down
	add si, sizeArgCmd				; point to next arg
	loop _shift_08					; loop through all args

	dec word [ RxDOS_BatchFile + batchNumArgs ]	; decr # args

_shift_32:
	mov word [ argpointer + si ], 0			; null out last arg
	retn


		; Truename [ anypath ]
		;
		; Displays the DOS expanded filename.
_Truename:
	entry
	defbytes	buffer, sizeLFNPATH

	call CheckOptOneArg				; should have an arg
	jc _truename_36					; error -->

	mov si, word [ argpointer + di ]		; get argument passed
	or si, si					; if not actually null
	jnz _truename_24				; then fine -->
	mov si, RxDOS_TruenameCurrDir			; get argument passed

_truename_24:
	lea di, [ _buffer + bp ]
	mov word [ di ], 0				; init area

	mov cl, LFNEXPAND_GETFULLPATHNAME
	Int21 LFNGetActualFileName

	lea dx, [ _buffer + bp ]
	call DisplayLine				; print line

_truename_36:
	Return


		; Type filename
		;
		; Unlike MSDOS, TYPE will permit both the use of the pause /p
		; switch and wild card characters in a name.
_Type:
	entry
	def	_argarray, di
	def	wildchars, FALSE
	def	abortFlag, FALSE
	def	handle

	def	ptrName
	def	findHandle, -1

	defbytes	finddata, sizeFindData
	defbytes	_pathArg, sizeLFNPATH
	defbytes	buffer, SAFE_ALLOCATION

	mov cx, 0001					; at least one arg
	mov dx, 0999					; unlimited number of args
	mov bx, _TypeSwitches
	call PreProcessCmndLine				; process switches
	ifc _TypeReturn					; if error -->

	mov ax, word [ _TypePauseSwitch + swFlags ]
	call setPagingMode

	getarg di, __argarray
	call FixUpArguments				; null terminate args


		; get next argument
_TypeNext:
	getarg di, __argarray
	mov dx, word [ argpointer + di ]
	or dx, dx					; any more args ?
	ifz _TypeReturn					; if no more -->


		; get path for argument
	fileAttrib ATTR_NORMAL
	mov di, word [ __argarray + bp ]
	mov si, word [ argpointer + di ]		; point to filename arg
	lea di, [ _finddata + bp ]			; name area
	lea dx, [ __pathArg + bp ]			; expanded path (sizeLFNPATH)
	call BuildFullPathFirstFile			; filename found for arg ?
	storarg _findHandle, bx				; save find handle
	storarg _ptrName, dx				; present name to next
	jnc _TypeOpenFile				; yes, open and display -->

	mov dx, _TypeCannotFind
	call DisplayLine

	mov di, word [ __argarray + bp ]
	mov dx, word [ argpointer + di ]		; point to filename arg
	call DisplayLine				; show arg
	jmp _TypeReturn					; return -->


		; open and print
_TypeOpenFile:
	lea dx, [ __pathArg + bp ]			; expanded path
	ExOpenFile dx, OPEN_ACCESS_READONLY		; read only
	storarg _handle, ax				; save handle or error
	jc _TypeReturn					; if something went wrong -->

	call CRLF

	lea di, [ _finddata + bp ]			; name area
	call LFNReturnPreferedFilenamePtr
	call DisplayLine				; show arg
	call CRLF


		; read and list
_TypeReadFile:
	getarg bx, _handle				; get handle
	mov cx, SAFE_ALLOCATION				; how much to read
	lea dx, [ _buffer + bp ]			; where to read
	Int21 ReadFile					; read buffer
	jc _TypeCloseFile

	or ax, ax					; at end of file ?
	jz _TypeCloseFile				; yes, go to next -->

	mov cx, ax					; how much read
	lea dx, [ _buffer + bp ]			; where to read
	call DisplayLine_ByCount			; display buffer
	jnc _TypeReadFile				; keep reading file if no carry -->

	storarg _abortFlag, TRUE			; else abort


		; close file
_TypeCloseFile:
	getarg bx, _handle				; get handle
	Int21 CloseFile
	call CRLF

	cmp word [ _abortFlag + bp ], byte TRUE		; abort ?
	jz _TypeReturn					; exit ->

	getarg dx, _ptrName				; name field
	getarg bx, _findHandle				; find handle
	lea di, [ _finddata + bp ]			; name area
	call BuildFullPathNextFile			; filename found for arg ?
	jnc _TypeOpenFile				; yes, open file -->

	getarg bx, _findHandle				; find handle
	storarg _findHandle, -1				; close handle
	call BuildFullPathClose				; close find file
	add word [ __argarray + bp ], sizeArgCmd
	jmp _TypeNext					; else go to next -->


		; return
_TypeReturn:
	getarg bx, _findHandle				; find handle
	call BuildFullPathClose				; close find file
	Return


		; Verify [ ON | OFF ]
		;
		; Sets, clears or reports on RxDOS disk verify parameters.
_Verify:
	entry
	def	_argarray, di
	def	args, ax

	call CheckOptOneArg				; see if 1 arg
	jc _VerifyExit					; if error -->

	or ax, ax					; any arguments ?
	jz _VerifyPrintcurrent				; none, print current status -->


		; test for On/ Off
	mov si, word [ argpointer + di ]		; get arg pointer
	mov cx, word [ arglength + di ]			; get arg length
	mov di, RxDOS_OnOff
	call CmndLookup					; lookup command
	jc _VerifyError					; if not on/off, print line -->

	mov al, bl
	Int21 SetVerifySwitch				; set or clear verify switch
	Return


		; must specify on or off
_VerifyError:
	mov dx, CmndError_MustSpecifyOnOff
	call DisplayErrorMessage
	Return


		; print verify on/off value
_VerifyPrintcurrent:
	Int21 GetVerify

	mov bl, al
	xor bh, bh
	add bx, bx
	mov dx, word [ _VerifyOptions + bx ]
	call DisplayLine

_VerifyExit:
	Return


		; RxDOS 7.20N:
		; Display RxDOS version
		;
		; No parameters expected.
		;
		; RxDOS 7.30:
		; Display OS and RxCMD version
		;
		; /R	Display kernel information
_Ver:
	entry
	defbytes	printbuffer, 128

	xor cx, cx					; min args
	xor dx, dx					; max args
	mov bx, _VerSwitches				; dir switches
	call PreProcessCmndLine				; process switches and args
	jc .exit					; if error -->

	mov dx, RxDOS_Version
	call DisplayLine

	mov dx, RxDOS_VersionCopyright
	call DisplayLine

	test word [ _VerRSwitch + swFlags ], SW_SWITCHSET
	jz .exit


	mov ax, 3000h
	int 21h
	xor cx, cx
	mov cl, bh
	push cx			; OEM id
	mov cl, ah
	push cx			; minor version
	mov cl, al
	push cx			; major version

	mov bx, msg.ver_r_30
	push bx						; format
	lea di, [ _printbuffer + bp ]
	push di
	call _sprintf
	add sp, ax					; # args passed
	call DisplayLine


	mov ax, 3306h
	int 21h
	xor cx, cx
	mov cl, bh
	push cx			; minor version
	mov cl, bl
	push cx			; major version

	mov bx, msg.ver_r_true
	push bx						; format
	lea di, [ _printbuffer + bp ]
	push di
	call _sprintf
	add sp, ax					; # args passed
	call DisplayLine

	mov dx, msg.ver_r_str
	call DisplayLine


	mov ax, 33FFh
	xor dx, dx
	int 21h

	test dx, dx
	jz @F

	xchg ax, dx
	mov es, ax
	jmp @FF

@@:
	mov dx, msg.ver_r_no_str
@@:
	call DisplayLine
	call CRLF
	
.exit:
	Return


		; Volume
		;
		; Displays volume information
_Vol:
	entry
	def	currdisk, 0

	defbytes	finddata, sizeFindData
	defbytes	printbuffer, 128

	Int21 CurrentDisk
	add al, 'A'					; get drive
	mov byte [ _currdisk + bp ], al			; save current disk

	call CheckOptOneArg
	jc _Vol_60					; parameter is wrong -->
	jz _Vol_30					; if no parameters -->

	mov si, word [ argpointer + di ]		; get pointer to first arg
	mov ax, word [ si ]
	cmp ah, ':'					; not a drive specification ?
	jnz _Vol_62					; no -->

	_upperCase al					; disk id
	cmp al, 'Z'+1
	jnc _Vol_62
	cmp al, 'A'
	jc _Vol_62

	storarg _currdisk, ax				; save disk


		; get disk volume
_Vol_30:
	lea di, [ _finddata + bp ]
	call returnVolumeName
	jc _Vol_62					; cannot open drive -->

	mov bx, _Dir_NoVolumeLabel			; assume no volume label
	jnz _Vol_34					; if no volume name -->

	push di						; save vol label pointer
	mov bx, _Dir_VolumeLabel			; print statement format

_Vol_34:
	lea di, [ _currdisk + bp ]			; pointer to current disk
	push di						; current disk
	push bx						; format
	lea di, [ _printbuffer + bp ]
	push di
	call _sprintf
	add sp, ax					; # args passed
	call DisplayLine


		; return
_Vol_60:
	Return


		; drive specification error
_Vol_62:
	mov dx, CmndError_InvalidDrive
	call DisplayErrorMessage
	Return


		; Break into debugger
_Int3:
	call CheckNoArgs				; check for no arguments

	mov dx, msg.int3
	call DisplayLine

	int3
	retn


		; Commands not supported
_Chcp:
_Ctty:
	mov dx, CmndError_NotSupportedInRxDOS
	call DisplayErrorMessage
	retn


		; Other commands
_Help:
_History:
_Move:
_Loadhigh:
	mov dx, CmndError_NotSupportedYet
	call DisplayErrorMessage
	retn


		; Not a valid command
_NotValidCommand:

	push di
	mov dx, CmndError_BadCommandOrFileName
	call DisplayLine				; display error message

	pop di
	mov bx, word [ sizeArgCmd + di ]		; get second argument
	or bx, bx					; second argument ?
	jz _NotValidCommand_08				; if no second argument -->
	mov word [ ss:bx ], 0				; set at null terminator

_NotValidCommand_08:
	mov dx, word [ argpointer + di ]		; get command name
	call DisplayLine				; display error message

	mov dx, CmndError_EndOfBadCommand
	call DisplayLine				; display error message
	retn


		; Exit
_Exit:

	push es
	Int21 GetPSPAddress

	mov es, bx
	cmp word [ es:pspParentId ], byte 0		; no parent ?
	jz _Exit_12					; can't exit -->

	lds bx, [ _Int23_Original ]
	Int21 SetIntVector, 23h				; restore int 23
	Int21 TerminateProgram, 00h			; exit

_Exit_12:
	pop es
	retn


		; Check File
		;
		; Usage:
		; cx	attributes
		; dx	filename
		; di	finddata structure
		;
		; Returns:
		; cy	file not found or other error
CheckFile:

	mov si, FINDDATA_MSDOSDATEFORMAT
	Int21 LFNFindFirstFile				; locate file
	jc CheckFile_22					; if not found -->

	mov bx, ax
	Int21 LFNFindClose				; close search file
	clc

CheckFile_22:
	retn


		; Check File Close
		;
		; Usage:
		; bx	handle, or -1
CheckFileClose:

	cmp bx, -1
	jz CheckFileClose_08
	Int21 LFNFindClose

CheckFileClose_08:
	retn


		; Return Prefered Filename
		;
		; Usage:
		; di	ptr FINDDATA structure
		;
		; Returns:
		; dx	returns ptr to Long name if present
		; else, Short name
		;
LFNReturnPreferedFilenamePtr:

	lea dx, [ findDataLongFilename + di ]
	cmp byte [ es:findDataLongFilename + di ], 0
	jnz _lfnPref_08

	lea dx, [ findDataShortFilename + di ]

_lfnPref_08:
	retn
		; RxDOS 7.20N:	This code is wrong. If there is no long name, the short name
		;		field is empty and the long name field holds the short name!


		; Build Expanded Filename
		;
		; Usage:
		; si	ptr source filename arg (may contain partial path info)
		; di	ptr FINDDATA structure
		; dx	ptr expanded path arg
		; cx	search attributes
		;
		; Usage:
		; bx	handle to findfirst or -1
		; dx	offset to name field in expanded path arg
		;
BuildFullPathFirstFile:
	entry
	def	patharg, si
	def	expandedpath, dx
	def	attributes, cx
	def	finddata, di
	def	handle, -1
	def	ptrName

	SaveRegisters di, si

	mov di, dx
	mov byte [ di ], 0				; init area
	mov cl, LFNEXPAND_GETFULLPATHNAME
	Int21 LFNGetActualFileName			; expanded name (may include *.*)

	xor ax, ax
	mov cx, -1
	repne scasb					; length of expanded string
	not cx						; make len positive
	dec cx						; dec for term null

BuildFullPathFirstName_08:
	cmp byte [ es:di - 1 ], '\'			; path divider ?
	jz BuildFullPathFirstName_12			; yes -->
	dec di
	loop BuildFullPathFirstName_08

BuildFullPathFirstName_12:
	storarg _ptrName, di

	getarg dx, _patharg				; expanded path
	getarg di, _finddata				; find work area
	getarg cx, _attributes				; search attributes
	mov si, FINDDATA_MSDOSDATEFORMAT		; date format
	Int21 LFNFindFirstFile				; locate file
	jc BuildFullPathFirstName_24			; if it does not exist -->

	storarg _handle, ax				; save handle

	getarg di, _finddata
	call LFNReturnPreferedFilenamePtr		; get whichever name is available

	mov si, dx
	getarg di, _ptrName
	call CopyString					; append filename

BuildFullPathFirstName_24:
	RestoreRegisters si, di

	getarg bx, _handle
	getarg dx, _ptrName
	Return


		; Build Next Expanded Filename
		;
		; Usage:
		; di	ptr FINDDATA structure
		; dx	ptr expanded path arg
		; bx	search handle
		;
BuildFullPathNextFile:
	entry
	def	handle, bx
	def	expandedpath, dx
	def	finddata, di

	SaveRegisters di, si, dx, cx, bx, ax

	getarg di, _finddata				; find work area
	mov si, FINDDATA_MSDOSDATEFORMAT		; date format
	Int21 LFNFindNextFile				; locate next file
	jc BuildFullPathNextName_24			; if it does not exist -->

	getarg di, _finddata
	call LFNReturnPreferedFilenamePtr		; get whichever name is available
	mov si, dx

	getarg di, _expandedpath			; where to copy expanded name
	call CopyString					; append filename

BuildFullPathNextName_24:
	RestoreRegisters ax, bx, cx, dx, si, di
	Return


		; Build Close Expanded Filename
		;
		; Usage:
		; bx	search handle
BuildFullPathClose:

	cmp bx, -1
	jz BuildFullPathClose_08
	Int21 LFNFindClose

BuildFullPathClose_08:
	retn


		; Compute Length
		;
		; Usage:
		; cx	length of string
		; si	starting address of string.
_computeLength:
	push si

_computeLength_06:
	cmp byte [ si ], ' '+ 1
	jc _computeLength_08
	cmp byte [ si ], ')'
	jz _computeLength_08
	cmp byte [ si ], ','
	jz _computeLength_08
	cmp byte [ si ], ';'
	jz _computeLength_08

	inc si
	jmp short _computeLength_06

_computeLength_08:
	pop cx
	xchg cx, si
	sub cx, si
	retn


		; delete Lead At Sign
		;
		; Input:
		; di	starting address of NULL terminated string.
		;
		; Output:
		; ZR	if lead character is @ sign
		; all registers preserved except flags.
deleteLeadAtSign:
	cmp byte [ di ], '@'				; starts with @ sign ?
	jnz deleteLeadAtSign_12				; no -->

	pushf
	SaveSegments di, si, ax

	setDS es
	mov si, di					; copy buffer ptr
	inc si						; source
	call CopyString

	RestoreSegments ax, si, di
	popf

deleteLeadAtSign_12:
	retn


		; See if Wild Characters Are Used.
		;
		; Usage:
		; cx	length of string
		; si	starting address of string.
_Seeif_WildCharacter:

	push si
	push cx

_WildCharacter_08:
	lodsb
	cmp al, '?'
	jz _WildCharacter_12
	cmp al, '*'
	jz _WildCharacter_12

	loop _WildCharacter_08
	stc

_WildCharacter_12:
	pop cx
	pop si
	retn


		; Create Default Master Environment, if none
		;
		; INP:	bx = value of [PSP:2Ch] (environment segment or 0)
		; OUT:	bx = environment
		;	es = PSP
_DefaultCreateEnvironment:
	entry
	def	CurrentPSP, es
	ddef	pgmName, 0, 0				; save ptr to orig pgm name

	or bx, bx					; env block passed ?
	jz _crEnvironment_24				; if no name passed, create -->

	mov es, bx					; current segment
	xor di, di					; byte offset
		; RxDOS 7.20N:	The environment is empty if that byte (!) is zero.
		; Actually it's unclear how many bytes are needed to indicate
		; an empty environment block.
	cmp byte [ es:di ], 0				; empty env block ?
	jnz _crEnvironment_36				; no, leave alone -->

	add di, 3					; skip over # strings word
	stordarg _pgmName, es, di			; save ptr to orig pgm name

		; allocate environment segment
_crEnvironment_24:
	mov bx, word [ _EnvSize ]			; from /E or default size
	shr bx, 1
	shr bx, 1
	shr bx, 1
	shr bx, 1					; # paragraphs
	Int21 AllocateMemory				; try to allocate
	jc _crEnvironment_36				; if couldn't -->

	mov es, ax
	mov word [ _EnvSegment ], ax			; updated env segment address

	xor di, di
	mov cx, word [ _EnvSize ]
	clearMemory

		; create COMSPEC
	cmp word [ _pgmName + _segment + bp ], byte 0	; source name ?
	jz _crEnvironment_36				; no -->

	mov si, RxDOS_CommandSpec
	call insertEnvVariable				; insert COMSPEC=
	jc _crEnvironment_36				; if no room -->

	push ds
	getdarg ds, si, _pgmName			; com spec name
	call insertEnvVariable				; insert spec name
	pop ds						; restore stack
	; jc _crEnvironment_36				; if no room -->

		; exit
_crEnvironment_36:
	mov bx, word [ _EnvSegment ]
	mov es, word [ _CurrentPSP + bp ]
	Return


		; Save Batch File Position
		;
		; Returns:
		; bx	batch file handle
		; dx:ax	position in batch file
getBatchPosition:

	xor cx, cx
	xor dx, dx
	mov bx, word [ RxDOS_BatchFile + batchFileHandle ]
	Int21 MoveFilePointer, SEEK_CUR
	retn


		; Manage Stdin Input
		;
		; Usage:
		; ss:dx-> buffer (pointer to max length)
_getStdinLine:
	entry
	def	buffer, dx

	push di
	push bx
	push dx

	mov di, dx
	mov bx, STDIN
	Int21 IoControl, 00h				; get stdin device data
	test dx, sftIsDevice				; file or device ?
	jnz _getStdinLine_32				; device, just read directly -->
		; RxDOS 7.20N:	I'm not certain this is required.


		; read by character if file
_getStdinLine_08:
	mov di, word [ _buffer + bp ]
	mov bl, byte [ bufActualLength + di ]		; store character into buffer
	xor bh, bh
	lea dx, [ bufData + di + bx ]			; data address

	mov cx, 1
	mov bx, STDIN
	Int21 ReadFile					; read character
	jc _getStdinLine_28

	or ax, ax					; read anything ?
	jz _getStdinLine_28				; no, see if return -->

	mov di, word [ _buffer + bp ]
	mov bl, byte [ bufActualLength + di ]		; store character into buffer
	xor bh, bh

	mov dl, byte [ bufData + di + bx ]		; get character
	cmp dl, 10					; character lf ?
	jz _getStdinLine_08				; ignore lf -->

	push dx
	Int21 DisplayOutput				; echo character

	pop dx
	inc byte [ bufActualLength + di ]		; store character into buffer
	cmp dl, 13					; character cr ?
	jz _getStdinLine_34				; yes, end of input -->

	mov al, byte [ bufActualLength + di ]		; actual less than max ?
	cmp al, byte [ bufMaxLength + di ]		; get max
	jc _getStdinLine_08
	jmp short _getStdinLine_34


		; end of file
_getStdinLine_28:
	mov di, word [ _buffer + bp ]
	mov dl, byte [ bufActualLength + di ]		; store character into buffer
	or dl, dl					; any characters ?
	jnz _getStdinLine_34				; yes, return -->


		; cancel stdin
	mov ax, 1					; this may have to change !
	mov bx, STDIN
	call _CloseRedirectedDevice


		; read directly if device
_getStdinLine_32:
%if 0
	mov ax, 4800h
	push es
	int 2Fh						; DOSKey (or CMDEDIT, etc.) installation check
	pop es						; Int2F.4800 destroys es
	pop dx						; buffer address (Int2F.4800 may destroy dx)
	or al, al					; ax is AA02h (MS), AACE (CMDEDIT), etc.
	jz .nodoskey
		; We don't have to use the installation check. Int2F.4810 sets ax = 0000h on success.
%else
	pop dx
%endif
	mov ax, 4810h
	int 2Fh						; DOSKey buffered input
	or ax, ax
	jz _getStdinLine_34				; got line from DOSKey compatible -->

%if 1
		; Possibly this DOSKey only supports buffers of 128 byte size!
		; If the buffer is larger than 128 byte, we can shrink it to that
		; size and try it again.
	xchg bx, dx					; ds:bx-> buffer
	cmp byte [bx], 128
	xchg bx, dx					; need to restore bx,dx if branching
	jbe .nodoskey					; ZR: no DOSKey. CY: buffer too small (<128 byte)
	xchg bx, dx
	push word [bx]					; save real size of buffer
	mov byte [bx], 128				; shrink buffer to 128 byte
	cmp byte [bx+1], 128				; more than 128 byte in recall buffer ?
	jna .recallfixed
	mov byte [bx+1], 128				; then shorten to 128 byte
.recallfixed:
	xchg bx, dx					; ds:dx-> buffer
	mov ax, 4810h
	int 2Fh						; try again to get input with 128 byte buffer
	or ax, ax
	xchg bx, dx					; ds:bx-> buffer
	pop ax
	mov byte [bx], al				; restore low byte only
	xchg bx, dx					; don't change flags here!
	jz _getStdinLine_34				; got up to 128 byte line from MS DOSKey -->
%endif	
.nodoskey:
	Int21 GetLine					; read direct from device

_getStdinLine_34:
	call CRLF
		; RxDOS 7.20N:	Make a line break after prompting for programs that start
		;		their output without one (even our ECHO command!).
		; RxDOS 7.20N:	This should possibly move to somewhere later. Blank lines
		;		(that don't execute anything) don't make this line break.
	getarg dx, _buffer
	pop bx
	pop di
	return


		; Read Line
		;
		; Usage:
		; ss:si	buffer (pointer to max length)
		; bx	file handle (null value means stdin )
		; al	echo status
		;
		; Returns:
		; ax	actual length not incl cr.
_ReadLine:
	entry
	ddef	buffer, ss, si

	or bx, bx					; process from batch file ?
	jz _ReadLine_08					; no, read from console -->

	call _ReadBatch					; else read batch file
	jmp short _ReadLine_26


		; read from keyboard
_ReadLine_08:
	call DisplayPrompt				; display prompt

	mov dx, word [ _buffer + _pointer + bp ]
	call _getStdinLine				; read buffer
	; call CRLF


		; return
_ReadLine_26:
	mov si, word [ _buffer + _pointer + bp ]
	mov al, byte [ bufActualLength + si ]
	and ax, 00FFh					; actual length
	Return


		; Read Batch Line
		;
		; Usage:
		; ss:si	buffer (pointer to max length)
		; bx	file handle (null value means stdin )
		; al	echo status
_ReadBatch:
	entry
	def	bytesRead
	def	echoline, ax
	def	Handle, bx
	ddef	buffer, ss, si

	add si, bufData					; offset to data
	ddef	bufferData, ss, si


		; read line
	mov cx, sizeCmdLine
	mov dx, word [ _bufferData + _pointer + bp ]	; where to read
	mov bx, word [ RxDOS_BatchFile + batchFileHandle ]

	call ReadBatchLine
	mov word [ _bytesRead + bp ], ax		; save count
	jnz _ReadBatch_08				; if none -->

	call _EndCall					; end batch file call

	xor ax, ax					; return zero bytes
	mov di, word [ _buffer + _pointer + bp ]	; buffer address
	mov byte [ bufActualLength + di ], al
	Return


		; trim line to carriage return
_ReadBatch_08:
	mov di, word [ _buffer + _pointer + bp ]	; buffer address
	mov byte [ bufActualLength + di ], al


		; perform variable replacement
_ReadBatch_20:
	mov bx, word [ _bytesRead + bp ]
	mov si, word [ _bufferData + _pointer + bp ]	; buffer address
	mov byte [ si+bx ], 00
	call ReplaceTempVariables			; replace %n variables

	mov si, word [ _buffer + _pointer + bp ]	; buffer address
	mov byte [ bufActualLength + si ], cl


		; echo enabled ?
	cmp byte [ _echoLine + bp ], 00
	jz _ReadBatch_32				; echo is off -->

	mov cx, ax					; length of line
	mov di, word [ _bufferData + _pointer + bp ]	; buffer address
	call deleteLeadAtSign				; clean up if lead at sign
	jz _ReadBatch_32				; if at sign, no echo -->

_ReadBatch_24:
	cmp byte [ di ], ' '				; still in white space ?
	jnz _ReadBatch_26				; no, echo line -->
	inc di
	loop _ReadBatch_24


		; echo this line
_ReadBatch_26:
	call CRLF
	call DisplayPrompt				; display prompt

	mov dx, di
	call DisplayLine				; echo line
%if 0
	call CRLF
%endif


		; return
_ReadBatch_32:
	mov di, word [ _buffer + _pointer + bp ]	; buffer address
	mov ax, word [ _bytesRead + bp ]
	or di, di					; data always returned
	return


		; Read Batch Line
		;
		; Returns:
		; bx	batch file handle
		; dx	line buffer address

ReadBatchLine:
	entry
	def	Handle, bx
	def	lineBuffer, dx
	def	bytesRead, 0
	ddef	filePosition
	defbytes	tempbuffer, 2


		; get current position in file
	xor cx, cx
	xor dx, dx
	Int21 MoveFilePointer, SEEK_CUR
	mov word [ _FilePosition + _low + bp ], ax
	mov word [ _FilePosition + _high + bp ], dx	; save current position


		; get current position in file
	getarg si, _lineBuffer
	mov byte [ si ], 00				; set null terminator at beg

	getarg bx, _Handle
	mov cx, sizeCmdLine
	getarg dx, _lineBuffer				; where to read batch file
	Int21 ReadFile					; read
	jc ReadBatchLine_36				; if error -->
	mov word [ _bytesRead + bp ], ax

	or ax, ax					; end of batch file ?
	jz ReadBatchLine_36				; yes -->


		; trim line to carriage return
	mov cx, ax					; scan line
	getarg di, _lineBuffer				; where to read batch file

	mov al, 13
	repne scasb					; scan for cr
	jz ReadBatchLine_20				; carriage return found -->

ReadBatchLine_12:
	mov cx, 1
	lea dx, [ _tempbuffer + bp ]			; scan char by character till cr
	Int21 ReadFile					; read
	jc ReadBatchLine_36				; if error -->
	or ax, ax					; end of file ?
	jz ReadBatchLine_36				; yes -->

	cmp byte [ _tempbuffer + bp ], 13		; carriage return ?
	jnz ReadBatchLine_12				; no -->
	jmp short ReadBatchLine_30			; process line a bit -->


		; position line immediately after cr
ReadBatchLine_20:
	mov ax, word [ _bytesRead + bp ]
	sub ax, cx
	push ax

	cmp byte [ di ], ControlJ
	jnz ReadBatchLine_22				; if line feed doesn't follow -->
	inc ax						; account for lf

ReadBatchLine_22:
	mov dx, word [ _FilePosition + _low + bp ]
	mov cx, word [ _FilePosition + _high + bp ]	; orig position
	add dx, ax
	adc cx, 0

	getarg bx, _Handle
	Int21 MoveFilePointer, SEEK_BEG			; get current position

	pop ax
	dec ax						; don't include cr
	mov word [ _bytesRead + bp ], ax		; bytes read


		; does line begin with a line feed ?
ReadBatchLine_30:
	getarg di, _lineBuffer
	cmp byte [ di ], 10
	jnz ReadBatchLine_32				; no -->

	getarg cx, _bytesRead
	mov si, di
	inc si
	repz movsb					; copy

	dec word [ _bytesRead + bp ]


		; place null terminator at end
ReadBatchLine_32:
	getarg bx, _bytesRead
	getarg si, _lineBuffer
	mov byte [ si+bx ], 0				; set null terminator at end

	mov ax, bx
	or si, si					; nz means valid return
	Return


		; end of file or error
ReadBatchLine_36:
	xor ax, ax
	Return


		; Initial command shell entry
		;
		; RxDOS 7.30:	Parts of the initializing should move into RXCMDINSTALLATION.
%if _BUILD_OBJ
..start:
%endif
CommandBegin:

	cli
	mov ax, cs
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov sp, RxDOS_CmdStack

	sti
	cld

	mov word [ RxDOS_BatchFile + batchEchoStatus ], ON
	mov word [ RxDOS_BatchFile + batchNumArgs ], 0	; no args


		; process startup command switches
	push ds
	mov ax, ds
	sub ax, sizePSP /16
	mov ds, ax					; segment

	xor cx, cx
	mov si, 81h					; where command line is in PSP
	mov cl, byte [ si - 1 ]
	call ProcessStartupSwitches			; get options
	pop ds


		; initialize stack frame
	entry
	defbytes	cmdline, sizeCmdLineStruct
	defbytes	SaveBatchInfo, sizeBATCH_ARGS	; previous batch file

	mov word [ RxDOS_PrevStackFrame ], sp		; current stack frame

	lea si, [ _cmdline + bp ]
	mov byte [ ss:bufActualLength + si ], 0

	mov si, RxDOS_BatchFile
	mov di, word [ RxDOS_PrevStackFrame ]		; copy args to stack frame
	mov cx, sizeBATCH_ARGS
	repz movsb					; copy


		; release unwanted memory (may be removed later)
%if 1
	Int21 GetPSPAddress
	mov word [ _PSPSegment ], bx

	mov es, bx					; block to be changed
%else
		; RxDOS 7.20N:	In .COM files, cs is also the PSP.
	mov word [ _PSPSegment ], cs

	push cs
	pop es						; block to be changed
%endif

%if 1
	mov bx, RXDOSLASTADDRESS +100h +16
	shr bx, 1
	shr bx, 1
	shr bx, 1
	shr bx, 1
%else
	mov bx, (RXDOSLASTADDRESS +100h +15) /16
%endif
	Int21 ModifyAllocatedMemory, 00
		; RxDOS 7.20N:	Check CY!


		; get or create environment and its size
	mov es, word [ _PSPSegment ]			; get PSP address
	mov bx, word [ es:pspEnvironment ]		; get segment of environment
	mov word [ _EnvSegment ], bx
	call _DefaultCreateEnvironment

	dec bx
	mov es, bx					; address MCB of environment
	mov bx, word [ es:_memAlloc ]			; size of environment block (in paragraphs)
	shl bx, 1
	shl bx, 1
	shl bx, 1
	shl bx, 1					; convert paragraphs to byte
	mov word [ _EnvSize ], bx			; save environment size


		; set DTA
	Int21 GetDTA
	mov word [ RxDOS_OrigDTA + _segment ], es
	mov word [ RxDOS_OrigDTA + _pointer ], bx
	currSegment es

	mov dx, RxDOS_DTA
	Int21 SetDTA					; set new disk transfer address


		; set interrupt vectors
	Int21 GetIntVector, 23h
	mov word [ _Int23_Original + _pointer ], bx
	mov word [ _Int23_Original + _segment ], es

	mov dx, _ControlC_ISR
	Int21 SetIntVector, 23h				; int 23h

	mov dx, CommandInput
	Int21 SetIntVector, 22h				; int 22h
		; RxDOS 7.20N:	This is a bad hack which doesn't work anyway. DOS always uses the Int22
		;		value stored in the PSP when terminating.


		; init screen
	setES ds					; restore es
	call CRLF

	mov dx, RxDOS_Version
	call DisplayLine				; print startup version

	mov dx, RxDOS_VersionCopyright
	call DisplayLine				; print startup version

		; execute RXAUTO.BAT
	ExOpenFile RXAUTO_BAT, OPEN_ACCESS_READONLY	; try RXAUTO.BAT first
	jnc CommandBegin_16
	ExOpenFile AUTOEXEC_BAT, OPEN_ACCESS_READONLY	; if not found, try AUTOEXEC.BAT
	jc CommandBegin_22
		; RxDOS 7.30:	Should move to RxDOS's initialization code. (Paramater: /D /K {filename})

CommandBegin_16:
	mov word [ RxDOS_BatchFile + batchFileHandle ], ax

CommandBegin_22:

		; basic command loop
CommandInput:
	setDS ss					; restore ds
	setES ds					; restore es
	mov sp, word [ RxDOS_PrevStackFrame ]		; current stack frame
%if 1
	call SetPageZero				; set page 0
%endif

%if 1
	mov dx, _Int2E_CommandParser
	Int21 SetIntVector, 2Eh				; int 2Eh
		; RxDOS 7.30:	Should move into RXCMDINSTALLATION.
%endif

	lea si, [ _cmdline + bp ]
	mov byte [ bufMaxLength + si ], sizeCmdLine
		; Not save to use bp and si here.

	mov bx, word [ RxDOS_BatchFile + batchFileHandle ]
	mov al, byte [ RxDOS_BatchFile + batchEchoStatus ]
	call _ReadLine
	jz CommandInput					; no, redisplay prompt -->

	mov bx, ax
	lea si, [ _cmdline + bufActualLength + bp ]
	call _CommandParser				; go parse / execute
	jmp short CommandInput


		; Process startup switches
		;
		; INP:	ds:si-> command line
		;	cx = command line length
		;
		; Warning: ds points to command line buffer
		;
		; RxDOS 7.30:	Should move into RXCMDINSTALLATION.
ProcessStartupSwitches:

	mov bx, cx
	mov byte [ si + bx ], 0				; null terminate line

_startupSwitches_08:
	lodsb

_startupSwitches_12:
	or al, al					; end of line ?
	jz _startupSwitches_Return			; yes -->

	cmp al, '/'					; switch ?
	jnz _startupSwitches_08				; not yet -->

		; get character past switch
	lodsb
	_upperCase al
	cmp al, 'E'					; set environment ?
	jz _startupSwitches_EnvSize			; yes -->
	cmp al, 'C'					; one command ?
	jz _startupSwitches_SingleCommand		; yes -->

		; RxDOS 7.20N:	Better command line parsing required.
		;		Add /C, /K and /P, ignore /D.

	jmp short _startupSwitches_12			; continue processing -->


		; One time command
		;
		; NOP
_startupSwitches_SingleCommand:
	jmp short _startupSwitches_08			; continue processing -->


		; Get environment size
_startupSwitches_EnvSize:
	xor dx, dx					; accum value

	lodsb						; skip through a delim
	cmp al, ' '
	je _startupSwitches_20
	cmp al, ':'					; separator follows "/E" ?
	je _startupSwitches_20				; yes -->
	cmp al, '='
	je _startupSwitches_20				; yes -->
	dec si						; go back

_startupSwitches_20:
	lodsb						; get character
	cmp al, '0'
	jb _startupSwitches_26				; if not a digit -->
	cmp al, '9'
	ja _startupSwitches_26				; if not a digit -->

	and ax, 15					; strip down value
	mov cx, dx
	add dx, dx					; *2
	add dx, dx					; *4
	add dx, cx					; *5
	add dx, dx					; *10
	add dx, ax					; add new value
	jmp short _startupSwitches_20

_startupSwitches_26:
	cmp dx, DEFAULT_MINENVIRONMENT
	jb _startupSwitches_12
	cmp dx, DEFAULT_MAXENVIRONMENT
	ja _startupSwitches_12

	mov word [ ss:_EnvSize ], dx			; environment size
	jmp short _startupSwitches_12			; continue processing -->


		; Return
_startupSwitches_Return:
	retn


		; Internal Commands
	align 2, db 0

RxDOS_InternalCommands:

	cmnd _ChangeDir,"cd"
	cmnd _ChangeDir,"chdir"
	cmnd _makeDir,	"md"
	cmnd _makeDir,	"mkdir"
	cmnd _RemDir,	"rd"
	cmnd _RemDir,	"rmdir"
	cmnd _Break,	"break"
	cmnd _Call,	"call"
	cmnd _Chcp,	"chcp"
	cmnd _Cls,	"cls"
	cmnd _Copy,	"copy"
	cmnd _Ctty,	"ctty"
	cmnd _Date,	"date"
	cmnd _Delete,	"del"
	cmnd _Dir,	"dir"
	cmnd _Echo,	"echo"
	cmnd _Delete,	"erase"
	cmnd _Exit,	"exit"
	cmnd _For,	"for"
	cmnd _Goto,	"goto"
	cmnd _If,	"if"
	cmnd _Loadhigh,	"lh"
	cmnd _Loadhigh,	"loadhigh"
	cmnd _Path,	"path"
	cmnd _Pause,	"pause"
	cmnd _Prompt,	"prompt"
	cmnd _Rem,	"rem"
	cmnd _Rename,	"rename"
	cmnd _Rename,	"ren"
	cmnd _Set,	"set"
	cmnd _Shift,	"shift"
	cmnd _Time,	"time"
	cmnd _Truename,	"truename"
	cmnd _Type,	"type"
	cmnd _Verify,	"verify"
	cmnd _Ver,	"ver"
	cmnd _Vol,	"vol"
	cmnd _Int3,	"int3"
	dw -1


		; Unix style commands
	align 2, db 0

RxDOS_UNIXStyleCommands:

	cmnd _Type,	"cat"
	cmnd _Copy,	"cp"
	cmnd _Delete,	"rm"
	cmnd _Dir,	"ls"
	cmnd _Move,	"mv"			; * future feature
	cmnd _Set,	"setenv"
	dw -1


		; Environment Variables
RxDOS_CommandSpec:	asciz "COMSPEC="
RxDOS_DirSpec:		asciz "DIRCMD="
RxDOS_PathSpec:		asciz "PATH="
RxDOS_PromptSpec:	asciz "PROMPT="
RxDOS_RxDOSSwitchSpec:	asciz "SWITCH="
RxDOS_RxDOSSpec:	asciz "RXDOS="
RxDOS_UNIXSpec:		asciz "UNIX"


		; Return code (errorlevel) of programs
RxDOS_ExecReturnCode:	dw 0

		; Execution Order
RxDOS_ExecOrder:	dw _asciz_com
			dw _asciz_exe
			dw _asciz_bat
			dw 0

_asciz_com:		asciz ".com"
_asciz_exe:		asciz ".exe"
_asciz_bat:		asciz ".bat"


		; ON/OFF options
RxDOS_OnOff:
	cmnd 1,		"on"
	cmnd 0,		"off"
	cmnd 1,		"1"
	cmnd 0,		"0"
	cmnd 1,		"true"
	cmnd 0,		"false"
	cmnd 1,		"enabled"
	cmnd 0,		"disabled"
	cmnd 1,		"active"
	cmnd 0,		"inactive"
	cmnd 1,		"yes"
	cmnd 0,		"no"

	dw -1


		; IF options
RxDOS_IfOptions:
	cmnd IF_ERRORLEVEL,	"errorlevel"
	cmnd IF_EXIST,		"exists"
	cmnd IF_EXIST,		"exist"
	cmnd IF_NOT,		"not"
	dw -1


		; FOR options
RxDOS_ForArgs:
	cmnd _IN,	"in"
	cmnd _DO,	"do"
	dw -1


		; Version number
RxDOS_Version:	db RXCMDLONG_S, " version ", RXCMDVERSIONLONG_S
%ifnidn _REVISIONID, ""
		db 13,10," Source Control Revision ID: ",_REVISIONID
%endif
		db 13,10," Build on ",__DATE__
		asciz

RxDOS_VersionCopyright:
		db 13,10
		db " Copyright (C) 1990-1999 Mike Podanoffsky",13,10
		db " Copyright (C) 2008-2018 C. Masloch",13,10
		asciz

		; Error Table
	align 2, db 0

CmndError_TextReferenceTable:

	dw 0						; 0000
	dw 0						; 0001
	dw CmndError_FileNotFound			; 0002
	dw CmndError_InvalidDirectory			; 0003
	dw 0						; 0004
	dw CmndError_AccessDenied			; 0005
	dw 0						; 0006
	dw 0						; 0007
	dw 0						; 0008
	dw 0						; 0009
	dw 0						; 0010
	dw 0						; 0011
	dw 0						; 0012
	dw 0						; 0013
	dw 0						; 0014
	dw 0						; 0015
	dw CmndError_CurrentDirectory			; 0016

CmndError_RefTableEntries	equ ($ - CmndError_TextReferenceTable)/2


		; Error Messages
CmndError_AccessDenied:			asciz "access denied"
CmndError_BadCommandOrFileName:		asciz "bad command: could not find or execute '"
CmndError_EndOfBadCommand:		asciz "'",13,10
CmndError_BadSwitch:			asciz "bad switch - "
CmndError_CannotCopyOverSelf:		asciz "file cannot be copied over itself"
CmndError_CannotCreateFile:		asciz "cannot create destination file"
CmndError_ContentsLostBeforeCopy:	asciz "contents of file lost before copy"
CmndError_CurrentDirectory:		asciz "cannot remove current directory"
CmndError_FileAlreadyExists:		asciz "file not found or already exists"
CmndError_FileNotFound:			asciz "file not found"
CmndError_NoFilesFound:			asciz " no files found",13,10
CmndError_InvalidDate:			asciz "invalid date"
CmndError_InvalidDirectory:		asciz "invalid directory"
CmndError_InvalidDrive:			asciz "invalid drive"
CmndError_InvalidTime:			asciz "invalid time"
CmndError_MustSpecifyOnOff:		asciz "must specify ON or OFF"
CmndError_NotSupportedYet:		asciz "command not supported yet !"
CmndError_NotSupportedInRxDOS:		asciz "command not supported in RxDOS"
CmndError_FileNameMissing:		asciz "file name missing"
CmndError_SubDirAlreadyExists:		asciz "subdirectory already exists"
CmndError_SyntaxError:			asciz "syntax error"
CmndError_TooManyParameters:		asciz "too many parameters - "
CmndError_ParametersMissing:		asciz "parameter(s) missing"
CmndError_NoPath:			asciz "no path"
CmndError_InvalidNumberArguments:	asciz "invalid number of arguments"
CmndError_OutOfEnvironmentSpace:	asciz "out of environment space"
CmndError_ReadErrorAbort:		asciz "error reading file"

msg:
.error_load_program:	asciz "Error loading program."
.int3:			asciz "Breaking into debugger.",13,10
.ver_r_30:	asciz 13,10,"Reported DOS version (Int21.3000): %id.%z2id OEM: %z2iXh",13,10
.ver_r_true:	asciz "Reported true DOS version (Int21.3306): %id.%z2id",13,10
.ver_r_str:	asciz "Version string (Int21.33FF): "
.ver_r_no_str:	asciz "(None)"
.invalid_sprintf_format:
		asciz "Internal error: Invalid sprintf format!",13,10

		; Other Variables
RxDOS_NewLine:			asciz 13,10

RxDOS_RootDirectoryDriveLetter	db "c:"
RxDOS_RootDirectory		asciz "\*.*"		; root directory
RxDOS_AllFiles			db "*"			; combines with next
RxDOS_AllExtensions		asciz ".*"

RxDOS_TruenameCurrDir		asciz "."		; current directory


		; Control-C Handling
	align 4, db 0

		; RxDOS 7.20N:	Will move into IISP entry.
_Int23_Original		 dd 0


		; Echo/Paging
LinesDisplayed			dw 00			; number of lines displayed, curr page
PageLines			db 00			; paging mode


		; Prompt
RxDOS_DefaultPrompt:		asciz "$P$G"		; "D:\>" where D:\ is the current drive and directory
RxDOS_Prompt:			fill 128, 0, asciz "$P$G"

		; Special command separators
_UnixStyle			db 0			; non-zero if Unix style commands enabled
_SwitchChar			db "/"			; switch character
_CmndParse_Separators		db " <>|[],+=()%"	; valid break characters
_CmndParse_SeparatorsLength	equ ($ - _CmndParse_Separators)

_CmndParse_FileSysReserved	db ":.\[];,+="		; file system reserved chars
_CmndParse_FileSysReservedLen	equ ($ - _CmndParse_FileSysReserved)


		; Environment location/size
_PSPSegment			dw 0			; PSP segment address
_EnvSegment			dw 0			; environment segment address
_EnvSize			dw DEFAULT_MINENVIRONMENT	; environment size (bytes)


		; Batch file arguments
RxDOS_BatchFile			times sizeBATCH_ARGS db 0
RxDOS_PrevStackFrame		dw 0			; end call stack frame
RxDOS_StackFrameNumEntries	dw 0			; number of entries in stack

		; RxDOS 7.30: This should move to RxDOS's initialization code.
RXAUTO_BAT		asciz "\RXAUTO.BAT"
AUTOEXEC_BAT		asciz "\AUTOEXEC.BAT"


		; Restore Original Parameters
RxDOS_OrigDTA		dd 0				; original DTA value


		; Type Switches
_TypeSwitches:
_TypePauseSwitch:	switch 'p', 0
			db -1

_TypeCannotFind:	asciz 'cannot find - '


		; Dir Switches
_DirSwitches:
_DirPauseSwitch:	switch 'p', 0
_DirWideSwitch:		switch 'w', 0
_DirAttribSwitch:	switch 'a', SW_LETTERCHOICE, SW_DIR_ATTRIB
_DirOrderSwitch:	switch 'o', SW_LETTERCHOICE, SW_DIR_ORDER
_DirSubDirSwitch:	switch 's', 0
_DirLowerCaseSwitch:	switch 'l', 0
_DirBareSwitch:		switch 'b', 0
			db -1

_VerSwitches:
_VerRSwitch:		switch 'r', 0
			db -1

SW_DIR_ATTRIB:		db '-dnsra', 0
SW_DIR_ORDER:		db '-negsd', 0

_Dir_NoVolumeLabel:	asciz " Volume in drive %c has no label",13,10
_Dir_VolumeLabel:	asciz " Volume in drive %c is %s",13,10
%if 1
_Dir_VolumeSerialNumber:asciz " Volume Serial Number is %s",13,10
_Dir_DirectoryOf:	asciz " Directory of %s",13,10,13,10
%else
_Dir_VolumeSerialNumber:asciz " Volume serial number is %s",13,10
_Dir_DirectoryOf:	asciz 13,10 \
				" Directory of %s",13,10,13,10
%endif
_Dir_Files_Summary:	asciz "    %5d file(s) %13,ld bytes",13,10, \
				"                  %13,ld bytes free",13,10
_Dir_Files_MBSummary:	asciz "    %5d file(s) %13,ld bytes",13,10, \
				"                  %9,ld.%2zd MB free",13,10

_Dir_FileEntry:		asciz "%8s %3s %9,ld %s %s %s",13,10
			;      SFN EXT size  DateTimeLFN
_Dir_DirEntry:		asciz "%8s %3s <DIR>     %s %s %s",13,10


		; Copy messages
_Copy_FilesCopied:	asciz "    %5d file(s) copied",13,10


		; Pause/Continue
_PressAnyKeyToContinue:	asciz "Press any key to continue . . . "
_Dir_Continuing:	asciz "(continuing %s)",13,10


%if 1
		; Display BREAK state
_BreakOptions:		dw _BreakIsOFF, _BreakIsON

_BreakIsOFF:		asciz "Break is OFF",13,10
_BreakIsON:		asciz "Break is ON",13,10


		; Display ECHO state
_EchoOptions:		dw _EchoIsOFF, _EchoIsON

_EchoIsOFF:		asciz "Echo is OFF",13,10
_EchoIsON:		asciz "Echo is ON",13,10


		; Display VERIFY state
_VerifyOptions:		dw _VerifyIsOFF, _VerifyIsON

_VerifyIsOFF:		asciz "Verify is OFF",13,10
_VerifyIsON:		asciz "Verify is ON",13,10

%else

_State:			dw _IsOFF, _IsON

_IsOFF:			asciz "%s is OFF",13,10
_IsON:			asciz "%s is ON",13,10

_BreakState:		asciz "BREAK"
_EchoState:		asciz "ECHO"
_VerifyState:		asciz "VERIFY"
_LfnforState:		asciz "LFNFOR"
%endif

		; Delete all files in a directory
_DeleteAllFiles:	db    "All files in directory will be deleted!",13,10
			asciz "Are you sure (Y/N)? "


		; Display and prompt for date
_ShowCurrentDate:	asciz "Current date is %s"
_PleaseEnterDate:	asciz 13,10,"Enter new date "		; missing colon intended


		; Display and prompt for time
_ShowCurrentTime:	asciz "Current time is %s"
_PleaseEnterTime:	asciz 13,10,"Enter new time: "

RxDOSIntl_DateTimeTable:
			intldate 001, "mm/dd/yyyy hh:mm:ss.00"	; USA
			intldate 002, "yyyy-mm-dd HH:mm:ss,00"	; Canada-French
			intldate 003, "dd/mm/yyyy hh:mm:ss.00"	; Latin America
			intldate 031, "dd-mm-yyyy HH:mm:ss,00"	; Netherlands
			intldate 032, "dd/mm/yyyy HH:mm:ss,00"	; Belgium
			intldate 033, "dd.mm.yyyy HH:mm:ss,00"	; France
			intldate 034, "dd/mm/yyyy HH:mm:ss,00"	; Spain
			intldate 036, "yyyy-mm-dd HH:mm:ss,00"	; Hungary
			intldate 038, "yyyy-mm-dd HH:mm:ss,00"	; Yugoslavia
			intldate 039, "dd/mm/yyyy HH.mm.ss,00"	; Italy
			intldate 041, "dd.mm.yyyy HH,mm,ss.00"	; Switzerland
			intldate 042, "yyyy-mm-dd HH:mm:ss,00"	; Czechoslovakia
			intldate 044, "dd/mm/yyyy HH:mm:ss.00"	; United Kingdom
			intldate 045, "dd-mm-yyyy HH:mm:ss,00"	; Denmark
			intldate 046, "yyyy-mm-dd HH.mm.ss,00"	; Sweden
			intldate 047, "dd.mm.yyyy HH:mm:ss,00"	; Norway
			intldate 048, "yyyy-mm-dd HH:mm:ss,00"	; Hungary
			intldate 049, "dd.mm.yyyy HH:mm:ss,00"	; Germany
			intldate 055, "dd/mm/yyyy HH:mm:ss,00"	; Brazil
			intldate 061, "dd/mm/yyyy HH:mm:ss.00"	; Intl English
			intldate 351, "dd-mm-yyyy HH:mm:ss,00"	; Portugal
			intldate 358, "dd.mm.yyyy HH.mm.ss,00"	; Finland
			dw -1

RxDOSIntl_TimeTemplate	asciz "hh:mm:ss.00"
RxDOSIntl_DateTemplate	asciz "www mm/dd/yyyy"			; USA
				; Remove hardcoded value or provide ISO 8601 alternative.

 %if 1
RxDOSIntl_DayOfWeek	asciz "SunMonTueWedThuFriSat"
 %else
RxDOSIntl_DayOfWeek	db "SunMonTueWedThuFriSat"
 %endif

		; Disk Transfer Area
			align 2
RxDOS_DTA:		times 128 db 20h


		; Stack
			align 2
			dw 5E5Eh				; bottom signature

			times (4 *1024) db 0
RxDOS_AltStack:		dw 0

			times (12 *1024) db 0
RxDOS_CmdStack:		dw 0

RXDOSLASTADDRESS	equ $

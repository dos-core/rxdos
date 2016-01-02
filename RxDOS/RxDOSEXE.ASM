
%if 0

RxDOSEXE - RxDOS executable loader for .COM and .EXE programs

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

	global copyCurrentPSP
	global loadProgram

	extern LocateFile
	extern ExpandFileName
	extern initdiskAccess
	extern readLogicalBuffer
	extern allocateMemBlock
	extern _allocateMinMaxMemBlock

	extern stdDeviceAssignTable
	extern _RetCallersStackFrame
	extern _freeMemBlock
	extern MapAppToSFTHandle
	extern FindSFTbyHandle

	extern _RxDOS_AllocStrategy
	extern _RxDOS_CurrentPSP
	extern _RxDOS_CurrentInstance
	extern _RxDOS_MaxMemory
	extern _RxDOS_DOSVersion
	extern _RxDOS_pDTA
	extern _CallDOS
	extern RxDOS_CMDLINE

	extern pexterrNotEnoughMemory

	extern StringLength


		; Load Program Image (COM, SYS, etc... )
		;
		; Input:
		; ds:dx-> ASCIZ name of program to load
		; es:bx-> LOADEXEC structure
		; al = mode (subfunction)
		;
		; Output:
		; dx = PSP segment address
		; CY if load failed
loadProgram:

	Entry
	def	Mode, ax
	def	ptrDirAccess, di
	ddef	ExecBlock, es, bx
	def	SizePara
	def	process_block_allocated_paras

	ddef	filesize
	ddef	PrevInstance
	ddef	DebuggerReturnTo

	defbytes	relocitem, 4
	defbytes	exeHeader, sizeEXEHEADER
	defbytes	diskAccess, sizeDISKACCESS
	defbytes	loadEnvelope, sizeloadEnvelope

	setES ss
	lea di, [ _loadEnvelope + bp ]
	clearMemory sizeloadEnvelope

	getdarg es, bx, _ExecBlock
	mov word [ _loadEnvelope + loadEnvExecBlock + _segment + bp ], es
	mov word [ _loadEnvelope + loadEnvExecBlock + _pointer + bp ], bx
	mov word [ _loadEnvelope + loadEnvOperationMode + bp ], ax

		; Debugger Info
	setDS ss
	mov bx, word [ ss:_RxDOS_CurrentInstance ]
	les bx, [ ss:bx ]
	stordarg _PrevInstance, es, bx			; instance before 

	mov dx, word [ es:_CS + bx ]
	mov ax, word [ es:_IP + bx ]
	stordarg _DebuggerReturnTo, dx, ax		; return address

	getarg ax, _Mode				; get mode
	Goto execSetExecuteMode, _loadProgram_SetExec
	Goto execLoadOverlay, _loadProgram_Overlay

		; Execute Program
	getdarg es, bx, _ExecBlock
	mov ax, word [ es:lprogCommandTail + _pointer + bx ]
	or ax, word [ es:lprogCommandTail + _segment + bx ]
	jz _loadProgram_08

	mov si, word [ es:lprogCommandTail + _pointer + bx ]
	mov es, word [ es:lprogCommandTail + _segment + bx ]
	mov cx, si

_loadProgram_04:
	inc si
	cmp byte [ es:si - 1 ], 0
	jnz _loadProgram_04

	sub cx, si
	neg cx						; length command line
	add cx, byte 8					;  add "CMDLINE=" string length
	mov word [ _loadEnvelope + loadEnvExtraEnvSizeParas + bp ], cx

_loadProgram_08:
	getarg si, _ptrDirAccess
	lea si, [ byte fileAcExpandedName + si ]	; program to load
	mov cx, si

_loadProgram_12:
	inc si
	cmp byte [ si - 1 ], 0
	jnz _loadProgram_12

	sub cx, si
	neg cx						; length command line
							; 4 = overhead bytes
	add cx, byte 4 + 15				; 15 = round up paragraphs
	add cx, word [ _loadEnvelope + loadEnvExtraEnvSizeParas + bp ]

	shr cx, 1
	shr cx, 1
	shr cx, 1
	shr cx, 1					; express bytes as paragraphs
	mov word [ _loadEnvelope + loadEnvExtraEnvSizeParas + bp ], cx

	jmp short _loadProgram_22

		; initialize mode
_loadProgram_SetExec:
	call _SetExecuteMode
	jmp _loadProgram_80

_loadProgram_Overlay:
	getdarg es, bx, _ExecBlock
	mov ax, word [ es:loverSegLoadAddress + bx ]
	mov dx, word [ es:loverRelocFactor + bx ]
	mov word [ _loadEnvelope + loadEnvStartSegment + bp ], ax
	mov word [ _loadEnvelope + loadEnvRelocFactor + bp ], dx

		; initialize disk access block
_loadProgram_22:
	setES ss
	getarg bx, _ptrDirAccess			; build access control block
	mov ax, word [ fileAcDrive + bx ]		; drive 
	mov cx, word [ fileAcCluster + _high + bx ]	; cluster (high)
	mov dx, word [ fileAcCluster + _low + bx ]	; cluster (low)

	lea bx, [ byte _diskAccess + bp ]		; build access control block
	call initdiskAccess				; ax is drive, cx:dx is cluster
	call checkEXEHeader				; EXE file ?
	jnz _loadProgram_30				; no, COM or SYS type -->

	getarg ax, _Mode				; get mode
	getarg di, _ptrDirAccess			; dir information
	lea bx, [ _loadEnvelope + bp ]			; load block
	call loadExe_Program				; pass off control to load EXE
	ifc _loadProgram_80				; if cannot -->
	jmp _loadProgram_54				; switch stack -->

		; load COM or SYS
_loadProgram_30:
	getarg bx, _ptrDirAccess			; dir information
	les di, [ fileAcBufferPtr + bx ]
	add di, word [ fileAcDirOffset + bx ]
	mov ax, word [ es:di + deFileSize + _low ]
	mov dx, word [ es:di + deFileSize + _high ]
	stordarg _filesize, dx, ax			; save file size

	add ax, byte (PARAGRAPH - 1)
	adc dx, byte 0					; just in case carry

	shr dx, 1
	rcr ax, 1
	shr dx, 1
	rcr ax, 1
	shr dx, 1
	rcr ax, 1
	shr dx, 1
	rcr ax, 1
	storarg _SizePara, ax				; save as paragraphs needed

	cmp byte [ _Mode + bp ], execLoadOverlay	; if load overlay 
	jz _loadProgram_34				; no need to allocate memeory -->

	mov dx, 0FFFFh					; max request (all of memory)
	lea bx, [ _loadEnvelope + bp ]
	call _LoaderAllocMemory				; alloc memory for env block/PSP
	ifc _loadProgram_80				; if cannot allocate -->

	mov word [ _loadEnvelope + loadEnvProgramPSP + bp ], ax
	mov word [ _loadEnvelope + loadEnvStartSegment + bp ], es
	mov word [ bp + process_block_allocated_paras ], cx

		; load module (at es:0000)
_loadProgram_34:
	xor di, di					; es:di == es:0000
	mov es, word [ _loadEnvelope + loadEnvStartSegment + bp ]
	lea bx, [ byte _diskAccess + bp ]		; build access control block
	mov word [ ss:bx + diskAcPosition + _high ], di
	mov word [ ss:bx + diskAcPosition + _low ], di	; zero

_loadProgram_36:
	mov cx, 60 * 1024				; read 60 KiB at a time
	mov ax, word [ _filesize + _low + bp ]
	mov dx, word [ _filesize + _high + bp ]
	sub ax, word [ ss:bx + diskAcPosition + _low ]
	sbb dx, word [ ss:bx + diskAcPosition + _high ]	
	or dx, dx					; more than 60 KiB ?
	jnz _loadProgram_38				; yes -->
	cmp ax, cx					; more than 60 KiB ?
	jnb _loadProgram_38				; yes -->
	mov cx, ax					; exact bytes to read

_loadProgram_38:
	jcxz _loadProgram_44				; if no more to read -->

	mov dx, word [ ss:diskAcPosition + _high + bx ]	
	mov ax, word [ ss:diskAcPosition + _low + bx ]
	lea bx, [ byte _diskAccess + bp ]		; build access control block

	call readLogicalBuffer				; ss:bx-> access buffer
	jcxz _loadProgram_44				; if no more to read -->

	push cx
	shr cx, 1
	shr cx, 1
	shr cx, 1
	shr cx, 1					; chars read in paras
	mov ax, es
	add ax, cx
	mov es, ax
	pop cx
	and cx, byte (PARAGRAPH - 1)
	add di, cx
	jmp short _loadProgram_36

		; switch to new process
_loadProgram_44:
	mov al, byte [ _Mode + bp ]			; if load overlay 
	getdarg cx, dx, _filesize
	call ifOverlayLoader				; set up ret args if overlay
	ifz _loadProgram_62				; no need to build return stack -->

	mov es, word [ _loadEnvelope + loadEnvProgramPSP + bp ]
	mov word [ _RxDOS_CurrentPSP ], es		; change running PSP

;	call _getSizeOfEnvString			; get size of env string

	mov cx, word [ bp + process_block_allocated_paras ]
	xor si, si					; 0 = 1_0000h with overflow
	cmp cx, (1024 /PARAGRAPH) * 64			; greater than 64 KiB ?
	jae _loadProgram_46				; yes, use max value for seg
	mov si, cx
	shl si, 1
	shl si, 1
	shl si, 1
	shl si, 1					; -> top of stack

_loadProgram_46:
	mov word [ es:si - 2 ], 0			; place a null return address at top of stack

	sub si, byte 4					; top value minus 2 words
	mov word [ es:pspUserStack + _pointer ], si
	mov word [ es:pspUserStack + _segment ], es	; child process psp

	sub si, byte _Flags				; -6
	mov bx, word [ ss:_RxDOS_CurrentInstance ]
	mov word [ ss:bx + _pointer ], si
	mov word [ ss:bx + _segment ], es		; where new process' startup stack will exist (COM)

	or si, si
	sti
	cld
	pushf
	pop word [ es:si + _Flags ]			; Flags are: NZ, NC, UP, EI

	mov word [ es:si + _IP ], 100h
	mov word [ es:si + _CS ], es
	mov word [ es:si + _ES ], es
	mov word [ es:si + _DS ], es
%if 1
	mov word [ es:si + _BP ], 0
	mov word [ es:si + _DI ], 0
	mov word [ es:si + _SI ], 0
	mov word [ es:si + _DX ], 0

	getdarg bx, cx, _filesize
	mov word [ es:si + _CX ], cx
	mov word [ es:si + _BX ], bx
%else
		; RxDOS 7.20N:	Above values are what DEBUG fills in the registers.
		;		Below values will emulate MS-DOS 3.30 more or less.
	mov word [ es:si + _BP ], 882h
	mov word [ es:si + _DI ], 0FFFEh
	mov word [ es:si + _SI ], 100h
	mov word [ es:si + _DX ], es
	mov word [ es:si + _BX ], 0
	mov word [ es:si + _CX ], 0FFh
%endif
	mov word [ es:si + _AX ], 0000

		; set DTA on the way out; switch stacks
_loadProgram_54:
	cmp byte [ _Mode + bp ], execLoadOverlay	; if load overlay 
	jz _loadProgram_62				; no need to allocate memory -->

	mov es, word [ _RxDOS_CurrentPSP ]		; new PSP
	mov word [ _RxDOS_pDTA + _segment ], es
	mov word [ _RxDOS_pDTA + _pointer ], pspCommandTail

	cli
	mov bx, word [ ss:_RxDOS_CurrentInstance ]
	mov ax, word [ es:pspParentId ]			; parent PSP address
	sti						; re-enable interrupts
	or ax, ax					; if no current PSP
	jz _loadProgram_56				; none -->

	push word [ ss:bx + _segment ]
	push word [ ss:bx + _pointer ]
	pop word [ es:pspUserStack + _pointer ]
	pop word [ es:pspUserStack + _segment ]		; child process

		; copy program name to Environment Block
_loadProgram_56:
	getarg bx, _ptrDirAccess			; build access control block
	mov es, word [ _RxDOS_CurrentPSP ]		; new PSP
	mov dx, word [ fileAcNameOffset + bx ]		; offset to short name
	call _setProgramNameInMemBlock

	mov ax, word [ es:pspEnvironment ]		; get environment block
	or ax, ax					; if no environment block
	jz _loadProgram_62				; -->

	push ds
	mov es, ax					; get environment block
	call _setProgramNameInMemBlock

	lea bx, [ _loadEnvelope + bp ]			; load envelope
	call AppendCmdLineToEnv

	setDS ss
	getarg bx, _ptrDirAccess			; build access control block
	lea dx, [ byte fileAcExpandedName + bx ]	; expanded name
	call appendProgramNametoEnv
	pop ds		

		;see if DEBUGGER support request
_loadProgram_62:
	cmp byte [ _Mode + bp ], execLoadAndReturnDebug
	clc
	jnz _loadProgram_80				; if not debugger mode -->

	SaveSegments
	mov es, word [ _RxDOS_CurrentPSP ]		; new PSP


		; get CS:IP
	mov es, word [ _RxDOS_CurrentPSP ]		; new PSP
	les bx, word [ es:pspUserStack ]		; es:bx = current stack
	mov dx, word [ es:bx + _CS ]			; get new prog cs:ip
	mov ax, word [ es:bx + _IP ]

	getdarg ds, si, _ExecBlock
	mov word [ lprogCSIP + _segment + si ], dx
	mov word [ lprogCSIP + _pointer + si ], ax	; save in exec block

		; save SS:SP in exec block
	mov word [ lprogSSSP + _segment + si ], es
	mov word [ lprogSSSP + _pointer + si ], bx	; stack to exec block

		; return to CS:IP of previous instance with new stack
	getdarg dx, ax, _DebuggerReturnTo
	mov word [ es:bx + _CS ], dx
	mov word [ es:bx + _IP ], ax

	mov bx, word [ ss:_RxDOS_CurrentInstance ]
	getdarg dx, ax, _PrevInstance
	mov word [ ss:bx + _segment ], dx
	mov word [ ss:bx + _pointer ], ax

	RestoreSegments
	clc

		; exit
_loadProgram_80:
	jnc _loadProgram_86

	pushf
	SaveAllRegisters
	mov es, word [ _loadEnvelope + loadEnvProgramPSP + bp ]
	call _freeMemBlock

	mov es, word [ _loadEnvelope + loadEnvEnvBlock + bp ]
	call _freeMemBlock
	RestoreAllRegisters
	popf

_loadProgram_86:
	Return
	

		; Load Exe Program
		;
		; Input:
		; ss:di-> directory block
		; es:bx-> EXEC structure
		; dx = load segment address if mode (al) is load Overlay
		; cx = code relocation factor
		; ax = subfunction code
		;
		; Output:
		; dx = PSP segment address
		; CY if load failed
loadExe_Program:

	Entry
	def	Mode, ax
	def	ptrDirAccess, di
	def	pLoadEnvelope, bx

	def	SizePara
	def	CheckSum, 0
	ddef	returnSize
	defbytes	exeHeader, sizeEXEHEADER
	defbytes	diskAccess, sizeDISKACCESS
	defbytes	relocitem, 4

	setDS ss
	mov word [ loadEnvProgramPSP + bx ], 0		; PSP

		; initialize disk access block
	mov ax, word [ fileAcDrive + di ]
	mov dx, word [ fileAcCluster + _low + di ]
	mov cx, word [ fileAcCluster + _high + di ]

	lea bx, [ byte _diskAccess + bp ]		; build access control block
	call initdiskAccess				; ax is drive, cx:dx is cluster

	les si, [ fileAcBufferPtr + di ]
	add si, word [ fileAcDirOffset + di ]
	mov ax, word [ es:si + deFileSize + _low ]
	mov dx, word [ es:si + deFileSize + _high ]
	mov word [ _diskAccess + diskAcFileSize + _low + bp ], ax
	mov word [ _diskAccess + diskAcFileSize + _high + bp ], dx

	sub ax,	200h
	sbb dx, byte 0					; return size
	mov word [ _returnSize + _low + bp ], ax
	mov word [ _returnSize + _high + bp ], dx

	xor dx, dx
	xor ax, ax					; position to beg of file
	setES ss
	lea di, [ byte _exeHeader + bp ]
	mov cx, sizeEXEHEADER
	call readLogicalBuffer				; Access buffer: ss:bx
	call computeChecksum
	mov word [ _CheckSum + bp ], ax

		; compute size in pages of load module
	mov dx, word [ _exeHeader + exeExtraBytes + bp ]
	add dx, byte (PARAGRAPH - 1)			; round up paragraphs needed
	shr dx, 1
	shr dx, 1
	shr dx, 1
	shr dx, 1					; paragraphs at end needed

	mov ax, word [ _exeHeader + exePages + bp ]
	; dec ax					; adjust for last block
	shl ax, 1					; conv pages to paragraphs
	shl ax, 1					; 4
	shl ax, 1					; 8
	shl ax, 1					; 16
	shl ax, 1					; 32
	sub ax, word [ _exeHeader + exeHeaderSize + bp ]
	add ax, dx					; actual paragr needed
	add ax, word [ _exeHeader + exeMinAlloc + bp ]
	storarg _SizePara, ax				; save as paragraphs needed

	getarg bx, _pLoadEnvelope
	cmp byte [ _Mode + bp ], execLoadOverlay	; if load overlay 
	jz loadExe_Program06				; no need to build return stack -->

	mov dx, word [ _exeHeader + exeMaxAlloc + bp ]
	call _LoaderAllocMemory				; alloc memory for env block/PSP
	ifc loadExe_Program50				; if cannot allocate -->

	getarg bx, _pLoadEnvelope
	mov word [ loadEnvStartSegment + bx ], es
	mov word [ loadEnvRelocFactor + bx ], es
	mov word [ loadEnvProgramPSP + bx ], ax

		; load module
loadExe_Program06:
	mov es, word [ loadEnvStartSegment + bx ]
	mov ax, word [ _exeHeader + exeHeaderSize + bp ]
	shl ax, 1					; 2
	shl ax, 1					; 4
	shl ax, 1					; 8
	shl ax, 1					; 16 byte offset
	xor dx, dx

loadExe_Program08:
	push es
	push dx
	push ax						; save position in file

	mov cx, word [ _SizePara + bp ]			; get paras to read
	test ch, 0F0h					; over 64 KiB ?
	jz loadExe_Program12				; no, read whole file -->
	mov cx, 0FFFh					; read as much as possible.

loadExe_Program12:
	push cx						; save paras to read

	shl cx, 1
	shl cx, 1
	shl cx, 1
	shl cx, 1
	push cx						; save bytes actually to read

	xor di, di					; load at _StartSeg:0000
	lea bx, [ byte _diskAccess + bp ]		; build access control block
	call readLogicalBuffer				; ss:bx-> access buffer
	call computeChecksum
	add word [ _CheckSum + bp ], ax

	pop cx						; bytes read
	pop bx						; paras read
	pop ax						; previous file offset
	pop dx
	add ax, cx					; incr position by bytes read
	adc dx, byte 0

	pop cx						; segment loaded
	add cx, bx					; increment by paras read
	mov es, cx					; set new read segment

	sub word [ _SizePara + bp ], bx			; subtract paragraphs used.
	jnz loadExe_Program08

	xor di, di					; load at _StartSeg:0000
	mov cx, word [ _exeHeader + exeExtraBytes + bp ]
	and cx, byte (PARAGRAPH - 1)			; last 15 bytes
	jz loadExe_Program20				; if none to read -->
	
	lea bx, [ byte _diskAccess + bp ]		; build access control block
	call readLogicalBuffer				; ss:bx-> access buffer
	call computeChecksum
	add word [ _CheckSum + bp ], ax


		; address relocation blocks
loadExe_Program20:
	mov ax, word [ _exeHeader + exeRelocItems + bp ]
	or ax, ax
	jz loadExe_Program32

loadExe_Program28:
	setES ss
	mov cx, 4
	xor dx, dx
	mov ax, word [ _exeHeader + exeRelocTable + bp ]

	lea di, [ byte _relocitem + bp ]
	lea bx, [ byte _diskAccess + bp ]		; build access control block
	call readLogicalBuffer				; ss:bx-> access buffer
	call computeChecksum
	add word [ _CheckSum + bp ], ax

	getarg bx, _pLoadEnvelope
	mov ax, word [ loadEnvRelocFactor + bx ]	; starting segment

	getdarg dx, di, _relocitem			; get reloc item
	add dx, ax
	mov es, dx
	add word [ es:di ], ax				; relocate load module

	add word [ _exeHeader + exeRelocTable + bp ], byte 4
	dec word [ _exeHeader + exeRelocItems + bp ]
	jnz loadExe_Program28

		; execute
loadExe_Program32:
	mov ax, word [ _CheckSum + bp ]
	add ax, word [ _exeHeader + exeChecksum + bp ]

	mov al, byte [ _Mode + bp ]			; if load overlay
	getdarg cx, dx, _returnSize			; return size
	call ifOverlayLoader				; set up ret args if overlay
	ifz loadExe_Program50				; no need to build return stack -->

	getarg bx, _pLoadEnvelope
	mov es, word [ loadEnvProgramPSP + bx ]
	mov dx, word [ loadEnvStartSegment + bx ]
	add dx, word [ _exeHeader + exeInitSS + bp ]
	mov si, word [ _exeHeader + exeInitSP + bp ]

	sub si, byte 2					; top value minus 1 word
	mov word [ es:pspUserStack + _pointer ], si
	mov word [ es:pspUserStack + _segment ], dx

	setES dx					; child program's stack seg
	sub si, byte _Flags
	mov bx, word [ ss:_RxDOS_CurrentInstance ]
	mov word [ ss:bx + _pointer ], si
	mov word [ ss:bx + _segment ], dx		; where new process' startup stack will exist

	or si, si
	sti
	cld
	pushf
	pop word [ es:si + _Flags ]			; flags: NC, NZ, UP, EI

	getarg bx, _pLoadEnvelope
	mov dx, word [ loadEnvProgramPSP + bx ]
	mov word [ es:si + _ES ], dx
	mov word [ es:si + _DS ], dx

	mov dx, word [ loadEnvStartSegment + bx ]
	add dx, word [ _exeHeader + exeInitCS + bp ]
	mov ax, word [ _exeHeader + exeInitIP + bp ]
	mov word [ es:si + _IP ], ax
	mov word [ es:si + _CS ], dx

	mov word [ es:si + _BP ], 0
	mov word [ es:si + _DI ], 0
	mov word [ es:si + _SI ], 0
	mov word [ es:si + _DX ], 0

	getdarg dx, ax, _returnSize
	mov word [ es:si + _CX ], ax
	mov word [ es:si + _BX ], dx
	mov word [ es:si + _AX ], 0

		; copy startup command line to _PSP
	getarg bx, _pLoadEnvelope
	mov ax, word [ loadEnvProgramPSP + bx ]
	mov word [ _RxDOS_CurrentPSP ], ax		; change running PSP
	clc

loadExe_Program50:
	Return


		; Determine if file contains an EXE header
		;
		; INP:	ss:bx-> disk access block
		; OUT:	ZR if file contains an EXE header
		;	NZ if file doesn't contain an EXE header
checkEXEHeader:
	entry
	defbytes	exeHeader, sizeEXEHEADER

	xor dx, dx
	xor ax, ax					; file pointer to beg of file
	mov cx, sizeEXEHEADER
	lea di, [ byte _exeHeader + bp ]
	call readLogicalBuffer				; ss:bx-> access buffer

		; RxDOS 7.20N:	Both "MZ" and "ZM" are accepted as EXE signature.
	cmp word [ _exeHeader + exeSignature + bp ], "MZ"
	je checkEXEHeader_08
	cmp word [ _exeHeader + exeSignature + bp ], "ZM"

checkEXEHeader_08:
	Return


		; Copy current PSP
		;
		; Usage:
		; es = PSP segment address to update
		;
		; Returns:
		; ZR = No parent PSP, not copied
		; NZ = Parent PSP found and copied
copyCurrentPSP:

	SaveSegments
	mov ax, word [ ss:_RxDOS_CurrentPSP ]		; current PSP
	or ax, ax					; any current PSP ?
	jz copyCurrentPSP_36				; no -->

	xor si, si
	xor di, di
	mov ds, ax					; current PSP
	mov cx, (sizePSP +1)/2
	repz movsw

		; duplicate all file handles (except for no inherit)
	mov ax, word [ ss:_RxDOS_CurrentPSP ]
	mov word [ es:pspParentId ], ax			; parent PSP address

	mov cx, sizePSPHandleTable 
	mov bx, pspHandleTable 
	mov word [ es:pspFileHandleCount ], cx
	mov word [ es:pspFileHandlePtr + _segment ], es
	mov word [ es:pspFileHandlePtr + _pointer ], bx

copyCurrentPSP_08:
	xor ax, ax
	mov al, byte [ es:bx ]				; get old handle
	cmp al, -1					; if entry not set
	jz copyCurrentPSP_14				; skip around -->

	push es
	push bx
	call FindSFTbyHandle				; get corresponding SFT (es:di)
	test word [ es:di + sftDevInfo ], sftNoInherit
	jnz copyCurrentPSP_12				; if no inherit -->

	inc word [ es:di + sftRefCount ]		; bump in use count

	pop bx
	pop es
	jmp short copyCurrentPSP_14

copyCurrentPSP_12:
	pop bx
	pop es
	mov byte [ es:bx ], -1				; free SFT handle in copy of PSP

copyCurrentPSP_14:
	inc bx
	cmp bx, byte (pspHandleTable + sizePSPHandleTable)
	jb copyCurrentPSP_08

		; RxDOS 7.20N:	Set NZ
	or bx, bx

		; done
copyCurrentPSP_36:
	RestoreSegments
	retn


		; Create Program Segment Prefix
		;
		; Input:
		; es = segment for PSP
		; cx = allocate size
		; dx:ax-> (if valid address) EXEC block
		; bx:di-> (if valid address) ASCIZ filename of executable
		;  (uppercased, no path)
		; ds = ss (RxDOS 7.20N only)
		;
		; Output:
		; es:0-> behind created PSP
createPSP:

	entry
	def	AllocSize, cx
	ddef	ExecBlock, dx, ax
%if 0
	ddef	ProgramName, bx, di
%endif

	push ds
	mov ax, es
	add ax, byte (sizePSP +15)/16			; always a fixed size
	push ax						; address of PSP to return

	xor di, di
%if 1
	mov ax, word [ ss:_RxDOS_CurrentPSP ]
	or ax, ax					; any parent ?
	jnz createPSP_08				; yes, copy parent -->
%else
	call copyCurrentPSP				; copy current PSP if parent found
	jnz createPSP_12				;  if parent found, NZ
%endif

		; else init a blank PSP
	xor ax, ax
	mov cx, (sizePSP +1)/2				; always a fixed size
	repz stosw					; clear with zeros

	mov ax, -1
	mov di, pspHandleTable
	mov cx, (sizePSPHandleTable +1)/2
	repz stosw					; init handle table

	mov dx, 1
%if 1
	mov al, byte [ (stdRedirec_Aux * sizeStdRedirec) + stdDeviceAssignTable + stdIOHandle ]
%else
	mov al, byte [ ss:(stdRedirec_Aux * sizeStdRedirec) + stdDeviceAssignTable + stdIOHandle ]
		; RxDOS 7.20N:	The RxDOS 7.1.5 source contains the ss: prefixes,
		;		but MASM didn't assemble them. Bad ASSUMption.
%endif
	mov byte [ es:pspHandleTable + STDAUX ], al
	call incrRefCount

%if 1
	mov al, byte [ (stdRedirec_Prn * sizeStdRedirec) + stdDeviceAssignTable + stdIOHandle ]
%else
	mov al, byte [ ss:(stdRedirec_Prn * sizeStdRedirec) + stdDeviceAssignTable + stdIOHandle ]
%endif
	mov byte [ es:pspHandleTable + STDPRN ], al
	call incrRefCount

%if 1
	mov al, byte [ (stdRedirec_Con * sizeStdRedirec) + stdDeviceAssignTable + stdIOHandle ]
%else
	mov al, byte [ ss:(stdRedirec_Con * sizeStdRedirec) + stdDeviceAssignTable + stdIOHandle ]
%endif
	mov byte [ es:pspHandleTable + STDIN ], al
	mov byte [ es:pspHandleTable + STDOUT ], al
	mov byte [ es:pspHandleTable + STDERR ], al

	mov dx, 3
	call incrRefCount

	mov al, ' '
	mov cx, (sizefnName +sizefnExtension)
	mov di, pspFCB_1
	repz stosb					; init (dummy) fcb 1

	mov cx, (sizefnName +sizefnExtension)
	mov di, pspFCB_2
	repz stosb					; init (dummy) fcb 2

	mov word [ es:pspFileHandlePtr +_segment ], es
	mov word [ es:pspFileHandlePtr +_pointer ], pspHandleTable
	mov word [ es:pspFileHandleCount ], sizepspHandleTable

%if 1
	mov ax, word [ _RxDOS_DOSVersion ]		; get DOS Version
	mov word [ es:pspVersion ], ax			; Major, Minor version (VERS)
%endif
%if 1
	jmp short createPSP_12

		; copy an existing PSP
createPSP_08:
	call copyCurrentPSP				; copy current PSP
%endif

		; other specific initialization
createPSP_12:
	mov ax, word [ ss:_RxDOS_CurrentPSP ]
	mov word [ es:pspParentId ], ax			; parent PSP address

	mov ax, es					; compute next alloc
	add ax, word [ _AllocSize + bp ]
	mov word [ es:pspNextParagraph ], ax

	mov word [ es:pspInt20 ], 20CDh			; "int 20h" instruction
	mov word [ es:pspDosCall ], 21CDh		; "int 21h" instruction
	mov word [ es:pspDosCall +2 ], 0CBh		; "retf"

	mov byte [ es:pspDispatcher ], 9Ah		; "call far" instruction
	mov word [ es:pspDispatcher +1 +_segment ], cs
	mov word [ es:pspDispatcher +1 +_pointer ], _CallDOS	; "CALL 5" entry
	mov word [ es:pspShareChain +_pointer ], -1	; share vector 
	mov word [ es:pspShareChain +_segment ], -1

%if 0

%if 0

The SETVER list is a list of executable filenames (without path) that should get another
version number into their PSP. Each entry in the list looks like:

by:[0000]	Number of characters in filename. Zero if end of list.
   [0001]	Filename. Not ASCIZ!
wo:[????]	Version number to return if filename matched. (Located behind filename.)

%endif

	mov dx, word [ _RxDOS_DOSVersion ]		; get default DOS Version
	push ds
	push si
	push es

	les di, [ _ProgramName + bp ]
	push es
	push di
	call validate_address
	jc createPSP_06					; use default if no filename -->

	lds si, [ ss:_RxDOS_pSETVERList ]
	push ds
	push si
	call validate_address
	jc createPSP_06					; use default if no SETVER list -->

	push es
	push di
	call StringLength
	jz createPSP_06					; use default if zero length filename -->

	or ch, ch
	jnz createPSP_06				; use default if filename too long -->

	mov ah, 0
	jmp short .firstSETVERlistentry

.nextSETVERlistentry:
	add si, ax
	inc si						; Not "inc ax" before "add"!
	inc si						;  This could leave ah non-zero!
.firstSETVERlistentry:
	lodsb
	or al, al
	jz createPSP_06					; end of list, not found -->

	cmp al, cl
	jne .nextSETVERlistentry			; if length doesn't match -->

	push cx
	push di
	repz cmpsb
	mov ax, cx					; remaining bytes in ax (if no match)
	pop di
	pop cx
	jnz .nextSETVERlistentry			; try next if it didn't match -->

.foundSETVERlistentry:
	lodsw						; ds:si-> version number word
	mov dx, ax					; return in dx

createPSP_06:
	pop es						; ds and si left on stack
	mov word [ es:pspVersion ], dx			; set default or SETVER version
%endif

%if 1
	push ds
	xor ax, ax
	mov ds, ax

	mov bx, ( intCONTROLC * 4 )			; Int23 control-C vector
	mov ax, word [ _pointer + bx ]			; existing value copied to PSP
	mov dx, word [ _segment + bx ]
	mov word [ es:pspControlCVect + _pointer ], ax
	mov word [ es:pspControlCVect + _segment ], dx

	mov bx, ( intCRITICALERROR * 4 )		; Int24 criterror vector
	mov ax, word [ _pointer + bx ]			; existing value copied to PSP
	mov dx, word [ _segment + bx ]
	mov word [ es:pspCritErrorVect + _pointer ], ax
	mov word [ es:pspCritErrorVect + _segment ], dx

	RetCallersStackFrame ds, bx			; Int22 terminate vector
	mov dx, word [ _CS + bx ]			; return address to Int21 caller
	mov ax, word [ _IP + bx ]
	mov word [ es:pspTerminateVect + _pointer ], ax
	mov word [ es:pspTerminateVect + _segment ], dx
	pop ds
%else
	mov di, pspTerminateVect
	RetCallersStackFrame ds, si
	add si, byte _IP
	movsw
	movsw						; copy Int21 return address (Int22) to PSP

	xor ax, ax
	mov ds, ax
	mov si, 23h *4
	movsw
	movsw						; copy current Int23 vector to PSP
	movsw
	movsw						; copy current Int24 vector to PSP

	pop si
	pop ds						; ds and si pushed above
%endif


		; copy command line
	mov word [ es:pspCommandTail ], 0D00h		; pre-init empty command line

	mov ax, word [ _ExecBlock + _segment + bp ]
	or ax, word [ _ExecBlock + _pointer + bp ]
	jz createPSP_56					; if no load execute block -->
	
	getdarg ds, di, _ExecBlock
	cmp word [ lexecCommandTail + _segment + di ], byte -1
	jz createPSP_36					; if no command tail to copy -->
	mov ax, word [ lexecCommandTail + _segment + di ]
	or ax, word [ lexecCommandTail + _pointer + di ]
	jz createPSP_36					; if no command tail to copy -->

	SaveRegisters es, si
	lds si, [ lexecCommandTail + di ]
	mov di, pspCommandTail

	mov cx, 1					; add one for length byte (thanks BillW)
	add cl, byte [ si ]				; get character count
	repz movsb					; copy
	mov byte [ es:di ], 13				; store trailing CR

	RestoreRegisters si, es				; address of PSP
	
createPSP_36:
	getdarg ds, di, _ExecBlock
	cmp word [ lexecFCB_1 + _segment + di ], byte -1
	jz createPSP_42					; if no FCB 1 to copy -->
	mov ax, word [ lexecFCB_1 + _segment + di ]
	or ax, word [ lexecFCB_1 + _pointer + di ]
	jz createPSP_42					; if no FCB 1 to copy -->

	lds si, [ lexecFCB_1 + di ]
	mov di, pspFCB_1
	mov cx, (pspFCB_2 - pspFCB_1)/ 2
	repz movsw
	
createPSP_42:
	getdarg ds, di, _ExecBlock
	cmp word [ lexecFCB_2 + _segment + di ], byte -1
	jz createPSP_56					; if no FCB 2 to copy -->
	mov ax, word [ lexecFCB_2 + _segment + di ]
	or ax, word [ lexecFCB_2 + _pointer + di ]
	jz createPSP_56					; if no FCB 2 to copy -->

	lds si, [ lexecFCB_2 + di ]
	mov di, pspFCB_2
	mov cx, (pspFCB_2 - pspFCB_1)/ 2
	repz movsw

		; exit
createPSP_56:
	pop es
	pop ds
	return


		; Increment Ref Count
		;
		; Input:
		; al	SFT handle
		; dx	increment value
incrRefCount:

	push es
	push di
	push dx
%if 1
	xor ah, ah
%endif
	call FindSFTbyHandle				; get corresponding SFT

	pop dx
	test word [ es:di + sftDevInfo ], sftNoInherit
	jnz incrRefCount_08				; if no inherit -->
	add word [ es:di + sftRefCount ], dx		; bump in use count

incrRefCount_08:
	pop di
	pop es
	retn


		; Allocate Loader Memory, copy Env block, init PSP
		;
		; Input:
		; ss:bx-> load envelope
		; ax = paragraphs of program expected
		; cx = additional env variable paras required
		; dx = max requested paragraphs
		;
		; OUT:	NC if successful,
		;	 ax = PSP segment address
		;	 es:0 -> allocated segment (points to behind PSP)
		;	 cx = size in paras of area allocated
		;	 dx:0 -> environment block
		;	CY if cannot create,
		;	 ax = error code
_LoaderAllocMemory:

	entry
	def	pLoadEnvelope, bx			; load envelope
	def	requiredParas, ax
	def	maxRequestedParas, dx
	def	allocatedSize, 0
	def	envSeg, 0
	def	AllocEnv, 0
	def	programPSP, 0
	def	loadHigh, FALSE
	def	StartSegment
	def	envSize

	add word [ _requiredParas + bp ], byte (sizePSP +15)/16
	ifc _loaderAllocMemory_50

	or dx, dx					; special 0 request ?
	jnz _loaderAllocMemory_04			; no -->
	mov word [ _maxRequestedParas + bp ], 0FFFFh
	mov word [ _loadHigh + bp ], TRUE		; if load HIGH

_loaderAllocMemory_04:
	mov ax, word [ _requiredParas + bp ]
	cmp ax, word [ _maxRequestedParas + bp ]
	jbe _loaderAllocMemory_08

	mov word [ _maxRequestedParas + bp ], ax

		; determine the size of the environment block, if any
_loaderAllocMemory_08:
	push word [ _RxDOS_AllocStrategy ]		; save current alloc policy

	getarg bx, _pLoadEnvelope
	les bx, [ loadEnvExecBlock + bx ]		; load exec module
	mov ax, word [ es:bx + lexecEnvironment ]
	or ax, ax					; env block address passed ?
	jnz _loaderAllocMemory_14			; if segment passed -->

	mov ax, word [ ss:_RxDOS_CurrentPSP ]
	or ax, ax					; current PSP available ?
	jz _loaderAllocMemory_12			; no, go figure something -->

	mov es, ax
	mov ax, word [ es:pspEnvironment ]		; get environment block address
	or ax, ax					; available ?
	jnz _loaderAllocMemory_14			; yes, use it -->

_loaderAllocMemory_12:
	mov word [ _RxDOS_AllocStrategy ], _MEM_FIRSTFIT_LOW
	mov cx, sizeParasPerPage			; if no exec block, default to this for now
	jmp short _loaderAllocMemory_24			; go allocate default size

_loaderAllocMemory_14:
	mov es, ax					; memory block address
	storarg _envSeg, ax				; save env segment to copy
	call _getSizeOfEnvString			; get size of env string

_loaderAllocMemory_24:
	getarg bx, _pLoadEnvelope
	add cx, word [ loadEnvExtraEnvSizeParas + bx ]	; addtl env size required (paras)
	storarg _envSize, cx				; save size in paras
	call allocateMemBlock				; return seg pointer to avail memory

	pop word [ _RxDOS_AllocStrategy ]		; restore current alloc policy
	jc _loaderAllocMemory_50			; if insufficient space to load -->

	storarg _AllocEnv, es				; store alloc environment

	xor ax, ax
	xor di, di					; start of area
	getarg cx, _envSize				; get size in paras
	shl cx, 1					; convert paras to words
	shl cx, 1					; convert paras to words
	shl cx, 1					; convert paras to words
	repz stosw					; clear/zero


		; copy environment
	cmp word [ _envSeg + bp ], byte 0		; no default segment ?
	jz _loaderAllocMemory_42			; skip copy -->

	push ds
	xor di, di
	xor si, si
	getarg ds, _envSeg
	getarg cx, _envSize				; env size in paras
	shl cx, 1					; convert to words !
	shl cx, 1
	shl cx, 1
	repz movsw					; copy env block

	pop ds


		; allocate block
_loaderAllocMemory_42:
	getarg ax, _requiredParas
	getarg dx, _maxRequestedParas
	call _allocateMinMaxMemBlock			; return seg pointer to avail memory
	jc _loaderAllocMemory_50			; if insufficient space to load -->
	storarg _programPSP, es				; save PSP seg address
	storarg _allocatedSize, cx			; allocated size

		; create child PSP
	getarg bx, _pLoadEnvelope
	mov dx, word [ loadEnvExecBlock + _segment + bx ]	; exec block
	mov ax, word [ loadEnvExecBlock + _pointer + bx ]
	call createPSP					; build PSP (cx contains alloc size)
	storarg _StartSegment, es			; PSP here

		; set Env Block in PSP
	getarg es, _programPSP
	getarg ax, _AllocEnv				; alloc environment
	mov word [ es:pspEnvironment ], ax		; environment block


		; insure parent's handle is set for both blocks
	mov dx, es					; PSP address
	mov ax, es
	dec ax						; -> PSP block's MCB
	mov es, ax					; point to allocation block
	mov word [ es:_memParent ], dx			; assign parent

	getarg ax, _AllocEnv
	or ax, ax					; none required ?
	jz _loaderAllocMemory_56			; no -->

	dec ax						; -> environment block's MCB
	mov es, ax					; point to allocation block
	mov word [ es:_memParent ], dx			; assign parent
	jmp short _loaderAllocMemory_56			; if everything is ok -->


		; free env block if error
_loaderAllocMemory_50:
	getarg es, _AllocEnv
	call _freeMemBlock
	SetError pexterrNotEnoughMemory
	jmp short _loaderAllocMemory_66


		; return 
_loaderAllocMemory_56:
	getarg es, _StartSegment
	getarg ax, _programPSP
	getarg cx, _allocatedSize
	getarg dx, _AllocEnv

	getarg bx, _pLoadEnvelope
	mov word [ loadEnvStartSegment + bx ], es
	mov word [ loadEnvProgramPSP + bx ], ax
	mov word [ loadEnvEnvBlock + bx ], dx

_loaderAllocMemory_66:
	return


		; Compute Checksum
		;
		; Input:
		; es:di-> block
		; cx = number of bytes in block
		;
		; Output:
		; ax = sum, ignoring carry, of all words in block
computeChecksum:
	push di
	push cx
	inc cx
	shr cx, 1
	xor ax, ax

computeChecksum_04:
	add ax, word [ es:di ]
	inc di
	inc di
	loop computeChecksum_04

	pop cx
	pop di
	retn


		; Set execution state (dummy)
		;
		; Usage:
		; ds:dx-> address of SETEXEC block
_SetExecuteMode:

	clc
	retn


		; Append CMDLINE to Environment block
		;
		; Input:
		; es = env block
		; bx = load envelope

AppendCmdLineToEnv:

	SaveSegments bx

	lds si, [ ss:bx + loadEnvExecBlock ]
	lds si, [ si + lexecCommandTail ]
	mov ax, ds
	or ax, si
	jz appendCmdLine_16

	push ds
	push si
	setDS cs
	mov si, RxDOS_CMDLINE
	call RemoveEnvString
	call AppendEnvString

	pop si
	pop ds
	call AppendEnvString

	stosb						; add terminating null

appendCmdLine_16:
	RestoreSegments bx
	retn


		; Remove Env String
		;
		; Input:
		; es = env block
		; ds:si-> key to match, '='-terminated
		;
		; Output:
		; es:di-> second terminating null at end of env
RemoveEnvString:

	xor di, di					; start of env space

%if 1
RemoveEnvString_08:
	push si

RemoveEnvString_12:
	mov al, byte [ es:di ]
	or al, al					; unexpected end char
	jz RemoveEnvString_22				; go scan next key -->

	cmp al, byte [ si ]				; matches search key ?
	jnz RemoveEnvString_20				; no, skip to next key -->

	cmp al, '='					; equal sign ? (search key terminator)
	jz RemoveEnvString_36				; we have a match -->

	inc di
	inc si
	jmp short RemoveEnvString_12

RemoveEnvString_20:
	inc di						; scan to end of key
	cmp byte [ es:di ], 0
	jnz RemoveEnvString_20

RemoveEnvString_22:
	pop si
	inc di
	cmp byte [ es:di ], 0				; at end of env space ?
	jnz RemoveEnvString_08				; no -->

	retn

RemoveEnvString_36:
	pop ax						; original si
	sub si, ax					; si will contain length of key word
	xchg si, ax					; si points to lookup key

	push si
	mov si, di
	sub si, ax					; must delete from

RemoveEnvString_38:
	inc di						; scan to end of key
	cmp byte [ es:di ], 0
	jnz RemoveEnvString_38

	inc di
	xchg si, di

RemoveEnvString_44:
	mov al, byte [ es:si ]				; copy down
	mov byte [ es:di ], al
	inc si
	inc di
	or al, al
	jnz RemoveEnvString_44

	cmp byte [ es:si ], 0				; end of env buffer ?
	jnz RemoveEnvString_44				; no -->

	mov byte [ es:di ], al				; append a second null

	pop si
	retn
%else
	push ax
	push bx
	push cx
	push si
	xor ax, ax

.loop:
	pop si
	push si
	scasb						; end of environment ?
	jz .done					; yes -->
	dec di						; point back di
.loopcharacter:
	cmpsb
	jnz .next
	cmp byte [ es:di-1 ], '='
	jnz .loopcharacter
.remove:
	pop bx						; original si
	sub si, bx					; si will contain length of key word
	xchg si, bx					; si points to lookup key
	push si

	mov si, di
	sub si, bx					; must delete from
	mov cx, -1
	repne scasb					; scan to end of key
	xchg si, di

	push di
	inc di						; fix down by one
.nextcharacter:
	dec di						; fix up by one while looping
	movsb						; copy down
	dec di						; byte just copied
	dec di						; one byte before; last copied word
	scasw						; zero word ?
	jnz .nextcharacter				; no, more bytes to copy -->

	pop di						; where removed variable was
	jmp short .loop					; check for another matching variable

.next:
	mov cx, -1
	repne scasb
	jmp short .loop	

.done:
	pop si
	pop cx
	pop bx
	pop ax
	retn
%endif


		; Append Env String
		;
		; Input:
		; es:di-> target position in env block
		; ds:si-> text to insert, null-terminated
		; Return:
		; es:di-> terminating null
AppendEnvString:

	lodsb						; copy arg
	stosb
	or al, al
	jnz AppendEnvString

	dec di						; ptr does not include 0
	retn


		; Append Program Name to Environment Block
		;
		; Usage:
		; es = environment block
		; ds:dx-> program name, null-terminated
appendProgramNametoEnv:

	mov si, dx					; save name to program

	xor al, al					; byte to search for
	xor di, di					; byte offset
	mov cx, 0FFFFh					; maximum length

appendPgmName_10:
	repne scasb					; scan for end of string
	scasb						; test if double null
	jne appendPgmName_10

	mov ax, 1					; # strings to append
	stosw

appendPgmName_14:
	lodsb
	stosb
	or al, al					; null byte copied ?
	jnz appendPgmName_14				; not yet -->

	retn


		; Get Size of Environment String
		;
		; Input:
		; es = environment block string (must be non-zero)
		;
		; Output:
		; cx = # paragraphs requested. (if zero, allocate none).
_getSizeOfEnvString:

	push di

	xor al, al					; byte to search for
	xor di, di					; byte offset
	mov cx, 0FFFFh					; maximum length

getSizeEnv_10:
	repne scasb					; scan for end of string
	scasb						; test if double null
	jne getSizeEnv_10

	lea cx, [ di +sizeEXPANDNAME +2 +15 ]		; get length (including filename, count word and rounding)

	shr cx, 1					; size to paragraphs
	shr cx, 1
	shr cx, 1
	shr cx, 1
	or cx, cx

	pop di
	retn


		; Set Program Name in Memory Block
		;
		; Input:
		; es = block to change (not header address)
		; ss:dx-> filename, null-terminated (may include path with '\')

_setProgramNameInMemBlock:

	SaveSegments
	mov ax, es
	or ax, ax					; no destination mem block ?
	jz _setProgName_22				; ignore set name -->

	dec ax
	push ax						; save seg address

	mov ax, ss
	mov ds, ax					; just in case it's not
	mov es, ax					; scan expanded name

	xor ax, ax
	mov cx, -1
	mov di, dx					; scan name for null terminator
	repne scasb					; scan name
	not cx						; valid count

_setProgName_08:
	cmp byte [ es:di - 1 ], '\'
	jz _setProgName_12				; we have start of name -->
	dec di
	loop _setProgName_08

	mov di, dx					; name contained no path

_setProgName_12:
	mov si, di					; save filename 
	mov dx, di					; save filename 
	pop es						; restore memblock seg address

	xor ax, ax
	mov di, _memPgmName				; where to init
	mov cx, sizefnName / 2				; size filename in words
	repz stosw					; initialize to blanks

	mov di, _memPgmName				; where to init
	mov cx, sizefnName				; size filename in bytes

_setProgName_16:
	lodsb						; get byte
	or al, al					; end of name ?
	jz _setProgName_22				; if end of name -->
	cmp al, '.'					; extension ?
	je _setProgName_22				; if end of name -->

	stosb						; save character in mem block
	loop _setProgName_16

_setProgName_22:
	RestoreSegments
	retn


		; If Overlay Loader, return size
		;
		; Input:
		; al = mode flag
		; cx:dx = file size to return
ifOverlayLoader:
	push ds
	push si
	RetCallersStackFrame ds, si			; save size only if non-Overlay
	mov word [ si + _CX ], dx
	mov word [ si + _BX ], cx
	mov word [ si + _AX ], 0
	pop si
	pop ds

	cmp al, execLoadOverlay				; load overlay ?
	clc
	retn

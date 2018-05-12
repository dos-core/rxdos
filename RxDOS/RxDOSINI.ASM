
%if 0

RxDOSINI - RxDOS initialize

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
%include "lmacros2.mac"

	numdef DOSFLAGS_DEFAULT, 0
	numdef DEFAULT_SFTS,		8
	numdef DEFAULT_CDS,		'E' - 'A' + 1
	numdef DEFAULT_CCBS,		DEFAULT_BUFFERS

	cpu 8086

%if _BUILD_OBJ
	segment RXDOS align=16 class=RXDOS use16 public
	segment RXDOS

	global RxDOS_initialize
	global RxDOS_Heap

	extern _RxDOS_bNumBlockDev
	extern _RxDOS_BufferList
	extern _RxDOS_CurrentDrive
	extern _RxDOS_BootDrive

	extern _RxDOS_CommandShell
	extern _RxDOS_bLastDrive
	extern _RxDOS_bSwitchChar
	extern _RxDOS_bCtrlBreakCheck
	extern _RxDOS_MaxMemory
	extern _RxDOS_NULLDev
	extern _RxDOS_pCDS
	extern _RxDOS_pLFNCDS
	extern _RxDOS_Buffers

	extern _RxDOS_pDPB
	extern _RxDOS_pFT
	extern _RxDOS_pStartMemBlock

	extern _RxDOS_CurrentSeg
	extern _RxDOS_CurrentStackTop

	extern _RxDOS_SharedBuffer
	extern _RxDOS_pDTA
	extern _RxDOS_CurrentPSP
	extern _RxDOS_pCONdriver
	extern _RxDOS_pCLOCKdriver

	extern _RxDOS_UserCodePage
	extern _RxDOS_SystemCodePage
	extern _RxDOS_CurrCountryInfo
	extern _RxDOS_UserCountryCode
	extern _RxDOS_SysCountryCode
	extern FindCountryInfo

	extern _RetCallersStackFrame
	extern RxDOS_start

	extern _CallDOS
	extern _Interrupt_00
	extern _Interrupt_06
	extern _Interrupt_20
	extern _Interrupt_21
	extern _Interrupt_23
	extern _Interrupt_24
	extern _Interrupt_25
	extern _Interrupt_26
	extern _Interrupt_27
	extern _Interrupt_28
	extern _Interrupt_2a
	extern _Interrupt_2f
	extern _IRet

	extern maxBlockDevices
	extern FindAvailableSFTHandle
	extern FindSFTbyHandle
	extern checkforDeviceType
	extern checkforDeviceName
	extern stdDeviceAssignTable

	extern scanDirectory
	extern initdiskAccess
	extern CopyStringArgs
	extern readLine
	extern _initializeMemoryBlock
	extern SDAExtendedSwapArea
	extern initReqBlock

	extern RxDOS_USA_DefaultUpperCaseFunction
%endif


		; CONFIG statement types
		;
		; WARNING: These values cannot be changed without also
		; changing the dispatch table.
CONFIGTYPE_ENDOFARGS	equ 0000h			; last entry
CONFIGTYPE_DOS		equ 0001h			; DOS=UMB,HIGH
CONFIGTYPE_NUMLOCK	equ 0002h			; NUMLOCK=ON|OFF
CONFIGTYPE_BREAK	equ 0003h			; BREAK=ON|OFF
CONFIGTYPE_SET		equ 0004h			; SET variable=value

CONFIGTYPE_COUNTRY	equ 0005h			; COUNTRY=countrynumber,codepage,filename
CONFIGTYPE_DEVICE	equ 0006h			; DEVICE=devicename [options]
CONFIGTYPE_DEVICEHIGH	equ 0007h			; DEVICEHIGH=devicename [options]
CONFIGTYPE_DRIVPARAM	equ 0008h			; DRIVEPARAM=
CONFIGTYPE_MULTITRACK	equ 0009h			; MULTITRACK=ON|OFF
CONFIGTYPE_SWITCHES	equ 0010h			; SWITCHES=/switch[/switch[...]]

CONFIGTYPE_BUFFERS	equ 0011h			; BUFFERS=number[,numreadahead]
CONFIGTYPE_FILES	equ 0012h			; FILES=x
CONFIGTYPE_FCBS		equ 0013h			; FCBS=number[,numprotected]
CONFIGTYPE_LASTDRIVE	equ 0014h			; LASTDRIVE=x
CONFIGTYPE_SHELL	equ 0015h			; SHELL=progname [options]
CONFIGTYPE_STACKS	equ 0016h			; STACKS=number[,size]

CONFIGTYPE_INSTALL	equ 0017h			; INSTALL=progname [options]
CONFIGTYPE_INSTALLHIGH	equ 0018h			; INSTALLHIGH=progname [options]

CONFIGTYPE_MENUDEFAULT	equ 0019h			; MENUDEFAULT=blockname[,timeout]
CONFIGTYPE_MENUITEM	equ 001Ah			; MENUITEM=blockname[,text]
CONFIGTYPE_MENUCOLOR	equ 001Bh			; MENUCOLOR=foreground[,background]
CONFIGTYPE_SUBMENU	equ 001Ch			; SUBMENU=blockname[,text]
CONFIGTYPE_INCLUDE	equ 001Dh			; INCLUDE=blockname
CONFIGTYPE_MENUBLOCK	equ 001Eh			; [blockname]

CONFIGTYPE_SWITCHCHAR	equ 0020h			; SWITCHAR=character
CONFIGTYPE_COMMENTS	equ 0021h			; ;comment
CONFIGTYPE_REM		equ 0022h			; REM=remark

CONFIGTYPE_DOSCODE	equ 0030h
CONFIGTYPE_DOSDATA	equ 0031h
CONFIGTYPE_UMB		equ 0032h
CONFIGTYPE_UMA		equ 0033h
CONFIGTYPE_HMA		equ 0034h


		; CONFIG flags and options
CONFIGFLAG_ENABLED	equ 0001h
CONFIGFLAG_PROCESSED	equ 0002h


		; CONFIGSTMT structure
	struc CONFIGSTMT
cStmtType		resw 1			; CONFIG statement type
cStmtName		resb 1			; statement starts here
	endstruc

		; CONFIGLINE Buffer
	struc CONFIGLINE
configType		resw 1			; CONFIG statement type
configLength		resw 1			; CONFIG line length
configFlags		resw 1			; CONFIG statement flags
configLineNumber	resw 1			; CONFIG statement line number
configStmtText		resw 1			; CONFIG statement pointer to actual name
configStatement		resb 1			; statement starts here
	endstruc


		; RXCONFIG.SYS file processing
		;
		; This module reads the entire RXCONFIG.SYS file from a
		; partially initialized system. It expects minimally buffers,
		; CDS, and other DOS data structures. CONFIG processing
		; happens in two phases: pass one gathers facts and pass two
		; reconfigures data structures and loads drivers.
		;
		; Returns:
		; ds = es = ss
		; ax = current drive
		;
		; INP:	es:di -> CONFIG processing buffer
configProcessing:

	Entry
	ddef	configStatements, es, di
	ddef	configNextLine, es, di

	def	comment	, ';'			; default comment character
	def	charsread
	def	linenumber, 0000

	defbytes	diskAccess, sizeDISKACCESS
	defbytes	linebuffer, 255

		; find/open RXCONFIG.SYS
	push cs
	pop ds
	push cs
	pop es
	xor dx, dx
	xor cx, cx
	xor ax, ax
	mov al, byte [ ss:_RxDOS_CurrentDrive ]	; startup drive

	mov di, _RxDOS_RXCONFIGSYS		; RXCONFIG.SYS filename
	call init2_to_doscode, scanDirectory	; search RXCONFIG.SYS
	jnc .08					; RXCONFIG.SYS found -->
						; open CONFIG.SYS instead if no RXCONFIG.SYS
	push cs
	pop ds
	push cs
	pop es
	mov di, _RxDOS_ConfigFile		; CONFIG.SYS filename
	xor dx, dx
	xor cx, cx
	xor ax, ax
	mov al, byte [ ss:_RxDOS_CurrentDrive ]	; startup drive
	call init2_to_doscode, scanDirectory	; search CONFIG.SYS
	jc .Return				; if none found -->

.08:
	push word [ es:si + deFileSize + _low ]
	push word [ es:si + deFileSize + _high ]

	setES ss
	lea bx, [ _diskAccess + bp ]		; build access control block
	call init2_to_doscode, initdiskAccess	; ax is drive, cx:dx is cluster

	pop word [ ss:bx + diskAcFileSize + _high ]
	pop word [ ss:bx + diskAcFileSize + _low ]

.12:
	getdarg es, di, _configNextLine
	mov word [ es:di + configType ], CONFIGTYPE_ENDOFARGS
	mov word [ es:di + configLength ], 0000

	setES ss
	mov cx, 254
	lea di, [ _linebuffer + bp ]
	lea bx, [ _diskAccess + bp ]		; build access control block
	call init2_to_doscode, readLine		; read a line
	ifz .36					; at end, reconfigure system -->

	inc word [ _linenumber + bp ]		; lines read

		; strip trailing newline
.14:
	lea di, [ _linebuffer + bp ]

	getarg ax, _comment			; parse out comments
	call configRemoveComments		; remove comments
	jz .12					; if nothing left on line -->
	mov word [ _charsread + bp ], cx	; characters read

	setES ss
	cmp byte [ ss:di ], ':'			; comment line ?
	jz .12					; yes, ignore -->
	cmp byte [ ss:di ], '['			; block item specifier ?
	jz .16					; yes -->

	mov si, _RxDOS_ConfigKeywords
	call _findCommand
	jnc .20

	; typeout msgUnknownCommandinConfig
	jmp short short .12

		; [ blockitem_name ]
.16:
	inc di
	call _skipSpaces			; skip any leading spaces

	push di
	call _scanToEndofName			; find terminating space
	mov byte [ ss:di ], 0			; set a terminator

	pop di
	mov dx, CONFIGTYPE_MENUBLOCK		; menu block

		; go save statement
.20:
	cmp dx, byte CONFIGTYPE_REM		; remark statement ?
	jz .12					; ignore -->

	cmp dx, byte CONFIGTYPE_COMMENTS	; if comment, go process
	jz .26					; process comment -->

	push es
	push di
	lea bx, [ _linebuffer + bp ]
	getarg cx, _charsread
	sub cx, di
	add cx, bx				; length difference to remember

	getdarg es, di, _configNextLine
	mov word [ es:di + configType ], dx	; save type
	mov word [ es:di + configStmtText ], si	; pointer to command name

	mov ax, word [ _linenumber + bp ]	; get line number
	mov word [ es:di + configLineNumber ], ax
	mov word [ es:di + configFlags ], 0

	mov word [ es:di + configLength ], cx

		; RxDOS 7.20N:	I think here's a bug for you.
	add word [ es:di + configLength ], (CONFIGLINE_size)

		; copy statement
	pop si
	pop ds
	lea di, [ configStatement + di ]	; offset to statement
	repe movsb

	xor ax, ax
	stosb					; null terminate

	mov di, word [ _configNextLine + bp ]
	add di, word [ es:di + configLength ]	; advance beyond type
	mov word [ _configNextLine + bp ], di
	jmp .12

		; process menu
.26:
	call _skipSpaces			; skip any leading spaces

	mov ax, word [ es:di ]			; get comment character
	cmp ah, ' ' + 1				; space or other control ?
	jnc .28					; no -->
	mov ah, 0

.28:
	storarg _comment, ax			; save comment character(s)
	jmp .12					; continue

		; process menu
.36:
	getdarg es, di, _configStatements
	call configMenu

	getdarg es, di, _configStatements
	call removeUnusedBlocks

		; reconfigure system
	getdarg es, di, _configStatements
	call processSwitchChar
	getdarg es, di, _configStatements
	call processNumLock
	getdarg es, di, _configStatements
	call processDOS

	getdarg es, di, _configStatements
	call processBuffers
	getdarg es, di, _configStatements
	call processFCBS
	getdarg es, di, _configStatements
	call processFiles
	getdarg es, di, _configStatements
	call processStack

	getdarg es, di, _configStatements
	call processLastDrive
	getdarg es, di, _configStatements
	call processDrivParam
	getdarg es, di, _configStatements
	call processMultiTrack

	getdarg es, di, _configStatements
	call processBreak
	getdarg es, di, _configStatements
	call processCountry
	getdarg es, di, _configStatements
	call processSwitches
	getdarg es, di, _configStatements
	call processShell

	getdarg es, di, _configStatements
	call processAnyDevice

		; Return
.Return:
	Return


		; Process Unsupported Commands
processDrivParam:
processMultiTrack:
processSwitches:

	retn						; ignores entire line


		; Process COUNTRY statement
		;
		; es:di-> start of statement in saved CONFIG buffer
processCountry:

	Entry
	def	country, DEFAULT_COUNTRYCODE
	def	codepage, -1

processCountry_08:
	mov ax, CONFIGTYPE_COUNTRY
	call _findStatementType				; find statement type
	jc processCountry_24				; if no more -->

	push es
	push di
	call ConfigPrompt				; check for ?= or F8 case
	jc processCountry_24				; ignore statement -->

		; get country code, optional code page
	mov cx, 1
	mov dx, 7FFFh
	call _getNumber					; get argument
	jc processCountry_24				; if beyond range -->
	storarg _country, ax

	mov cx, 1
	mov dx, 7FFFh
	call _getNumber					; get argument
	jc processCountry_12				; if no argument or is invalid
	storarg _codepage, ax

		; find country info
processCountry_12:
	call init2_to_doscode, FindCountryInfo
	jc processCountry_24				; if country not found -->

	push ss
	pop es
	mov word [ _RxDOS_UserCountryCode ], ax		; country
	mov word [ _RxDOS_SysCountryCode ], ax		; country

	cmp word [ _codepage + bp ], byte -1		; user code page defined ?
	jz processCountry_18				; no, use country defaults -->
	mov dx, word [ _codepage + bp ]			; get user defined code page

processCountry_18:
	mov word [ _RxDOS_UserCodePage ], dx		; code page
	mov word [ _RxDOS_SystemCodePage ], dx		; code page

	mov di, _RxDOS_CurrCountryInfo
	mov cx, sizeCOUNTRYINFO /2
	repe movsw

		; see if other COUNTRY statement
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp short processCountry_08

processCountry_24:
	Return


		; Process BREAK statement
		;
		; es:di-> start of statement in saved CONFIG buffer
processBreak:

	Entry
	def	break, _ON				; 0 is off; 1 is on

processBreak_08:
	mov ax, CONFIGTYPE_BREAK
	call _findStatementType				; find statement type
	jc processBreak_24				; if no more -->

	push es
	push di
	call ConfigPrompt				; check for ?= or F8 case
	jc processBreak_12				; ignore statement -->

	mov si, config_onoff_options
	call _findCommand				; locate on or off
	jc processBreak_12				; if none of the above -->
	storarg _break, dx				; else ok to save

processBreak_12:
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp short processBreak_08

		; return
processBreak_24:
	getarg ax, _break				; get break
	mov byte [ _RxDOS_bCtrlBreakCheck ], al

	Return


		; Process BUFFERS statements
		;
		; es:di-> start of statement in saved CONFIG buffer
processBuffers:
	Entry
	ddef	buffers, 0, _DEFAULT_CCBS

processBuffers_08:
	mov ax, CONFIGTYPE_BUFFERS
	call _findStatementType				; find statement type
	jc processBuffers_24				; if no more -->

	push es
	push di
	call ConfigPrompt				; check for ?= or F8 case
	jc processBuffers_16				; ignore statement -->

	mov cx, 1
	mov dx, CONFIGMAX_BUFFERS
	call _getNumber
	jc processBuffers_16				; if beyond range -->
	mov word [ _buffers + _low + bp ], ax		; else ok to save

	mov cx, 0
	mov dx, ax					; highest cannot exceed first number
	call _getNumber
	jc processBuffers_16				; if beyond range -->
	mov word [ _buffers + _high + bp ], ax		; else ok to save

processBuffers_16:
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp short processBuffers_08

		; return
processBuffers_24:
	getdarg dx, ax, _buffers
	mov word [cs:init2_ccbs], ax

	Return


		; Process DEVICE and DEVICEHIGH statements
		;
		; es:di-> first CONFIGLINE statement in saved CONFIG buffer
processAnyDevice:
	Entry

	Int21 GetUMBLink				; get current UMB link
	mov ah, 0
	def	original_umblink, ax

	Int21 GetAllocationStrategy			; get current allocation strategy
	def	original_memorystrategy, ax

	def	type
	def	step
	def	SegAddress
	def	SegSize, -1

	ddef	ptrInitCommandLine
	ddef	CurrentStatement
	ddef	ExecBlock
	ddef	strategy
	ddef	interrupt
	ddef	loadSize

	defbytes	reqBlock, sizeINITReqHeader
	defbytes	devicename, 128
	defbytes	arguments, 128


processAnyDevice_08:
	mov si, init2_configtype_anydevice
	call _findstatement_multiple_types		; find statement type
	jnc .got_one					; if any more -->

		; return
	getarg bx, _original_memorystrategy
	Int21 SetAllocationStrategy			; restore allocation strategy

	getarg bx, _original_umblink
	Int21 SetUMBLink				; restore UMB link

	Return


.got_one:
	mov ax, word [es:di + configType]
	mov word [bp + _type], ax			; store type

	push es
	push di
	stordarg _CurrentStatement, es, di		; current statement at '='
	call ConfigPrompt				; check for ?= or F8 case
	jc processAnyDevice_next_no_segs		; if ignore -->

		; allocate memory, load device and initialize
	mov ax, DEVICEINIT * 256			; ah = DEVICEINIT, al = 0
	lea di, [ word _reqBlock + bp ]
	call init2_to_doscode, initReqBlock		; initialize request block


		; scan command line parsing out extra characters at the start of name
	push ds
	push es
	getdarg ds, si, _CurrentStatement		; current statement at '='
	lea si, [ word configStatement + si ]

processAnyDevice_16:
	lodsb
	or al, al
	ifz processAnyDevice_64				; if no name, can't load
	cmp al, '='
	jz processAnyDevice_16				; skip = -->
	cmp al, '?'
	jz processAnyDevice_16				; skip ? -->
	cmp al, ' '
	jz processAnyDevice_16				; skip space -->

		; copy device name and path
	lea bx, [ word _devicename + bp ]
	dec si
	push si

processAnyDevice_20:
	lodsb
	or al, al
	jz processAnyDevice_22
	cmp al, ' '
	jz processAnyDevice_22

	mov byte [ ss:bx ], al
	inc bx
	jmp short processAnyDevice_20

processAnyDevice_22:
	mov byte [ ss:bx ], 00

		; copy entire line to arguments
	pop si
	lea bx, [ _arguments + bp ]
	mov word [ _reqBlock + irParamAddress + _segment + bp ], ss
	mov word [ _reqBlock + irParamAddress + _pointer + bp ], bx

processAnyDevice_26:
	lodsb
	or al, al
	jz processAnyDevice_28				; if end of filename -->

	mov byte [ ss:bx ], al
	inc bx
	jmp short processAnyDevice_26

processAnyDevice_28:
	mov word [ ss:bx ], ControlM*256 + ControlM


	and word [bp + _step], 0			; indicate only try

	cmp word [bp + _type], CONFIGTYPE_DEVICE	; without high ?
	je .memstrat_low_only				; yes, use LMA -->

	mov bx, _UMBLINK_ENABLED
	Int21 SetUMBLink				; link in UMBs

	mov bx, _MEM_FIRSTFIT_HIGHONLY
	Int21 SetAllocationStrategy			; first fit, high only

	inc word [bp + _step]				; indicate first try
	jmp .gotmemstrat				; -->


.memstrat_low_only:
	mov bx, _UMBLINK_DISABLED
	Int21 SetUMBLink				; do not link in UMBs

	mov bx, _MEM_FIRSTFIT_LOW
	Int21 SetAllocationStrategy			; first fit, low only

.gotmemstrat:
	mov bx, 0FFFFh
	Int21 AllocateMemory				; get largest available memory block
	storarg _SegSize, bx				; store size of segment
	test bx, bx
	jz processAnyDevice_66
	Int21 AllocateMemory				; else allocate largest available
	jc processAnyDevice_66				; if can't, should display an error message -->

	mov word [ _ExecBlock + loverSegLoadAddress + bp ], ax
	mov word [ _ExecBlock + loverRelocFactor + bp ], ax
	storarg _SegAddress, ax				; store address of segment

	add ax, word [ _SegSize + bp ]			; add alloc size to segment (max size)
	dec ax						; protection
	mov word [ _reqBlock + irEndAddress + _segment + bp ], ax
	mov word [ _reqBlock + irEndAddress + _pointer + bp ], 0000


		; load program
	mov ax, ss
	mov es, ax
	mov ds, ax
	lea bx, [ word _ExecBlock + bp ]		; address of exec block
	lea dx, [ word _devicename + bp ]		; address of device name
	Int21 ExecuteProgram, 03h			; load overlay
	stordarg _loadSize, bx, cx			; load size
	jnc processAnyDevice_32				; if successful -->

	cmp word [bp + _step], 1			; first try, UMA only ?
	jne .error_out					; no -->
	cmp ax, errNotEnoughMemory			; this error ?
	je processAnyDevice_66_plus_60			; yes, second try -->
.error_out:

	push cs
	pop ds
	mov si, RxDOSmsg_CouldNotLoadDriver
	call RxDOSIni_TypeMessage			; say couldn't load ...

	push ss
	pop ds
	lea si, [ word _devicename + bp ]		; address of device name
	call RxDOSIni_TypeMessage			; ... say which driver
	jmp processAnyDevice_60				; go release memory when load failed -->

		; call device init
processAnyDevice_32:
	xor bx, bx
	getarg es, _SegAddress
	mov ax, word [ es:bx + devStrategy ]
	stordarg _strategy, es, ax

	mov ax, word [ es:bx + devInterrupt ]
	stordarg _interrupt, es, ax

	setES ss
	lea bx, [ word _reqBlock + bp ]
	mov word [ _reqBlock + rhStatus + bp ], OP_DONE

	mov al, byte [ _RxDOS_bNumBlockDev ]
	mov byte [ _reqBlock + irDriveNumber + bp ], al
	mov byte [ _reqBlock + irUnits + bp ], 00

	push bp
	mov ds, word [ _strategy + _segment + bp ]
	call far [ _strategy + bp ]		; strategy

	pop bp
	push bp
	lea bx, [ word _reqBlock + bp ]
	mov ds, word [ _strategy + _segment + bp ]
	call far [ _interrupt + bp ]		; interrupt
	pop bp

		; free up any extra memory
	setDS ss
	getarg es, _SegAddress
	test word [ _reqBlock + rhStatus + bp ], OP_ERROR
	jnz processAnyDevice_60				; if error -->

		; compute actual size (in bx:cx)
	mov bx, word [ _reqBlock + irEndAddress + _pointer + bp ]
	add bx, byte (sizePARAGRAPH - 1)		; round up to nearest paragraph boundary

	shr bx, 1
	shr bx, 1
	shr bx, 1
	shr bx, 1					; end para
	add bx, word [ _reqBlock + irEndAddress + _segment + bp ]
	sub bx, word [ _SegAddress + bp ]		; paragraph size
	jbe processAnyDevice_60				; no size, go free-up -->

	Int21 ModifyAllocatedMemory			; free memory to given size

		; is driver a file system or blocked device ?
	test word [ es:devAttributes ], DEV_CHAR	; is it a character device ?
	jnz processAnyDevice_56				; yes -->

	mov dx, es					; driver address (segment)
	mov cl, byte [ _reqBlock + irUnits + bp ]	; get number of device units
	call InitializeAttachedFileSystem

	mov cl, byte [ _reqBlock + irUnits + bp ]
	add byte [ _RxDOS_bNumBlockDev ], cl

		; Link device into device chain
processAnyDevice_56:
	mov bx, word [ _RxDOS_NULLDev + _segment ]
	mov ax, word [ _RxDOS_NULLDev + _pointer ]
	mov word [ es:devLink + _segment ], bx
	mov word [ es:devLink + _pointer ], ax		; Move address that former was at NUL device to loaded driver

	mov word [ _RxDOS_NULLDev + _segment ], es
	mov word [ _RxDOS_NULLDev + _pointer ], 0	; Move address of loaded driver into NUL device
	jmp short processAnyDevice_64

processAnyDevice_60:
	getarg es, _SegAddress
	Int21 FreeAllocatedMemory			; if error while loading

processAnyDevice_64:
	mov ax, word [cs:init2_dosflags]
	call init2_relocate_device

	jmp processAnyDevice_next

processAnyDevice_66_plus_60:				; free allocation
	getarg es, _SegAddress
	Int21 FreeAllocatedMemory			; if error while loading

processAnyDevice_66:
	cmp word [bp + _step], 1			; error while trying to load high?
	jne processAnyDevice_error_out_of_memory_next	; no, error out -->
	inc word [bp + _step]				; indicate second try
	jmp processAnyDevice_28.memstrat_low_only	; second try is in LMA


processAnyDevice_error_out_of_memory_next:
	push cs
	pop ds
	mov si, RxDOSmsg_CouldNotLoadDriver
	call RxDOSIni_TypeMessage			; say couldn't load ...

	push ss
	pop ds
	lea si, [ word _devicename + bp ]		; address of device name
	call RxDOSIni_TypeMessage			; ... say which driver

processAnyDevice_next:
	pop es
	pop ds

processAnyDevice_next_no_segs:
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp processAnyDevice_08


		; Process DOS statement
		;
		; es:di-> start of statement in saved CONFIG buffer
processDOS:
	lframe near
	lvar	word, type
	lenter

.08:
	mov si, init2_configtype_dos_dosdata_doscode_umb_uma_hma
	call _findstatement_multiple_types	; find statement type
	jc .24					; if no more -->
	mov ax, word [es:di + configType]
	mov word [bp + ?type], ax		; store type

	push es
	push di
	call ConfigPrompt			; check for ?= or F8 case
	jc .12					; ignore statement -->

.10:
	mov si, config_dos_options
	mov ax, word [bp + ?type]
	cmp ax, CONFIGTYPE_DOS
	je .options
	mov si, config_doscode_options
	cmp ax, CONFIGTYPE_DOSCODE
	je .options
	mov si, config_dosdata_options
	cmp ax, CONFIGTYPE_DOSDATA
	je .options
	mov si, config_uma_options
	cmp ax, CONFIGTYPE_UMA
	je .options
	mov si, config_hma_options
	cmp ax, CONFIGTYPE_HMA
	je .options
	cmp ax, CONFIGTYPE_UMB
	je .umb

	mov dx, init2_msg.internal_error_config
	call init2_disp_msg_asciz_cs_dx
	jmp .12

.umb:
	mov si, config_onoff_options
	call _findCommand
	jc .12
	test dx, dx
	jz @F
	or word [cs:init2_dosflags], DOSFLAGS_LINK_UMB
	jmp .12

@@:
	and word [cs:init2_dosflags], ~ DOSFLAGS_LINK_UMB
	jmp .12


.options:
	call _findCommand			; locate options like high and umb
	jnc .gotoption				; if any found -->

	jmp .12

.gotoption:
	or dx, dx
	jns .or
.and:
	and word [cs:init2_dosflags], dx	; and option if it says off
	jmp short .11

.or:
	or word [cs:init2_dosflags], dx		; or option if it says on

.11:
	call _nextArgument			; point to next argument
	jnc .options				; go process -->

.12:
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp .08

		; return
.24:
	lleave
	lret


		; Process FCBS statement
		;
		; es:di-> start of statement in saved CONFIG buffer
processFCBS:
	Entry
	ddef	FCBS, 0, DEFAULT_FCBS

processFCBS_08:
	mov ax, CONFIGTYPE_FCBS
	call _findStatementType				; find statement type
	jc processFCBS_24				; if no more -->

	push es
	push di
	call ConfigPrompt				; check for ?= or F8 case
	jc processFCBS_16				; if ignore -->

	mov cx, 1
	mov dx, CONFIGMAX_FCBS_X
	call _getNumber
	jc processFCBS_16				; if beyond range -->
	mov word [ _FCBS + _low + bp ], ax		; else ok to save

	mov cx, 0
	mov dx, CONFIGMAX_FCBS_Y
	call _getNumber
	jc processFCBS_16				; if beyond range -->
	mov word [ _FCBS + _high + bp ], ax		; else ok to save

processFCBS_16:
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp short processFCBS_08

		; return
processFCBS_24:
	getdarg dx, ax, _FCBS				; return FCBS
	Return


		; Process FILES statements
		;
		; es:di-> start of statement in saved CONFIG buffer
processFiles:
	Entry
	def	files, _DEFAULT_SFTS
	def	fcbs, ax

processFiles_08:
	mov ax, CONFIGTYPE_FILES
	call _findStatementType				; find statement type
	jc processFiles_24				; if no more -->

	push es
	push di
	call ConfigPrompt				; check for ?= or F8 case
	jc processFiles_12				; if ignore -->

	mov cx, 1
	mov dx, CONFIGMAX_FILES
	call _getNumber
	jc processFiles_12				; if beyond range -->
	storarg _files, ax				; else ok to save

processFiles_12:
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp short processFiles_08

		; return
processFiles_24:
	getarg ax, _files				; return files
	add ax, word [ _fcbs + bp ]
	mov word [cs:init2_sfts], ax

	Return


		; Process LASTDRIVE statement
		;
		; es:di-> start of statement in saved CONFIG buffer
processLastDrive:
	Entry
	def	LastDrive, _DEFAULT_CDS

processLastDrive_08:
	mov ax, CONFIGTYPE_LASTDRIVE
	call _findStatementType				; find statement type
	jc processLastDrive_24				; if no more -->

	push es
	push di
	call ConfigPrompt				; check for ?= or F8 case
	jc processLastDrive_12				; if ignore -->

	xor ax, ax
	mov al, byte [ es:di ]
	_upperCase al					; upper case
	sub al, 'A'-1
	jbe processLastDrive_12				; A: = 1, B: = 2, ...
	cmp al, 32					; above 32 ?
	ja processLastDrive_12				; yes -->
	storarg _LastDrive, ax

processLastDrive_12:
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp short processLastDrive_08

		; return
processLastDrive_24:
	getarg ax, _LastDrive				; get last drive info, if any
	mov word [cs:init2_cds], ax

	Return


		; Process NUMLOCK Statement
		;
		; es:di-> start of statement in saved CONFIG buffer
processNumLock:
	Entry
	def	numlock, -1				; 0 = off, 1 = on, -1 = leave unchanged

processNumLock_08:
	mov ax, CONFIGTYPE_NUMLOCK
	call _findStatementType				; find statement type
	jc processNumLock_24				; if no more -->

	push es
	push di
	call ConfigPrompt				; check for ?= or F8 case
	jc processNumLock_12				; if ignore -->

	mov si, config_onoff_options
	call _findCommand				; locate on or off
	jc processNumLock_12				; if none of the above -->
	storarg _numlock, dx				; else ok to save

processNumLock_12:
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp short processNumLock_08

		; return
processNumLock_24:
	push es
	getarg ax, _numlock				; get numlock
	cmp ax, -1					; any change ?
	jz processNumLock_46				; if no change -->

	mov bx, 40h
	mov es, bx					; BIOS communications area
	mov bx, _BIOS_KeyboardFlags			; keyboard status flags
	or ax, ax					; set num lock ?
	jnz processNumLock_32				; if set -->

	and byte [ es:bx ], ~ _BIOS_KB_NumLock		; else clear num lock
	jmp short processNumLock_46

processNumLock_32:
	or byte [ es:bx ], _BIOS_KB_NumLock		; set num lock

processNumLock_46:
	pop es

	Return


		; Process SHELL statement
		;
		; es:di-> start of statement in saved CONFIG buffer
processShell:
	Entry

processShell_08:
	mov ax, CONFIGTYPE_SHELL
	call _findStatementType				; find statement type
	jc processShell_24				; if no more -->

	push es
	push di
	call ConfigPrompt				; check for ?= or F8 case
	jc processShell_12				; if ignore -->

	push es
	push di						; source args
	push ds
	mov bx, _RxDOSini_CommandShell
	push bx						; destination args
	call init2_to_doscode, CopyStringArgs		; copy string

processShell_12:
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp short processShell_08

		; return
processShell_24:

	Return


		; Process STACKS statement
		;
		; es:di-> start of statement in saved CONFIG buffer
processStack:
	Entry
	ddef	stacks, 0, DEFAULT_STACKS

processStack_08:
	mov ax, CONFIGTYPE_STACKS
	call _findStatementType				; find statement type
	jc processStack_24				; if no more -->

	push es
	push di
	call ConfigPrompt				; check for ?= or F8 case
	jc processStack_16				; if ignore -->

	mov cx, CONFIGMIN_STACKS_X
	mov dx, CONFIGMAX_STACKS_X
	call _getNumber
	jc processStack_16				; if beyond range -->
	mov word [ _stacks + _low + bp ], ax		; else ok to save

	mov cx, CONFIGMIN_STACKS_Y
	mov dx, CONFIGMAX_STACKS_Y
	call _getNumber
	jc processStack_16				; if beyond range -->
	mov word [ _stacks + _high + bp ], ax		; else ok to save

processStack_16:
	pop di
	pop es
	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp short processStack_08

		; return
processStack_24:
	getdarg dx, ax, _stacks				; return stacks

	Return


		; Process Switch Char
		;
		; es:di-> start of statement in saved CONFIG buffer
processSwitchChar:
	Entry
	def	SwitchChar, '/'

processSwitchChar_08:
	mov ax, CONFIGTYPE_SWITCHCHAR
	call _findStatementType				; find statement type
	jc processSwitchChar_24				; if no more -->

	xor ax, ax
	mov al, byte [ es:di + configStatement ]
	storarg _SwitchChar, ax				; save last switch character

	or word [ es:di + configFlags ], byte CONFIGFLAG_PROCESSED
	add di, word [ es:di + configLength ]
	jmp short processSwitchChar_08

		; return
processSwitchChar_24:
	getarg ax, _SwitchChar				; get last switch character or use default
	mov byte [ _RxDOS_bSwitchChar ], al

	Return


		; Remove comments, leading blanks, blank lines
		;
		; ax = comment character
		; cx = current line count
		; ss:di-> line read from disk
		;
		; This reads through blocks and changes each block to a REM
		; block that was not selected as a menu option.
configRemoveComments:

	call _skipSpaces

	push di						; save buffer pointer
	cmp ah, 0					; double character comments ?
	jnz configRemoveComments_12			; yes -->

configRemoveComments_06:
	cmp al, byte [ ss:di ]				; is it comment character ?
	jz configRemoveComments_20			; yes -->
	inc di
	loop configRemoveComments_06
	jmp short configRemoveComments_20

configRemoveComments_12:
	cmp ax, word [ ss:di ]				; is it comment character ?
	jz configRemoveComments_20			; yes -->
	inc di
	loop configRemoveComments_12

configRemoveComments_20:
	mov cx, di
	pop di
	sub cx, di					; new length
	retn


		; Find Statement Type
		;
		; INP:	ax = searched CONFIG item type
		;	es:di-> CONFIGLINE structure
		; OUT:	CY if none found,
		;	 es:di -> CONFIGLINE structure with CONFIGTYPE_ENDOFARGS
		;	NC if found,
		;	 es:di -> CONFIGLINE structure with the specified types
		; CHG:	ax, si
_findStatementType:
	mov si, init2_configtype_single
	mov word [cs:init2_configtype_single.configtype \
		- init2_configtype_single + si], ax

		; Find Statement Type
		;
		; INP:	cs:si -> word number of entries, words CONFIG item types
		;	es:di-> CONFIGLINE structure
		; OUT:	si unchanged
		;	CY if none found,
		;	 es:di -> CONFIGLINE structure with CONFIGTYPE_ENDOFARGS
		;	NC if found,
		;	 es:di -> CONFIGLINE structure with any of the types
		; CHG:	ax
_findstatement_multiple_types:
	push ds
	push es
	push cx

	push es
	pop ds				; ds:di -> CONFIGLINE structure
	push cs
	pop es				; es:si -> configtype structure
	xchg si, di			; ds:si -> CONFIGLINE structure
					; es:di -> configtype structure

.loop:
	cmp word [si + configType], byte CONFIGTYPE_ENDOFARGS
	stc
	je .return			; not found if at end -->
.check:
	push di
	mov ax, word [si + configType]	; ax = configtype of this line
	mov cx, word [es:di]		; number of entries
	scasw				; skip number of entries, di -> types
	repne scasw			; match to searched type
	pop di
	jnz .next			; if not, goto next -->
.found:
					; found type (NC after scasw matched)
.return:
	pop cx
	pop es
	pop ds
	xchg si, di
	retn

.next:
	add si, word [si + configLength]
	jmp short .loop


		; CONFIG statement prompt
		;
		; ax = statement type
		; es:di-> first non-space after keyword
		;
		; OUT:	NC if statement parsing should proceed
		;	CY if F8 pressed or 'N' answered to prompt, abort parsing of this line
ConfigPrompt:
	Entry
	ddef	configTextPtr
	ddef	configStmt, es, di

	lea di, [ word configStatement + di ]
	stordarg _configTextPtr, es, di		; save pointer

	cmp word [ es:di ], '?='		; is it ?=
	jz .12					; yes, go prompt -->
	call checkforF8				; detect F8 during boot time
	jz .24					; no, go skip = if set -->

		; prompt statement
.12:
	push ds
	setDS cs
	getdarg es, di, _configStmt
	mov si, word [ es:di + configStmtText ]
	call RxDOSIni_TypeMessage		; show statement type

	getdarg ds, si, _configTextPtr
	call RxDOSIni_TypeMessage		; show user text

	setDS cs
	mov si, msgProcessCommandYesNo
	call RxDOSIni_TypeMessage

.16:
	xor ax, ax
	int 16h

	_upperCase al				; upper case
	cmp al, 'Y'				; check for Yes
	jz .20
	cmp al, 'N'				; check for No
	jnz .16					; Get next character if invalid

.20:
	int 29h					; echo character
	call RxDOSIni_TypeCR

	pop ds
	getdarg es, di, _configTextPtr
	cmp al, 'N'				; if No
	stc					; set carry if No
	jz .36					; exit -->

		; Skip ? and ?= and any spaces which follow
.24:
	cmp word [ es:di ], '?='		; '?=' in prompt ?
	jnz .26					; no -->
	inc di					; skip over question mark

.26:
	cmp byte [ es:di ], '='			; '=' in prompt ?
	jnz .28					; no -->
	inc di					; skip over equal sign

.28:
	cmp byte [ es:di ], ' '			; space follows ?
	jnz .32					; no, return -->
	inc di					; skip over space
	jmp short .28				; loop through all spaces -->

.32:
	clc					; clear carry

.36:
	Return


		; Skip to next argument
		;
		; Usage:
		; es:di-> line buffer
_nextArgument:
	cmp byte [ es:di ], ' '			; ignore spaces
	jz _nextArgument_06
	cmp byte [ es:di ], '='			; ignore equal signs
	jz _nextArgument_06
	cmp byte [ es:di ], ','			; ignore commas
	jnz _nextArgument_08

_nextArgument_06:
	inc di
	jmp short _nextArgument

_nextArgument_08:
	cmp byte [ es:di ], ' '			; CY means end of line
	retn


		; Process Menus
configMenu:
	Entry
	ddef	ConfigStatements, es, di

		; identify all common components as enabled
configMenu_04:
	mov ax, CONFIGTYPE_MENUBLOCK
	mov bx, Config_CommonSelector
	call _findConfigMenuStatement			; identify common components
	jc configMenu_08				; if none left -->

	or word [ es:di + configFlags ], byte CONFIGFLAG_ENABLED
	add di, word [ es:di + configLength ]
	jmp short configMenu_04

		; search for menu starter
configMenu_08:
	mov ax, CONFIGTYPE_MENUBLOCK
	mov bx, Config_MenuSelector
	getdarg es, di, _ConfigStatements
	call _findConfigMenuStatement
	jc configMenu_68

	; ...

configMenu_68:
	Return


		; Remove unused blocks
		;
		; es:di-> CONFIG table
		;
		; This reads through blocks and changes each block to a REM
		; block that was not selected as a menu option.
removeUnusedBlocks:
	mov ax, CONFIGTYPE_MENUBLOCK
	call _findStatementType				; find start of block
	jc removeUnusedBlocks_32			; if none left -->

removeUnusedBlocks_08:
	test word [ es:di + configFlags ], CONFIGFLAG_ENABLED
	jz removeUnusedBlocks_12			; if disabled, delete -->
	add di, word [ es:di + configLength ]
	jmp short removeUnusedBlocks			; if enabled, we'll keep ->

		; remove disabled blocks
removeUnusedBlocks_12:
	mov word [ es:di + configType ], CONFIGTYPE_REM
	add di, word [ es:di + configLength ]

	cmp word [ es:di + configType ], byte CONFIGTYPE_ENDOFARGS
	jz removeUnusedBlocks_32			; if none left -->
	cmp word [ es:di + configType ], byte CONFIGTYPE_MENUBLOCK
	jz removeUnusedBlocks_08			; if next block -->
	jmp short removeUnusedBlocks_12			; go remove -->

		; return
removeUnusedBlocks_32:
	retn


		; Find Menu statement
		;
		; ax = config item type
		; ds:bx-> menu name
		; es:di-> CONFIG table
_findConfigMenuStatement:

	cmp word [ es:configType + di ], byte CONFIGTYPE_ENDOFARGS
	jnz _findConfigMenuStatement_08
	stc
	retn

_findConfigMenuStatement_08:
	cmp ax, word [ es:configType + di ]		; is it menu type ?
	jnz _findConfigMenuStatement_32			; if not, goto next -->

	push di
	push bx
	push ax
	lea di, [ word configStatement + di ]		; point to actual statement

_findConfigMenuStatement_12:
	mov ah, byte [ bx ]				; get character from searched menu block name
	_upperCase ah					; upper case

	mov al, byte [ es:di ]				; get character from actual statement
	_upperCase al					; upper case

	inc bx
	inc di
	cmp ah, al					; compare strings
	jnz _findConfigMenuStatement_28			; if not equal -->

	or al, al					; both null terminators ?
	jnz _findConfigMenuStatement_12			; not yet -->

	pop ax
	pop bx
	pop di
	clc
	retn

_findConfigMenuStatement_28:
	pop ax
	pop bx
	pop di

_findConfigMenuStatement_32:
	add di, word [ es:di + configLength ]		; search in next CONFIGLINE structure
	jmp short _findConfigMenuStatement


		; Get Number
		;
		; Input:
		; cx	minimal acceptable number
		; dx	maximal acceptable number
		; es:di-> line buffer
		;
		; Returns:
		; ax = number, if any
		; di = pointer to argument past command
		; CY if not a number
_getNumber:
	push cx
	xor ax, ax

_getNumber_08:
	cmp byte [ es:di ], '0'				; valid digit ?
	jc _getNumber_26				; no longer -->
	cmp byte [ es:di ], '9' + 1			; valid digit ?
	jnc _getNumber_26				; no longer -->

	mov cx, ax
	add ax, ax					; *2
	add ax, ax					; *4
	add ax, cx					; *5
	add ax, ax					; *10

	mov cl, byte [ es:di ]				; get digit
	and cx, byte 15					; ch = 0, and remove the 30h ('0' = 30h, '1' = 31h, ...)
	add ax, cx
	jc _getNumber_16				; overflow -->

	inc di
	jmp short _getNumber_08

		; overflow
_getNumber_16:
	pop cx
		; RxDOS 7.30: message for number overflow here
	xor ax, ax
	dec ax						; NZ
	pushf
	jmp short _getNumber_32				; sets CY

		; check for error
_getNumber_26:
	pop cx
	or ax, ax
		; RxDOS 7.20N:	Do not change above line to clc. It'll also set ZF
		;		according to the result.
	pushf						; save current status
	cmp ax, cx					; is it at least as large as ...
	jc _getNumber_32				; no -->
	cmp ax, dx					; is it greater than ...
	jbe _getNumber_36				; if within range -->

_getNumber_32:
	popf
	stc
	pushf						; change status

		; skip to next argument
_getNumber_36:
	cmp byte [ es:di ], ' '
	jb _getNumber_48				; if control character
	je _getNumber_38				; if space -->
	cmp byte [ es:di ], ':'
	je _getNumber_38				; if colon -->
	cmp byte [ es:di ], '='
	je _getNumber_38				; if equal sign -->
	cmp byte [ es:di ], ','
	jne _getNumber_48				; if not comma -->

_getNumber_38:
	inc di
	jmp short _getNumber_36

		; return
_getNumber_48:
	popf
	retn


		; Find Command
		;
		; Input:
		; es:di-> line buffer
		; cs:si-> table to search
		;
		; Returns:
		; dx	command type
		; di	pointer to argument past command
		; si	-> cStmtName of table entry that matches
		; cy	command not found
_findCommand:
.:
	cmp word [ cs:si ], byte -1
	jne .12					; if not end of table ->
	cmp word [ cs:si + 2 ], byte 0
	je .Error				; if end -->

.12:
	push word [ cs:si + cStmtType ]		; if item matches
	; lea si, [ word cStmtName + si ]	; skip to name
	lodsw

	xor bx, bx

.18:
	mov al, byte [ es:di + bx ]		; get character
	_lowerCase al				; lower case character
	cmp al, byte [ cs:si + bx ]		; this command ?
	jnz .32					; not this command -->

	inc bx
	cmp byte [ cs:si + bx ], 0		; end of string ?
	jnz .18					; not yet -->

	mov al, byte [es:di + bx]
	cmp al, ' '
	jbe @F
	cmp al, '='
	je @F
	cmp al, ','
	je @F
	cmp al, '?'
	je @F
	cmp al, '!'
	je @F

	jmp .32

@@:
		; if command match is made, skip to next argument
	add di, bx				; offset

.22:
	cmp byte [ es:di ], 0
	jz .26
	cmp byte [ es:di ], ' ' + 1		; skip spaces
	jnb .26

	inc di
	jmp short .22

.26:
	pop dx					; statement type
	or dx, dx
	retn

		; if not a match, try next command in table
.32:
	inc si					; increment past
	cmp byte [ cs:si - 1 ], 0		; end of string ?
	jnz .32					; loop -->

	pop ax					; ignore saved stmt type
	jmp .					; continue -->

.Error:
	stc
	retn


		; Skip leading spaces and control characters
		;
		; Usage:
		; ss:di-> line buffer
_skipSpaces:
	cmp byte [ ss:di ], 0
	jz _skipSpaces_08
	cmp byte [ ss:di ], ' ' + 1
	jnb _skipSpaces_08

	inc di
	jmp short _skipSpaces

_skipSpaces_08:
	retn


		; Skip to next space
		;
		; Usage:
		; ss:di-> line buffer
_scanToEndofName:
	cmp byte [ ss:di ], 0
	jz _scanToEndofName_08

	mov al, byte [ ss:di ]
	cmp al, ' ' + 1
	jb _scanToEndofName_08
	_upperCase al					; upper case
		; RxDOS 7.20N:	Below sequence is a bit weird. Shouldn't it also
		;		check if the character is above-equal 'A'?
	cmp al, 'Z' + 1
	jae _scanToEndofName_08
	cmp al, 'A'
	jb _scanToEndofName_08

	inc di
	jmp short _scanToEndofName

_scanToEndofName_08:
	cmp byte [ ss:di ], 0
	retn


AllocateSystemSpace_with_type: equ init2_alloc_s_mcb


		; RxDOS Disk Parameter Blocks subsystem initialize
		;
		; No Parameters Required.
RxDOSini_DPBSubSystem:

	push ds
	push es

	push ss
	pop ds

	mov al, sizeDPB
	mov cl, 32
	mul cl					; max number of logical devices
	mov cl, S_DPB
	call AllocateSystemSpace_with_type	; allocate DPBs for all devices

	mov word [ _RxDOS_pDPB + _pointer ], di
	mov word [ _RxDOS_pDPB + _segment ], es

	xor ax, ax
	mov cx, 32
	setDS es				; point to PDB area

		; values are defaults without special meaning
		; actual values are assigned later by calling driver
RxDOS_DPBinit_12:
	mov byte [ _dpbDrive + di ], al
	mov byte [ _dpbUnit + di ], -1		; unit 0FFh of default block
	mov word [ _dpbBytesPerSector + di ], 512
	mov byte [ _dpbClusterSizeMask + di ], 0FEh
	mov byte [ _dpbClusterSizeShift + di ], 0
	mov word [ _dpbFirstFAT + di ], 1
	mov byte [ _dpbNumCopiesFAT + di ], 2
	mov word [ _dpbMaxAllocRootDir + di ], 64
	mov word [ _dpbFirstDataSector + di ], 9
	mov word [ _dpbMaxClusterNumber + di ], 352

	mov word [ _dpbSectorsPerFat + di ], 2
	mov word [ _dpbFirstDirSector + di ], 5
	mov word [ _dpbptrDeviceDriver + _segment + di ], 70h
	mov word [ _dpbptrDeviceDriver + _pointer + di ], block
	mov byte [ _dpbMediaDescriptor + di ], 0
	mov byte [ _dpbAccessFlag + di ], -1	; UNACCESSED

	lea bx, [ sizeDPB + di ]		; current pointer + sizeDPB
	mov word [ _dpbNextDPB + _segment + di ], ds
	mov word [ _dpbNextDPB + _pointer + di ], bx
	mov word [ _dpbNextFree + di ], 0
	mov word [ _dpbFreeCount + _low + di ], -1
	mov word [ _dpbFreeCount + _high + di ], -1

	inc ax
	mov di, bx
	loop RxDOS_DPBinit_12

		; set end marker at last DPB
	mov word [ _dpbNextDPB + _segment - sizeDPB + di ], -1
	mov word [ _dpbNextDPB + _pointer - sizeDPB + di ], -1

		; loop through DPB's and assign drivers
	push ss
	pop es
	mov bx, _RxDOS_NULLDev				; get start of chain
.loop_end_devicechain:
	cmp word [ es:bx + devLink ], -1
	je .found_end_devicechain
	les bx, [ es:bx + devLink ]
	jmp .loop_end_devicechain

		; es:bx -> last device header
.found_end_devicechain:
	lds si, [ ss:_RxDOS_pDPB ]
	xor di, di
.loop_devices:
	test word [ es:bx + devAttributes ], DEV_CHAR
	jnz .after_add_devices		; if a character device -->

	xor cx, cx
	or cl, [ es:bx + devName ]
	jz .after_add_devices
	xor dx, dx
	jmp .first_unit

.next_unit:
	lds si, [ si + _dpbNextDPB ]
.first_unit:
	cmp di, 32
	jb @F
	push ds
	 push cs
	 pop ds
	mov si, init_msg.too_many_block_units
	call RxDOSIni_TypeMessage
	pop ds
	jmp .after_add_devices
@@:
	cmp si, -1
	je .dpb_fail
	inc di				; increment total drives counter
	mov byte [ si + _dpbUnit ], dl	; set unit
	inc dx				; increment unit-within-block-device
	mov word [ si + _dpbptrDeviceDriver ], bx
	mov word [ si + _dpbptrDeviceDriver + 2 ], es	; set device
@@:
	loop .next_unit

.after_add_devices:
	mov cx, bx
	mov dx, es

	push ss
	pop es
	mov bx, _RxDOS_NULLDev	; -> NUL device

	cmp word [ es:bx + devLink ], cx	; points to prior one ?
	jne @F
	cmp word [ es:bx + devLink + 2 ], dx
	je .all_devices_done			; yes, all done
						;  (NUL is no block device) -->
@@:

.loop_find_next_device:
	cmp word [ es:bx + devLink ], cx
	jne @F
	cmp word [ es:bx + devLink + 2 ], dx
	je .loop_devices
@@:

	cmp word [ es:bx + devLink ], -1
	je .devices_fail
	les bx, [ es:bx + devLink ]
	jmp .loop_find_next_device

.devices_fail:
	 push cs
	 pop ds
	mov si, init_msg.devices_error
	call RxDOSIni_TypeMessage
	mov ax, es
	call init_disp_ax_hex
	mov si, init_msg.devices_error_colon
	call RxDOSIni_TypeMessage
	mov ax, bx
	call init_disp_ax_hex
	mov si, init_msg.devices_error_after
	call RxDOSIni_TypeMessage

.68:
	jmp RxDOS_init_68

.dpb_fail:
	push si
	push ds
	 push cs
	 pop ds
	mov si, init_msg.dpb_error_dev
	call RxDOSIni_TypeMessage
	pop ax
	call init_disp_ax_hex
	mov si, init_msg.dpb_error_colon
	call RxDOSIni_TypeMessage
	pop ax
	call init_disp_ax_hex
	mov si, init_msg.dpb_error_after
	call RxDOSIni_TypeMessage

	jmp .68

.all_devices_done:
	mov ax, di
	mov byte [ss:number_block_devices], al

	pop es
	pop ds
	retn


		; RxDOS Current Directory Structure subsystem initialize
		;
		; No Parameters Required.
		;
		; ss = DOS data segment
RxDOSini_CDSSubSystem:
	push ds
	push es

	push ss
	pop ds
	mov ax, sizeCDS
	xor bx, bx
	mov bl, [ _RxDOS_bLastDrive ]
	mul bx					; (dx:)ax = size of CDS
	mov cl, S_CDS
	call AllocateSystemSpace_with_type
	mov word [ _RxDOS_pCDS + _segment ], es
	mov word [ _RxDOS_pCDS + _pointer ], di

	xor ax, ax
	shr cx, 1
	repe stosw				; init entire space to nulls

	mov ax, sizeLFNCDS
	xor cx, cx
	mov cl, byte [ _RxDOS_bLastDrive ]
	mul cx			 		; (dx:)ax = size of LFN CDS
	mov cl, S_LFNCDS
	call AllocateSystemSpace_with_type
	mov word [ _RxDOS_pLFNCDS + _segment ], es
	mov word [ _RxDOS_pLFNCDS + _pointer ], di

	xor ax, ax
	shr cx, 1
	repe stosw				; init entire space to nulls

	xor cx, cx
	mov cl, byte [ _RxDOS_bLastDrive ]
	mov di, word [ _RxDOS_pLFNCDS + _pointer ]	; es is still what we put in _RxDOS_pLFNCDS+_segment

	mov dx, word [ _RxDOS_pCDS + _segment ]
	mov bx, word [ _RxDOS_pCDS + _pointer ]

		; Link each LFNCDS entry to its CDS entry
RxDOS_CDSinit_04:
	mov word [ es:_lfnPtrToCDS + _segment + di ], dx
	mov word [ es:_lfnPtrToCDS + _pointer + di ], bx
	add bx, byte sizeCDS
	add di, sizeLFNCDS
	loop RxDOS_CDSinit_04

		; Fill in the default path (root directory) for each CDS
	mov al, 'A'					; starts with A:
	xor cx, cx
	mov cl, byte [ _RxDOS_bLastDrive ]
	les di, [ _RxDOS_pCDS ]

RxDOS_CDSinit_08:
	mov byte [ es:di + _cdsActualDirectory ], al
	mov byte [ es:di + _cdsActualDirectory + 1 ], ':'
	mov byte [ es:di + _cdsActualDirectory + 2 ], '\'
	mov byte [ es:di + _cdsActualDirectory + 3 ], 0	; drive,':\',0
	mov byte [ es:di + _cdsNonSubstOffset ], 3	; points to the 0

	inc al						; next letter
	add di, byte sizeCDS
	loop RxDOS_CDSinit_08

		; init DPB values for each CDS
	xor cx, cx
	les di, [ _RxDOS_pCDS ]
	mov si, _RxDOS_pDPB - _dpbNextDPB
	mov cl, byte [ _RxDOS_bNumBlockDev ]

RxDOS_CDSinit_12:
	cmp word [ si + _dpbNextDPB ], -1
	je .dpb_fail
	lds si, [ si + _dpbNextDPB ]
	or word [ es:di + _cdsFlags ], _CDS_PHYSICALDRIVE
	mov word [ es:di + _cdsPtrToDPB + _pointer ], si
	mov word [ es:di + _cdsPtrToDPB + _segment ], ds
	add di, byte sizeCDS
	loop RxDOS_CDSinit_12

	pop es
	pop ds
	retn


.dpb_fail:
	push si
	push ds
	 push cs
	 pop ds
	mov si, init_msg.dpb_error_cds
	call RxDOSIni_TypeMessage
	pop ax
	call init_disp_ax_hex
	mov si, init_msg.dpb_error_colon
	call RxDOSIni_TypeMessage
	pop ax
	call init_disp_ax_hex
	mov si, init_msg.dpb_error_after
	call RxDOSIni_TypeMessage

	jmp RxDOS_init_68


		; RxDOS System File Tables subsystem initialize
		;
		; ax = number of SFT entries to initialize
RxDOSini_SFTSubSystem:

	push ds
	 push ss
	 pop ds
	push ax						; files
	mov cx, sizeSFT
	mul cx						; total bytes for the actual SFT entries
	add ax, byte sizeFT

	mov cl, S_SFT
	call AllocateSystemSpace_with_type

	push di
	xor ax, ax
	shr cx, 1
	repe stosw					; init entire space to nulls
	pop di

	mov word [ _RxDOS_pFT + _segment ], es
	mov word [ _RxDOS_pFT + _pointer ], di

	dec ax
	mov word [ es:di + nextFTPointer + _pointer ], ax
	mov word [ es:di + nextFTPointer + _segment ], ax
	pop word [ es:di + numberSFTEntries ]

	call RxDOSini_StdInStdOutDrivers		; initialize drivers
	pop ds
	retn


		; RxDOS Cache Control Buffers subsystem initialize
		;
		; ax = number of CCBs to initialize
		; ds = DOSDATA
RxDOSini_CCBSubSystem:
	push ds
	push es

	d2bp

	push ax						; buffers
	mov cx, sizeCCB
	mul cx						; total bytes for cache blocks

	mov cl, S_CCB
	call AllocateSystemSpace_with_type
	mov word [ _RxDOS_BufferList + _segment ], es
	mov word [ _RxDOS_BufferList + _pointer ], di

	pop cx						; number of buffers
%if 0
		; RxDOS 7.20N:	I think this instruction should be commented.
		;
		;		Test: Leave it uncommented and verify after bootup if
		;		amount of buffers defined (BUFFERS=) is initialized,
		;		or if it's one buffer to less. If it's one to less
		;		most probably this instruction caused the trouble.
	dec cx
%endif
	mov dx, -1					; previous of first is invalid

RxDOS_CCBinit_10:
	lea ax, [ sizeCCB + di ]
	mov word [ es:di + ccbNext ], ax		; next
	mov word [ es:di + ccbPrev ], dx		; previous
	mov byte [ es:di + ccbDrive ], -1		; unitialized

	mov dx, di					; current becomes previous
	mov di, ax					; go to next
	loop RxDOS_CCBinit_10				; go to next -->

	mov di, dx					; at end set end marker
	mov word [ es:di + ccbNext ], -1		; next of last is invalid

	pop es
	pop ds
	retn


		; Allocate SFTs for StdIn and StdOut Devices
RxDOSini_StdInStdOutDrivers:

	push es
	push ds

		; Update system CON pointer to last driver with StdIn and StdOut bits
	mov ax, ( DEV_STDINPUT + DEV_STDOUTPUT )
	call init2_to_doscode, checkforDeviceType
	jc RxDOS_DRIVERinit_10

	mov word [ _RxDOS_pCONdriver + _pointer ], bx
	mov word [ _RxDOS_pCONdriver + _segment ], es

RxDOS_DRIVERinit_10:

		; Update system CLOCK pointer to last driver with Clock bit
	mov ax, ( DEV_CLOCK )
	call init2_to_doscode, checkforDeviceType
	jc RxDOS_DRIVERinit_12

	mov word [ _RxDOS_pCLOCKdriver + _pointer ], bx
	mov word [ _RxDOS_pCLOCKdriver + _segment ], es

		; allocate StdIn, StdOut, StdErr, StdAux, StdPrn
RxDOS_DRIVERinit_12:
	push ss
	pop ds
	mov di, stdDeviceAssignTable

RxDOS_DRIVERinit_14:
	push ss
	pop es
	call init2_to_doscode, checkforDeviceName	; locate device
	jc RxDOS_DRIVERinit_22				; if can't be located -->

	push bx
	push es						; save pointer to driver

	push di
	mov ax, word [ ss:di + stdIOHandle ]		; get assigned handle
	call init2_to_doscode, FindSFTbyHandle		; find SFT address (es:di)
	mov bx, di					; SFT address to bx
	pop di						; restore
	jc RxDOS_DRIVERinit_22				; if can't be located -->

	mov ax, word [ ss:di + stdDevInfo ]
	or ax, sftProtected				; can't close those
	mov word [ es:bx + sftDevInfo ], ax

	push di
	push bx
	mov cx, sizeFnName

RxDOS_DRIVERinit_16:
	mov al, byte [ ss:di + stdDriverName ]		; copy name
	mov byte [ es:bx + sftFileName ], al
	inc bx
	inc di
	loop RxDOS_DRIVERinit_16

	pop bx
	pop di
	pop word [ es:bx + sftDHD + _segment ]
	pop word [ es:bx + sftDHD + _pointer ]		; set pointer to device header
	inc word [ es:bx + sftRefCount ]		; bump use count

RxDOS_DRIVERinit_22:
	add di, byte sizeStdRedirec
	cmp word [ ss:di ], byte -1
	jnz RxDOS_DRIVERinit_14

	pop ds
	pop es
	retn


		; Initialize attached file system
		;
		; cl = number of blocked devices
		; dx = driver segment
InitializeAttachedFileSystem:

	xor ch, ch
	or cx, cx					; any devices declared ?
	jz Init_AttachedFileSystem_16			; none -->

	saveSegments di, si

	mov ax, sizeCDS
	mul byte [ _RxDOS_bNumBlockDev ]		; offset into CDS

	les di, [ _RxDOS_pCDS ]
	add di, ax					; pointer to first CDS

	mov ax, sizeDPB
	mul byte [ _RxDOS_bNumBlockDev ]		; offset into DPB
	lds si, [ _RxDOS_pDPB ]				; starting DPB address in ds:si
	add si, ax					; offset to drive
	xor ax, ax					; logical unit

Init_AttachedFileSystem_08:
	or word [ es:di + _cdsFlags ], _CDS_PHYSICALDRIVE
	mov word [ es:di + _cdsPtrToDPB + _pointer ], si
	mov word [ es:di + _cdsPtrToDPB + _segment ], ds

	mov byte [ _dpbUnit + si ], al
	mov byte [ _dpbAccessFlag + si ], -1		; never used before
	mov word [ _dpbptrDeviceDriver + _segment + si ], dx	; driver segment
	mov word [ _dpbptrDeviceDriver + _pointer + si ], 0

	inc ax
	add si, byte sizeDPB
	add di, byte sizeCDS
	loop Init_AttachedFileSystem_08

	restoreSegments si, di

Init_AttachedFileSystem_16:
	retn


		align 4
		; CONFIG Switches
F5_SkipConfigProcessing dw 0000				; non-zero if skipping
F8_PromptRequired	dw 0000				; non-zero if prompt required
init_verbose:		dw 1
init2_dosflags:		dw _DOSFLAGS_DEFAULT
init2_sfts:		dw _DEFAULT_SFTS
init2_cds:		dw _DEFAULT_CDS
init2_ccbs:		dw _DEFAULT_CCBS


init2_configtype_single:dw 1
.configtype:		dw 0
init2_configtype_anydevice:
			dw (.after - .first) / 2
.first:
			dw CONFIGTYPE_DEVICEHIGH
			dw CONFIGTYPE_DEVICE
.after:
init2_configtype_dos_dosdata_doscode_umb_uma_hma:
			dw (.after - .first) / 2
.first:
			dw CONFIGTYPE_DOS
			dw CONFIGTYPE_DOSCODE
			dw CONFIGTYPE_DOSDATA
			dw CONFIGTYPE_UMB
			dw CONFIGTYPE_UMA
			dw CONFIGTYPE_HMA
.after:


		; CONFIG.SYS keywords
_RxDOS_RXCONFIGSYS:	db "RXCONFIGSYS", 0
_RxDOS_ConfigFile:	db "CONFIG  SYS", 0

_RxDOS_ConfigKeywords:	dw CONFIGTYPE_BREAK
			db 'break', 0

			dw CONFIGTYPE_BUFFERS
			db 'buffers', 0

			dw CONFIGTYPE_COUNTRY
			db 'country', 0

			dw CONFIGTYPE_COMMENTS
			db 'comments', 0

			dw CONFIGTYPE_DEVICEHIGH
			db 'devicehigh', 0

			dw CONFIGTYPE_DEVICE
			db 'device', 0

			dw CONFIGTYPE_DOS
			db 'dos', 0

			dw CONFIGTYPE_DOSCODE
			db 'doscode', 0

			dw CONFIGTYPE_DOSDATA
			db 'dosdata', 0

			dw CONFIGTYPE_UMB
			db 'umb', 0

			dw CONFIGTYPE_UMA
			db 'uma', 0

			dw CONFIGTYPE_HMA
			db 'hma', 0

			dw CONFIGTYPE_DRIVPARAM
			db 'drivparm', 0

			dw CONFIGTYPE_FCBS
			db 'fcbs', 0

			dw CONFIGTYPE_FILES
			db 'files', 0

			dw CONFIGTYPE_INCLUDE
			db 'include', 0

			dw CONFIGTYPE_INSTALLHIGH
			db 'installhigh', 0

			dw CONFIGTYPE_INSTALL
			db 'install', 0

			dw CONFIGTYPE_LASTDRIVE
			db 'lastdrive', 0

			dw CONFIGTYPE_MENUCOLOR
			db 'menucolor', 0

			dw CONFIGTYPE_MENUDEFAULT
			db 'menudefault', 0

			dw CONFIGTYPE_MENUITEM
			db 'menuitem', 0

			dw CONFIGTYPE_MULTITRACK
			db 'multitrack', 0

			dw CONFIGTYPE_NUMLOCK
			db 'numlock', 0

			dw CONFIGTYPE_REM
			db 'rem', 0

			dw CONFIGTYPE_SET
			db 'set', 0

			dw CONFIGTYPE_SHELL
			db 'shell', 0

			dw CONFIGTYPE_STACKS
			db 'stacks', 0

			dw CONFIGTYPE_SUBMENU
			db 'submenu', 0

			dw CONFIGTYPE_SWITCHCHAR
			db 'switchar', 0

			dw CONFIGTYPE_SWITCHES
			db 'switches', 0

			dw -1, 0


		; DOS options
config_dos_options:
			dw DOSFLAGS_LINK_UMB
			db 'umb', 0

			dw DOSFLAGS_LINK_UMB
			db 'uma', 0

			dw ~ DOSFLAGS_LINK_UMB
			db 'noumb', 0

			dw ~ DOSFLAGS_LINK_UMB
			db 'nouma', 0


			dw DOSFLAGS_RELOCATE_DOSCODE_HMA
			db 'high', 0

			dw DOSFLAGS_RELOCATE_DOSCODE_HMA
			db 'hma', 0

			dw ~ DOSFLAGS_RELOCATE_DOSCODE_HMA
			db 'low', 0

			dw ~ DOSFLAGS_RELOCATE_DOSCODE_HMA
			db 'nohigh', 0

			dw ~ DOSFLAGS_RELOCATE_DOSCODE_HMA
			db 'nohma', 0

			dw -1, 0


		; DOSCODE options
config_doscode_options:
			dw DOSFLAGS_RELOCATE_DOSCODE_UMA
			db 'uma', 0

			dw ~ DOSFLAGS_RELOCATE_DOSCODE_UMA
			db 'nouma', 0

			dw DOSFLAGS_RELOCATE_DOSCODE_HMA
			db 'hma', 0

			dw ~ DOSFLAGS_RELOCATE_DOSCODE_HMA
			db 'nohma', 0

			dw -1, 0


		; DOSDATA options
config_dosdata_options:
			dw DOSFLAGS_RELOCATE_DOSDATA_UMA
			db 'uma', 0

			dw ~ DOSFLAGS_RELOCATE_DOSDATA_UMA
			db 'nouma', 0

			dw -1, 0


		; UMA options
config_uma_options:
			dw DOSFLAGS_RELOCATE_DOSDATA_UMA
			db 'dosdata', 0

			dw ~ DOSFLAGS_RELOCATE_DOSDATA_UMA
			db 'nodosdata', 0

			dw DOSFLAGS_RELOCATE_DOSCODE_UMA
			db 'doscode', 0

			dw ~ DOSFLAGS_RELOCATE_DOSCODE_UMA
			db 'nodoscode', 0

			dw DOSFLAGS_RELOCATE_ALL_UMA
			db 'all', 0

			dw ~ DOSFLAGS_RELOCATE_ALL_UMA
			db 'none', 0

			dw -1, 0


		; HMA options
config_hma_options:
			dw DOSFLAGS_RELOCATE_DOSCODE_HMA
			db 'doscode', 0

			dw ~ DOSFLAGS_RELOCATE_DOSCODE_HMA
			db 'nodoscode', 0

			dw DOSFLAGS_RELOCATE_ALL_HMA
			db 'all', 0

			dw ~ DOSFLAGS_RELOCATE_ALL_HMA
			db 'none', 0

			dw -1, 0


		; On/Off table
config_onoff_options:
			dw 1
			db 'on', 0

			dw 0
			db 'off', 0


			dw 1
			db 'enable', 0

			dw 0
			db 'disable', 0


			dw 1
			db '0', 0

			dw 0
			db '1', 0


			dw 1
			db 'yes', 0

			dw 0
			db 'no', 0

			dw 1
			db 'true', 0

			dw 0
			db 'false', 0

			dw -1, 0


		; Error Messages
msgUnknownCommandinConfig:	db 'Unrecognized command in config.sys', 0
msgProcessCommandYesNo:	db ' [y,n]?', 0

Config_MenuSelector:	db 'MENU', 0
Config_CommonSelector:	db 'COMMON', 0


		; Initialize
		;
		; INP:	cs = INIT2
		;	word [DOSDATA:dosdata_to_doscode_segment] = DOSCODE segment
		;	word [DOSENTRY:dosentry_to_dosdata_segment] = DOSDATA segment
		;	70h = DOSENTRY segment
		;	ip = 0
		;	cx = number of default block device's units (<= 32)
		;	word [INIT2:init2_to_init1_segment] = INIT1
RxDOS_initialize:
	cli						; disable interrupts
	cld						; set direction

	mov ax, 70h
	mov ds, ax
	mov ax, word [dosentry_to_dosdata_segment]
	mov ds, ax
	mov ss, ax
	mov sp, dosdata_stack + RXDOS_PERCALL_STACKRESERVE

	sti

		; initialize data segment
	Entry
	defbytes	execBlock, sizeEXEC

	mov ax, 0500h					; set page zero
	int 10h


		; compute number of block devices installed
	call init2_to_doscode, maxBlockDevices
	 push ss
	 pop ds
	mov byte [ _RxDOS_bNumBlockDev ], cl		; number of block devices

		; initialized environment size
	mov ax, _RxDOS_SharedBuffer
	mov word [ _RxDOS_pDTA + _pointer ], ax
	mov word [ _RxDOS_pDTA + _segment ], ds

		; initialize memory and other buffers
	call RxDOSini_DPBSubSystem
	call RxDOSini_CDSSubSystem

	mov ax, _DEFAULT_SFTS
	call RxDOSini_SFTSubSystem			; open CON, AUX, PRN

	mov ax, _DEFAULT_CCBS
	call RxDOSini_CCBSubSystem

	mov word [ _RxDOS_UserCodePage ], DEFAULT_CODEPAGE
	mov word [ _RxDOS_SystemCodePage ], DEFAULT_CODEPAGE

		; parse RXCONFIG.SYS file
	mov cl, S_INITCONFIG
	mov ax, 65535
	call init2_alloc_s_mcb_top

	push es
	call configProcessing				; process RXCONFIG.SYS file
	pop es
	xor di, di
	mov cx, 8000h
	xor ax, ax
	rep stosw					; discard this space
	mov ah, 49h
	int 21h

	d4bp
	 push ss
	 pop ds
	call RxDOSini_StdInStdOutDrivers		; initialize drivers

		; parse command line
	setDS cs
	setES ss

	mov ax, word [cs:init2_dosflags]
	call init2_relocate_device
	mov ax, word [cs:init2_dosflags]
	call init2_relocate_end

	push cs
	pop ds						; ds = INIT2
	push ss
	pop es						; es = DOSDATA / stack

	lea di, [ word _execBlock + bp ]
	clearMemory sizeEXEC				; clear load exec block

	mov word [ bp + _execBlock + lexecCommandTail + 2 ], cs
	mov word [ bp + _execBlock + lexecCommandTail ], init_msg.double_null
	mov al, ' '
	mov cx, 128
	mov di, _RxDOSini_CommandShell
	 push cs
	 pop es						; es = INIT2
	cmp byte [ es:di ], 0				; starts with a null character ?
	jz RxDOS_init_36				; yes, go do default -->

	cmp byte [ es:di ], al				; starts with a space ?
	jnz RxDOS_init_14				; no -->
	repz scasb					; scan for first non-space
	or cx, cx					; zero here would mean all spaces
	jz RxDOS_init_36				; yes, go do default -->
	dec di						; adjust address

RxDOS_init_14:
	push cx						; save start address
	push di						; save start address
	repnz scasb					; scan for space delimiter
	or cx, cx					; zero means no space delimeter
	jz RxDOS_init_24				; no arguments passed -->

	push cx
	dec di						; adj address
	mov si, di
	mov di, _RxDOSini_CommandTail			; command tail copy
	mov word [ _execBlock + lexecCommandTail + _segment + bp ], es
	mov word [ _execBlock + lexecCommandTail + _pointer + bp ], di

	inc di						; store address

RxDOS_init_18:
	lodsb
	stosb						; copy rest of line
	or al, al					; null terminator ?
	jz RxDOS_init_20				; no more than required -->
	loop RxDOS_init_18				; no more than required -->

RxDOS_init_20:
	mov ax, di
	sub ax, (_RxDOSini_CommandTail + 2)
	mov byte [ _RxDOSini_CommandTail ], al		; command tail length
	pop cx
	inc cx
	inc cx

		; load RxCMD and transfer control
RxDOS_init_24:
	pop si						; start of command area
	pop ax
	dec cx
	sub ax, cx
	xchg cx, ax
	mov di, _RxDOS_CommandShell
	repe movsb					; copy shell command/command line arguments

	push ss
	pop es						; es = DOSDATA / stack
	lea bx, [ word _execBlock + bp ]		; exec block address
	mov dx, _RxDOS_CommandShell
	call init_shell_verbose

	d4bp
	Int21 ExecuteProgram, 00			; execute custom user shell from RXCONFIG.SYS SHELL= statement
	call init_shell_verbose_error
	jnc RxDOS_init_68				; only branches if the main shell terminated

RxDOS_init_36:
	push ss
	pop es
	lea bx, [ word _execBlock + bp ]		; exec block address
	mov dx, _RxDOSini_DefaultShell
	call init_shell_verbose

	d4bp
	Int21 ExecuteProgram, 00			; if failed, execute default shell (RXCMD.EXE)
	call init_shell_verbose_error
	jnc RxDOS_init_68				; only branches if the main shell terminated
		; RxDOS 7.30: This should check the error code returned here.

	push ss
	pop es
	lea bx, [ word _execBlock + bp ]
	mov dx, _RxDOSini_DefaultShell
	mov word [ _RxDOSini_DefaultShellExt + 0 ], ".C"
	mov word [ _RxDOSini_DefaultShellExt + 2 ], "OM"; set .COM extension
	mov byte [ _RxDOSini_DefaultShellExt + 4 ], 0	; make sure it's zero
	call init_shell_verbose

	d4bp
	Int21 ExecuteProgram, 00			; if failed, execute default shell (RXCMD.COM)
	call init_shell_verbose_error
	jnc RxDOS_init_68				; only branches if the main shell terminated
		; RxDOS 7.30: This should check the error code returned here.

	push ss
	pop es
	lea bx, [ word _execBlock + bp ]
	mov dx, _RxDOSini_compatibilityshell
	call init_shell_verbose

	d4bp
	Int21 ExecuteProgram, 00			; if failed, execute compatibility shell (COMMAND.COM)
	call init_shell_verbose_error
	jnc RxDOS_init_68				; only branches if the main shell terminated

		; Display Error Message and stop
	push cs
	pop ds
	mov si, RxDOSmsg_CouldNotFindShell
	cmp ax, errFileNotFound
	jz RxDOS_init_62

	mov si, RxDOSmsg_InvalidPathShell
	cmp ax, errPathNotFound
	jz RxDOS_init_62

	mov si, RxDOSmsg_ArenaTrashedShell
	cmp ax, errArenaTrashed
	jz RxDOS_init_62

	mov si, RxDOSmsg_NotEnoughMemoryShell

RxDOS_init_62:
	call RxDOSIni_TypeMessage

		; Wait for Ctrl+Alt+Del
RxDOS_init_68:
	push cs
	pop ds
	mov si, init_msg.reboot_prompt
	call RxDOSIni_TypeMessage
.loop:
	d4bp
	xor ax, ax
	int 16h						; this allows Ctrl+Alt+Del
	jmp short .loop					; infinite loop


		; INP:	ds:dx -> ASCIZ shell to be loaded
		;	es:bx -> exec block
		; OUT:	-
		; CHG:	si
init_shell_verbose:
	push ds
	 push cs
	 pop ds
	cmp word [ init_verbose ], 0
	je .return
	 mov si, init_msg.loading_shell
	call RxDOSIni_TypeMessage
	pop ds
	push ds
	mov si, dx
	call RxDOSIni_TypeMessage
	 push cs
	 pop ds
	mov si, init_msg.loading_shell_arg
	call RxDOSIni_TypeMessage
	pop ds
	push ds
	lds si, [ es:bx + lexecCommandTail ]
	inc si
	call RxDOSIni_TypeMessage
	 push cs
	 pop ds
	mov si, init_msg.loading_shell_after
	call RxDOSIni_TypeMessage
.return:
	pop ds
	retn


		; INP:	CF = whether error
		;	CY if error,
		;	 ax = error code
		; OUT:	-
		; CHG:	si, bx
init_shell_verbose_error:
	push ds
	pushf
	push cs
	pop ds
	jnc .return
	cmp word [ init_verbose ], 0
	je .return
	mov si, init_msg.loaded_shell_error
	call RxDOSIni_TypeMessage
	call init_disp_ax_hex
	mov si, init_msg.loaded_shell_error_q
	call RxDOSIni_TypeMessage

	cmp ax, init_msg_errors.count
	jb .valid
	mov si, init_msg_errors.unknown_error
	jmp short .disp_error
.valid:
	mov bx, ax
	add bx, bx
	mov si, [ init_msg_errors + bx ]
.disp_error:
	call RxDOSIni_TypeMessage
	mov si, init_msg.linebreak
	call RxDOSIni_TypeMessage
.return:
	popf
	pop ds
	retn


		; INP:	ax = number
		; OUT:	-
		; CHG:	-
init_disp_ax_hex:		; ax
	xchg al,ah
	call init_disp_al_hex		; display former ah
	xchg al,ah			;  and fall trough for al
init_disp_al_hex:		; al
	push cx
	mov cl,4
	ror al,cl
	call init_disp_al_lownibble_hex	; display former high-nibble
	rol al,cl
	pop cx
					;  and fall trough for low-nibble
init_disp_al_lownibble_hex:
	push ax				; save ax for call return
	and al,00001111b		; high nibble must be zero
	add al,'0'			; if number is 0-9, now it's the correct character
	cmp al,'9'
	jna .decimalnum			; if we get decimal number with this, ok -->
	add al, - ('9' + 1) + 'A'	;  otherwise, adjust to our alphabet
 .decimalnum:
	call init_disp_al
	pop ax
	retn

		; INP:	al = character
		; OUT:	-
		; CHG:	-
init_disp_al:
%if 0
	push bx
	push ax
	push ax
	mov ah, 0Fh
	int 10h				; get video mode and active page
	pop ax
	mov ah, 0Eh
	mov bl, 07h
	push bp
	int 10h
	pop bp
	pop ax
	pop bx
%else
	int 29h
%endif
	retn


		; Type Message
		;
		; ds:si-> ASCIZ message
RxDOSIni_TypeMessage:

	push ax

RxDOSIni_TypeMessage_08:
	lodsb
	or al, al
	jz RxDOSIni_TypeMessage_12

	int 29h
	jmp short RxDOSIni_TypeMessage_08

RxDOSIni_TypeMessage_12:
	pop ax
	retn


		; Type CR, LF
RxDOSIni_TypeCR:

	push ax

	mov al, 13
	int 29h
	mov al, 10
	int 29h

	pop ax
	retn


		; Detect F8 during boot time
checkforF8:

	mov ah, 01h
	int 16h						; test for F8 keystroke
	jz checkforF8_exit				; if no character -->

	xor ax, ax
	int 16h						; get character
	cmp ax, 4200h					; F8 character ?
	jnz checkforF8					; eat character and look ahead -->

	mov word [ cs:F8_PromptRequired ], 0001

checkforF8_exit:
	cmp word [ cs:F8_PromptRequired ], byte 0000	; check flag
	retn


init_msg:
.loading_shell:		db "init: Loading shell ", '"', 0
.loading_shell_arg:	db '"', " arguments: ", '"', 0
.loading_shell_after:	db '"', 13, 10, 0
.loaded_shell_error:	db "init: Error ",0
.loaded_shell_error_q:	db "h: ",0
.linebreak:		db 13,10,0
.mcb_chain_corrupted_error:	asciz "init: Error, MCB chain corrupted.",13,10
.dpb_error_dev:		db "init: Error while walking DPB chain linking devices, last=",0
.dpb_error_cds:		db "init: Error while walking DPB chain linking CDS, last=",0
.devices_error:		db "init: Error while walking device chain linking devices, last=",0
.dpb_error_colon:
.devices_error_colon:	db "h:",0
.dpb_error_after:
.devices_error_after:	db "h.",13,10,0
.too_many_block_units:	db "init: Too many block device units, ignoring!",13,10,0
.reboot_prompt:		db "Halted. Press Ctrl+Alt+Del to reboot.",13,10
.double_null:		db 0,0

	align 2
init_msg_errors:
.:
	dw .no_error
	dw .invalid_function
	dw .file_not_found
	dw .path_not_found
	dw .no_handles_available
	dw .access_denied
	dw .invalid_handle
	dw .mcb_destroyed
	dw .insufficient_memory
	dw .mcb_invalid
	dw .environment_invalid
	dw .format_invalid
	dw .access_code_invalid
	dw .data_invalid
	dw .fixup_overflow
	dw .invalid_drive
	dw .attempted_to_remove_current_directory
	dw .not_same_device
	dw .no_more_files
.count equ ($ - .) / 2
.unknown_error:		db "Unknown error",0
.no_error:		db "No error",0
.invalid_function:	db "Invalid function",0
.file_not_found:	db "File not found",0
.path_not_found:	db "Path not found",0
.no_handles_available:	db "No handles available",0
.access_denied:		db "Access denied",0
.invalid_handle:	db "Invalid handle",0
.mcb_destroyed:		db "MCB destroyed",0
.insufficient_memory:	db "Insufficient memory",0
.mcb_invalid:		db "MCB invalid",0
.environment_invalid:	db "Environment invalid",0
.format_invalid:	db "Format invalid",0
.access_code_invalid:	db "Access code invalid",0
.data_invalid:		db "Data invalid",0
.fixup_overflow:	db "Fixup overflow",0
.invalid_drive:		db "Invalid drive",0
.attempted_to_remove_current_directory:		db "Attempted to remove current directory",0
.not_same_device:	db "Not same device",0
.no_more_files:		db "No more files",0


		; Error Message
RxDOSmsg_CouldNotFindShell:
	db 13,10,"Could not find command shell",13,10,0

RxDOSmsg_InvalidPathShell:
	db 13,10,"Invalid Path: Shell command line probably contains wrong path",13,10,0

RxDOSmsg_ArenaTrashedShell:
	db 13,10,"Arena trashed detected while loading command shell",13,10,0

RxDOSmsg_NotEnoughMemoryShell:
	db 13,10,"Not enough memory to load command shell",13,10,0

RxDOSmsg_CouldNotLoadDriver:
	db 13,10,"Could not load: ",0


		; Shell Name
	align 16, db 0
_RxDOS_CommandShell:
	times 128 db 0
_RxDOSini_CommandShell:
	times 128 db 0					; command shell
_RxDOSini_CommandTail:
	times 128 db 0					; command tail

_RxDOSini_DefaultShell:
	db "RXCMD"
_RxDOSini_DefaultShellExt:
	db ".EXE",0

_RxDOSini_compatibilityshell:
	db "COMMAND.COM",0


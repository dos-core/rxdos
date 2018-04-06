
%if 0

RxDOSDEV - RxDOS device interface and search functions

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

(c) Copyright 1990, 1999. Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

%if 0

Developer's Comments

-- mikep 09/08/98 ----------------
Although FAT32 has been added, what we really need is to
reorganize the code into a file system architecture. We
should create a VTBL that points to different file systems.

We'll add that in December when we have more time to test.


cm: (2008-07-07)

Unfortunately there was never a December version.

%endif

%include "RXDMACRO.NEW"
%include "RXDSTRUC.NEW"

	cpu 8086

%if _BUILD_OBJ
	segment RXDOS align=16 class=RXDOS use16 public
	segment RXDOS

	global checkforDeviceType
	global checkforDeviceName
	global maxBlockDevices
	global DevMediaRequest
	global DevRemovableRequest
	global DevRead
	global DevWrite
	global devCharRead
	global devCharWrite
	global devCharReadLine
	global devCharWriteLine
	global initReqBlock
	global BlockedDevRequest
	global getDPB
	global getAddrDPB
	global DefineDPB
	global incorrectDiskMedia

	global getSysDate
	global setSysDate
	global getExpandedDateTime
	global getExpandedDate

	global readConsoleIn
	global writeConsoleOut
	global CharDevRequest
	global _callCriticalError
	global validate_address

	extern _bitShiftTable
	extern sizeShiftTable
	extern _RxDOS_bLastDrive
	extern _RxDOS_NULLDev
	extern _RxDOS_pCDS
	extern _RxDOS_pCLOCKdriver
	extern _RxDOS_pCONdriver
	extern _RxDOS_Verify
	extern _RxDOS_AbortInProgress
	extern _RxDOS_StackLongJump

	extern _RxDOS_CurrentInstance
	extern _RxDOS_INDOSFlag
	extern _RxDOS_CurrentPSP
	extern SDAInt24_SPSave

	extern _mul32
	extern _div32

	extern saveStackFrame
	extern _RetCallersStackFrame
	extern updateAllChangedCCBBuffers
	extern invalidateBuffers

	extern AmountFreeSpace
	extern _TerminateProcess
	extern getSysDateinDirFormat
%endif

		; Default StdIn Access
		;
		; Input:
		; es:bx	buffer address.
		; cx	length.
readConsoleIn:

	or cx, cx
	jz readConsoleIn_08

	xor dx, dx
	mov di, bx
	push word [ ss:_RxDOS_pCONdriver + _segment ]
	push word [ ss:_RxDOS_pCONdriver + _pointer ]
	call devCharReadLine				; read til cr or eof

readConsoleIn_08:
	retn


		; Default Stdout Access
		;
		; Input:
		; es:bx	buffer address.
		; cx	length.
writeConsoleOut:

	or cx, cx
	jz writeConsoleOut_08

	mov di, bx
	push word [ ss:_RxDOS_pCONdriver + _segment ]
	push word [ ss:_RxDOS_pCONdriver + _pointer ]
	call devCharWrite

writeConsoleOut_08:
	retn


		; Locate Device Driver By Type
		;
		; Input:
		; ax	type to match.	must match all bits set.
		;
		; Output:
		; es:bx	pointer to driver header block
checkforDeviceType:

	push es
	currSegment es					; point to NULL device
	mov bx, _RxDOS_NULLDev				; get start of chain

chkDevType_08:
	cmp bx, byte -1					; end of list ?
	stc						; set error
	jz chkDevType_16				; if end of list -->

	mov cx, word [ es:devAttributes + bx ]
	and cx, ax					; strip away only mask bits 
	cmp cx, ax					; all bits match ?
	jnz chkDevType_14				; no, go to next -->

	add sp, byte 2					; pop old es:
	push es						; save current es: for return
	jmp short chkDevType_16				; return -->

chkDevType_14:
	les bx, [ es:devLink + bx ]
	jmp short chkDevType_08				; go to next ->

chkDevType_16:
	pop es
	retn


		; Locate Device Driver By Name
		;
		; Input:
		; es:di	name to match.	character devices only.
		;
		; Output:
		; es:bx	pointer to driver header block
		; cy	driver was not located
checkforDeviceName:

	Entry
	defbytes	tempdevname, sizedevName

	push ds
	push di
	push si
	push es


		; init by creating a blank filled upper case mask
	mov si, di
	lea di, [ byte _tempdevname + bp ]
	mov cx, sizedevName

chkDevName_08:
	mov al, byte [ es:si ]
	_upperCase al

	cmp al, ' ' + 1					; null or special character ?
	jb chkDevName_12

	cmp al, ':'					; colon ?
	jz chkDevName_12

	mov byte [ ss:di ], al				; store character
	inc si
	inc di
	loop chkDevName_08

chkDevName_12:
	or cx, cx
	jz chkDevName_14

	mov byte [ ss:di ], ' '				; blank fill
	inc di
	loop chkDevName_08


		; match against all known driver names
chkDevName_14:
	setds ss	
	currSegment es
	mov bx, _RxDOS_NULLDev			; get start of chain

chkDevName_20:
	cmp bx, byte -1					; end of list ?
	stc						; set error
	jz chkDevName_26				; if end of list -->

	test word [ es:devAttributes + bx ], ( DEV_CHAR )
	jz chkDevName_24				; not a character device ->

	lea si, [ byte _tempdevname + bp ]
	lea di, [ byte devName + bx ]
	mov cx, sizedevName
	repz cmpsb					; compare names
	jnz chkDevName_24				; if not equal, go to next -->

	clc						; no carry means we have a valid device
	pop si						; remove old es:
	push es						; return this es:
	jmp short chkDevName_26

chkDevName_24:
	les bx, [ es:devLink + bx ]
	jmp short chkDevName_20				; go to next ->


		; return
chkDevName_26:
	pop es
	pop si
	pop di
	pop ds
	Return


		; Locate Blocked Devices
		;
		; Input:
		; al	drive
		;
		; Output:
		; dx:cx	pointer to driver header block
findInstalledBlockDevice:

	Entry
	def	drive, ax

	push es
	push bx
	call maxBlockDevices				; get number of blocked devices

	currSegment es
	mov bx, _RxDOS_NULLDev				; get start of chain
	getarg ax, _drive

findBlockedDev_08:
	cmp bx, byte -1					; end of list ?
	stc						; set error
	jz findBlockedDev_16				; if end of list -->

	test word [ es:devAttributes + bx ], ( DEV_CHAR )
	jnz findBlockedDev_14				; if a character device -->

	sub cl, byte [ es:bx + devUnits ]		; # units supported
	cmp al, cl					; compare against drive code
	jb findBlockedDev_14				; if not device of interest -->

	or ax, ax					; clear carry
	jmp short findBlockedDev_16			; return -->

findBlockedDev_14:
	les bx, [ es:devLink + bx ]
	jmp short findBlockedDev_08			; go to next ->

findBlockedDev_16:
	mov cx, es
	mov dx, bx
	getarg ax, _drive
	pop bx
	pop es
	Return


		; Report Max Block Devices Available
		;
		; Output:
		; cx	number of blocked devices
maxBlockDevices:

	push es
	currSegment es
	mov bx, _RxDOS_NULLDev		; get start of chain
	xor cx, cx			; # blocked devices

.08:
	cmp bx, byte -1			; end of list ?
	jz .16				; if end of list -->

	test word [ es:bx + devAttributes ], ( DEV_CHAR )
	jnz .14				; if a character device -->
	add cl, byte [ es:bx + devName ]
	jc .max
	cmp cl, 32
	ja .max

.14:
	les bx, [ es:bx + devLink ]
	jmp short .08			; go to next ->

.max:
	mov cl, 32
.16:
	pop es
	retn


		; Driver Media Request
		;
		; Input:
		; al	drive to check
		; ah	media type expected
		; ss:bx	ptr for volume id return value
		; 	(value set only if line changed)

		; Output:
		; cy	if abort/ not ready

		; ax	original drive info
		; ch	new media type
		; cl	if changed flags
DevMediaRequest:

	Entry
	def	drive, ax
	def	ptrVolumeID, bx				; ss:
	defbytes	reqBlock, sizeMaxReqHeader

	SaveRegisters es, di, bx, ax

	mov ah, MEDIAREQUEST
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock

	mov byte [ _reqBlock + mrMediaID + bp ], ah
	mov byte [ _reqBlock + mrLength + bp ], sizeMEDIAReqHeader
	mov byte [ _reqBlock + mrFunction + bp ], MEDIAREQUEST
	getarg ax, _drive				; restore drive
	call BlockedDevRequest				; call blocked device

	mov bx, word [ _ptrVolumeID + bp ]
	mov ax, word [ _reqBlock + mrVolumeID + _low + bp ]
	mov cx, word [ _reqBlock + mrVolumeID + _high + bp ]
	mov word [ ss:_low + bx ], ax
	mov word [ ss:_high + bx ], cx

	mov ch, byte [ _reqBlock + mrMediaID + bp ]
	mov cl, byte [ _reqBlock + mrReturn + bp ]

	RestoreRegisters ax, bx, di, es
	Return


		; Incorrect Disk Media
		;
		; Input:
		; ax	drive
		; cx:dx	serial number required
		;
		; Output:
		; CY	if abort/not ready
		; ax	original drive info
incorrectDiskMedia:

	Entry
	defbytes	devVolumeId, sizeVolumeID
	defbytes	reqBlock, sizeMaxReqHeader

	mov ah, MEDIAREQUEST
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock

	mov ax, devErrInvalidDiskChange
	lea bx, [ byte _reqBlock + bp ]
	call _callCriticalError
	Return


		; Driver Removable Request
		;
		; Input:
		; al	drive to check
		;
		; Output:
		; CY	if abort/ not ready
		;
		; ax	original drive info
		; cl	0000 removable/ 0001 if fixed drive
DevRemovableRequest:

	Entry
	def	drive, ax
	defbytes	reqBlock, sizeMaxReqHeader

	SaveRegisters es, di, bx, ax

	mov ah, REMOVABLEMEDIA
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock

	getarg ax, _drive				; restore drive
	mov byte [ _reqBlock + rhLength + bp ], sizeDEVReqHeader
	call BlockedDevRequest				; call blocked device

	mov cx, word [ _reqBlock + rhStatus + bp ]
	and cx, OP_BUSY
	jz DevRemovableRequest_12
	mov cx, 1

DevRemovableRequest_12:
	RestoreRegisters ax, bx, di, es
	Return


		; Driver READ
		;
		; Input:
		; al	drive
		; bx	# sectors to read
		; cx:dx	starting sector address to read
		; es:di	buffer to read (buffer address cannot wrap-around)

		; Output:
		; cy	if abort/ not ready
DevRead:

	Entry
	def	drive, ax
	def	sectors, bx
	ddef	bufferPtr, es, di
	ddef	sector, cx, dx
	defbytes	volumeID, sizevolumeLabel
	defbytes	reqBlock, sizeMaxReqHeader

	SaveRegisters es, di, bx, ax

	call getAddrDPB					; (es:bx) Device Parameter Block
	jc DevRead_16					; if invalid drive -->

	push word [ es:bx + _dpbMediaDescriptor ]

	mov ah, DEVICEREAD
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock

	getarg ax, _sectors
	mov word [ _reqBlock + rwrBytesReq + bp ], ax

	pop ax						; media descriptor
	mov byte [ _reqBlock + rwrMediaID + bp ], al

	mov dx, word [ _bufferPtr + _segment + bp ]
	mov ax, word [ _bufferPtr + _pointer + bp ]
	mov word [ _reqBlock + rwrBuffer + _segment + bp ], dx
	mov word [ _reqBlock + rwrBuffer + _pointer + bp ], ax

	lea di, [ byte _volumeID + bp ]
	mov word [ _reqBlock + rwrVolumeID + _pointer + bp ], di
	mov word [ _reqBlock + rwrVolumeID + _segment + bp ], ss


		; if address is huge, store in huge request area
	getdarg cx, dx, _sector
	jcxz DevRead_08					; skip if no huge address -->

	mov word [ _reqBlock + rwrHugeStartSec + _high + bp ], cx
	mov word [ _reqBlock + rwrHugeStartSec + _low + bp ], dx
	mov dx, -1

DevRead_08:
	mov word [ _reqBlock + rwrStartSec + bp ], dx	; sector (or -1 if huge)
	getarg ax, _drive				; restore drive
	call BlockedDevRequest				; call blocked device

DevRead_16:
	RestoreRegisters ax, bx, di, es
	Return


		; Driver CHAR READ LINE
		;
		; Reads until CR or end of buffer
		;
		; Input:
		; cx	characters to read
		; dx	max characters in buffer to echo/ backup
		; es:di	buffer to read
		; stack	driver to read from
		;
		; Output:
		; cx	characters actually returned
		; zr	if end of file
devCharReadLine:
DevCharReadLine:

	Entry 2
	darg	device

	def	maxread, cx
	def	backupbytes, dx
	def	updatedBuffers, FALSE
	ddef	clockticks	
	ddef	bufferPtr, es, di
	defbytes	tempBuffer, 8
	defbytes	lineEdit, sizeLINEEDITOR
	defbytes	reqBlock, sizeMaxReqHeader

	setds ss
	SaveRegisters es, di, bx

	mov al, -1					; not a block device
	mov ah, NONDESTRREAD
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock				; (returns es:bx request block)

	call ClockTimer					; dx: ax
	stordarg _clockticks, dx, ax

	setds ss
	getarg cx, _maxread
	getdarg dx, ax, _bufferPtr
	lea di, [ byte _lineEdit + bp ]
	call _lineEditorInit				; init line editor control block

	getarg dx, _backupbytes	
	mov word [ ss:editTemplateCharsAvailable + di ], dx


		; init block
	lea di, [ byte _tempBuffer + bp ]
	mov word [ _reqBlock + rwrBuffer + _segment + bp ], ss
	mov word [ _reqBlock + rwrBuffer + _pointer + bp ], di
	mov word [ _reqBlock + rwrBytesReq + bp ], 1


		; wait for character
DevCharReadLine_12:
	setes ss
	lea bx, [ byte _reqBlock + bp ]

	mov byte [ ss:bx + rwrFunction ], NONDESTRREAD
	mov word [ ss:bx + rwrStatus ], 0

	push word [ _device + _segment + bp ]
	push word [ _device + _pointer + bp ]
	call CharDevRequest				; test for character

	test word [ _reqBlock + rwrStatus + bp ], OP_DONE
	jz DevCharReadLine_16				; time out -->
	test word [ _reqBlock + rwrStatus + bp ], OP_BUSY
	jz DevCharReadLine_20				; we have a character -->

DevCharReadLine_16:
	cmp word [ _updatedBuffers + bp ], byte TRUE	; already updated buffers ?
	jz DevCharReadLine_18				; skip around -->
	call updateAllChangedCCBBuffers			; optimized update changed CCBs
	mov word [ _updatedBuffers + bp ], TRUE		; already updated buffers !

DevCharReadLine_18:
	int intIDLELOOP					; let other applications run
	jmp short DevCharReadLine_12			; continue looping -->


		; get character, see if end of buffer or CR
DevCharReadLine_20:
	mov byte [ ss:bx + rwrFunction ], DEVICEREAD

	push word [ _device + _segment + bp ]
	push word [ _device + _pointer + bp ]
	call CharDevRequest				; get character

	mov ax, word [ _tempBuffer + bp ]		; get character
	or al, al					; is it an extended char ?
	jz DevCharReadLine_22				; yes -->
	mov ah, 0					; else clearly pad fill with null

DevCharReadLine_22:
	lea di, [ byte _lineEdit + bp ]
	call _lineEditor				; store character/ line editor

	cmp ax, byte ControlC				; Ctrl-C ?
	jz DevCharReadLine_36				; yes -->
	cmp ax, byte ControlM				; return character ?
	jz DevCharReadLine_36				; yes -->

	mov cx, word [ ss:editMaxAvail + di ]		; get max chars
	cmp cx, word [ ss:editMaxBuffer + di ]		; at max end of line ?
	jb DevCharReadLine_12				; else, continue -->


		; exit
DevCharReadLine_36:
	getdarg es, di, _bufferPtr
	mov cx, word [ _lineEdit + editMaxAvail + bp ] ; get chars entered
	cmp ax, byte ControlC				; Ctrl-C ?
	clc

	RestoreRegisters bx, di, es
	Return


		; Driver CHAR READ
		;
		; Input:
		; cx	characters to read
		; es:di	buffer to read
		; stack	driver to read from
		;
		; Output:
		; cx	characters actually read
devCharRead:
DevCharRead:

	Entry 2
	darg	device

	def	count, cx
	ddef	bufferPtr, es, di
	defbytes	reqBlock, sizeMaxReqHeader

	push bx
	push ax

	mov al, -1					; not a block device
	mov ah, IOCTLREAD
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock

	mov dx, word [ _bufferPtr + _segment + bp ]
	mov ax, word [ _bufferPtr + _pointer + bp ]
	mov word [ _reqBlock + rwrBuffer + _segment + bp ], dx
	mov word [ _reqBlock + rwrBuffer + _pointer + bp ], ax

	getarg cx, _count
	mov word [ _reqBlock + rwrBytesReq + bp ], cx

	push word [ _device + _segment + bp ]
	push word [ _device + _pointer + bp ]
	call CharDevRequest				; call device (get character)

	mov cx, word [ _reqBlock + rwrBytesReq + bp ]	; actual bytes read
	getdarg es, di, _bufferPtr			; restore es:di

	pop ax
	pop bx
	Return


		; Driver WRITE or WRITE/VERIFY
		;
		; Input:
		; al	drive to write to
		; bx	# sectors to write
		; cx:dx	starting sector address where to write
		; es:di	buffer to write (buffer address cannot wrap-around)
		;
		; Output:
		; CY	if abort/not ready
DevWrite:

	Entry
	def	drive, ax
	def	sectors, bx
	ddef	bufferPtr, es, di
	ddef	sector, cx, dx
	defbytes	volumeID, sizevolumeLabel
	defbytes	reqBlock, sizeMaxReqHeader


		; ok to write
	SaveRegisters es, di, bx, ax

DevWrite_02:
	call getAddrDPB					; (es:bx) Device Parameter Block
	jc DevWrite_36					; if invalid drive -->

	push word [ es:bx + _dpbMediaDescriptor ]

	mov ah, DEVICEWRITE
	cmp byte [ ss:_RxDOS_Verify ], 0		; non-zero means verify
	je DevWrite_06					; if not verify -->
	mov ah, DEVICEWRITEVERIFY			; if verify writes

DevWrite_06:
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock				; al contains [logical unit]

	getarg ax, _sectors
	mov word [ _reqBlock + rwrBytesReq + bp ], ax

	pop ax						; media descriptor
	mov byte [ _reqBlock + rwrMediaID + bp ], al

	mov dx, word [ _bufferPtr + _segment + bp ]
	mov ax, word [ _bufferPtr + _pointer + bp ]
	mov word [ _reqBlock + rwrBuffer + _segment + bp ], dx
	mov word [ _reqBlock + rwrBuffer + _pointer + bp ], ax

	lea di, [ byte _volumeID + bp ]
	mov word [ _reqBlock + rwrVolumeID + _pointer + bp ], di
	mov word [ _reqBlock + rwrVolumeID + _segment + bp ], ss


		; if address is huge, store in huge request area
	getdarg cx, dx, _sector
	jcxz DevWrite_08				; skip if no huge address -->

	mov word [ _reqBlock + rwrHugeStartSec + _high + bp ], cx
	mov word [ _reqBlock + rwrHugeStartSec + _low + bp ], dx
	mov dx, -1

DevWrite_08:
	getarg ax, _drive				; restore drive
	mov word [ _reqBlock + rwrStartSec + bp ], dx

	call BlockedDevRequest				; call blocked device

DevWrite_36:
	RestoreRegisters ax, bx, di, es
	Return


		; Driver CHAR WRITE
		;
		; Input:
		; cx	characters to write
		; es:di	buffer to write
		; stack	driver address to write to
		;
		; Output:
		; cy	if abort/not ready
devCharWrite:
DevCharWrite:
devCharWriteLine:
DevCharWriteLine:				; intentional alias

	Entry 2
	darg	device

	def	count, cx
	ddef	bufferPtr, es, di
	defbytes	volumeID, sizevolumeLabel
	defbytes	reqBlock, sizeMaxReqHeader

	push es
	push bx
	push di
	push ax

	mov al, -1					; not a block device
	mov ah, DEVICEWRITE
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock

	mov dx, word [ _bufferPtr + _segment + bp ]
	mov ax, word [ _bufferPtr + _pointer + bp ]
	mov word [ _reqBlock + rwrBuffer + _segment + bp ], dx
	mov word [ _reqBlock + rwrBuffer + _pointer + bp ], ax

	lea di, [ byte _volumeID + bp ]
	mov word [ _reqBlock + rwrVolumeID + _pointer + bp ], di
	mov word [ _reqBlock + rwrVolumeID + _segment + bp ], ss

	getarg cx, _count
	mov word [ _reqBlock + rwrBytesReq + bp ], cx

	push word [ _device + _segment + bp ]
	push word [ _device + _pointer + bp ]
	call CharDevRequest				; call device

	getarg cx, _count				; assume written
	pop ax
	pop di
	pop bx
	pop es
	Return


		; Get System Date and Time
		;
		; Usage:
		; es:di	points to date structure
getSysDate:

	Entry
	defbytes	reqBlock, sizeMaxReqHeader

	saveRegisters es, di, dx, cx

	push es
	push di

	mov al, -1					; not a block device
	mov ah, DEVICEREAD
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock

	mov word [ _reqBlock + rwrBytesReq + bp ], sizeCLOCKDATA
	pop word [ _reqBlock + rwrBuffer + _pointer + bp ]	; di
	pop word [ _reqBlock + rwrBuffer + _segment + bp ]	; es

	push word [ _RxDOS_pCLOCKdriver + _segment ]
	push word [ _RxDOS_pCLOCKdriver + _pointer ]
	call CharDevRequest

	restoreRegisters cx, dx, di, es
	Return


		; Set System Date and Time
		;
		; Usage:
		; es:di	points to date structure
setSysDate:

	Entry
	defbytes	reqBlock, sizeMaxReqHeader

	saveRegisters es, di, dx, cx

	push es
	push di

	mov al, -1					; not a block device
	mov ah, DEVICEWRITE
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock

	mov word [ _reqBlock + rwrBytesReq + bp ], sizeCLOCKDATA
	pop word [ _reqBlock + rwrBuffer + _pointer + bp ]	; di
	pop word [ _reqBlock + rwrBuffer + _segment + bp ]	; es

	push word [ _RxDOS_pCLOCKdriver + _segment ]
	push word [ _RxDOS_pCLOCKdriver + _pointer ]
	call CharDevRequest

	restoreRegisters cx, dx, di, es
	Return


		; Get Days/Time From Bios
		;
		; Output:
		; ch	hours
		; cl	minutes
		; dh	seconds
		; dl	hundredths of seconds
getExpandedDateTime:

	Entry
	defbytes	datedef, sizeCLOCKDATA

	saveRegisters es, di

	setes ss
	lea di, [ byte _datedef + bp ]
	call getSysDate					; get system date

	mov cx, word [ _datedef + cl_minutes + bp ]
	mov dx, word [ _datedef + cl_hseconds + bp ]
	mov ax, word [ _datedef + cl_daysSince1980 + bp ]

	restoreRegisters di, es
	Return


		; Get Date From Bios
		;
		; Output:
		; dh	month
		; dl	day
		; cx	year
getExpandedDate:

	Entry
	defbytes	datedef, sizeCLOCKDATA

	saveRegisters es, di

	setES ss
	lea di, [ byte _datedef + bp ]
	call getSysDate					; get system date

	mov dl, byte [ bp + _datedef + cl_day ]
	mov dh, byte [ bp + _datedef + cl_month ]
	mov cx, word [ bp + _datedef + cl_year ]
	mov ax, word [ bp + _datedef + cl_daysSince1980 ]

	restoreRegisters di, es
	Return


		; Call character device
		;
		; Input:
		; es:bx-> request block
		; stack-> device
		;
		; Output:
		; CY if abort requested on Int24 error
CharDevRequest:

	entry 2
	darg	device

	ddef	strategy
	ddef	interrupt
	ddef	packet, es, bx

	saveSegments bp, bx, ax

	getdarg es, bx, _device				; get device
	mov ax, es
	or ax, bx					; if no device address
	jz CharDevRequest_12				; error exit -->

	mov ax, word [ es:bx + devStrategy ]
	stordarg _strategy, es, ax

	mov ax, word [ es:bx + devInterrupt ]
	stordarg _interrupt, es, ax

	push ds
	push bp
	getdarg es, bx, _packet
	mov ds, word [ _strategy + _segment + bp ]
	call far [ _strategy + bp ]			; strategy

	pop bp
	push bp
	getdarg es, bx, _packet
	mov ds, word [ _strategy + _segment + bp ]
	call far [ _interrupt + bp ]			; interrupt
	pop bp
	pop ds

	getdarg es, bx, _packet
	cmp word [ es:bx + mrStatus ], byte 0
	je CharDevRequest_12
	test word [ es:bx + mrStatus ], OP_ERROR
	jz CharDevRequest_16				; (NC) -->

		; time out, other error exit
CharDevRequest_12:
	stc

		; exit
CharDevRequest_16:
	restoreSegments ax, bx, bp
	Return


		; Call block device
		;
		; Input:
		; al = drive unit
		; es:bx-> request block
		;
		; Output:
		; CY if abort requested on Int24 error
BlockedDevRequest:

	Entry
	def	drive, ax
	def	sectors
	def	sectorsRead
	ddef	strategy
	ddef	interrupt
	ddef	packet, es, bx

	saveSegments bp, bx, ax

	mov cx, word [ es:bx + rwrBytesReq ]
	storarg _sectors, cx				; sectors

	call getAddrDPB					; (es:bx) Device Parameter Block
	ifc BlockedDevRequest_28			; no device info -->
	
	les bx, [ es:bx + _dpbptrDeviceDriver ]

	push es
	push bx
%if _VERIFYDEV
	call validate_device
%else
	call validate_address
%endif
	ifc BlockedDevRequest_28			; invalid device address -->

	mov ax, word [ es:bx + devStrategy ]
	stordarg _strategy, es, ax

	mov ax, word [ es:bx + devInterrupt ]
	stordarg _interrupt, es, ax

BlockedDevRequest_06:
	getarg ax, _sectors
	getdarg es, bx, _packet				; restore packet address
	mov word [ es:bx + rwrBytesReq ], ax		; bytes request 
	mov word [ es:bx + rhStatus ], 0		; (kill prev error code)

	push ds
	push bp
	mov ds, word [ bp + _strategy + _segment ]
	call far [ bp + _strategy ]			; strategy

	pop bp
	push bp
	getdarg es, bx, _packet

	mov ds, word [ bp + _strategy + _segment ]
	call far [ bp + _interrupt ]			; interrupt

	pop bp
	pop ds

	getdarg es, bx, _packet				; restore packet address
	mov cx, word [ es:bx + rwrBytesReq ]		; actual sectors read
	storarg _sectorsRead, cx			; sectors read

	cmp word [ es:bx + rhStatus ], byte 0
	jz BlockedDevRequest_08
	test word [ es:bx + rhStatus ], OP_ERROR
	jz BlockedDevRequest_32


		; Abort, Retry, Ignore ?
BlockedDevRequest_08:
	cmp word [ ss:_RxDOS_AbortInProgress ], byte 0	; already in critical error ?
	jnz BlockedDevRequest_28			; ignore error --> (fail)

	mov ax, word [ es:bx + rhStatus ]		; get error report
	call _callCriticalError				; switch context stack

	goto CRITERROR_TERMINATE, BlockedDevRequest_24
	goto CRITERROR_IGNORE	, BlockedDevRequest_32
	goto CRITERROR_FAIL	, BlockedDevRequest_28
	goto CRITERROR_RETRY	, BlockedDevRequest_20
	jmp short BlockedDevRequest_28


		; retry
BlockedDevRequest_20:
	SaveAllRegisters
%if _386
	movzx ax, byte [ _drive + bp ]			; get drive letter
%else
	xor ax, ax
	mov al, byte [ _drive + bp ]			; get drive letter
%endif
	call getDPB					; check for drive change/invalid buffers
	RestoreAllRegisters				; restore registers
	jmp BlockedDevRequest_06


		; terminate application
BlockedDevRequest_24:
	xor ax, ax
	call _TerminateProcess				; terminate curr process

	cli
	mov ax, word [ ss:_RxDOS_StackLongJump ]
	dec ax
	dec ax

	mov sp, ax					; cancel stack, return
	xor ax, ax					; NC
	sti
	retn						; returns to the Int21 dispatcher

		; exit
BlockedDevRequest_28:
	stc

BlockedDevRequest_32:
	getarg cx, _sectorsRead				; sectors read
	restoreSegments ax, bx, bp
	Return


%if _VERIFYDEV
		; INP:	dwo:stack-> device header
		; OUT:	CY if it isn't a (linked) device
		;	NC if it's a linked device,
		;	 ZR if it's a block device
		;	 NZ if it's a character device
validate_device:

	entry 2
	darg address
	push ds
	push ax
	push bx

	setds ss
	mov bx, _RxDOS_NULLDev				; first device is NUL

.loop:
	cmp bx, [ bp + _address + _pointer ]		; pointer matches ?
	jne .nextdevice					; no -->
	mov ax, ds
	cmp ax, [ bp + _address + _segment ]		; segment matches ?
	jne .nextdevice					; no -->
	test byte [ bx + devAttributes + 1 ], DEV_CHAR <<8 ; test if it's a character device (sets NC)
	jmp short .return

.nextdevice:
	lds bx, [ bx + devNext ]			; link to next
	push ds
	push bx
	call validate_address				; valid ?
	jnc .loop					; yes, then compare next -->
	stc						; no, not a linked device
.return:
	pop bx
	pop ax
	pop ds
	return
%endif

		; INP:	dwo:stack = address
		; OUT:	CY if invalid address (segment 0000h or 0FFFFh; or pointer 0FFFFh)
		;	NC if valid address
validate_address:

	entry 2
	darg address
	push ax
	stc						; assume invalid

	mov ax, [ bp + _address + _pointer ]
	inc ax
	jz .return					; was 0FFFFh -->

	mov ax, [ bp + _address + _segment ]
	inc ax
	jz .return					; was 0FFFFh -->
	dec ax
	jz .return					; was 0000h -->

	clc						; is valid
.return:
	pop ax
	return


		; Init request block
		;
		; Input:
		; al = drive (-1 if char device)
		; ah = device function request header is to be used for
		; (unused) cx = bytes requested
		; ss:di-> request block on stack, size at least sizeMaxReqHeader
		;
		; Output:
		; es:bx-> request block
		;
		; CHG:	cx
initReqBlock:

	push ax						; drive
	cmp al, -1					; character device ?
	jz initReqBlock_08				; yes, skip address -->
	call getAddrDPB					; get address of DOS Parameter Block
	mov al, [ es:bx + _dpbUnit ]			; get unit 

initReqBlock_08:
	push ax						; save unit
	push di

	setes ss	
	xor al, al
	mov cx, sizeMaxReqHeader
	repz stosb					; init request block

	pop di
	mov al, sizeMaxReqHeader			; if unknown function, use maximal length
	cmp ah, sizeDevDefaultLength
	jnc initReqBlock_12

%if _386
	movzx bx, ah					; get index into devDefaultLength table
%else
	mov bl, ah					; get index into devDefaultLength table
	xor bh, bh
%endif
	mov al, byte [ ss:bx + devDefaultLength ]	; retrieve length of request header

initReqBlock_12:
	mov byte [ es:di + rhLength ], al		; set length of request header

	setes ss
	pop ax						; unit
	cmp al, -1					; character device ?
	jnz initReqBlock_16				; no -->
	xor al, al					; set unit to 00

initReqBlock_16:
	mov byte [ es:di + rwrUnit ], al		; set unit
	mov byte [ es:di + rwrFunction ], ah		; set function
	mov bx, di
	pop ax						; restore drive
	retn


		; default length table
devDefaultLength:
	db sizeMaxReqHeader				; device init
	db sizeMEDIAReqHeader				; media request
	db sizeBUILDBPBReqHeader			; build dpb
	db sizeMaxReqHeader				; ioctl read
	db sizeREADReqHeader				; device read
	db sizeREADReqHeader				; non destr read
	db sizeMaxReqHeader				; input status
	db sizeMaxReqHeader				; input flush
	db sizeMaxReqHeader				; device write
	db sizeMaxReqHeader				; device write verify
	db sizeMaxReqHeader				; output status
	db sizeMaxReqHeader				; output flush
	db sizeMaxReqHeader				; ioctl write
	db sizeMaxReqHeader				; open device 
	db sizeMaxReqHeader				; close device 
	db sizeMaxReqHeader				; removable media
	db sizeMaxReqHeader				; output till busy
	db sizeMaxReqHeader				; generic ioctl
	db sizeMaxReqHeader				; get logical device
	db sizeMaxReqHeader				; set logical device
	db sizeMaxReqHeader				; ioctl query

sizeDevDefaultLength	equ ($ - devDefaultLength)


		; Get Address of Device Parameter Block
		;
		; Input:
		; ax	drive
		;
		; Output:
		; ax	drive
		; NC if valid drive
		;  es:bx-> device parameter block for drive
		; CY if invalid drive
getAddrDPB:

	push ax
	push cx

	les bx, [ ss:_RxDOS_pCDS ]			; point to CDS
	and ax, byte sftDrivemask			; optimize for drive A:
	jz getAddrDPB_12				; if drive A:, skip check -->

	cmp al, byte [ ss:_RxDOS_bLastDrive ]		; drive valid if B (= CY)
	cmc						; change sense of test (NC if valid)
	jc getAddrDPB_16				; not a valid drive -->

	mov cl, sizeCDS
	mul cl						; create CDS offset
	add bx, ax

getAddrDPB_12:
	mov ax, word [ es:bx + _cdsPtrToDPB + _segment ]
	or ax, word [ es:bx + _cdsPtrToDPB + _pointer ]
	stc						; set error if not intialized
	jz getAddrDPB_16				; not initialized -->

	clc
	les bx, [ es:bx + _cdsPtrToDPB ]		; else, pointer is valid

getAddrDPB_16:
	pop cx
	pop ax
	retn


		; Get Device Parameter Block
		;
		; Input:
		; ax	drive
		;
		; Output:
		; ax	drive
		; es:bx	address of device parameter block for drive
getDPB:

	Entry
	def	drive, ax
	ddef	dpbAddress
	defbytes	devVolumeId, sizeVolumeID

		; see if valid and initialized
	saveAllRegisters
	call getAddrDPB
	jc getDPB_36					; if device does not exist -->

	stordarg _dpbAddress, es, bx			; save valid address

		; see if removable media and disk changed
getDPB_08:
	getarg ax, _drive				; restore drive
	getdarg es, bx, _dpbAddress			; get address of dpb
	mov ah, byte [ es:bx + _dpbMediaDescriptor ]
	lea bx, [ byte _devVolumeId + bp ]		; location to store new label id
	call DevMediaRequest				; rebuild Media ID if removable
	jc getDPB_24					; if error, attempt initialize -->

	getdarg es, bx, _dpbAddress			; get address of dpb
	cmp byte [ es:bx + _dpbAccessFlag ], -1		; this block used before ?
	jz getDPB_24					; no, so just initialize now -->

	cmp cl, MEDIA_HASCHANGED			; has media changed ?
	jz getDPB_24					; no, it has not changed -->

	mov ax, word [ bp + _devVolumeId + _low ]
	cmp ax, word [ es:bx + _dpbVolumeId + _low ]
	jnz getDPB_24					; if different volume -->

	mov ax, word [ bp + _devVolumeId + _high ]
	cmp ax, word [ es:bx + _dpbVolumeId + _high ]
	jz getDPB_30					; if same volume, then ok -->

		; init drive parameters
getDPB_24:
	getarg ax, _drive
	call invalidateBuffers				; invalidate buffers
	call initDriveParameters			; rebuild drive parameters

	getdarg es, bx, _dpbAddress			; get address of dpb
	mov ax, word [ bp + _devVolumeId + _low ]
	mov dx, word [ bp + _devVolumeId + _high ]
	mov word [ es:bx + _dpbVolumeId + _low ], ax
	mov word [ es:bx + _dpbVolumeId + _high ], dx

		; return
getDPB_30:
	clc

getDPB_36:
	restoreAllRegisters
	getdarg es, bx, _dpbAddress			; get address of dpb
	Return


		; Translate BIOS Parameter Block to DPB
		;
		; Input:
		; arg-> BIOS parameter block
		; arg-> Buffer for drive parameter block
		;
		; Creates an extended DPB for FAT32 drives or normal DPB for FAT12/FAT16
DefineDPB:

	Entry 4
	darg	biosParamBlock
	darg	dosDiskParamBlock

	SaveSegments 

	getdarg ds, di, _biosParamBlock
	getdarg es, bx, _dosDiskParamBlock

	call DefineDPB32				; if FAT32 logical drive
	jz DefineDPB_24					; if FAT32 -->
	call DefineDPB16				; all other standard drives

DefineDPB_24:
	or ax, ax
	mov byte [ es:bx + _dpbAccessFlag ], 0
	RestoreSegments
	Return


		; Translate BIOS Parameter Block to DPB (FAT12/FAT16)
		;
		; Input:
		; ds:di-> BIOS parameter block
		; es:bx-> drive parameter block
		;
		; NOTE:	expects to only be called from DefineDPB
		;
		; See DefineDPB32 for FAT32 drives.
DefineDPB16:

	mov ax, word [ di + _bpbBytesPerSector ]
	mov word [ es:bx + _dpbBytesPerSector ], ax

	mov ax, word [ di + _bpbResSectors ]
	mov word [ es:bx + _dpbFirstFAT ], ax

	mov al, byte [ di + _bpbNumCopiesFAT ]
	mov byte [ es:bx + _dpbNumCopiesFAT ], al

	mov al, byte [ di + _bpbMediaDescriptor ]
	mov byte [ es:bx + _dpbMediaDescriptor ], al

	mov ax, word [ di + _bpbSectorsPerFat ]
	mov word [ es:bx + _dpbSectorsPerFat ], ax

	mov word [ es:bx + _dpbFreeCount + _high ], -1	; invalidate disk free space
	mov word [ es:bx + _dpbFreeCount + _low ], -1

		; compute shift and mask factors for sectors/cluster
	mov al, byte [ di + _bpbSectorsPerCluster ] 

	push di
	push es
	 push cs
	 pop es
	mov di, _bitShiftTable
	mov cx, sizeShiftTable
	repnz scasb

	sub cx, sizeShiftTable - 1
	neg cx						; proper sense

	pop es
	pop di

	dec al
	mov byte [ es:bx + _dpbClusterSizeMask ], al	; 1 + mask == actual value
	mov byte [ es:bx + _dpbClusterSizeShift ], cl	; 1 << shift == actual value

		; compute reserved/max sectors
	push cx						; save shift

	xor ax, ax
	mov al, byte [ di + _bpbNumCopiesFAT ]
	mul word [ di + _bpbSectorsPerFat ]		; ignore dx

	add ax, word [ di + _bpbResSectors ]
	mov word [ es:bx + _dpbFirstDirSector ], ax

	xor dx, dx
	mov ax, word [ di + _bpbMaxAllocRootDir ]
	mov word [ es:bx + _dpbMaxAllocRootDir ], ax
	mov cx, sizeDIRENTRY
	mul cx

	add ax, word [ di + _bpbBytesPerSector ]	; (round up)
	dec ax
	mov cx, word [ di + _bpbBytesPerSector ]
	call _div32

	add ax, word [ es:bx + _dpbFirstDirSector ]
	mov word [ es:bx + _dpbFirstDataSector ], ax

	xor dx, dx
	mov ax, word [ di + _bpbMaxSectors ]
	or ax, ax
	jnz DefineDPB16_08				; value is legitimate
	mov dx, word [ di + _bpbHugeSectors + _high ]
	mov ax, word [ di + _bpbHugeSectors + _low ]

DefineDPB16_08:
	sub ax, word [ es:bx + _dpbFirstDataSector ]
	sbb dx, byte 0					; if nc = 0, else = FFFFh
	pop cx						; restore shift value

DefineDPB16_12:
	jcxz DefineDPB16_14

	shr dx, 1
	rcr ax, 1
	loop DefineDPB16_12

DefineDPB16_14:
	; inc ax
	mov word [ es:bx + _dpbMaxClusterNumber ], ax
	mov byte [ es:bx + _dpbAccessFlag ], 0

	clc
	retn


		; Translate BIOS Parameter Block to DPB (FAT32)
		;
		; Input:
		; ds:di	pointer to bios parameter block
		; es:bx	pointer to drive parameter block
		;
		; Output:
		; NZ if no FAT32 drive
		; ZR if FAT32 drive, DPB created
		;
		; NOTE:	expects to only be called from DefineDPB
		;
		; See DefineDPB16 for FAT12/FAT16 drives.
DefineDPB32:

	cmp word [ _bpbSectorsPerFat + di ], byte 0
	jz DefineDPB32_08				; if FAT32 drive -->
	retn

DefineDPB32_08:
	pushf						; save ZF (also NC)
	call DefineDPB16				; copy FAT16 stuff for completeness

		; copy some basic info
	mov word [ es:bx + _dpbMaxClusterNumber ], 0
	mov word [ es:bx + _dpbFirstDirSector ], 0
	mov word [ es:bx + _dpbSectorsPerFat ], 0	; small values unused if FAT32

	mov ax, word [ di + _bpbxFSINFOSector ]
	mov word [ es:bx + _dpbxFSINFOSector ], ax

	mov ax, word [ di + _bpbxBackUpBootSector ]
	mov word [ es:bx + _dpbxBackUpBootSector ], ax	; copy special info sectors for FAT32

	mov dx, word [ di + _bpbxFreeClusters + _high ]
	mov ax, word [ di + _bpbxFreeClusters + _low ]
	mov word [ es:bx + _dpbFreeCount + _high ], dx
	mov word [ es:bx + _dpbFreeCount + _low ], ax	; copy free sectors count

	mov dx, word [ di + _bpbxNextFreeCluster + _high ]
	mov ax, word [ di + _bpbxNextFreeCluster + _low ]
	mov word [ es:bx + _dpbxNextFreeCluster + _high ], dx
	mov word [ es:bx + _dpbxNextFreeCluster + _low ], ax	; next free cluster number

	mov dx, word [ di + _bpbxRootDirStartCluster + _high ]
	mov ax, word [ di + _bpbxRootDirStartCluster + _low ]
	mov word [ es:bx + _dpbxRootCluster + _high ], dx
	mov word [ es:bx + _dpbxRootCluster + _low ], ax

	mov dx, word [ di + _bpbxBigSectorsPerFat + _high ]
	mov ax, word [ di + _bpbxBigSectorsPerFat + _low ]
	mov word [ es:bx + _dpbxSectorsPerFat + _high ], dx
	mov word [ es:bx + _dpbxSectorsPerFat + _low ], ax	; larger values used if FAT32 


		; compute sector address of first sector
	xor cx, cx
	mov cl, byte [ es:bx + _dpbNumCopiesFAT ]
	call _mul32

		; dx:ax = (sectors per FAT)*(number of FATs)
	add ax, word [ di + _bpbResSectors ]
	adc dx, byte 0
	mov word [ es:bx + _dpbxFirstSector + _low ], ax
	mov word [ es:bx + _dpbxFirstSector + _high ], dx

	mov ax, word [ di + _bpbResSectors ]
	mov word [ es:bx + _dpbxReserveSectors + _low ], ax
	mov word [ es:bx + _dpbxReserveSectors + _high ], 0

	mov ax, word [ di + _bpbHugeSectors + _low ]
	mov dx, word [ di + _bpbHugeSectors + _high ]
	sub ax, word [ es:bx + _dpbxFirstSector + _low ]
	sbb dx, word [ es:bx + _dpbxFirstSector + _high ]

	xor cx, cx
	mov cl, byte [ di + _bpbSectorsPerCluster ]
	call _div32

	mov word [ es:bx + _dpbxMaxCluster + _high ], dx
	mov word [ es:bx + _dpbxMaxCluster + _low ], ax

	popf						; Restore ZF
	retn


		; Convert logical sector address to physical CHS
		;
		; Input:
		; ds:di	= disk parameter block address
		; ax:dx	= logical sector address (within partition)

		; Output:
		; ds:di	disk parameter block address
		; cx	cl = sector/ch = track
		; dx	dl = unit/dh = head
ConvertLogSectorToPhysical:

	add ax, word [ di + _bpbHiddenSectors + _low ]
	adc dx, word [ di + _bpbHiddenSectors + _high ]
		; dx:ax = LBA sector number in the unit

	mov cx, word [ _bpbSectorsPerTrack + di ]
	call _div32

	inc cx
	push cx						; sector
	mov cx, word [ di + _bpbHeads ]
	call _div32
	mov dh, cl					; head

	; track is at ax
	; head is at cx

	clc
	shl ah, 1
	shl ah, 1
	shl ah, 1
	shl ah, 1
	shl ah, 1
	shl ah, 1					; move high order of cyl up 

	pop cx
	or cl, ah					; top two bits of cyl or'd into phys sector
	mov ch, al					; rest of cyl 
	retn


		; Init Drive Parameters
		;
		; Input:
		; ax	drive to check
		;
		; Output:
		; ax	drive to check
		; CY	if drive is invalid or contains no media
initDriveParameters:

	Entry
	def	drive, ax
	ddef	dpbAddress
	defbytes	reqBlock, sizeMaxReqHeader
	defbytes	sectorBuffer, sizeSector

	call getAddrDPB					; (es:bx) Device Parameter Block
	jc initDriveParameters_22			; if error -->
	stordarg _dpbAddress, es, bx			; save address

	mov word [ es:bx + _dpbFreeCount + _high ], -1	; invalidate disk free space
	mov word [ es:bx + _dpbFreeCount + _low ], -1

	mov dx, word [ es:bx + _dpbptrDeviceDriver + _pointer ]
	or dx, word [ es:bx + _dpbptrDeviceDriver + _segment ]
	jnz initDriveParameters_10

	call findInstalledBlockDevice
	jc initDriveParameters_22
	mov word [ es:bx + _dpbptrDeviceDriver + _pointer ], dx
	mov word [ es:bx + _dpbptrDeviceDriver + _segment ], cx

initDriveParameters_10:
	getarg ax, _drive				; restore drive
	mov ah, BUILDBPB
	lea di, [ byte _reqBlock + bp ]
	call initReqBlock				; initialize

	lea di, [ _sectorBuffer + bp ]
	mov word [ es:bx + bbrFATSector + _pointer ], di
	mov word [ es:bx + bbrFATSector + _segment ], ss

	getarg ax, _drive				; restore drive
	call BlockedDevRequest				; call blocked device
	jc initDriveParameters_22			; if error or wrong dev -->

	push word [ es:bx + bbrBPBAddress + _segment ]
	push word [ es:bx + bbrBPBAddress + _pointer ]
	push word [ _dpbAddress + _segment + bp ]
	push word [ _dpbAddress + _pointer + bp ]	; address of DPB
	call DefineDPB					; build DPB

initDriveParameters_22:
	Return


		; Find Drive from Unit Code
		;
		; Input:
		; al	BIOS unit code (0, 1, 80, 81, ...)
		;
		; Output:
		; al	Drive code
_GetDriveCodeFromUnitCode:
	
	push es
	push si

	les si, [ _RxDOS_pCDS ]
	mov cl, byte [ _RxDOS_bLastDrive ]
	mov ch, 0					; cx = number of valid CDS entries

_GetDriveCode_08:
	mov dx, word [ es:si + _cdsPtrToDPB + _pointer ]
	or dx, word [ es:si + _cdsPtrToDPB + _segment ]
	jz _GetDriveCode_16				; DPB address is zero, no valid DPB -->

	push es
	push si
	les si, [ es:si + _cdsPtrToDPB ]
	cmp al, byte [ es:si + _dpbUnit ]		; compare given unit to DPB value
	pop si
	pop es
	jnz _GetDriveCode_16

	mov al, byte [ _RxDOS_bLastDrive ]		; Found match! now get maximal value
	sub al, cl					; and subtract count to get current entry
	clc						; no error
	jmp short _GetDriveCode_22

_GetDriveCode_16:
	add si, byte sizeCDS
	loop _GetDriveCode_08				; loop until all CDS entries done

	mov al, -1
	stc

_GetDriveCode_22:
	pop si
	pop es
	retn


		; Set Exit Code If Control-C
		;
		; Input:
		; ax	character
		; dx	TRUE if end of file
		; ZR	if end of file
SetExit_IfControlC:
	mov dx, TRUE					; assume end of file

	cmp ax, byte ControlZ				; Ctrl-Z ? (CP/M EOF)
	jz SetExit_IfControlC_08			; yes, success -->
	cmp ax, byte ControlC				; Ctrl-C ? (Break)
	jz SetExit_IfControlC_08			; yes, success -->
	mov dl, FALSE					;  otherwise no, set FALSE, NZ
							; (however preserve ZF!)

SetExit_IfControlC_08:
	retn


		; Call User's Critical Error Handler
		;
		; Input:
		; es:bx	pointer to current device header
		; ax	error code
_callCriticalError:

	Entry
	ddef	devicereqblock, es, bx
	def	errorCode, ax
	def	allowed, 0000

	push word [ ss:SDAInt24_SPSave + _segment ]
	push word [ ss:SDAInt24_SPSave + _pointer ]

	push es
	push ds
	push bx
	push bp

	; even if PSP == 0, we should display error message, so we'll change
	; this code at a later date.

	mov dl, CRITERROR_FAIL
	cmp word [ ss:_RxDOS_CurrentPSP ], byte 0
	ifz _callCriticalError_32			; if no valid PSP -->

		; set arguments for int 24 call
	xor ah, ah					; upper bits zero
	mov di, ax					; set error code
	mov al, byte [ es:bx + rwrUnit ]		; unit
	mov ah, byte [ cs:di + DevAllowedTable ]	; get allowed bits
	mov byte [ _allowed + bp ], ah			; save value
	call _GetDriveCodeFromUnitCode			; drive code

	cmp di, byte sizeDevAllowedTable		; is error within device allowed errors ?
	jb _callCriticalError_06			; if ok -->
	mov ah, CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED

_callCriticalError_06:
	or ah, 110b					; data area
	cmp byte [ es:bx + rwrFunction ], DEVICEWRITE
	jz _callCriticalError_08
	cmp byte [ es:bx + rwrFunction ], DEVICEWRITEVERIFY
	jnz _callCriticalError_10

_callCriticalError_08:
	or ah, 1					; write function

_callCriticalError_10:
	call saveStackFrame

	mov bp, es					; point to driver's header
	mov si, bx					; es:bx --> bp:si
	mov bx, word [ ss:_RxDOS_CurrentInstance ]	; base address of current stack
	les bx, [ ss:bx + _pointer ]

	cli
	mov word [ ss:SDAInt24_SPSave + _segment ], ss
	mov word [ ss:SDAInt24_SPSave + _pointer ], sp
		; RxDOS 7.20N:	This seems very ugly. Other DOS don't
		;		 use this fields for these values.
		;		Actually, the field is used like this,
		;		 but it is only a word, for SP only.

	mov dx, es
	mov ss, dx
	lea sp, [ byte bx - sizeStackFrame ]		; adjust user stack ptr
	sti

	push word [ es:bx + _DS ]
	push word [ es:bx + _ES ]
	pop es
	pop ds

	Int intCRITICALERROR				; perform int 24h

	cli
	mov dl, al					; save value returned
	mov bp, 70h
	push ds
	push bp						; swap bp
	pop ds
	pop bp						;  and ds
	mov ds, word [dosdata_segment]
	mov ss, word [ SDAInt24_SPSave + _segment ]
	mov sp, word [ SDAInt24_SPSave + _pointer ]
	mov ds, bp					; restore ds
	sti

		; fix-up returned codes if conflict between allowed and returned

	pop bp
	push bp
	cmp dl, CRITERROR_IGNORE			; ignore returned ?
	jnz _callCriticalError_22			; no -->
	test word [ _allowed + bp ], CRITERROR_IGNOREALLOWED
	jnz _callCriticalError_32			; yes -->
	mov dl, CRITERROR_FAIL				; otherwise default to fail

_callCriticalError_22:
	cmp dl, CRITERROR_RETRY				; retry returned ?
	jnz _callCriticalError_24			; no -->
	test word [ _allowed + bp ], CRITERROR_RETRYALLOWED
	jnz _callCriticalError_32			; yes -->
	mov dl, CRITERROR_FAIL				; otherwise default to fail

_callCriticalError_24:
	cmp dl, CRITERROR_FAIL				; fail returned ?
	jnz _callCriticalError_32			; no -->
	test word [ _allowed + bp ], CRITERROR_FAILALLOWED
	jnz _callCriticalError_32			; yes -->
	mov dl, CRITERROR_TERMINATE			; otherwise default to terminate 

_callCriticalError_32:
	pop bp
	pop bx
	pop ds
	pop es

	pop word [ ss:SDAInt24_SPSave + _pointer ]
	pop word [ ss:SDAInt24_SPSave + _segment ]

	mov al, dl
	Return


		; Allowed attributes for specific errors
DevAllowedTable:	

		db CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrWriteProtectVol	

		db CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrUnknownUnit	

		db CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrDeviceNotReady	

		db CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrUnknownCommand	

		db CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrCRCerr		

		db CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrBadDriveReq	

		db CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrSeekError	 

		db CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrUnknownMedia	

		db CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrSectorNotFound	

		db CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrPrinterOutPaper	

		db CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrWriteFault	

		db CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrReadFault	 

		db CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrGeneralFailure	

		db CRITERROR_IGNOREALLOWED + CRITERROR_FAILALLOWED
						; devErrSharingViolation

		db CRITERROR_IGNOREALLOWED + CRITERROR_FAILALLOWED
						; devErrLockViolation

		db CRITERROR_IGNOREALLOWED + CRITERROR_RETRYALLOWED + CRITERROR_FAILALLOWED
						; devErrInvalidDiskChange 

sizeDevAllowedTable	equ ($ - DevAllowedTable)


		; Clock Tick Counter
		;
		; Returns:
		; dx:ax	clock ticks
ClockTimer:

	push ds
	push bx

	xor bx, bx
	mov ds, bx
	mov ax, word [ 46Ch ]
	mov dx, word [ 46Eh ]

	pop bx
	pop ds
	retn


		; Line Editor Control Block Init
		;
		; Usage:
		; ss:di	pointer to editor control block
		; dx:ax	pointer to client buffer
		; cx	max characters
_lineEditorInit:

	push ax
	push bx
	push cx
	push dx
	push di
	push es
	setes ss

	xor ax, ax
	mov cx, sizeLINEEDITOR
	repz stosb					; clear Edit Control Block

	mov ax, 0F00h					; read current mode
	int 10h						; get page into bh

	mov ax, 0300h					; get current cursor position
	int 10h						; get cursor position in dh/dl

	pop es
	pop di						; Edit Control Block
	mov byte [ ss:di + editPhysCursorRow ], dh
	mov byte [ ss:di + editPhysCursorCol ], dl

	call getSysDateinDirFormat			; stamp

	pop dx
	pop cx
	pop bx
	pop ax

	mov word [ ss:di + editBufPointer + _low ], ax
	mov word [ ss:di + editBufPointer + _high ], dx
	mov word [ ss:di + editMaxBuffer ], cx
	retn


		; Line Editor
		;
		; Usage:
		; ss:di	pointer to editor control block
		; ax	character to process
_lineEditor:
	entry
	def	DisplayPage, 0
	ddef	lineEditControlBlock, es, di

	SaveSegments di, bx, ax
	setds ss
	les bx, [ editBufPointer + di ]
	cmp word [ editMaxBuffer + di ], byte 1		; just one character ?
	jnz _lineEditor_04				; even if NULL -->

	mov byte [ es:bx ], al				; store character into buffer
	inc word [ editMaxAvail + di ]			; character stored
	inc word [ editCursor + di ]			;
	jmp _lineEditor_60				; exit -->

		; use line editor
_lineEditor_04:
	mov ax, 0F00h
	int 10h						; get current display page
	mov byte [ _DisplayPage + bp ], bh

		; lookup character
	pop ax
	push ax						; restore character
	les bx, [ editBufPointer + di ]
	add bx, word [ editCursor + di ]

	Goto	4B00h, _editorLeft			; 4Bh 00h	Left
	Goto	4D00h, _editorRight			; 4Dh 00h	Right
	Goto	5200h, _editorInsert			; 52h 00h	Insert
	Goto	5300h, _editorDelete			; 53h 00h	Delete
	Goto	4700h, _editorHome			; 47h 00h	Home
	Goto	4F00h, _editorEnd			; 4Fh 00h	End
	Goto	3C00h, _editorF2SetSearchMode		; 3Ch 00h	F2
	Goto	3D00h, _editorF3CopyTemplate		; 3Dh 00h	F3

	or al, al					; double byte sequence ?
	ifz _lineEditor_60				; ignore if not resolved -->

	test word [ editFlags + di ], editSearchFlag
	ifnz _editorF2SearchTemplate			; process search char -->

		; lookup character
_lineEditor_08:
	cmp al, ' '
	jae _lineEditor_16				; if character ->

	Goto	'C'-40h, _editorControlC		; if ctrl-C (03) -->
	Goto	'H'-40h, _editorBackspaceDelete		; if bs/del (08) -->
	Goto	'I'-40h, _editorTab			; if tab (09) -->
	Goto	'['-40h, _editorEscape			; if escape (1B) -->
	Goto	'M'-40h, _editorCRLF			; if cr (0D) -->
	; Goto	'G'-40h, _editorBell

		; store or insert character
_lineEditor_16:
	mov cx, word [ editMaxBuffer + di ]		; max buffer
	cmp cx, word [ editMaxAvail + di ]		; characters so far 
	jb _lineEditor_60				; if can't insert -->

	test word [ editFlags + di ], editInsertFlag
	jz _lineEditor_Store				; if not insert mode -->

	mov cx, word [ editTemplateCharsAvailable + di ]
	sub cx, word [ editCursor + di ]		; at max end of line ?
	jz _lineEditor_Store				; yes, can't go right -->

		; if insert
	inc word [ editTemplateCharsAvailable + di ]
	mov cx, word [ editTemplateCharsAvailable + di ]
	sub cx, word [ editCursor + di ]		; at max end of line ?
	push bx

_lineEditor_20:
	xchg al, byte [ es:bx ]				; ripple insert character
	inc bx						; point to next column 
	loop _lineEditor_20				; loop thru all characters -->

	pop bx
	inc word [ editMaxAvail + di ]
	mov cx, word [ editMaxAvail + di ]
	sub cx, word [ editCursor + di ]		; at max end of line ?
	inc word [ editCursor + di ]

_lineEditor_22:
	mov al, byte [ es:bx ]				; update display
	call _lineEditor_displayCharacter

	inc bx						; point to next column 
	loop _lineEditor_22				; loop thru all characters -->
	jmp short _lineEditor_54			; display cursor

		; store character
_lineEditor_Store:
	mov byte [ es:bx ], al

_lineEditor_46:
	call _lineEditor_displayCharacter
	inc word [ editCursor + di ]			; increment cursor

	mov cx, word [ editCursor + di ]
	cmp cx, word [ editMaxAvail + di ]		; is cursor past max length ?
	jb _lineEditor_54				; no -->
	mov word [ editMaxAvail + di ], cx		; cursor is max length

		; return
_lineEditor_54:
	call _editorSetCursorPosition

_lineEditor_60:
	RestoreSegments ax, bx, di
	Return


		; Set Control Mode
_editor_SetInControlMode:
	or word [ editFlags + di ], editControlFlag
	jmp short _lineEditor_60


		; Insert
_editorInsert:
	xor word [ editFlags + di ], editInsertFlag
	jmp short _lineEditor_60


		; Exit, No Text
_editorControlC:
	mov word [ editMaxAvail + di ], 0		; cursor is max length

	les bx, [ editBufPointer + di ]
	mov byte [ es:bx ], 00				; null out line

	call _lineEditor_displayCharacter		; echo control C


		; display CR, LF using Int29, return
_editorCRLF:
	mov al, 13
	int 29h
	jmp short _lineEditor_60


		; Home
_editorHome:
	mov word [ editCursor + di ], 0			; set end pointer
	jmp short _lineEditor_54


		; End
_editorEnd:
	mov cx, word [ editMaxAvail + di ]		; get max chars
	mov word [ editCursor + di ], cx		; set end pointer
	jmp short _lineEditor_54


		; Left
_editorLeft:
	cmp word [ editCursor + di ], byte 0		; at start of line ?
	jz _editorLeft_08				; yes, can't go backwards -->
	dec word [ editCursor + di ]

_editorLeft_08:
	jmp short _lineEditor_54


		; Right
_editorRight:
	mov cx, word [ editMaxAvail + di ]		; get max chars
	cmp cx, word [ editTemplateCharsAvailable + di ]
	jae _editorRight_08

	mov cx, word [ editTemplateCharsAvailable + di ]

_editorRight_08:
	cmp cx, word [ editCursor + di ]		; at max end of line ?
	jz _lineEditor_60				; yes, can't go right -->

	mov al, byte [ es:bx ]
	jmp short _lineEditor_46


		; Backspace/Delete
_editorBackspaceDelete:
	cmp word [ editCursor + di ], byte 0		; at start of line ?
	jz _editorDelete_16				; yes, can't go backwards -->
	dec word [ editCursor + di ]			; set cursor
	dec bx						; set position
	call _editorSetCursorPosition			; redisplay cursor


		; Delete
_editorDelete:
	mov cx, word [ editTemplateCharsAvailable + di ]
	sub cx, word [ editCursor + di ]		; at max end of line ?
	dec cx						; at end of buffer ?
	jbe _editorDelete_08				; yes, echo rubout space -->

_editorDelete_06:
	mov al, byte [ es:bx + 1 ]
	mov byte [ es:bx ], al				; copy characters
	inc bx						; point to next column 
	loop _editorDelete_06				; loop thru all characters -->

_editorDelete_08:
	mov cx, word [ editMaxAvail + di ]
	sub cx, word [ editCursor + di ]		; at max end of line ?
	dec cx						; at end of buffer ?
	jbe _editorDelete_16				; yes, echo rubout space -->

_editorDelete_12:
	mov al, byte [ es:bx ]
	call _lineEditor_displayCharacter

	inc bx
	loop _editorDelete_12				; loop thru all characters -->

_editorDelete_16:
	mov bh, byte [ _DisplayPage + bp ]
	mov cx, word [ editMaxAvail + di ]
	mov ax, 0E20h					; echo a space
	int 10h

	mov ax, word [ editMaxAvail + di ]		; is max chars
	cmp ax, word [ editCursor + di ]		; greater than current position ?
	jbe _editorDelete_20				; no -->

	dec word [ editMaxAvail + di ]			; adjust max chars

_editorDelete_20:
	mov ax, word [ editTemplateCharsAvailable + di ]
	cmp ax, word [ editCursor + di ]		; greater than current position ?
	jbe _editorDelete_22				; no -->

	dec word [ editTemplateCharsAvailable + di ]

_editorDelete_22:
	jmp _lineEditor_54


		; Copy Template
_editorF3CopyTemplate:
	mov cx, word [ editTemplateCharsAvailable + di ]
	sub cx, word [ editCursor + di ]
	jbe _editorF3CopyTemplate_12			; if can't echo -->

	mov word [ editMaxAvail + di ], cx		; get max chars
	mov word [ editCursor + di ], cx		; set cursor

_editorF3CopyTemplate_08:
	mov al, byte [ es:bx ]
	call _lineEditor_displayCharacter

	inc bx
	loop _editorF3CopyTemplate_08

_editorF3CopyTemplate_12:
	jmp _lineEditor_60


		; Set Search Mode
_editorF2SetSearchMode:
	or word [ editFlags + di ], editSearchFlag
	jmp _lineEditor_60


		; Search Template
_editorF2SearchTemplate:
	xor word [ editFlags + di ], editSearchFlag

	mov cx, word [ editTemplateCharsAvailable + di ]
	sub cx, word [ editCursor + di ]		; chars to copy
	jbe _editorF2SearchTemplate_28			; if can't echo -->

	push cx
	push bx
	mov dl, al
	_upperCase dl					; char to search

_editorF2SearchTemplate_08:
	mov al, byte [ es:bx ]
	inc bx
	_upperCase al					; make character upper case
	cmp al, dl					; on search character ?
	jz _editorF2SearchTemplate_12			; we have a match, exit -->
	loop _editorF2SearchTemplate_08

_editorF2SearchTemplate_12:
	pop bx
	pop ax
	or cx, cx					; character found ?
	jz _editorF2SearchTemplate_28			; no, exit -->

	sub cx, ax					; real distance to copy
	neg cx						; distance in cx
	inc cx
	add word [ editMaxAvail + di ], cx		; get max chars
	add word [ editCursor + di ], cx		; set cursor

_editorF2SearchTemplate_18:
	mov al, byte [ es:bx ]
	call _lineEditor_displayCharacter

	inc bx
	loop _editorF2SearchTemplate_18

_editorF2SearchTemplate_28:
	jmp _lineEditor_60


		; Tab, Tab completion support
_editorTab:
	jmp _lineEditor_60


		; Escape
_editorEscape:
	mov word [ editCursor + di ], 0			; set cursor
	call _editorSetCursorPosition			; position cursor at home

	cmp word [ editMaxAvail + di ], byte 0		; already at start of line ?
	jz _editorEscape_12				; yes -->

_editorEscape_08:
	mov bh, byte [ _DisplayPage + bp ]
	mov ax, 0E20h
	int 10h						; set cursor position

	dec word [ editMaxAvail + di ]			; already at start of line ?
	jnz _editorEscape_08				; keep looping -->

_editorEscape_12:
	mov word [ editMaxAvail + di ], 0		; cursor is max length
	mov word [ editCursor + di ], 0			; set cursor
	call _editorSetCursorPosition			; position cursor at home
	jmp _lineEditor_60


		; Line Editor Display - Set Cursor Position
_editorSetCursorPosition:

	push bx
	mov dh, byte [ editPhysCursorRow + di ]
	mov dl, byte [ editPhysCursorCol + di ]
	add dl, byte [ editCursor + di ]
	mov bh, byte [ _DisplayPage + bp ]
	mov ax, 0200h
	int 10h						; set cursor position

	pop bx
	retn


		; Line Editor Display Character
_lineEditor_displayCharacter:

	push bx
	mov bh, byte [ _DisplayPage + bp ]

	mov ah, 0Eh					; echo character in AL
	cmp al, ' '					; if control character, echo ^(control letter)
	jae _lineEditorDisplayChar_12			; else just echo character

	push ax
	mov al, '^'
	int 10h
	pop ax						; restore character
	add ax, 'A' - 1					; make it a letter

_lineEditorDisplayChar_12:
	int 10h
	pop bx
	retn


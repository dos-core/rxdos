
%if 0

RxBIO - RxDOS Basic Input/Output kernel

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

(c) Copyright 1990, 1999. Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

%if 0

Load remainder of RxDOS

When RxBIO is loaded by the disk boot loader, it loads automatically
the first three sectors regardless of the cluster allocation. For RxDOS,
only the first sector in a cluster needs to actually be loaded. This
loads this portion of the RxBIO code, which loads the remainder of the
program using FAT allocations.

The boot program has also detected and read the first sector of the
root directory which is located at 0000:0500 (that is, 50:0).

Boot sequence is
 
RxMBR (master boot record)
 loads at 0:7C00h, relocated to 60h:0
 located at LBA 0 (cyl: 0 head: 0 sector: 1)
 
boot12/16/32 (boot record)
 loads at 0:7C00h
 located at start of partition (in partition's logical sector 0)

iniload
 loaded at eg 70h:0 (entry :400h), loads remainder of BIO + DOS

RxBIO
RxDOS
 provides user-level DOS services
 sets up DOS memory management
 currently the code segment and the DOS data segment are synonymous

RxCMD
 loaded by RxDOS if not otherwise instructed
 shows DOS prompt to user and executes internal/external commands

%endif


%include "RXDMACRO.NEW"
%include "RXDSTRUC.NEW"


		align 2
dosdata_segment:		dw 0
doscode_segment:		dw 0

		align 4
ptrStartBlockedDeviceTable:	dd -1		; -> first UPB

RxDOS_CLOCKDATA:		times CLOCKDATA_size db 0

		; Form Codes
DSKFORMTYPES_40_9		equ 00h		 ; 40 cyls, <= 9 sect/track
DSKFORMTYPES_80_15		equ 01h		 ; 80 cyls, 15 sect/track
DSKFORMTYPES_80_9		equ 02h		 ; 80 cyls, 9 sect/track
DSKFORMTYPES_HARDDISK		equ 03h		 ; hard disk
DSKFORMTYPES_FLOPPY_OTHER	equ 07h		 ; other floppy disk types
DSKFORMTYPES_80_36		equ 07h		 ; 80 cyls, 36 sect/track 1.44M


		; Status Codes
IsNonRemovable			equ 0001h		; non-removable media
ChgLineSupportedbyBIOS		equ 0002h		; change line supported
BPBLocked			equ 0004h		; BPB Locked status
GoodTrackLayout			equ 0008h		; if continuous sectors on track
SharesPhysDevice		equ 0010h		; if physical unit partitioned
ActiveUnit			equ 0020h		; if active unit
DiskChangeDetected		equ 0040h		; disk change detected
DASD_SetRequired		equ 0080h		; DASD_SetRequired
VerifyWrite			equ 0100h		; Verify Write
RW_Disabled			equ 0200h		; read/ write disabled

RxBIOS_FIXEDDRIVEMASK		equ 80h			; fixed drive mask


%if 0
		; Load remainder of RxDOS
	mov ax, sizeDISKBLOCK				; number of block devices
	mul cx						; size required by table

	add ax, RxBIO_LastAddress + (sizeParagraph - 1)
	adc dx, 0
%rep 4
	shr dx, 1
	rcr ax, 1
%endrep
							; paragraphs size

	mov dx, cs					; current segment
	add dx, ax					; seg address to load next module.
	inc dx
	xor ax, ax
	push dx
	push ax				; on stack: far address of DOS
	dec dx

	mov ax, [ dosdata_segment ]
	dec ax				; => DOSDATA S MCB
	mov cx, (16 + (dosdata_end - dosdata_start)) >> 4

	cmp dx, ax
	ja error_memory_layout

	call movp			; move DOS into place

	inc dx
	mov word [dosdata_segment], dx
	mov word [doscode_segment], dx
	xor bx, bx
	mov es, bx
	mov word [es:30h * 4 + 6], dx	; update DR-DOS compatible reference
	mov es, ax
	mov word [es:mcbOwner], 0	; free the DOSDATA S MCB

	 push cs
	 pop es
	mov di, RxBIO_INITBLOCK		; -> SYSINIT structure
	retf				; jump to DOS
%endif

	align 4
		; Strategy Argument
Strategy:		dd 0

		; CON definition
	devheader con, clock, 70h, (DEV_CHAR+ DEV_STDINPUT+ DEV_STDOUTPUT+ DEV_FASTCHARIO), \
		_DevStrategy, con_interrupt, 'CON'

		; CLOCK$ definition
	devheader clock, prn, 70h, (DEV_CHAR+ DEV_CLOCK), \
		_DevStrategy, clock_interrupt, 'CLOCK$'

		; PRN, LPT1, LPT2, LPT3 definitions
	devheader prn, lpt1, 70h, (DEV_CHAR+ DEV_OUTPUTTILLBUSY), \
		_DevStrategy, prn_interrupt, 'PRN'
	devheader lpt1, lpt2, 70h, (DEV_CHAR+ DEV_OUTPUTTILLBUSY), \
		_DevStrategy, lpt1_interrupt, 'LPT1'
	devheader lpt2, lpt3, 70h, (DEV_CHAR+ DEV_OUTPUTTILLBUSY), \
		_DevStrategy, lpt2_interrupt, 'LPT2'
	devheader lpt3, aux, 70h, (DEV_CHAR+ DEV_OUTPUTTILLBUSY), \
		_DevStrategy, lpt3_interrupt, 'LPT3'

		; AUX, COM1, COM2, COM3, COM4 definitions
	devheader aux, com1, 70h, (DEV_CHAR), \
		_DevStrategy, aux_interrupt, 'AUX'
	devheader com1, com2, 70h, (DEV_CHAR), \
		_DevStrategy, com1_interrupt, 'COM1'
	devheader com2, com3, 70h, (DEV_CHAR), \
		_DevStrategy, com2_interrupt, 'COM2'
	devheader com3, com4, 70h, (DEV_CHAR), \
		_DevStrategy, com3_interrupt, 'COM3'
	devheader com4, block, 70h, (DEV_CHAR), \
		_DevStrategy, com4_interrupt, 'COM4'

		; Block Device, pre-initialised to three units
	devheader block, -1, -1, (DEV_REMOVABLEMEDIA+ DEV_LOGICALMAPPING+ DEV_IOCTL), \
		_DevStrategy, block_interrupt, 3, "RXBLOCK"

	align 2
		; Comm LookAhead Buffer
Comm_LookAhead:		times 4 db 0			; COM1, COM2, COM3, COM4

		; CON variables
Con_LookAhead		dw 0
Con_TabPosition		dw 0
Con_ScanCode		db 0

	align 2
con_servicetable:	dw (.max - $ - 2) / 2
			dw _NoAction			; = 0, Init
			dw _NoAction			; = 1, Media Check
			dw _NoAction			; = 2, Build BPB
			dw _NoAction			; = 3, IOCTL Read
			dw ConRead			; = 4, Read
			dw ConNonDestrRead		; = 5, Nondestructive Read
			dw ConStatus			; = 6, Input Status
			dw ConInputFlush		; = 7, Input Flush
			dw ConWrite			; = 8, Write
			dw ConWrite			; = 9, Write With Verify
			dw _NoAction			; =10, Output Status
.max:

clock_servicetable:	dw (.max - $ - 2) / 2
			dw _NoAction			; = 0, Init
			dw _NoAction			; = 1, Media Check
			dw _NoAction			; = 2, Build BPB
			dw _IllegalFunction		; = 3, IOCTL Read
			dw ClockRead			; = 4, Read
			dw ClockRead			; = 5, Nondestructive Read
			dw _NoAction			; = 6, Input Status
			dw _NoAction			; = 7, Input Flush
			dw ClockWrite			; = 8, Write
			dw ClockWrite			; = 9, Write With Verify
			dw _NoAction			; =10, Output Status
.max:

prn_servicetable:	dw (.max - $ - 2) / 2
			dw _NoAction			; = 0, Init
			dw _NoAction			; = 1, Media Check
			dw _NoAction			; = 2, Build BPB
			dw _NoAction			; = 3, IOCTL Read
			dw _NoAction			; = 4, Read
			dw _NoAction			; = 5, Nondestructive Read
			dw _NoAction			; = 6, Input Status
			dw _NoAction			; = 7, Input Flush
			dw PrnWrite			; = 8, Write
			dw PrnWrite			; = 9, Write With Verify
			dw PrnStatus			; =10, Output Status
			dw _NoAction			; =11, Output Flush
			dw _NoAction			; =12, IOCTL Write
			dw _NoAction			; =13, Open Device
			dw _NoAction			; =14, Close Device
			dw _NoAction			; =15, Removable Media
			dw _NoAction			; =16, Output Until Busy
			dw _NoAction			; =17, unused
			dw _NoAction			; =18, unused
			dw _NoAction			; =19, Generic IOCTL
			dw _NoAction			; =20, unused
			dw _NoAction			; =21, unused
			dw _NoAction			; =22, unused
			dw _NoAction			; =23, Get Logical Device
			dw _NoAction			; =24, Set Logical Device
			dw _NoAction			; =25, IOCTL query
.max:


aux_servicetable:	dw (.max - $ - 2) / 2
			dw _NoAction			; = 0, Init
			dw _NoAction			; = 1, Media Check
			dw _NoAction			; = 2, Build BPB
			dw _NoAction			; = 3, IOCTL Read
			dw AuxRead			; = 4, Read
			dw AuxNonDestrRead		; = 5, Nondestructive Read
			dw _NoAction			; = 6, Input Status
			dw AuxInputFlush		; = 7, Input Flush
			dw AuxWrite			; = 8, Write
			dw AuxWrite			; = 9, Write With Verify
			dw AuxOutputStatus		; =10, Output Status
.max:

block_servicetable:	dw (.max - $ - 2) / 2
			dw _NoAction			; = 0, Init
			dw _hdMediaCheck		; = 1, Media Check
			dw _hdBuildBPB			; = 2, Build BPB
			dw _hdIOCTLRead			; = 3, IOCTL Read
			dw _hdRead			; = 4, Read
			dw _NoAction			; = 5, Nondestructive Read
			dw _NoAction			; = 6, Input Status
			dw _NoAction			; = 7, Input Flush
			dw _hdWrite			; = 8, Write
			dw _hdWriteWithVerify		; = 9, Write With Verify
			dw _NoAction			; =10, Output Status
			dw _NoAction			; =11, Output Flush
			dw _hdIOCTLWrite		; =12, IOCTL Write
			dw _hdOpenDevice		; =13, Open Device
			dw _hdCloseDevice		; =14, Close Device
			dw _hdRemovableMedia		; =15, Removable Media
			dw _NoAction			; =16, Output Until Busy
			dw _NoAction			; =17, unused
			dw _NoAction			; =18, unused
			dw _hdGenericIOCTL		; =19, Generic IOCTL
			dw _NoAction			; =20, unused
			dw _NoAction			; =21, unused
			dw _NoAction			; =22, unused
			dw _hdGetLogicalDevice		; =23, Get Logical Device
			dw _hdSetLogicalDevice		; =24, Set Logical Device
			dw _hdIOCTLQuery		; =25, IOCTL query
.max:

		; Device Strategy
		; 
		; Input:
		; es:bx -> request header
_DevStrategy:
	; cli
	mov word [ cs:Strategy + _segment ], es
	mov word [ cs:Strategy + _pointer ], bx
	retf

		; Device Interrupt
		; 
		; Input:
		; INP:	DWO [cs:Strategy] -> request header
		;	BY [cs:WO [ss:sp]] = logical unit number
		;	WO [cs:WO [ss:sp] + 1] -> strategy table
		; 
		; This appears to be a function, but is some common code that
		; *most* but not necessarily all functions jump to. On exit,
		; it must pop the near call's pointer and then return far.
_DevInterrupt:
	entry
	rarg	InfoPointer, 2
	def	LogicalUnit
	def	StrategyTable
	ddef	RequestBlock
	def	ServiceAddr

	cld
	SaveAllRegisters

	xor ax, ax
	mov si, [ bp + _InfoPointer ]
	cs lodsb
	mov word [ bp + _LogicalUnit ], ax
	cs lodsw
	mov word [ bp + _StrategyTable ], ax

	lds bx, [ cs:Strategy ]				; compliant strategy call
	stordarg _RequestBlock, ds, bx			; see text for compliance issues
%if 0
RxDOS 7.20N: This comment appears to refer to the book, Dissecting DOS,
		page 264, in chapter 5 File Management. Quoting:

Devices within DOS have an accessible device header that contains a
set of flags describing what services the device provides, for example,
whether it is a blocked or character device and the address of two entry
points. These are the strategy and interrupt entry points. The term
/interrupt/ here has nothing to do with hardware interrupts. If a device
driver provides interrupt handling support, it links directly to the
interrupt address vector in low memory. Rather, the strategy and interrupt
entry points are misnamed entry points. They would more aptly be named
request and execute entry points.

DOS chose a somewhat restrictive mechanism for communicating with device
drivers. This mechanism requires calling the device driver twice for every
function call. The first call is to the device driver's strategy entry point.
The caller must pass the request header or packet's address, which the
driver saves. The second call is to the driver's interrupt entry point. The
driver executes the request made in the previous call.

The unfortunate and restrictive aspect of this calling sequence relates
to their use in real-time applications. No application should interfere
between the two function calls made to a device driver. However, there is
no way to actually know that another application may be running, that a
device driver request was made, or that it may be interrupting a device
driver call in progress, except that the interface is restricted to being
used by DOS and DOS provides an in-use flag to prevent more than one
function call at a time. A somewhat better interface would have been a
single request/execute call.

To support the two-call strategy and execute requirement of device drivers,
RxDOS makes a single function call to an internal routine that handles the
driver protocol. These functions are CharDevRequest and BlockedDevRequest,
for character and block devices, respectively. These functions are also
responsible for detecting errors reported by device drivers, the only errors
for which error handling is required.

%endif
	sti

	xor ax, ax
	mov al, byte [ bx + rhFunction ]		; ax = function number
	mov si, word [ bp + _StrategyTable ]		; -> table
	cmp ax, word [ cs:si ]				; table entries count
	mov cx, _IllegalFunction			; default handler
	jae .got_service_address
	inc ax						; skip count word
	add ax, ax
	add si, ax					; -> table entry
	mov cx, word [ cs:si ]
.got_service_address:
	mov word [ bp + _ServiceAddr ], cx

	push bp						; device or BIOS might change bp
	mov ah, byte [ bx + mrMediaID ]
	mov al, byte [ bx + rhUnit ]
	mov cx, word [ bx + rwrBytesReq ]
	mov dx, word [ bp + _LogicalUnit ]		; passed to function
	mov word [ bx + rhStatus ], 0000

		; es:di-> buffer, if any
		; ds:bx-> packet
	les di, [ bx + rwrBuffer ]
	call word [ bp + _ServiceAddr ]
	pop bp						; device or BIOS may have changed bp

	lds bx, [ bp + _RequestBlock ]
	or word [ bx + rhStatus ], (OP_DONE)

	RestoreAllRegisters				; restore all other registers
	mov sp, bp

	pop bp
	add sp, byte 2					; get rid of info pointer
	retf


		; No Action
_NoAction:

	mov word [ bx + rwrStatus ], ( OP_DONE )
	retn


		; Illegal Function
_IllegalFunction:

	mov word [ bx + rwrStatus ], ( OP_EXITERROR + devErrUnknownCommand )
	mov word [ bx + rwrBytesReq ], 0000
	retn


	align 2
		; Strategies
clock_interrupt:
			call _DevInterrupt
			db 0
			dw clock_servicetable

prn_interrupt:
			call _DevInterrupt
			db 0
			dw prn_servicetable
lpt1_interrupt:
			call _DevInterrupt
			db 0
			dw prn_servicetable
lpt2_interrupt:
			call _DevInterrupt
			db 1
			dw prn_servicetable
lpt3_interrupt:
			call _DevInterrupt
			db 2
			dw prn_servicetable

aux_interrupt:
			call _DevInterrupt
			db 0
			dw aux_servicetable
com1_interrupt:
			call _DevInterrupt
			db 0
			dw aux_servicetable
com2_interrupt:
			call _DevInterrupt
			db 1
			dw aux_servicetable
com3_interrupt:
			call _DevInterrupt
			db 2
			dw aux_servicetable
com4_interrupt:
			call _DevInterrupt
			db 3
			dw aux_servicetable

con_interrupt:
			call _DevInterrupt
			db 0
			dw con_servicetable

block_interrupt:
			call _DevInterrupt
			db 0
			dw block_servicetable


		; Clock Read
		;
		; On Input:
		;
		; ds:bx-> request header
		; es:di-> CLOCKDATA buffer
		; cx = characters to transfer
		; dl = logical device
ClockRead:

	mov word [ bx + rwrBytesReq ], CLOCKDATA_size
	mov di, word [ bx + rwrBuffer + _pointer ]	; packet
	mov es, word [ bx + rwrBuffer + _segment ]
	call actualGetDate

	retn


		; Clock Write
		;
		; On Input:
		;
		; ds:bx-> request header
		; es:di-> CLOCKDATA buffer
		; cx = characters to transfer
		; dl = logical device
ClockWrite:

	entry
	ddef	packet, ds, bx
	ddef	buffer, es, di

	def	yearBCD
	def	monthBCD
	def	dayBCD
	ddef	ticks

	mov di, word [ bx + rwrBuffer + _pointer ]	; packet
	mov es, word [ bx + rwrBuffer + _segment ]
	stordarg _buffer, es, di

	mov al, byte [ es:di + cl_day ]
	call convToBCD					; day
	storarg _dayBCD, ax

	mov al, byte [ es:di + cl_month ]
	call convToBCD					; month
	storarg _monthBCD, ax

	mov ax, word [ es:di + cl_year ]
	mov cx, 100
	xor dx, dx
	div cx

	push dx						; save remainder
	call convToBCD					; year
	storarg _yearBCD, ax

	pop ax
	call convToBCD					; century
	mov cl, al
	mov ch, byte [ bp + _yearBCD ]

	mov dh, byte [ bp + _monthBCD ]
	mov dl, byte [ bp + _dayBCD ]
	mov ax, 0500h
	exint 1Ah					; set date

	getdarg es, di, _buffer
	mov al, byte [ es:di + cl_hours ]
	xor ah, ah
	mov cx, 60
	mul cx						; express hours in minutes

	add al, byte [ es:di + cl_minutes ]
	adc ah, 0
	mul cx						; express time in seconds

	add al, byte [ es:di + cl_seconds ]
	adc ah, 0
	mov cx, 182
	call _mul32					; express time in hseconds

	add al, byte [ es:di + cl_hseconds ]
	adc ah, 0
	adc dx, byte 0

	mov cx, 10
	call _div32					; express time in hseconds

	mov cx, dx
	mov dx, ax
	mov ax, 0100h
	exint 1Ah					; set date

	return


		; Get Days Since 1980
		;
		; Input:
		; cx = year (1980 - 2099)
		; dh = month (1 - 12)
		; dl = day (1 - 31)
		;
		; Output:
		; ax = days since 1980 format


getDaysSince1980:

	entry
	def	year, cx
	def	month, 0000
	def	day, 0000
	def	m14_12, 0000
	ddef	daysSince

	push bx
	push cx
	push dx

	mov byte [ _month + bp ], dh
	mov byte [ _day + bp ], dl

	dec dh
	jnz getDaysSince1980_06
	mov word [ _m14_12 + bp ], -1

getDaysSince1980_06:
	xor dx, dx
	mov ax, word [ _m14_12 + bp ]
	mov cx, 12
	mul cx					; *12
	inc ax
	inc ax					; 2
	sub ax, word [ _month + bp ]
	neg ax					; - m_14
	mov cx, 367
	mul cx

	xor dx, dx
	mov cx, 12
	div cx
	mov word [ _daysSince + _low + bp ], ax
	mov word [ _daysSince + _high + bp ], 0000

	mov ax, word [ _m14_12 + bp ]
	add ax, 4900
	add ax, word [ _year + bp ]

;;;	jdn = (long)(d - 32076)
;;;		+ 1461L * (y + 4800L + (m - 14) / 12) / 4
;;;		+ 367 * (m - 2 - (m - 14) / 12 * 12) / 12
;;;		- 3 * ((y + 4900L + (m - 14) / 12) / 100) / 4
;;;		+ 1;		/* correction by rdg */

	xor dx, dx
	mov cx, 100
	div cx

	mov cx, 3
	mul cx

	shr ax, 1
	shr ax, 1				; / 4
	dec ax
	sub word [ _daysSince + _low + bp ], ax
	sbb word [ _daysSince + _high + bp ], byte 0000

	mov ax, word [ _m14_12 + bp ]
	add ax, 4800
	add ax, word [ _year + bp ]

	mov cx, 1461
	mul cx

	; do a long shift here
	shr dx, 1
	rcr ax, 1
	shr dx, 1				; / 4
	rcr ax, 1
	add word [ _daysSince + _low + bp ], ax
	adc word [ _daysSince + _high + bp ], dx

	xor dx, dx
	mov ax, word [ _day + bp ]
	sub ax, 32076
	sbb dx, byte 0000
	add ax, word [ _daysSince + _low + bp ]
	adc dx, word [ _daysSince + _high + bp ]

	sub ax, 4BD0h
	sbb dx, byte 25h


%ifdef OLDDATE_LOGIC

	sub cx, 1980
	storarg _year, cx

	mov ax, 365
	mul cx					; rough estimate of days

	shr cx, 1
	shr cx, 1				; # leap years 
	inc cx					; adj for 1980
	add ax, cx				; days since
	storarg _daysSince, ax			; days since as of last year

	xor ax, ax
	getarg dx, _monthnDays
	mov bl, dh
	and bx, 255
	jz getDaysSince1980_08

getDaysSince1980_06:
	add al, byte [ cs:DaysInMonthTable + bx ]
	adc ah, 0
	dec bx
	jnz getDaysSince1980_06

getDaysSince1980_08:
	mov dh, 0				; days only in dx
	add ax, dx				; days this year
	cmp ax, byte 28				; between Jan 1 and Feb 28 ?
	jle getDaysSince1980_12		 ; yes -->

	test word [ _year + bp ], 11b	; this year a leap year ?
	jnz getDaysSince1980_12		 ; no -->
	inc ax					; we get one more day
	add ax, word [ _daysSince + bp ]
%endif

getDaysSince1980_12:
	pop dx
	pop cx
	pop bx
	Return


		; Get Date

		; 
		; Input:
		; es:di	buffer
		; 
		; Output:
		; es:di	buffer to store ClockData
		; ax	days since 1980 format


actualGetDate:

	entry
	ddef	buffer, es, di
	ddef	ticks
	def	daysSince1980
	def	seconds
	def	minutes
	def	hours
	def	century
	def	year
	def	month
	def	day


	xor ax, ax					; read real time clock 
	Exint 1Ah					; cx/dx contains time of day
	or al, al					; over 24 hours ?
	jz getDate_12					; no -->
	inc word [ _day + bp ]				; increment day.

getDate_12:
	stordarg _ticks, cx, dx				; save clock ticks

	mov ax, 0400h					; see if extended BIOS support
	mov cx, -1					; these will change if extended support
	mov dx, -1					; ch = BCD century	/ cl = BCD year
	Exint 1Ah					; dh = BCD month	/ dl = BCD day
	cmp cx, byte -1					; was date returned ?
	jz getDate_14					; no, we'll skip save -->

	push dx						; month/ day
	push cx						; century/ year
	mov al, ch					; century
	call ConvBCDToBin
	mov word [ _century + bp ], ax

	pop ax						; year
	call ConvBCDToBin
	mov word [ _year + bp ], ax

	pop dx
	push dx
	mov al, dh					; month
	call ConvBCDToBin
	mov word [ _month + bp ], ax

	pop ax						; day 
	call ConvBCDToBin
	mov word [ _day + bp ], ax

		; compute days since 1980
	mov ax, 100
	mul word [ _century + bp ]		 ; century
	add ax, word [ _year + bp ]
	mov cx, ax					; 1994, ... 2004, ...

	mov dh, byte [ _month + bp ]
	mov dl, byte [ _day + bp ]

	getdarg es, di, _buffer
	mov byte [ es:cl_day + di ], dl
	mov byte [ es:cl_month + di ], dh
	mov word [ es:cl_year + di ], cx
	call getDaysSince1980

	getdarg es, di, _buffer
	mov word [ es:cl_daysSince1980 + di ], ax
	storarg _daysSince1980, ax

		; compute time from ticks
getDate_14:
	mov ax, 0200h					; see if extended BIOS support
	mov cx, -1					; these will change if extended support
	mov dx, -1					; ch = BCD hours / cl = BCD minutes
	exint 1Ah					; dh = BCD seconds / dl = daylight savings time

	getdarg es, di, _buffer
	getdarg dx, ax, _ticks				; get clock ticks back
	mov cx, 10
	call _mul32					; ticks times 10

	mov cx, 182					; clock ticks per second
	call _div32

	push ax
	push dx
	xor dx, dx
	mov ax, 549
	call _mul32					; each tick is .0549 of a second

	mov cx, 100
	call _div32					; hundreds
	mov byte [ es:cl_hseconds + di ], cl

	pop dx
	pop ax
	mov cx, 60					; seconds per minute
	call _div32
	storarg _seconds, cx
	mov byte [ es:cl_seconds + di ], cl

	mov cx, 60					; minutes per hour
	call _div32
	storarg _minutes, cx
	storarg _hours, ax

	mov byte [ es:di + cl_minutes ], cl
	mov byte [ es:di + cl_hours ], al

	mov dl, byte [ es:di + cl_day ]
	mov dh, byte [ es:di + cl_month ]
	mov cx, word [ es:di + cl_year ]
	call getDaysSince1980

	getdarg es, di, _buffer
	mov word [ es:di + cl_daysSince1980 ], ax
	storarg _daysSince1980, ax

		; Convert to BCD form
	call convToBCD					; hours (already in AX) to BCD
	mov ch, al					; hours

	getarg ax, _minutes
	call convToBCD					; minutes
	mov cl, al					; minutes

	getarg ax, _seconds
	call convToBCD					; seconds
	mov dh, al					; seconds
	mov dl, 0					; daylight savings time (don't know)

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	Day of Week (not computed)
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -




	getarg ax, _daysSince1980
	Return


		; Code Segment Data


DaysInMonthTable:	db 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31


		; Convert AL to BCD form


convToBCD:

	mov ah, 0
	aam						; divide by ten
	shl ah, 1
	shl ah, 1
	shl ah, 1
	shl ah, 1					; shift four bits
	or al, ah					; BCD form
	mov ah, 0
	ret


		; Convert BCD to Binary


ConvBCDToBin:

	mov ah, al
	and al, 0Fh
	shr ah, 1
	shr ah, 1
	shr ah, 1
	shr ah, 1

	mov ch, ah					; 1
	add ah, ah					; 2
	add ah, ah					; 4
	add ah, ch					; 5
	add ah, ah					; 10
	add al, ah
	mov ah, 0
	ret


		; 32 Bit Multiply

		; 
		; Input:
		; dx:ax	numerator
		; cx	multiplier
		; 


_mul32:
	or dx, dx					; simple multiply ?
	jnz _mul32_12					; not really -->

	mul cx
	ret

_mul32_12:
	push bx
	mov bx, ax
	mov ax, dx
	mul cx
	xchg ax, bx

	mul cx
	add dx, bx
	pop bx						; restore bx
	ret


		; 32 Bit Divide

		; 
		; Input:
		; dx:ax	numerator
		; cx	divisor
		; 
		; Output:
		; dx:ax	answer
		; cx	remainder
		; 


_div32:
	or cx, cx					; protect from zero divisor
	stc						; in case of error
	jz _div32_return				; if so, just return with carry

	push bx
	mov bx, dx
	xchg ax, bx
	xor dx, dx
	div cx						; divide high order first

	xchg ax, bx
	div cx						; REMAINDER WILL BE IN DX
	mov cx, dx					; save remainder
	mov dx, bx					; full 32-bit answer
	pop bx

_div32_return:
	ret


		; Con Read (Fct 4)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device
		; 
		; for block devices:
		; 
		; ah	device media (old )
		; al	block device unit (a: = 0, ... )


ConRead:

	or cx, cx					; any input requested ?
	jz ConRead_22					; no, failsafe exit -->

ConRead_12:
	call getConData				 ; read from con device
	or al, al					; is data an extended char ?
	jnz ConRead_16					; no -->
	cmp cx, byte 1					; one character read ?
	jnz ConRead_12					; we'll ignore -->
	stosw						; else save entire 2 bytes
	xor cx, cx					; all read
	jmp short ConRead_22				; then return -->

ConRead_16:
	stosb						; fill data in buffer
	loop ConRead_12				 ; if more data -->

ConRead_22:
	sub word [ rwrBytesReq + bx ], cx
	ret


		; Con NonDestructive Read (Fct 5)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


ConNonDestrRead:

	mov ah, BIOS_ConStatus
	Int 16h					 ; see if characters waiting ?
	jz ConNonDestrRead_NoData			; none waiting -->

	mov byte [ ndrCharRead + bx ], al		; return lookahead character.
	ret

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	If no data
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

ConNonDestrRead_NoData:
	mov word [ ndrStatus + bx ], (OP_NODATA)
	ret


		; Con Status (Fct 6)
		; 
		; ds:bx	points to request header
		; cx	characters to transfer
		; dl	logical device
		; 
		; for block devices:
		; 
		; ah	device media (old )
		; al	block device unit (a: = 0, ... )


ConStatus:

	cmp word [ cs:Con_LookAhead ], byte 0000	; character in pending area ?
	jnz ConStatus_16				; yes -->

	mov ah, BIOS_ConStatus
	Int 16h						; see if characters waiting ?
	jz ConStatus_NoData				; none waiting -->

ConStatus_16:
	retn

		; If no data
ConStatus_NoData:
	mov word [ rhStatus + bx ], (OP_NODATA)
	retn


		; Con Input Flush (Fct 7)
		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


ConInputFlush:

	mov word [ cs:Con_LookAhead ], 0000		; flush input character

ConInputFlush_08:
	mov ah, BIOS_ConStatus
	Int 16h						; see if characters waiting ?
	jz ConInputFlush_NoData				; no more -->

	mov ah, BIOS_ConRead
	Int 16h						; read waiting character
	jmp short ConInputFlush_08			; test for more -->

ConInputFlush_NoData:
	retn


		; Con Write (Fcts 8, 9)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


ConWrite:

	or cx, cx
	jz ConWrite_38

ConWrite_08:
	mov al, byte [ es:di ]			; get character
	inc di

	cmp al, ControlJ				; line feed ?
	jz ConWrite_14					; yes -->
	cmp al, ControlM				; carriage return ?
	jz ConWrite_14					; yes -->
	cmp al, ControlI				; tab character ?
	jz ConWrite_22					; yes -->

	inc byte [ cs:Con_TabPosition ]		; tab position
	Int 29h					 ; internal Video Driver
	jmp short ConWrite_32

ConWrite_14:
	mov word [ cs:Con_TabPosition ], 0000	; set tab position
	Int 29h					 ; internal Video Driver
	jmp short ConWrite_32

ConWrite_22:
	mov al, ' '					; display a space
	Int 29h					 ; internal Video Driver

	inc byte [ cs:Con_TabPosition ]		; tab position
	test byte [ cs:Con_TabPosition ], 7	 ; tab position
	jnz ConWrite_14

ConWrite_32:
	loop ConWrite_08				; go get additional characters -->

ConWrite_38:
	ret


		; Get Con Character

		; ds:bx	points to request header
		; dl	logical device


getConData:

	xor ax, ax
	xchg ax, word [ cs:Con_LookAhead ]		; get char waiting
	or ax, ax					; any character waiting ?
	jnz getConData_08				; no -->

	mov ah, BIOS_ConRead
	Int 16h						; wait for character
	or ax, ax					; anything returned ?
	jz getConData					; continue looping -->

getConData_08:
	mov byte [ cs:Con_ScanCode ], ah		; save scan code
	ret


		; Prn Output Characters (Fct 8, 9)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


PrnWrite:

	or cx, cx
	jz PrnWrite_16

PrnWrite_08:
	mov bx, Prn_RetryCount

PrnWrite_10:
	mov ah, BIOS_PrnWrite
	mov al, byte [ es:di ]
	inc di
	Int 17h

	mov al, devErrDeviceNotReady
	test ax, Prn_IOError				; i/o error ?
	jnz PrnWrite_Retry				; yes -->

	test ax, Prn_TimeOut				; operation timed out ?
	jz PrnWrite_14					; no -->

PrnWrite_Retry:
	dec di
	dec bx
	jnz PrnWrite_10
	jmp short PrnWrite_WriteFault

PrnWrite_14:
	loop PrnWrite_08

PrnWrite_16:
	ret

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	If no data
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

PrnWrite_WriteFault:
	test ax, Prn_OutOfPaper
	jz PrnWrite_WriteFault_08
	mov al, devErrPrinterOutPaper

PrnWrite_WriteFault_08:
	or ax, OP_EXITERROR
	mov word [ rwrStatus + bx ], ax
	ret


		; Prn Output Status (Fct 10)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


PrnStatus:

	mov ah, BIOS_PrnStatus
	Int 17h

	;** this is wrong

	mov al, devErrDeviceNotReady
	test ax, Prn_OutOfPaper			 ; out of paper ?
	jz PrnStatus_08				 ; no -->
	mov al, devErrPrinterOutPaper

PrnStatus_08:
	xor ah, ah
	or ax, OP_EXITERROR
	mov word [ rwrStatus + bx ], ax
	ret


		; Com Read (Fct 4)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device
		; 
		; for block devices:
		; 
		; ah	device media (old )
		; al	block device unit (a: = 0, ... )


AuxRead:

	or cx, cx
	jz AuxRead_16

AuxRead_12:
	call getComData				 ; read from comm device
	test ax, (CommLS_FE + CommLS_PE + CommLS_OE)
	jnz AuxRead_Error				; if errors (no data or timeout) -->
	stosb						; fill data in buffer
	loop AuxRead_12				 ; if more data -->

AuxRead_16:
	mov word [ rwrBytesReq + bx ], 0000
	ret

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	if error
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

AuxRead_Error:
	sub word [ rwrBytesReq + bx ], cx
	mov word [ rwrStatus + bx ], (devErrReadFault + OP_EXITERROR)
	ret


		; Com NonDestructive Read (Fct 5)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


AuxNonDestrRead:

	call getComStatus				; read from comm device
	test ax, CommLS_DataAvail			; data available ?
	jz AuxNonDestrRead_NoData			; if no data -->
	test ax, CommMS_DSR				; DSR ?
	jz AuxNonDestrRead_NoData			; if no dsr -->

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	If Data Available, read data (lookahead)
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

	call getComData
	jnz AuxRead_Error				; if no data or timeout -->

	mov si, dx
	add si, Comm_LookAhead			; 
	mov byte [ cs:si ], al			; save waiting data.

	mov byte [ ndrCharRead + bx ], al		; return lookahead character.
	ret

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	If no data
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

AuxNonDestrRead_NoData:
	mov word [ ndrStatus + bx ], (OP_NODATA)
	ret


		; Aux Input Flush (Fct 7)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


AuxInputFlush:

	mov si, dx
	add si, Comm_LookAhead			; 
	mov byte [ cs:si ], 00			; flush input character
	ret


		; Aux Output Characters (Fct 8, 9)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


AuxWrite:

	or cx, cx
	jz AuxWrite_16

AuxWrite_12:
	mov ah, BIOS_ComWrite
	mov al, byte [ es:di ]
	inc di
	Int 14h
	test ax, CommLS_TimeOut
	jnz AuxWrite_WriteFault

	loop AuxWrite_12

AuxWrite_16:
	ret

;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
;	If no data
;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

AuxWrite_WriteFault:
	mov word [ rwrStatus + bx ], (devErrWriteFault + OP_EXITERROR)
	ret


		; Aux Output Status (Fct 10)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


AuxOutputStatus:

	mov ah, BIOS_ComStatus
	Int 14h
	test ax, CommMS_DSR
	jz AuxOutputStatus_08
	test ax, CommLS_HoldRegEmpty
	jnz AuxOutputStatus_12

AuxOutputStatus_08:
	mov word [ rwrStatus + bx ], OP_NODATA

AuxOutputStatus_12:
	ret


		; Get Com Character

		; ds:bx	points to request header
		; dl	logical device


getComData:

	mov si, dx
	add si, Comm_LookAhead			; 
	cmp byte [ cs:si ], 00			; data waiting ?
	jz getComData_08				; no -->

	xor ax, ax
	xchg al, byte [ cs:si ]			; get char waiting
	ret

getComData_08:
	mov ah, BIOS_ComRead
	Int 14h
	test ax, (CommLS_FE + CommLS_PE + CommLS_OE)	; errors ??
	ret


		; Get Com Status
		;
		; ds:bx	points to request header
		; dx	logical device
getComStatus:

	mov si, dx
	add si, Comm_LookAhead
	cmp byte [ cs:si ], 00				; data waiting ?
	jz getComStatus_08				; no -->

	mov ax, CommLS_DataAvail
	mov al, byte [ cs:si ]				; get char waiting
	retn

getComStatus_08:
	mov ah, BIOS_ComStatus
	Int 14h
	retn


		; General Interrupt Trap
IntReturn:
	iret


		; Interrupt 19 - Ctrl Alt Delete
Interrupt_19:
	cli
	cld

	xor ax, ax
	mov es, ax

	mov si, InterruptRestorationTable

.08:
	xor bx, bx
	mov bl, byte [ si ]
	cmp bl, -1
	jz .16

	inc si

	add bx, bx
	add bx, bx					; compute interrupt address
	mov dx, word [ si + 2 ]				; _segment
	mov ax, word [ si ]				; _pointer
							; restore interrupt
	mov word [ es:bx + 2 ], dx			; _segment
	mov word [ es:bx ], ax				; _pointer

	add si, byte 4
	jmp short .08

.16:
	int 19h					 	; go to original int 19
	iret


		; Interrupt 29
		; 
		; al	character to display
		;
		;  This default handler just gives the call to Int10.0E, Video BIOS display character
Interrupt_29:

	sti
	saveAllRegisters

	mov ah, 0Eh					; write teletype (parses CR, LF, Backspace, Bell)
	mov bx, 0007h					; default page 0, color 07
	Int 10h

	restoreAllRegisters
	iret


		; Block Device Media Descriptor
		; 
		; Input:
		; ds:bx	request header
		; es:di	buffer
		; cx	characters to transfer
_hdMediaCheck:

	entry
	ddef	packet, ds, bx

	mov al, byte [ bx + mrUnit ]			; get unit requested
	call BuildDiskParameterBlock			; es:di
	jc _hdMediaCheck_12

	getdarg ds, bx, _packet
	mov cl, byte [ es:di + _dskBPB + _bpbMediaDescriptor ]
	mov byte [ bx + mrMediaID ], cl			; media ID

	mov dx, word [ es:di + _dskSerialNumber + _high ]
	mov ax, word [ es:di + _dskSerialNumber + _low ]
	mov word [ bx + mrVolumeID + _high ], dx
	mov word [ bx + mrVolumeID + _low ], ax

	mov byte [ bx + mrReturn ], MEDIA_UNCHANGED
	test word [ es:di + _dskStatusFlag ], DiskChangeDetected
	jz _hdMediaCheck_12				; not changed -->
	mov byte [ bx + mrReturn ], MEDIA_HASCHANGED

_hdMediaCheck_12:
	push word [ bp + _packet + _segment ]
	push word [ bp + _packet + _pointer ]
	call SetInvalidDriveError			; if error, set error code -->
	return


		; Block Device Build BPB
		; 
		; Input:
		; ds:bx	request header
		; es:di	buffer
		; cx	characters to transfer
_hdBuildBPB:

	entry
	ddef	packet, ds, bx

	mov word [ bx + bbrBPBAddress + _pointer ], NULL
	mov word [ bx + bbrBPBAddress + _segment ], NULL

	mov al, byte [ bx + bbrUnit ]			; get unit requested
	call BuildDiskParameterBlock			; es:di
	jc _hdBuildBPB_12

	push di
	mov al, cl					; Media Descriptor
	lea di, [ di + _dskBPB ]

	getdarg ds, bx, _packet
	mov byte [ bx + bbrMediaID ], al		; media ID
	mov word [ bx + bbrBPBAddress + _pointer ], di
	mov word [ bx + bbrBPBAddress + _segment ], es
	pop di

	call stampTimerCount

_hdBuildBPB_12:
	push word [ bp + _packet + _segment ]
	push word [ bp + _packet + _pointer ]
	call SetInvalidDriveError			; if error, set error code -->
	return


		; Block Device Read Multiple Sectors
		; 
		; Input:
		; ds:bx	request header
		; es:di	buffer
		; cx	sectors to transfer
_hdRead:

	entry
	ddef	packet, ds, bx
	ddef	buffer, es, di
	ddef	diskparameters
	ddef	logSector
	def	numSectorsRemain, cx
	def	numSectorsRead, cx
	def	numSectorsTotal, 0000

	NormalizeBuffer es, di				; normalize address
	stordarg _buffer, es, di			; buffer address

	xor dx, dx
	mov ax, word [ bx + rwrStartSec ]		; get start sector address
	cmp ax, byte -1					; use huge instead ?
	jnz _hdRead_08					; if not -->

	mov ax, word [ bx + rwrHugeStartSec + _low ]	; get huge sector
	mov dx, word [ bx + rwrHugeStartSec + _high ]

_hdRead_08:
	stordarg _logSector, dx, ax

	mov al, byte [ bx + rwrUnit ]			; get unit requested
	call FindDiskParameterBlock			; make sure disk is fine
	stordarg _diskparameters, es, di
	jc _hdRead_Return

	cmp word [ bp + _numSectorsRemain ], byte 0000	; read zero sectors ?
	jz _hdRead_Return				; just a read test -->

	getdarg es, bx, _buffer				; buffer address
	getdarg dx, ax, _logSector
	getdarg ds, di, _diskparameters

	test byte [ di + _dskExtReadWrite ], 1
	jz .chs_read
.lba_read:
	call ExtendedRead
	jmp .common

.chs_read:
	call _nonLBARead
.common:
	mov word [ bp + _numSectorsTotal ], ax

_hdRead_Return:
	pushf
	push word [ bp + _packet + _segment ]
	push word [ bp + _packet + _pointer ]
	call SetInvalidDriveError			; if error, set error code

	getdarg es, di, _diskparameters
	call stampTimerCount

	getdarg ds, bx, _packet
	mov ax, word [ bp + _numSectorsTotal ]
	mov word [ bx + rwrBytesReq ], ax		; sectors read
	popf
	return


		; Block device write multiple sectors
		; 
		; Input:
		; ds:bx	request header
		; es:di	buffer
		; cx	sectors to write
_hdWrite:
_hdWriteWithVerify:

	entry
	ddef	packet, ds, bx
	ddef	buffer, es, di
	ddef	diskparameters
	ddef	logSector
	def	numSectorsRemain, cx
	def	numSectorsWrite, cx
	def	numSectorsTotal, 0000
	def	Verify, 0003h

	cmp byte [ bx + rhFunction ], DEVICEWRITEVERIFY
	jnz _hdWrite_06					; if just write
	storarg _Verify, 4h				; write with verify command

_hdWrite_06:
	NormalizeBuffer es, di				; normalize address
	stordarg _buffer, es, di			; buffer address

	xor dx, dx
	mov ax, word [ bx + rwrStartSec ]		; get start sector address
	cmp ax, byte -1					; use huge instead ?
	jnz _hdWrite_08					; if not -->

	mov ax, word [ bx + rwrHugeStartSec + _low ]	; get huge sector
	mov dx, word [ bx + rwrHugeStartSec + _high ]

_hdWrite_08:
	stordarg _logSector, dx, ax

	mov al, byte [ bx + rwrUnit ]			; get unit requested
	call FindDiskParameterBlock			; make sure disk is fine
	stordarg _diskparameters, es, di
	jc _hdWrite_Return

	cmp word [ bp + _numSectorsRemain ], byte 0000	; read zero sectors ?
	jz _hdWrite_Return				; just a Write test -->

	getdarg es, bx, _buffer				; buffer address
	getdarg dx, ax, _logSector
	getdarg ds, di, _diskparameters
	push word [ bp + _Verify ]

	test byte [ di + _dskExtReadWrite ], 1
	jz .chs_write
.lba_write:
	call ExtendedWrite
	jmp .common

.chs_write:
	call _nonLBAWrite
.common:
	mov word [ bp + _numSectorsTotal ], ax

_hdWrite_Return:
	pushf
	push word [ bp + _packet + _segment ]
	push word [ bp + _packet + _pointer ]
	call SetInvalidDriveError			; if error, set error code

	getdarg es, di, _diskparameters
	call stampTimerCount

	getdarg ds, bx, _packet
	mov ax, word [ bp + _numSectorsTotal ]
	mov word [ bx + rwrBytesReq ], ax		; sectors written
	popf
	return


		; Hard Disk Functions
		; 
		; Input:
		; es:bx	request header
_hdIOCTLRead:
_hdIOCTLWrite:
_hdOpenDevice:
_hdCloseDevice:
_hdGenericIOCTL:
_hdGetLogicalDevice:
_hdSetLogicalDevice:
_hdIOCTLQuery:
		jmp _NoAction


		; Is Media Removable
		; 
		; Input:
		; ds:bx	request header
		; es:di	buffer
_hdRemovableMedia:

	and word [ bx + rhStatus ], ~ OP_BUSY		; say not busy

	mov al, byte [ bx + rhUnit ]			; get unit requested
	call FindDiskParameterBlock			; make sure disk is fine

	test byte [ es:di + _dskPhysDriveNumber ], RxBIOS_FIXEDDRIVEMASK
	jz _hdRemovableMedia_12				; if removable unit -->
	or word [ bx + rhStatus ], OP_BUSY

_hdRemovableMedia_12:
	retn


		; Convert LBA to CHS address
		; 
		; Input:
		; INP:	ds:di-> disk parameter block address
		;	ax:dx	= LBA
		; OUT:	ds:di-> disk parameter block address
		;	ch = track
		;	cl = sector
		;	dh = head
		;	dl = unit
		; CHG:	ax
ConvertLBAtoCHS:

	add ax, word [ di + _dskExtHiddenSectors + _low ]
	adc dx, word [ di + _dskExtHiddenSectors + _high ]

	mov cx, word [ di + _dskBPB + _bpbSectorsPerTrack ]
	call _div32		; dx:ax = track number, cx = sector in track
	inc cx			; CHS sector-in-track is one-based
	push cx					 	; sector

	mov cx, word [ di + _dskBPB + _bpbHeads ]
	call _div32

	; track is at ax
	; head is at cx

	mov dh, cl					; head
	mov dl, byte [ di + _dskPhysDriveNumber ]	; unit

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


		; Read for non-LBA drives
		; 
		; Input:
		; es:bx	buffer
		; dx:ax	sector address
		; cx	sectors to transfer
		; ds:di	disk parameter block
_nonLBARead:
_NonLBARead:

	entry
	ddef	buffer, es, bx
	ddef	logSector, dx, ax
	ddef	diskparameters, ds, di
	def	numSectorsRemain, cx
	def	numSectorsRead, cx
	def	numSectorsTotal, 0000

	cmp word [ _numSectorsRemain + bp ], byte 0000; read zero sectors ?
	jz _NonLBARead_Return				; just a read test -->

_NonLBARead_12:
	getdarg ds, di, _diskparameters
	getdarg dx, ax, _logSector
	call ConvertLBAtoCHS

	test byte [ di + _dskBPB + _dskPhysDriveNumber ], RxBIOS_FIXEDDRIVEMASK
	jnz _NonLBARead_14				; read contiguous -->

	mov ax, word [ di + _dskBPB + _bpbSectorsPerTrack ]
	mov bx, cx					; sector
	and bx, byte 003Fh				; drop high order cyl portion
	sub ax, bx					; sectors remaining in track
	inc ax						; number is inclusive
	cmp ax, word [ bp + _numSectorsRemain ]		; more than sectors requested ?
	jc _NonLBARead_14				; if carry, only allow max -->
	mov ax, word [ bp + _numSectorsRemain ]		; more than sectors requested ?

_NonLBARead_14:
	getdarg es, bx, _buffer				; buffer address
	NormalizeBuffer es, bx				; normalize address
	stordarg _buffer, es, bx

	call maxReadBlock
	jc _NonLBARead_Return				; if error -->

	mov word [ bp + _numSectorsRead ], ax		; number sectors read
	add word [ bp + _numSectorsTotal ], ax		; total 
	add word [ bp + _logSector + _low ], ax
	adc word [ bp + _logSector + _high ], byte 0000

	xchg ah, al
	add ax, ax					; quick multiply by 200 hex
	add word [ bp + _buffer + _pointer ], ax	; adjust pointer

	mov ax, word [ bp + _numSectorsRead ]
	sub word [ bp + _numSectorsRemain ], ax		; compute how many more to go 
	ja _NonLBARead_12				; if more to go -->
	clc

_NonLBARead_Return:
	getarg ax, _numSectorsTotal
	return


		; Maximize Address Around FE Boundary
		;
		; Input:
		; ax	sectors to read
		; es:bx	buffer address
		;
		; Output:
		; es:bx	buffer address fixed
maxReadBlock:

	entry 
	def	blocks, ax
	def	ifdmabuffer, FALSE
	ddef	userbuffer, es, bx
	defbytes	dmabuffer, sizeSECTOR

	push cx
	call CheckDMABoundaryCondition
	stordarg _userbuffer, es, bx
	storarg _blocks, ax				; max blocks can read safely
	jnc maxReadBlock_16				; block count is within limits -->

	setes ss
	lea bx, [ bp + _dmabuffer ]
	mov word [ bp + _ifdmabuffer ], TRUE

maxReadBlock_16:
	pop cx
	mov ah, 02h					; read function
	call DiskFunctionsWithRetry			; perform read
	jc maxReadBlock_32				; if succeeded -->

	cmp word [ bp + _ifdmabuffer ], byte FALSE
	jz maxReadBlock_28				; if dma buffer not used -->

	push ds
	setds ss
	mov cx, sizeSector
	lea si, [ bp + _dmabuffer ]
	getdarg es, di, _userbuffer
	fastmove					; move buffer
	pop ds

maxReadBlock_28:
	clc

maxReadBlock_32:
	getdarg es, bx, _userbuffer
	getarg ax, _blocks
	return


		; Write for non-LBA drives
		; 
		; Input:
		; es:bx	buffer
		; dx:ax	sector address
		; cx	sectors to transfer
		; di	disk parameter block
_nonLBAWrite:
_NonLBAWrite:

	entry 1
	arg	Verify

	ddef	buffer, es, bx
	ddef	logSector, dx, ax
	ddef	diskparameters, ds, di
	def	numSectorsRemain, cx
	def	numSectorsWritten, 0000
	def	numSectorsTotal, 0000

	cmp word [ bp + _numSectorsRemain ], byte 0000	; read zero sectors ?
	jz _NonLBAWrite_Return				; just a write test -->

_NonLBAWrite_12:
	getdarg ds, di, _diskparameters
	getdarg dx, ax, _logSector
	call ConvertLBAtoCHS

	test byte [ di + _dskBPB + _dskPhysDriveNumber ], RxBIOS_FIXEDDRIVEMASK
	jnz _NonLBAWrite_14				; read contiguous -->

	mov ax, word [ di + _dskBPB + _bpbSectorsPerTrack ]
	mov bx, cx					; sector
	and bx, byte 003Fh				; drop high order cyl portion
	sub ax, bx					; sectors remaining in track
	inc ax						; number is inclusive
	cmp ax, word [ bp + _numSectorsRemain ]		; more than sectors requested ?
	jc _NonLBAWrite_14				; if carry, only allow max -->
	mov ax, word [ bp + _numSectorsRemain ]		; more than sectors requested ?

_NonLBAWrite_14:
	getdarg es, bx, _buffer				; buffer address
	NormalizeBuffer es, bx				; normalize address
	stordarg _buffer, es, bx

	push word [ bp + _Verify ]			; pass verify arg on stack
	call maxWriteBlock				; perform actual write
	jc _NonLBAWrite_Return				; if error -->

	mov word [ bp + _numSectorsWritten ], ax	; number sectors written
	add word [ bp + _numSectorsTotal ], ax		; total 
	add word [ bp + _logSector + _low ], ax
	adc word [ bp + _logSector + _high ], byte 0000

	xchg ah, al
	add ax, ax					; quick multiply by 200 hex
	add word [ bp + _buffer + _pointer ], ax	; adjust pointer

	mov ax, word [ bp + _numSectorsWritten ]
	sub word [ bp + _numSectorsRemain ], ax		; compute how many more to go 
	jg _NonLBAWrite_12				; if more to go -->

	clc

_NonLBAWrite_Return:
	getarg ax, _numSectorsTotal
	return


		; Maximize Address Around FE Boundary
		; 
		; Input:
		; ax	sectors to read
		; cx:dx	sector address
		; es:bx	buffer address
		; 
		; Output:
		; es:bx	buffer address fixed
maxWriteBlock:

	entry 1
	arg	writeCommand

	def	blocks, ax
	def	ifdmabuffer, FALSE
	ddef	userbuffer, es, bx
	defbytes	dmabuffer, sizeSECTOR

	push cx
	call CheckDMABoundaryCondition
	stordarg _userbuffer, es, bx
	storarg _blocks, ax				; max blocks can write safely
	jnc maxWriteBlock_16				; block count is within limits -->

	push ds
	setes ss
	mov cx, sizeSector
	getdarg ds, si, _userbuffer
	lea di, [ bp + _dmabuffer ]
	mov bx, di					; save buffer address
	fastmove					; move buffer
	pop ds

	mov word [ bp + _ifdmabuffer ], TRUE
	storarg _blocks, 1				; one sector

maxWriteBlock_16:
	pop cx
	getarg ax, _blocks
	mov ah, byte [ bp + _writeCommand ]		; write function
	call DiskFunctionsWithRetry			; perform write

maxWriteBlock_32:
	getdarg es, bx, _userbuffer
	getarg ax, _blocks
	return


		; Check DMA Boundary Condition
		; 
		; Input:
		; ax	sectors to read
		; es:bx	buffer address
		; 
		; Output:
		; es:bx	normalized buffer address
		; cy	if must read only one buffer block
CheckDMABoundaryCondition:

	push cx
	NormalizeBuffer es, bx				; normalize address

	mov cx, ax					; _blocks
	cmp cx, 64 * (1024 / SIZESECTOR)		; cannot exceed 64 k
	jc CheckDMABoundary_08				; if within 64 k -->
	mov cx, 64 * (1024 / SIZESECTOR)		; cannot exceed 64 k

CheckDMABoundary_08:
	mov ax, es
	and ax, 0FFFh
	sub ax, 0FE0h
	neg ax
	jle CheckDMABoundary_14
	shr ax, 1
	shr ax, 1
	shr ax, 1
	shr ax, 1
	shr ax, 1
	or ax, ax
	jz CheckDMABoundary_14
	cmp ax, cx					; _blocks
	jnc CheckDMABoundary_16				; block count is within limits -->

	clc
	mov cx, ax					; max blocks can read safely
	jmp short CheckDMABoundary_16			; block count is within limits -->

CheckDMABoundary_14:
	mov cx, 1					; force one sector
	stc

CheckDMABoundary_16:
	mov ax, cx
	pop cx
	retn


		; Rebuild BIOS Parameter Block (if disk changed)
		; 
		; Input:
		; es:di	disk parameter block address (unitialized)
		; 
		; Output:
		; es:di	disk parameter block address, if carry not set.
		; zr	if diskette not changed
		; nz	if diskette changed
_ChangedLineSet:

	push es
	push di
	and word [ es:di + _dskStatusFlag ], byte ~ DiskChangeDetected
	cmp byte [ es:di + _dskDeviceType ], -1		; device entry not initialized ?
	jz _ChangedLineSet_ChangeLineSet		; set as changed -->
	test word [ es:di + _dskStatusFlag ], IsNonRemovable
	jnz _ChangedLineSet_notChanged

	call GetTimerCount				; timer count into dx:ax
	sub ax, word [ es:di + _dskClockAtLastOp + _low ]
	sbb dx, word [ es:di + _dskClockAtLastOp + _high ]
	cmp ax, byte 18 * 2				; within 2 seconds ?
	jc _ChangedLineSet_notChanged			; line not changed -->

	mov ah, 16h
	mov dl, byte [ es:di + _dskPhysDriveNumber ]
	call DiskFunctions				; see if change line set
	; jc _ChangedLineSet_ChangeLineSet		; assume changed -->
	cmp ah, 06h					; diskette change line set ?
	jnz _ChangedLineSet_notChanged

_ChangedLineSet_ChangeLineSet:
	or word [ es:di + _dskStatusFlag ], byte DiskChangeDetected

_ChangedLineSet_notChanged:
	pop di
	pop es
	test word [ es:di + _dskStatusFlag ], DiskChangeDetected
	retn


		; Get BIOS Timer Count
		; 
		; Output:
		; dx:ax	BIOS Timer Value
GetTimerCount:

	push es
	push di
	xor ax, ax
	mov es, ax
	; mov di, 46Ch
	mov ax, word [ es:46Ch ]
	mov dx, word [ es:46Eh ]

	pop di
	pop es
	retn


		; Get BIOS Timer Count
		; 
		; Output:
		; dx:ax	BIOS Timer Value
stampTimerCount:

	push ax
	push dx
	push es
	push di

	xor ax, ax
	mov es, ax
	; mov di, 46Ch
	mov ax, word [ es:46Ch ]
	mov dx, word [ es:46Eh ]

	pop di
	pop es
	mov word [ es:di + _dskClockAtLastOp + _low ], ax
	mov word [ es:di + _dskClockAtLastOp + _high ], dx

	pop dx
	pop ax
	retn


		; Rebuild BIOS Parameter Block (if disk changed)
		; 
		; Input:
		; es:di	disk parameter block address
		; 
		; Output:
		; es:di	disk parameter block address, if carry not set
		; cy	if error
RebuildBPB:

	entry
	ddef	dskParameterTable, es, di

	push ds
	setds cs				; (used to access DiskBuffer)

		; Rebuild BIOS Parameter Block
_RebuildBPB_12:
	getdarg ds, di, _dskParameterTable		; ds:di -> UPB
	push cs
	pop es
	mov bx, RxBIO_DiskBuffer			; es:bx -> DiskBuffer

	xor ax, ax
	xor dx, dx					; dx:ax = sector number

	mov cx, 1					; cx = 1

	test byte [ di + _dskExtReadWrite ], 1
	jz .chs_read
.lba_read:
	call ExtendedRead
	jmp .common

.chs_read:
	call _nonLBARead
.common:
	jc _RebuildBPB_38
	push cs
	pop ds

		; Copy standard boot sector info
	getdarg es, di, _dskParameterTable
	lea si, [ RxBIO_DiskBuffer + _bsBytesPerSector ]
	lea di, [ di + _dskBPB ]
	mov cx, sizeBPB
	repe movsb

	mov di, word [ bp + _dskParameterTable + _pointer ]
	mov byte [ es:di + _dskDeviceType ], DSKFILESYSTYPE_IsValid

	mov ax, word [ RxBIO_DiskBuffer + _bsVolumeId + _low ]
	mov dx, word [ RxBIO_DiskBuffer + _bsVolumeId + _high ]
	mov word [ es:di + _dskSerialNumber + _low ], ax
	mov word [ es:di + _dskSerialNumber + _high ], dx

	mov dl, byte [ es:di + _dskPartitionEndCylinder ]
	mov dh, byte [ es:di + _dskPartitionEndSector ]
	rol dh, 1
	rol dh, 1
	and dx, 3ffh

	mov cl, byte [ es:di + _dskPartitionBeginCylinder ]
	mov ch, byte [ es:di + _dskPartitionBeginSector ]
	rol ch, 1
	rol ch, 1
	and cx, 3ffh
	sub dx, cx
	inc dx
	mov word [ es:di + _dskCylinders ], dx

		; see if Extended LBA Supported
	mov word [ es:di + _dskExtReadFct ], _nonLBARead
	mov word [ es:di + _dskExtWriteFct ], _nonLBAWrite

	mov dl, byte [ es:di + _dskPhysDriveNumber ]
	call seeIfSupportsExtendedReadWrite
	mov byte [ es:di + _dskExtReadWrite ], al
	jc _RebuildBPB_24

	mov word [ es:di + _dskExtReadFct ], ExtendedRead
	mov word [ es:di + _dskExtWriteFct ], ExtendedWrite

		; see if FAT32 logical drive
_RebuildBPB_24:
	mov al, byte [ es:di + _dskFATSystemType ]	; get logical device type
	call isFAT32Device				; is device FAT32 ?
	jnz _RebuildBPB_34				; no -->

	mov ax, word [ RxBIO_DiskBuffer + _bsxVolumeId + _low ]
	mov dx, word [ RxBIO_DiskBuffer + _bsxVolumeId + _high ]
	mov word [ es:di + _dskSerialNumber + _low ], ax
	mov word [ es:di + _dskSerialNumber + _high ], dx

	mov word [ es:di + _dskBPB + _bpbSectorsPerFat ], 0000

	lea si, [ RxBIO_DiskBuffer + _bsxBigSectorsPerFat ]
	lea di, [ di + _dskBPB + _bpbxBigSectorsPerFat ]
	mov cx, ( _bpbxReserved - _bpbxBigSectorsPerFat )
	rep movsb

	getdarg ds, di, _dskParameterTable		; ds:di -> UPB
	push cs
	pop es
	mov bx, RxBIO_DiskBuffer			; es:bx -> DiskBuffer

	mov ax, word [ es:di + _dskBPB + _bpbxFSINFOSector ]
	xor dx, dx					; dx:ax = sector number

	mov cx, 1					; cx = 1

	test byte [ di + _dskExtReadWrite ], 1
	jz .chs_read
.lba_read:
	call ExtendedRead
	jmp .common

.chs_read:
	call _nonLBARead
.common:
	jc _RebuildBPB_38
	push cs
	pop ds

	mov si, RxBIO_DiskBuffer + sizeSector - (BIGFATBOOTFSINFO_size) - 4
	les di, [ bp + _dskParameterTable ]
	mov cx, word [ si + _bfFSInfoFreeClusterCnt + _high ]
	mov dx, word [ si + _bfFSInfoFreeClusterCnt + _low ]
	mov word [ es:di + _dskBPB + _bpbxFreeClusters + _low ], dx
	mov word [ es:di + _dskBPB + _bpbxFreeClusters + _high ], cx

	mov cx, word [ si + _bfFSInfoNextFreeCluster + _high ]
	mov dx, word [ si + _bfFSInfoNextFreeCluster + _low ]
	mov word [ es:di + _dskBPB + _bpbxNextFreeCluster + _low ], dx
	mov word [ es:di + _dskBPB + _bpbxNextFreeCluster + _high ], cx

		; Return with media descriptor
_RebuildBPB_34:
	les di, [ bp + _dskParameterTable ]
	mov cl, byte [ es:di + _dskBPB + _bpbMediaDescriptor ]
	clc

_RebuildBPB_38:
	pop ds
	Return


		; Is Logical Drive FAT32
		; 
		; Input:
		; al	PTT
		; 
		; Output:
		; zr	if FAT32 partition
isFAT32Device:

	cmp al, FILESYSID_FAT32			 	; FAT32
	jz _isFAT32Device_08				; yes -->
	cmp al, FILESYSID_FAT32LBA			; FAT32 LBA
_isFAT32Device_08:
	retn


		; Init Reset Drive
		;
		; 
		; Input:
		; es:di	disk parameter block address, if carry not set.
		; 
		; Output:
		; cy	if error
InitResetDrive:

	cmp byte [ es:di + _dskDeviceType ], -1		; device entry not initialized ?
	clc						; (set no error )
	jnz InitResetDrive_08				; if already initialized -->

	mov word [ es:di + _dskStatusFlag ], 0000	; no flags

	mov dl, byte [ es:di + _dskPhysDriveNumber ]
	test dl, RxBIOS_FIXEDDRIVEMASK			; fixed drive ?
	jz InitResetDrive_06				; no -->
	or word [ es:di + _dskStatusFlag ], byte IsNonRemovable

InitResetDrive_06:
	mov ah, 00h
	call DiskFunctions				; reset drive

	push es
	push di
	or word [ es:di + _dskStatusFlag ], byte ActiveUnit

	mov ax, 0800h
	mov dl, byte [ es:di + _dskPhysDriveNumber ]
	call DiskFunctionsWithRetry			; get disk parameters

	mov bx, es
	or bx, di					; disk parameter table == 0 ?
	pop di
	pop es						; restore pointr to 
	jnz InitResetDrive_08				; if valid drive -->
	and word [ es:di + _dskStatusFlag ], byte ~ ActiveUnit
	stc						; set carry (error ) flag

InitResetDrive_08:
	ret


		; Build Disk Parameter Block
		;
		; Input:
		; al	DOS disk unit.
		;
		; Output:
		; es:di	Disk Parameter Block Address, if carry not set.
		; cy	if error.
BuildDiskParameterBlock:

	cmp word [ cs:ptrStartBlockedDeviceTable + _segment ], byte 0000
	jz _buildBPB_Error				; if not initialized -->

	les di, [ cs:ptrStartBlockedDeviceTable ]

_buildBPB_08:
	cmp al, byte [ es:di + _dskDOSLogicalDiskUnit ]
	je _buildBPB_12					; if logical unit ->

	cmp word [ es:di + _dskNextPointer + _pointer ], byte -1
	je _buildBPB_Error				; if end of list -->

	les di, [ es:di + _dskNextPointer ]
	jmp short _buildBPB_08				; if not found, try next -->

		; if never initialized or disk change suspected, rebuild BPB
_buildBPB_12:
	call InitResetDrive				; is drive valid ?
	jc _buildBPB_Error				; no -->

	test word [ es:di + _dskStatusFlag ], ActiveUnit
	jz _buildBPB_Error				; if unit is invalid -->
	call _ChangedLineSet				; see if removable
	jz _buildBPB_20					; if line not changed -->

	call RebuildBPB					; else rebuild BPB
	jc _buildBPB_Error				; exit if no error -->

_buildBPB_20:
	clc
	retn

_buildBPB_Error:
	stc
	retn


		; Find Block Device Info
		; 
		; Input:
		; al	DOS disk unit
		; 
		; Output:
		; es:di	Disk Parameter Block Address, if carry not set
		; cy	if error
FindDiskParameterBlock:

	cmp word [ cs:ptrStartBlockedDeviceTable + _segment ], byte 0000
	jz _findBPB_Error				; if not initialized -->

	les di, [ cs:ptrStartBlockedDeviceTable ]

_findBPB_08:
	cmp al, byte [ es:di + _dskDOSLogicalDiskUnit ]
	jz _findBPB_12					; if logical unit ->

	cmp word [ es:di + _dskNextPointer + _pointer ], byte -1
	jz _findBPB_Error				; if end of list -->

	les di, [ es:di + _dskNextPointer ]
	jmp short _findBPB_08

		; if never initialized or disk change suspected, rebuild BPB
_findBPB_12:
	cmp byte [ es:di + _dskDeviceType ], -1		; device entry not initialized ?
	jnz _findBPB_14					; if already init -->
	call InitResetDrive				; is drive valid ?
	jc _findBPB_Error				; if error -->

_findBPB_14:
	test word [ es:di + _dskStatusFlag ], ActiveUnit
	jz _findBPB_Error				; if unit is invalid -->
	call _ChangedLineSet				; see if removable
	jz _findBPB_20					; if line not changed -->
	call RebuildBPB				; else rebuild BPB
	jc _findBPB_Error				; exit if no error -->

_findBPB_20:
	clc
	retn

_findBPB_Error:
	stc
	retn


		; Disk Functions
DiskFunctions:
	push bp
	int 13h
	pop bp
	; call SetDiskError
	retn


		; Disk Functions
DiskFunctionsWithRetry:

	entry
	def	retries, 03
	def	errorcode
	def	drive, dx
	def	function, ax

DiskFctRetry_08:
	push bp
	int 13h
	pop bp
	jnc DiskFctRetry_12

	mov byte [ bp + _errorcode ], ah

	push bp
	mov ah, 00h
	mov dl, byte [ bp + _drive ]
	int 13h
	pop bp

	mov ax, word [ bp + _function ]
	dec word [ bp + _retries ]
	jnz DiskFctRetry_08

	mov ah, byte [ bp + _errorcode ]
	stc

DiskFctRetry_12:
	return


		; See if Int13 Extended read/write supported
		; 
		; Input:
		; dl	physical unit
		; 
		; Output:
		; cy	not supported
		; ax	true if supported/false otherwise
seeIfSupportsExtendedReadWrite:

	test dl, 80h					; hard disk?
	jz _extendedReadWrite_NotSupported		; otherwise assume no LBA available -->

	mov ax, 4100h					; Int13 Extended installation check
	mov bx, 55AAh					; Magic value
	int 13h
	jc _extendedReadWrite_NotSupported

	cmp bx, 0AA55h					; ensure pattern reversed
	jne _extendedReadWrite_NotSupported		; if not, then not supported -->

	test cl, 01h					; Support bitmap
	jz _extendedReadWrite_NotSupported		;  Extended read/write not supported?
	; NC after test

	mov ax, True
	retn

_extendedReadWrite_NotSupported:
	stc
	mov ax, False
	retn


		; Extended Read
		; 
		; Input:
		; cx	num blocks
		; dx:ax	sector address
		; es:bx	buffer address
		; ds:di	disk parameter block
		; 
		; Output:
		; cy	not supported
		; ax	number sectors actually transferred
ExtendedRead:

	entry
	def	unit
	def	numblocks, cx
	ddef	buffer, es, bx
	ddef	diskParameterBlock, ds, di
	ddef	sectoraddress, dx, ax
	defbytes	packet, sizeEXTENDEDREQUESTPACKET

	add ax, word [ di + _dskExtHiddenSectors + _low ]
	adc dx, word [ di + _dskExtHiddenSectors + _high ]
	stordarg _sectoraddress, dx, ax

	xor dh, dh
	mov dl, byte [ di + _dskPhysDriveNumber ]	; unit
	storarg _unit, dx

	setes ss
	lea di, [ bp + _packet ]
	clearMemory sizeEXTENDEDREQUESTPACKET

	mov byte [ bp + _packet + _lbaSize ], sizeEXTENDEDREQUESTPACKET
	mov word [ bp + _packet + _lbaNumBlocks ], cx

	getdarg es, bx, _buffer
	NormalizeBuffer es, bx				; normalize address
	mov word [ bp + _packet + _lbaTransferAddress + _segment ], es
	mov word [ bp + _packet + _lbaTransferAddress + _pointer ], bx

	; (Cylinder*NumHeads + SelectedHead) * SectorPerTrack + SelectedSector - 1

	getdarg dx, ax, _sectoraddress
	mov word [ bp + _packet + _lbaAbsBlockNumber + _LOW ], ax
	mov word [ bp + _packet + _lbaAbsBlockNumber + _HIGH ], dx

	setds ss
	mov ax, 4200h
	getarg dx, _unit
	lea si, [ bp + _packet ]
	int 13h

	mov ax, word [ bp + _packet + _lbaNumBlocks ]
	return


		; Extended Write
		; 
		; Input:
		; cx	num blocks
		; dx:ax	sector address
		; es:bx	buffer address
		; ds:di	disk parameter block
		; 
		; Output:
		; cy	not supported
		; ax	number sectors actually transferred
ExtendedWrite:

	entry 1
	arg	Verify

	def	unit
	def	numblocks, cx
	ddef	buffer, es, bx
	ddef	diskParameterBlock, ds, di
	ddef	sectoraddress, dx, ax
	defbytes	packet, sizeEXTENDEDREQUESTPACKET

	or word [ bp + _Verify ], byte 40h

	add ax, word [ di + _dskExtHiddenSectors + _low ]
	adc dx, word [ di + _dskExtHiddenSectors + _high ]
	stordarg _sectoraddress, dx, ax

	xor dh, dh
	mov dl, byte [ di + _dskPhysDriveNumber ]	; unit
	storarg _unit, dx

	setes ss
	lea di, [ bp + _packet ]
	clearMemory sizeEXTENDEDREQUESTPACKET

	mov byte [ bp + _packet + _lbaSize ], sizeEXTENDEDREQUESTPACKET
	mov word [ bp + _packet + _lbaNumBlocks ], cx

	getdarg es, bx, _buffer
	NormalizeBuffer es, bx				; normalize address
	mov word [ bp + _packet + _lbaTransferAddress + _segment ], es
	mov word [ bp + _packet + _lbaTransferAddress + _pointer ], bx

	; (Cylinder*NumHeads + SelectedHead) * SectorPerTrack + SelectedSector - 1

	getdarg dx, ax, _sectoraddress
	mov word [ bp + _packet + _lbaAbsBlockNumber + _LOW ], ax
	mov word [ bp + _packet + _lbaAbsBlockNumber + _HIGH ], dx

	setds ss
	xor ax, ax
	getarg dx, _unit
	mov ah, byte [ bp + _Verify ]
	lea si, [ bp + _packet ]
	int 13h

	mov ax, word [ bp + _packet + _lbaNumBlocks ]
	Return


		; Disk Functions
		;
		; AX	contains BIOS error status
setPacketReqError:

	entry 2
	darg	packet
	jnc setPacketReqError_08			; if not an error -->

	pushf
	push ds
	push bx
	call convertErrorCodefromBIOSStatus

	getdarg ds, bx, _packet
	mov word [ bx + rhStatus ], ax			; set error flag

	pop bx
	pop ds
	popf

setPacketReqError_08:
	return


		; Error Trap Functions
SetInvalidDriveError:

	entry 2
	darg	packet
	jnc SetInvalidDriveError_08

	pushf
	push ds
	push bx
	getdarg ds, bx, _packet
	mov word [ bx + rhStatus ], devErrUnknownUnit + OP_ERROR

	pop bx
	pop ds
	popf

SetInvalidDriveError_08:
	return


		; Disk Functions
		;
		; AX	contains BIOS error status
convertErrorCodefromBIOSStatus:

	xor bx, bx
	mov bl, ah					; BIOS error code to index register
	mov ax, devErrDeviceNotReady
	cmp bx, dskErrDriveTimeOut
	jz convErr_08
	cmp bx, dskErrDriveNotReady
	jz convErr_08

	xor ax, ax
	cmp bx, strict word Max_BIOSErrorCodeTable
	jnc convErr_08
	mov al, byte [ cs:bx + BIOSErrorCodeTable ]

convErr_08:
	or ax, OP_ERROR
	retn


BIOSErrorCodeTable:

	db 0						;  0 - dskErrNoError
	db devErrBadDriveReq				;  1 - dskErrInvalidParameter
	db devErrBadDriveReq				;  2 - dskErrAddrMarkNotFound
	db devErrWriteProtectViol			;  3 - dskErrWriteProtected
	db devErrSectorNotFound				;  4 - dskErrSectorNotFound
	db devErrGeneralFailure				;  5 - dskErrResetFailed
	db devErrGeneralFailure				;  6 - dskErrDisketteRemoved
	db devErrGeneralFailure				;  7 - dskErrBadParameterTable
	db devErrGeneralFailure				;  8 - dskErrDMAOverrun
	db devErrGeneralFailure				;  9 - dskErrCross64kBoundary
	db devErrGeneralFailure				; 10 - dskErrBadSector
	db devErrGeneralFailure				; 11 - dskErrBadCylinder
	db devErrGeneralFailure				; 12 - dskErrMediaTypeNotFound
	db devErrGeneralFailure				; 13 - dskErrInvalidNumSectors
	db devErrGeneralFailure				; 14 - dskErrControlAddrMark
	db devErrGeneralFailure				; 15 - dskErrDMAArbOutOfRange
	db devErrCRCerr					; 16 - dskErrCRCerror
	db devErrCRCerr					; 17 - dskErrECCCorrectedErr

Max_BIOSErrorCodeTable		equ ($ - BIOSErrorCodeTable - 1)


		; Reallocated Space
	align 16
RxBIO_DiskBuffer:
	times 8192 + 16 db 0



%if 0

biocode - RxDOS Basic Input/Output kernel

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

(c) Copyright 1990, 1999. Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

%if 0

Boot sequence is
 
ldosmbr (master boot record)
 loads at 0:7C00h, relocated to 60h:0
 located at LBA 0 (cyl: 0 head: 0 sector: 1)
 
boot12/16/32 (partition boot record) - ldosboot
 loads at 0:7C00h
 located at start of partition (in partition's logical sector 0)
 FSIBOOT: located in FAT32 partition's FSINFO sector

iniload - ldosboot
 loaded at eg 70h:0 (entry :400h), loads remainder of BIO + DOS
 located at beginning of RxDOS.COM

RxDOS
 located in RxDOS.COM (lDOSLOAD.BIN portion)
 provides user-level DOS services
 sets up DOS memory management
 contains the following segments:
 * DOSENTRY (relocated by INIT1 to 70h:0)
	ldos/entry.asm, RxDOS/bioentry.asm, RxDOS/int19.asm
 * DOSCODE (later relocated by INIT2 to LMA, UMA, or HMA)
	ldos/init.asm, RxDOS/biocode.asm, RxDOS/doscode.asm, RxDOS/RxDOS*.ASM
 * DOSDATA (later relocated by INIT2 to LMA or UMA)
	RxDOS/dosdata.asm
 * INIT0 (early relocation, discarded immediately, before MCBs are set up)
	ldos/init.asm
 * INIT1 (early initialisation, sets up DOSENTRY and hooks interrupts)
	ldos/init.asm
 * INIT2 (data init, RxCONFIG.SYS processing, UMB linking, relocations)
	ldos/init.asm, RxDOS/RxDOSINI.ASM
 * INIT3 (init PSP)
	ldos/init.asm

RxCMD
 loaded by RxDOS if not otherwise instructed
 shows DOS prompt to user and executes internal/external commands

%endif


%include "RXDMACRO.NEW"
%include "RXDSTRUC.NEW"


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
		; INP:	es:bx -> request header
		;	word [ss:sp + 2] = dispatch table
		;	word [ss:sp] = logical unit number, if any
DEVStrategy:
	lframe 0
	lpar word, table
	lpar word, unit
	lvar word, function
	lenter
	lvar dword, requestheader
	push es
	push bx

	cld
	SaveAllRegisters

	push es
	pop ds

;	lds bx, [ cs:Strategy ]				; compliant strategy call
;	stordarg _RequestBlock, ds, bx			; see text for compliance issues
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
	mov si, word [ bp + ?table ]			; -> table
	cmp ax, word [ cs:si ]				; table entries count
	mov cx, _IllegalFunction			; default handler
	jae .got_service_address
	inc ax						; skip count word
	add ax, ax
	add si, ax					; -> table entry
	mov cx, word [ cs:si ]
.got_service_address:
	mov word [ bp + ?function ], cx

	push bp						; device or BIOS might change bp
	mov ah, byte [ bx + mrMediaID ]
	mov al, byte [ bx + rhUnit ]
	mov cx, word [ bx + rwrBytesReq ]
	mov dx, word [ bp + ?unit ]			; passed to function
	mov word [ bx + rhStatus ], 0000

		; es:di-> buffer, if any
		; ds:bx-> packet
	les di, [ bx + rwrBuffer ]
	call word [ bp + ?function ]
	pop bp						; device or BIOS may have changed bp

	lds bx, [ bp + ?requestheader ]
	or word [ bx + rhStatus ], (OP_DONE)

	RestoreAllRegisters				; restore all other registers
	lleave
	add sp, byte 4			; (discard ?table and ?unit)
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
	push es
	mov ax, 70h
	mov es, ax
	mov es, word [es:dosentry_to_dosdata_segment]

	cmp word [ es:Con_LookAhead ], byte 0000	; character in pending area ?
	jnz ConStatus_16				; yes -->

	mov ah, BIOS_ConStatus
	Int 16h						; see if characters waiting ?
	jz ConStatus_NoData				; none waiting -->

ConStatus_16:
	pop es
	retn

		; If no data
ConStatus_NoData:
	mov word [ rhStatus + bx ], (OP_NODATA)
	pop es
	retn


		; Con Input Flush (Fct 7)
		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


ConInputFlush:
	push es
	mov ax, 70h
	mov es, ax
	mov es, word [es:dosentry_to_dosdata_segment]

	mov word [ es:Con_LookAhead ], 0000		; flush input character

ConInputFlush_08:
	mov ah, BIOS_ConStatus
	Int 16h						; see if characters waiting ?
	jz ConInputFlush_NoData				; no more -->

	mov ah, BIOS_ConRead
	Int 16h						; read waiting character
	jmp short ConInputFlush_08			; test for more -->

ConInputFlush_NoData:
	pop es
	retn


		; Con Write (Fcts 8, 9)

		; 
		; ds:bx	points to request header
		; es:di	points to request buffer
		; cx	characters to transfer
		; dl	logical device


ConWrite:
	push es

	or cx, cx
	jz ConWrite_38

ConWrite_08:
	pop es
	mov al, byte [ es:di ]			; get character
	inc di
	push es

	mov bx, 70h
	mov es, bx
	mov es, word [es:dosentry_to_dosdata_segment]

	cmp al, ControlJ			; line feed ?
	jz .cr_or_lf				; yes -->
	cmp al, ControlM			; carriage return ?
	jz .cr_or_lf				; yes -->
	cmp al, ControlI			; tab character ?
	jz .tab					; yes -->

	inc byte [ es:Con_TabPosition ]		; tab position
	Int 29h					; internal Video Driver
	jmp short .next

.cr_or_lf:
	mov word [ es:Con_TabPosition ], 0000	; set tab position
	Int 29h					; internal Video Driver
	jmp short .next

.tab:
	mov al, ' '				; display a space
	Int 29h					; internal Video Driver

	inc byte [ es:Con_TabPosition ]		; tab position
	test byte [ es:Con_TabPosition ], 7	; tab position
	jnz .tab

.next:
	loop ConWrite_08			; go get additional characters -->

ConWrite_38:
	pop es
	ret


		; Get Con Character

		; ds:bx	points to request header
		; dl	logical device


getConData:
	push es
	mov ax, 70h
	mov es, ax
	mov es, word [es:dosentry_to_dosdata_segment]

	xor ax, ax
	xchg ax, word [ es:Con_LookAhead ]		; get char waiting
	or ax, ax					; any character waiting ?
	jnz getConData_08				; no -->

	mov ah, BIOS_ConRead
	Int 16h						; wait for character
	or ax, ax					; anything returned ?
	jz getConData					; continue looping -->

getConData_08:
	mov byte [ es:Con_ScanCode ], ah		; save scan code
	pop es
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

	push es
	mov si, 70h
	mov es, si
	mov es, word [es:dosentry_to_dosdata_segment]
	mov si, dx
	add si, Comm_LookAhead			; 
	mov byte [ es:si ], al			; save waiting data.
	pop es

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
	push es
	mov si, 70h
	mov es, si
	mov es, word [es:dosentry_to_dosdata_segment]
	mov si, dx
	add si, Comm_LookAhead			; 
	mov byte [ es:si ], 00			; flush input character
	pop es
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
	push es
	mov si, 70h
	mov es, si
	mov es, word [es:dosentry_to_dosdata_segment]
	mov si, dx
	add si, Comm_LookAhead			; 
	cmp byte [ es:si ], 00			; data waiting ?
	jz getComData_08				; no -->

	xor ax, ax
	xchg al, byte [ es:si ]			; get char waiting
	pop es
	ret

getComData_08:
	mov ah, BIOS_ComRead
	Int 14h
	test ax, (CommLS_FE + CommLS_PE + CommLS_OE)	; errors ??
	pop es
	ret


		; Get Com Status
		;
		; ds:bx	points to request header
		; dx	logical device
getComStatus:
	push es
	mov si, 70h
	mov es, si
	mov es, word [es:dosentry_to_dosdata_segment]
	mov si, dx
	add si, Comm_LookAhead
	cmp byte [ es:si ], 00				; data waiting ?
	jz getComStatus_08				; no -->

	mov ax, CommLS_DataAvail
	mov al, byte [ es:si ]				; get char waiting
	pop es
	retn

getComStatus_08:
	mov ah, BIOS_ComStatus
	Int 14h
	pop es
	retn


%ifn _INT19_IN_DOSENTRY
%include "int19.asm"
%endif


		; Interrupt 29
		; 
		; al	character to display
		;
		;  This default handler just gives the call to Int10.0E, Video BIOS display character
relocated i29:

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
	mov si, 70h				; => DOSENTRY
	mov ds, si
	mov ds, word [dosentry_to_dosdata_segment]	; => DOSDATA
	mov si, word [dosdata_to_diskbuffer_segment]	; => DiskBuffer
	mov ds, si				; (used to access DiskBuffer)

		; Rebuild BIOS Parameter Block
_RebuildBPB_12:
	getdarg ds, di, _dskParameterTable		; ds:di -> UPB
	mov es, si
	xor bx, bx					; es:bx -> DiskBuffer

	xor ax, ax
	xor dx, dx					; dx:ax = sector number

	mov cx, 1					; cx = 1

	push si
	test byte [ di + _dskExtReadWrite ], 1
	jz .chs_read
.lba_read:
	call ExtendedRead
	jmp .common

.chs_read:
	call _nonLBARead
.common:
	pop si
	jc _RebuildBPB_38
	mov ds, si

		; Copy standard boot sector info
	getdarg es, di, _dskParameterTable
	push si
	lea si, [ _bsBytesPerSector ]
	lea di, [ di + _dskBPB ]
	mov cx, sizeBPB
	repe movsb
	pop si

	mov di, word [ bp + _dskParameterTable + _pointer ]
	mov byte [ es:di + _dskDeviceType ], DSKFILESYSTYPE_IsValid

	mov ax, word [ _bsVolumeId + _low ]
	mov dx, word [ _bsVolumeId + _high ]
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

	mov ax, word [ _bsxVolumeId + _low ]
	mov dx, word [ _bsxVolumeId + _high ]
	mov word [ es:di + _dskSerialNumber + _low ], ax
	mov word [ es:di + _dskSerialNumber + _high ], dx

	mov word [ es:di + _dskBPB + _bpbSectorsPerFat ], 0000

	push si
	lea si, [ _bsxBigSectorsPerFat ]
	lea di, [ di + _dskBPB + _bpbxBigSectorsPerFat ]
	mov cx, ( _bpbxReserved - _bpbxBigSectorsPerFat )
	rep movsb
	pop si

	getdarg ds, di, _dskParameterTable		; ds:di -> UPB
	mov es, si
	xor bx, bx					; es:bx -> DiskBuffer

	mov ax, word [ es:di + _dskBPB + _bpbxFSINFOSector ]
	xor dx, dx					; dx:ax = sector number

	mov cx, 1					; cx = 1

	push si
	test byte [ di + _dskExtReadWrite ], 1
	jz .chs_read
.lba_read:
	call ExtendedRead
	jmp .common

.chs_read:
	call _nonLBARead
.common:
	pop si
	jc _RebuildBPB_38
	mov ds, si

	push si
	mov si, sizeSector - (BIGFATBOOTFSINFO_size) - 4
	les di, [ bp + _dskParameterTable ]
	mov cx, word [ si + _bfFSInfoFreeClusterCnt + _high ]
	mov dx, word [ si + _bfFSInfoFreeClusterCnt + _low ]
	mov word [ es:di + _dskBPB + _bpbxFreeClusters + _low ], dx
	mov word [ es:di + _dskBPB + _bpbxFreeClusters + _high ], cx

	mov cx, word [ si + _bfFSInfoNextFreeCluster + _high ]
	mov dx, word [ si + _bfFSInfoNextFreeCluster + _low ]
	mov word [ es:di + _dskBPB + _bpbxNextFreeCluster + _low ], dx
	mov word [ es:di + _dskBPB + _bpbxNextFreeCluster + _high ], cx
	pop si

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

	mov di, 70h
	mov es, di
	mov es, word [es:dosentry_to_dosdata_segment]
	cmp word [ es:ptrStartBlockedDeviceTable ], byte -1
	jz _buildBPB_Error				; if not initialized -->

	les di, [ es:ptrStartBlockedDeviceTable ]

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

	mov di, 70h
	mov es, di
	mov es, word [es:dosentry_to_dosdata_segment]
	cmp word [ es:ptrStartBlockedDeviceTable ], byte -1
	jz _findBPB_Error				; if not initialized -->

	les di, [ es:ptrStartBlockedDeviceTable ]

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
	cmp bx, Max_BIOSErrorCodeTable
	jae convErr_08
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


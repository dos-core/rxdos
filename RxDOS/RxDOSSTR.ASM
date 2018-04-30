
%if 0

RxDOSSTR - RxDOS string functions

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

	global upperCaseName
	global capitalise
	global skipToNextName
	global skipToLast
	global skipSpaces
	global ifPathSeparator
	global scanInvalidFilenameChars
	global CompareString
	global CopyString
	global CopyStringArgs
	global CopyStringLowercase
	global CopyBlock
	global StringLength			; StrLen
	global condStringLength
	global convFilenametoFCBString
	global convFCBNametoASCIZ
	global convDirEntrytoASCIZ
	global getSysDateinDirFormat
	global __ascii_stosb
	global getMonthDayYear
	global getDaysSince1980
	global getSystemDateValue

	extern GetActualDrive
	extern sizeInvFnChars
	extern _invalidFnCharacters
	extern getSysDate
	extern getExpandedDateTime
	extern DaysInMonthTable
	extern AccumDaysPerMonthTable
%endif

		; Upper case FCB format filename
		;
		; Usage:
		; es:si pointer to buffer
UpperCaseName:
	push si
	mov cx, sizeFILENAME

UpperCaseName_08:
	mov al, byte [ es:si ]
	_upperCase al					; upper case
	mov byte [ es:si ], al
	inc si
	loop UpperCaseName_08

	pop si
	retn


capitalise:
	_upperCase al
	retn

		; Skip to start of name
		;
		; This is a simple routine that skips any \ and spaces to a
		; name.	It will not parse drives or anything else.
		;
		; INP:	ds:si-> buffer
		; OUT:	ds:si-> all '/', '\' and ' ' skipped
		;	al = character at [ ds:si ]
skipToNextName:

	cmp byte [ si ], ' '
	jz skipToNextName_04				; if space -->
	cmp byte [ si ], '/'
	jz skipToNextName_04				; if slash -->
	cmp byte [ si ], '\'
	jnz skipToNextName_08				; if anything but name -->

skipToNextName_04:
	inc si
	jmp short skipToNextName

skipToNextName_08:
	mov al, byte [ si ]
	or al, al
	retn


		; Skip to start of last name in path string
		;
		; This routine skips any components of a name until it reaches
		; the last name.
		;
		; es:si-> buffer
skipToLast:
	push bx
	mov bx, si

skipToLast_04:
	mov al, byte [ es:si ]
	or al, al
	jz skipToLast_12

	inc si
	cmp al, '/'
	jz skipToLast_08				; if slash -->
	cmp al, '\'
	jnz skipToLast_04				; if anything but slash -->

skipToLast_08:
	mov bx, si					; remember last /
	jmp short skipToLast_04

skipToLast_12:
	mov si, bx
	mov al, byte [ es:si ]
	or al, al
	pop bx
	retn


		; Skip spaces
		;
		; es:si-> buffer
skipSpaces:

	cmp byte [ es:si ], ' '
	jnz skipSpaces_04				; non-space -->

	inc si
	jmp short skipSpaces

skipSpaces_04:
	mov al, byte [ es:si ]
	or al, al
	retn


		; Check For Path Separator
		;
		; INP:	al = character
		; OUT:	ZR if al was either '/' or '\'
ifPathSeparator:

	cmp al, '/'
	jnz ifPathSeparator_08
	mov al, '\'					; convert / to '\'

ifPathSeparator_08:
	cmp al, '\'
	retn


		; Scan Invalid Filename Chars
		;
		; INP:	es:si -> buffer
		; OUT:	CY if invalid characters found
		;	NC if none
		; CHG:	al, cx
scanInvalidFilenameChars:

	saveSegments di, si
	setDS es

scanInvalidFnChars_08:
	lodsb						; get character
	or al, al					; end of file name ?
	jz scanInvalidFnChars_12			; yes -->

	cmp al, ' '					; make sure its not a control character
	jc scanInvalidFnChars_10			; if invalid character ->

	setES cs
	mov di, _invalidFnCharacters
	mov cx, sizeInvFnChars
	repnz scasb					; any in invalid character list ?
	jnz scanInvalidFnChars_08			; if valid character ->

scanInvalidFnChars_10:
	stc

scanInvalidFnChars_12:
	restoreSegments si, di
	retn


		; Compare String
		;
		; Emulates rep cmpsb instruction except that it matches '?'
		; characters.	No character conversions.
		;
		; Input:
		; ds:si	source string (may contain ? character )
		; es:di	match string (may not contain wild character )
		; cx	count
		; OUT:	ZF set (ZR) if equal
CompareString:

	repe cmpsb					; match ?
	jz compareString_16				; yes, continue if not zero -->

	mov al, byte [ si - 1 ]
	cmp al, questionMark				; previous a wild character ?
	jnz compareString_16				; if not ? wild character -->
	or cx, cx
	jnz CompareString				; else continue matching -->

compareString_16:
	retn


		; Copy String
		;
		; Usage:
		; ds:si	source string address
		; es:di	dest string address
		;
		; Returns:
		; es:di	points to null terminator of dest string.
CopyString:
	lodsb
	stosb
	or al, al
	jnz CopyString

	dec di
	retn


		; Copy string lowercase
		;
		; Usage:
		; ds:si-> source ASCIZ string
		; es:di-> destination buffer
		;
		; Returns:
		; es:di-> null terminator of destination string
CopyStringLowercase:
	lodsb
	_lowerCase al

	stosb
	or al, al
	jnz CopyStringLowercase

	dec di
	retn


		; Copy string from arguments
		;
		; Usage:
		; stack-> source ASCIZ string
		; stack-> destination buffer
		;
		; Returns:
		; es:di-> null terminator of destination string
	doscode_insure_low_byte_not_0CCh
CopyStringArgs:

	Entry 4
	darg	srcstring
	darg	dststring

	saveRegisters ds, si, ax

	getdarg ds, si, _srcstring
	getdarg es, di, _dststring

CopyStringArgs_08:
	lodsb
	stosb
	or al, al
	jnz CopyStringArgs_08

	dec di
	restoreRegisters ax, si, ds
	Return


		; Copy block
		;
		; Usage:
		; stack-> source
		; stack-> destination
		; cx = length
CopyBlock:

	Entry 4
	darg	src
	darg	dest

	saveSegments di, si

	getdarg ds, si, _src
	getdarg es, di, _dest
	repe movsb

	restoreSegments si, di
	Return


		; Compute String Length
		;
		; Input:
		; stack-> ASCIZ string
		;
		; Output:
		; cx = string length
		; ZR if cx = 0
StringLength:

	Entry 2
	darg	string

	push es
	push di
	push ax
	xor al, al
	mov cx, -1
	getdarg es, di, _string
	repnz scasb

	not cx
	dec cx
	or cx, cx

	pop ax
	pop di
	pop es
	Return


		; Conditional String Length
		;
		; Input:
		; stack-> ASCIZ string
		; cx = maximal string length to scan
		;
		; Output:
		; cx = actual string length
		; al = character just before null
		; ZR if string terminates with null
condStringLength:

	Entry 2
	darg	string

	push es
	push di
	push bx

	xor al, al
	mov bx, cx					; orig length to bx
	getdarg es, di, _string				; where to search
	repnz scasb					; scan for null

	pushf						; zr means we have located a null
	sub cx, bx
	neg cx						; -length
	dec cx						; minus the null
	mov al, byte [ es:di - 2 ]			; character just before null

	popf						; return status
	pop bx
	pop di
	pop es
	Return


		; Fix Pattern Match
		;
		; If * in pattern matching filenames is the last character in
		; either the filename or extension, we can convert the pattern
		; to a simple question filled pattern.	If the pattern is not
		; converted, the NZ flag is returned.	ZR is returned if the
		; pattern has been converted or if there was no conversion
		; necessary.
		;
		; This function will also convert a filename from (text.ext)
		; to space padded (8 + 3 ) format.
		;
		; Input:
		; ds:si	source string (null terminated)
		; es:di	output string
		;
		; Output:
		; ds:si	points to terminator found in source string
		; es:di	points to output string
		; zr	filename is all blank
convFilenametoFCBString:

	push di						; save original pointers
	mov al, ' '
	mov cx, sizeFILENAME				; max filename field length
	repe stosb					; blank fill

	pop di
	push di						; save original pointers
	call skipToNextName				; skip to starting name

		; see if special cases . and ..
	cmp word [ si ], byte '.'		; special case of just . filename ?
	jz convFilenametoFCBString_08			; yes -->
	cmp word [ si ], '..'			; special case of just .. filename ?
	jnz convFilenametoFCBString_12			; no -->
	cmp byte [ si + 2 ], 0			; must be ..[0]
	jnz convFilenametoFCBString_12			; no -->

convFilenametoFCBString_08:
	lodsb						; get next
	or al, al					; end of string
	jz convFilenametoFCBString_14			; yes -->

	stosb						; save period
	jmp short convFilenametoFCBString_08		; continue copy -->

		; presumably normal filename
convFilenametoFCBString_12:
	mov cx, sizeFILENAME				; max filename field length
	call __convfilename				; get name
	jnz convFilenametoFCBString_14			; if not followed by a period -->

	add di, byte sizefnName
	mov cx, sizefnExtension				; max extension field length
	call __convfilename				; get extension

convFilenametoFCBString_14:
	pop di
	cmp byte [ es:di ], ' '				; if entire name is blank
	retn


		; Grab/fill filename characters
		;
		; Input:
		; ds:si-> ASCIZ source string
		; es:di-> output string
		;
		; Output:
		; ZR means dot following name term encountered
__convfilename:

	push di

__convfilename_04:
	lodsb						; get character
	or al, al
	jz __convfilename_26				; null is end of name -->
	cmp al, ' '
	jz __convfilename_04				; null is end of name -->
	cmp al, '/'
	jz __convfilename_28				; '\' is end of name -->
	cmp al, '\'
	jz __convfilename_28				; '\' is end of name -->
	cmp al, '.'
	jz __convfilename_14				; period is end of name -->
	cmp al, ','
	jz __convfilename_28				; comma is end of name -->
	cmp al, ';'
	jz __convfilename_28				; semicolon is end of name -->
	cmp al, ':'
	jz __convfilename_28				; colon is end of name -->
	cmp al, '*'
	jz __convfilename_16				; '*' requires expansion -->

	_upperCase al					; upper case
	stosb						; else just copy
	loop __convfilename_04
	jmp short __convfilename_20

		; space fill if dot
__convfilename_14:
	mov al, ' '
	repe stosb

	mov al, '.'
	jmp short __convfilename_28

		; asterisk fill
__convfilename_16:
	mov al, questionMark
	repe stosb

		; keep scanning until end of field
__convfilename_20:
	lodsb						; get character
	or al, al
	jz __convfilename_26				; null is end of name -->
	cmp al, ' '
	jz __convfilename_20				; null is end of name -->
	cmp al, '\'
	jz __convfilename_28				; '\' is end of name -->
	cmp al, '/'
	jz __convfilename_28				; '/' is end of name -->
	cmp al, '.'
	jz __convfilename_28				; period is end of name -->
	cmp al, ','
	jz __convfilename_28				; comma is end of name -->
	cmp al, ';'
	jz __convfilename_28				; semicolon is end of name -->
	jmp short __convfilename_20

		; return
__convfilename_26:
	dec si
	xor ax, ax					; invalid term ends with null

__convfilename_28:
	cmp al, '.'					; last character parsed a period ?
	pop di
	retn


		; Convert FCB Name to ASCIZ
		;
		; Usage:
		; arg-> FCB
		; arg-> expanded name buffer
convFCBNametoASCIZ:

	Entry 4
	darg	source
	darg	destination

	SaveSegments di, si, dx, cx

	getdarg ds, si, _source
	push word [ si ]				; drive code from FCB
	call GetActualDrive				; convert to actual
	mov al, dl					; in case of error, restore value

	mov ah, ':'
	add al, 'A'

	getdarg es, di, _destination
	stosw

	call convDirEntrytoASCIZ
	restoreSegments cx, dx, si, di
	Return


		; Convert short directory entry to ASCIZ
		;
		; Usage:
		; ds:si-> directory entry
		; es:di-> buffer for ASCIZ name
		;
		; Returned:
		; all input parameters preserved
		; cx	returned with size of ASCIZ name
convDirEntrytoASCIZ:

	SaveRegisters di, si

	push si
	mov cx, sizefnName

convDirEntry_08:
	lodsb						; get character
	cmp al, ' '+1
	jc convDirEntry_12
	stosb						; copy filename
	loop convDirEntry_08

convDirEntry_12:
	pop si
	add si, byte sizefnName
	mov cx, sizefnExtension
	cmp byte [ si ], ' '+1
	jc convDirEntry_20

	mov al, '.'					; place a period after
	stosb

convDirEntry_14:
	lodsb
	cmp al, ' '+1
	jc convDirEntry_20
	stosb						; copy extension
	loop convDirEntry_14

convDirEntry_20:
	mov cx, di
	mov byte [ es:di ], 0			; NULL terminator
	RestoreRegisters si, di

	sub cx, di					; length
	retn


		; Convert al to ASCII string at [es:di]
		;
		; Input:
		; al
		;
		; Output:
		; [es:di] = two byte ASCII contents of al
		; di increased by two
__ascii_stosb:
	push ax
	mov ah, al
	shr al, 1
	shr al, 1
	shr al, 1
	shr al, 1
	and ax, 0f0fh					; mask off extra bits
	add ax, 'AA'					; convert to ASCII
	stosw						; save
	pop ax						; restore ax
	retn


		; Get month, day and year from system date
		;
		; Input:
		; ax	system day
		;
		; Output:
		; al	day of week (Sunday = 0, ...)
		; cx	year
		; dh	month
		; dl	day
getMonthDayYear:

	push bx

		; compute year
	xor dx, dx
	mov cx, 365
	div cx						; expected years

	mov cx, ax					; year to cx
	test cx, 11b					; leap year ?
	jz getMonthDayYear_08				; yes -->
	dec dx						; adjust days left in year
	call _daysAdjust				; adjust for days in year

getMonthDayYear_08:
	shr cx, 1
	shr cx, 1					; divide by 4
	sub dx, cx					; day this year
	jnc getMonthDayYear_10				; this year -->
	call _daysAdjust				; adjust for days in year

		; compute month
getMonthDayYear_10:
	xor ch, ch
	xor bx, bx
	xchg ax, dx					; day this year

getMonthDayYear_12:
	mov cl, byte [ cs:bx + DaysInMonthTable ]
	test dx, 11b					; leap year ?
	jnz getMonthDayYear_14				; no -->
	cmp bl, 1					; is this february ?
	jnz getMonthDayYear_14				; no -->
	inc cl

getMonthDayYear_14:
	cmp ax, cx					; this month ?
	jc getMonthDayYear_20				; yes -->

	sub ax, cx					; account for this month
	inc bx
	jmp short getMonthDayYear_12

		; dx = year, bx = month, ax = day
getMonthDayYear_20:
	mov cx, dx
	add cx, 1980					; year

	mov dh, bl					; month
	mov dl, al					; day
	add dx, 0101h					; within proper range

	call getDayOfWeek
	pop bx
	retn

		; adjust for undeflow in year/day
_daysAdjust:

	or dx, dx					; days left negative ?
%if 1
	jge _daysAdjust_08				; no -->
%else
	jge _daysAdjust_08				; no -->
%endif

	dec ax						; convert to days
	add dx, 365					; if wrap around error,
	test ax, 11b					; leap year ?
	jnz _daysAdjust_08				; no -->
	inc dx						; if leap year

_daysAdjust_08:
	retn


		; Get Day of Week
		;
		; Input:
		; cx	year	(1980 ...)
		; dh	month	(1 - 12)
		; dl	day	(1 - 31)
		;
		; Output:
		; ax	day of week (Sunday = 0, ...)
getDayOfWeek:

	Entry
	def	dayofweek

	push bx
	push cx
	push dx
	mov bx, dx
	sub bh, 2					; past february ?
	ja getDayOfWeek_08				; yes -->

	add bh, 12					; rotate full year
	dec cx						; adjust year

getDayOfWeek_08:
	mov ax, 13
	mul bh						; months * 13
	dec ax						; 13 * months - 1
	mov dh, 5
	div dh						; (13 * months - 1)/5
	xor ah, ah					; ignore remainder

	add al, bl					; add days
	storarg _dayofweek, ax				; save interim value

	xor dx, dx
	mov ax, cx					; copy years
	mov cx, 100					; century
	div cx						; centuries in ax/ years in dx

	add word [ _dayofweek + bp ], dx		; add year

	shr dx, 1
	shr dx, 1
	add word [ _dayofweek + bp ], dx		; add year/4

	mov dx, ax
	shr dx, 1
	shr dx, 1
	add word [ _dayofweek + bp ], dx		; add century/4

	add ax, ax					; 2 * century
	sub word [ _dayofweek + bp ], ax		; sub 2*century

	xor dx, dx
	getarg ax, _dayofweek
	mov cx, 7
	div cx						; divide by 7

	mov dx, ax
	add ax, ax					; *2
	add dx, ax					; *3
	add ax, ax					; *4
	add dx, ax					; *7

	getarg ax, _dayofweek
	sub ax, dx					; real day of week
	jae getDayOfWeek_12				; if ok -->
	add ax, 7					; else wrap around day of week

getDayOfWeek_12:
	pop dx
	pop cx
	pop bx
	Return


		; Get Days Since 1980
		;
		; Input:
		; cx	year	( 1980 ... )
		; dh	month	( 1 - 12)
		; dl	day	( 1 - 31)
		;
		; Output:
		; ax	days since 1980 format
		;
		; Based On:
		;
		; jdn = (long)(d - 32076)
		; + 1461L * (y + 4800L + (m - 14) / 12) / 4
		; + 367 * (m - 2 - (m - 14) / 12 * 12) / 12
		; - 3 * ((y + 4900L + (m - 14) / 12) / 100) / 4
		; + 1;		/* correction by rdg */
		;
getDaysSince1980:

	Entry
	def	year, cx
	def	month, 0000
	def	day, 0000
	def	m14_12, 0000
	ddef	daysSince

	push bx
	push cx
	push dx

	mov byte [ _month + bp ], dh
	mov byte [ _day	+ bp ], dl

	dec dh
	jnz .06
	mov word [ _m14_12 + bp ], -1

.06:
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
	jz .08

.06:
	add al, byte [ cs:DaysInMonthTable + bx ]
	adc ah, 0
	dec bx
	jnz .06

.08:
	mov dh, 0				; days only in dx
	add ax, dx				; days this year
	cmp ax, byte 28				; between Jan 1 and Feb 28 ?
	jle .12		 			; yes -->

	test word [ _year + bp ], 11b		; this year a leap year ?
	jnz .12					; no -->
	inc ax					; we get one more day
	add ax, word [ _daysSince + bp ]
%endif

.12:
	pop dx
	pop cx
	pop bx
	Return


		; Get system date, day of week from year, month, day
		;
		; Input:
		; cx	year
		; dh	month
		; dl	day
		;
		; Output:
		; dx	system day
		; al	day of week (Sunday = 0, ...)
getSystemDateValue:

	Entry
	def	year, cx				; not adjusted
	def	month					; adjusted
	def	day					; adjusted
	def	Totaldays

	push bx

	xor ax, ax
	mov al, dh
	storarg _month, ax

	mov al, dl
	storarg _day, ax

	mov ax, 365
	sub cx, 1980
	mul cx						; * 365
	storarg _Totaldays, ax

	or cx, cx					; 1980 ?
	jz getSystemDateValue_06			; yes -->

	dec cx						; adjust for current year
	shr cx, 1
	shr cx, 1					; years / 4
	inc cx						; adjust for 1980 (leap year)
	add word [ _Totaldays + bp ], cx

	; or cx, cx					; 1980 ?
	; jz getSystemDateValue_06			; yes -->
	; inc word [ _Totaldays + bp ]			; adjust days for 1980

getSystemDateValue_06:
	; xor dx, dx
	; mov ax, cx
	; mov bx, 100
	; div bx
	; sub word [ _Totaldays + bp ], ax

	; shr ax, 1
	; shr ax, 1					; years / 400
	; add word [ _Totaldays + bp ], ax

	mov bx, word [ _month + bp ]
	dec bx
	add bx, bx
	mov ax, word [ cs:bx + AccumDaysPerMonthTable ]

	cmp word [ _month + bp ], byte 2
	jbe getSystemDateValue_08

	test word [ _year + bp ], 11b
	jnz getSystemDateValue_08
	inc ax						; adjust for leap year

getSystemDateValue_08:
	add ax, word [ _day + bp ]
	add ax, word [ _Totaldays + bp ]
	push ax						; save days

	xor dx, dx
	inc ax
	mov cx, 7
	div cx
	pop ax
	xchg ax, dx

	pop bx
	Return


		; Get system date and time in dir format
		;
		; Output:
		; ax	time of day
		; dx	date
getSysDateinDirFormat:

	SaveSegments di, si, cx, bx

	call getExpandedDateTime			; get system date

		; date
	push cx
	push dx
	call getMonthDayYear				; convert system day to cx = year, dx = month/day
	call convSysDatetoDirDate			; convert cx/dx to ax date in directory format

		; time
	pop dx
	pop cx						; recall time
	push ax						; save dir date
	call convSysTimetoDirTime			; convert time to directory format

	pop dx						; date to dx

	RestoreSegments bx, cx, si, di
	retn


		; Convert cx/dx date to directory date.
		;
		; Input:
		; cx	year (1980+)
		; dh	month
		; dl	day
		;
		; Output:
		; ax	date in directory format
convSysDatetoDirDate:

	sub cx, 1980
	mov ax, cx
	shl ax, 1
	shl ax, 1
	shl ax, 1
	shl ax, 1					; shift over to get month

	or al, dh					; month
	shl ax, 1
	shl ax, 1
	shl ax, 1
	shl ax, 1
	shl ax, 1

	or al, dl					; day
	retn


		; Convert cx/dx time to directory time
		;
		; Input:
		; ch	hours
		; cl	minutes
		; dh	seconds
		; dl	hundredths of seconds
		;
		; Output:
		; ax	time in dir format
convSysTimetoDirTime:

	mov al, ch					; hours
	shl ax, 1
	shl ax, 1
	shl ax, 1
	shl ax, 1
	shl ax, 1
	shl ax, 1

	or al, cl					; minutes
	shl ax, 1
	shl ax, 1
	shl ax, 1
	shl ax, 1
	shl ax, 1

	shr dh, 1
	or al, cl					; seconds
	retn


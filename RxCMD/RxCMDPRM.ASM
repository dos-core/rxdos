
%if 0

RxCMDPRM - RxCMD PROMPT, DATE and TIME commands

This product is distributed AS IS and contains no warranty
whatsoever, including warranty of merchantability or
fitness for a particular purpose.

Copyright (C) 1990-1999 Mike Podanoffsky

This is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License, see
the file LICENSE.TXT.

%endif

	cpu 8086

	segment RXCMD align=16 class=RXCMD use16 public start=100h
	segment RXCMD

%include "RXDMACRO.MAC"
%include "RXDSTRUC.MAC"
%include "RXCSTRUC.MAC"


	global DisplayPrompt
	global formatCurrentDate
	global formatCurrentTime

	global _Prompt
	global _Date
	global _Time

	extern CheckOptOneArg
	extern _sprintf
	extern DisplayLine
	extern _GetNumber
	extern _getStdinLine
	extern RxDOS_DefaultPrompt
	extern RxDOS_Prompt
	extern CopyString
	extern RxDOS_PromptSpec
	extern searchEnvVariable
	extern deleteEnvVariable
	extern insertEnvVariable
	extern _PleaseEnterDate
	extern _ShowCurrentDate
	extern _ShowCurrentTime
	extern _PleaseEnterTime
	extern CmndError_InvalidDate
	extern CmndError_InvalidTime
	extern CmndError_OutOfEnvironmentSpace
	extern DisplayErrorMessage
	extern DisplayOutEnvSpace

	extern CRLF
	extern RxDOS_Version
	extern RxDOSIntl_DateTemplate
	extern RxDOSIntl_DayOfWeek
	extern RxDOSIntl_TimeTemplate
	extern RxDOSIntl_DateTimeTable

	extern _EnvSegment


		; Display prompt
		;
		; Parsed command codes inside %PROMPT% variable:
		;  $q	=
		;  $$	$
		;  $t	time
		;  $d	date
		;  $p	current directory (including drive)
		;  $v	RxCMD version
		;  $n	current drive
		;  $g	>
		;  $l	<
		;  $b	| (pipe)
		;  $_	line break
		;  $e	Escape (27)
		;  $h	Backspace (8)
DisplayPrompt:
	entry
	defbytes	buffer, 260

		; locate init (environment) prompt string
	push di

	mov si, RxDOS_PromptSpec
	call searchEnvVariable				; locate prompt= spec
	jnz DisplayPrompt_06				; if none -->

	push ds
	add di, dx					; point to environment variable value
	mov si, RxDOS_Prompt
	mov ds, word [ _EnvSegment ]			; segment of environment
	xchg di, si
	call CopyString
	pop ds

DisplayPrompt_06:
	mov si, RxDOS_Prompt
	lea di, [ _buffer + bp ]
	mov byte [ di ], 0				; terminate if not displaying prompt

%if 0
	cmp word [ RxDOS_BatchFile + batchEchoStatus ], NO
	jz DisplayPrompt_48				; if ECHO switched off, don't display -->

	mov ax, 10<<8|13
	stosw
		; RxDOS 7.20N:	A line break is displayed before the prompt.
%endif


		; scan prompt
DisplayPrompt_08:
	lodsb

DisplayPrompt_10:
	stosb
	or al, al					; end of string ?
	ifz DisplayPrompt_48				; yes -->

	cmp al, '$'					; special command ?
	jnz DisplayPrompt_08				; no, loop -->


		; special case
	dec di
	lodsb
%if 1
	or al, al
	ifz DisplayPrompt_48
		; RxDOS 7.20N:	Falls through and then jumps to DisplayPrompt_10.
%endif

%if 0
	; mov ah, 20h
	; and ah, al
	call lowercase
%else
	_lowerCase al
%endif
%if 1
	Translate 'q', '=', DisplayPrompt_18
	Translate '$', '$', DisplayPrompt_18
	Translate 'g', '>', DisplayPrompt_18
	Translate 'l', '<', DisplayPrompt_18
	Translate 'b', '|', DisplayPrompt_18
	Translate 'e', 27, DisplayPrompt_18
%if 0
	Translate 'a', '&', DisplayPrompt_18
	Translate 'c', '(', DisplayPrompt_18
	Translate 'f', ')', DisplayPrompt_18
	Translate 's', ' ', DisplayPrompt_18
		; RxDOS 7.30:	Some additional NT CMD.EXE values.
%endif
%else
	translate 'q', '='
	translate '$', '$'
	translate 'g', '>'
	translate 'l', '<'
	translate 'b', '|'
	translate 'e', 27
	translate 'a', '&'
	translate 'c', '('
	translate 'f', ')'
	translate 's', ' '
%endif

	cmp al, 't'
	ife DisplayPrompt_Time				; $t time -->
	COMPAT_NOP
	cmp al, 'd'
	ife DisplayPrompt_Date				; $d date -->
	COMPAT_NOP
	cmp al, 'p'
	ife DisplayPrompt_Path				; $p path -->
	COMPAT_NOP
	cmp al, 'v'
	ife DisplayPrompt_Version			; $v version -->
	COMPAT_NOP
	cmp al, 'n'
	ife DisplayPrompt_Drive				; $d drive -->
	COMPAT_NOP
	cmp al, '_'
	je DisplayPrompt_CRLF				; $_ line break -->
	cmp al, 'h'
	je DisplayPrompt_Backspace			; $b backspace -->
%if 0
	; or ah, ah					; was uppercase flag set ?
	; jz DisplayPrompt_10				; no -->
	; call uppercase				; uppercase, if still that letter
%endif
	jmp short DisplayPrompt_10


%if 1
		; translate
DisplayPrompt_18:
	mov al, ah
	stosb						; translated value
	jmp short DisplayPrompt_08
%endif

		; backspace
DisplayPrompt_Backspace:
	dec di
DisplayPrompt_08_01:
	jmp short DisplayPrompt_08


		; line break
DisplayPrompt_CRLF:
	mov ax, 10<<8|13
	stosw
%if 1
	jmp DisplayPrompt_08
%else
	jmp short DisplayPrompt_08_01
%endif


		; time
DisplayPrompt_Time:
	call formatCurrentTime
	jmp DisplayPrompt_08


		; date
DisplayPrompt_Date:
	call formatCurrentDate
%if 1
	jmp DisplayPrompt_08
%else
	jmp short DisplayPrompt_08_01
%endif


		; path
DisplayPrompt_Path:
	push si

	Int21 CurrentDisk
	mov dl, al					; save drive letter
	add al, 'A'					; get drive
	stosb

	mov ax, ":\"
	stosw						; "d:\"

	inc dl						; A: = 1, ...
	mov si, di
	mov byte [ si ], 0
		; RxDOS 7.20N:	Setting this byte to zero shouldn't be required.
	Int21 LFNGetCurrentDirectory			; get current directory

%if 1
DisplayPrompt_Path_08:
	lodsb
	or al, al
	jnz DisplayPrompt_Path_08

	dec si
	mov di, si
%else
	xor al, al
	repnz scasb					; find terminating zero
	dec di						; point to zero
%endif

	pop si
%if 1
	jmp DisplayPrompt_08
%else
	jmp short DisplayPrompt_08_01
%endif


		; version
DisplayPrompt_Version:
	push si
	mov si, RxDOS_Version
	call CopyString
	dec di						; point to terminating zero
	pop si
%if 1
	jmp DisplayPrompt_08
%else
	jmp short DisplayPrompt_08_01
%endif


		; drive letter
DisplayPrompt_Drive:
	Int21 CurrentDisk
	add al, 'A'					; get drive
 %if 1
	stosb
%if 1
	jmp DisplayPrompt_08
%else
	jmp short DisplayPrompt_08_01
%endif
 %else
	jmp DisplayPrompt_10
 %endif


		; display prompt
DisplayPrompt_48:
	lea dx, [ _buffer + bp ]
	call DisplayLine

	pop di
	return


		; Convert al to 2 character decimal
ConvTo2CharDecimal:

	push cx
	xor ah, ah
	mov cl, 10
	div cl
	or ax, "00"
	stosw

	pop cx
	retn


		; Convert ax to 4 character decimal
ConvTo4CharDecimal:

	push cx
%if 0
	mov cx, 4
	add di, cx
%else
	add di, 4
%endif
	push di
__4CharDecimal_04:
	xor dx, dx
%if 0
	push cx
%endif
	mov cx, 10
	div cx
%if 0
	pop cx
%endif

	dec di
	or dl, '0'
	mov byte [ di ], dl

%if 1
	or ax, ax
	jnz __4CharDecimal_04
		; RxDOS 7.20N:	This only works if ax is at least 1000.
%else
	loop __4CharDecimal_04
%endif

	pop di
	pop cx
	retn


		; Format date string
formatCurrentDate:
	entry
	defbytes	countryInfo, sizeCOUNTRYINFO

	push si
	push di
	mov si, RxDOSIntl_DateTemplate
	call CopyString

	; eventually, make this international

	lea dx, [ COMPAT_WORD _countryInfo + bp ]
	Int21 CountryDependentInfo, 00			; get country info

	Int21 GetDate

	pop di
	xor ah, ah
	mov si, ax
	add si, si
	add si, ax					; offset to day of week text
	add si, RxDOSIntl_DayOfWeek

	push cx
	mov cx, 3
	repz movsb					; copy 3 bytes

	inc di
	mov al, dh					; month
	call ConvTo2CharDecimal

	inc di
	mov al, dl					; day
	call ConvTo2CharDecimal

	inc di
	pop ax						; year
	call ConvTo4CharDecimal

	pop si
	Return


		; Format time string
formatCurrentTime:
	entry
	defbytes	countryInfo, sizeCOUNTRYINFO

	push si
	push di
	mov si, RxDOSIntl_TimeTemplate
	call CopyString

	; eventually, make this international

	lea dx, [ COMPAT_WORD _countryInfo + bp ]
	Int21 CountryDependentInfo, 00			; get country info

	Int21 GetTime

	pop di
	mov al, ch					; hours
	call ConvTo2CharDecimal

	inc di
	mov al, cl					; minutes
	call ConvTo2CharDecimal

	inc di
	mov al, dh					; seconds
	call ConvTo2CharDecimal

	inc di
	mov al, dh					; hundreths
	call ConvTo2CharDecimal

	pop si
	Return


		; DATE [ date ]
		;
		; INP:	ss:di-> argument array
		;	ax = number of arguments in array
_Date:
	entry
	def	_argarray, di				; argument array
	defwords	parsedDatePtrs, 3
	defbytes	parsedDate, sizeDATE
	defbytes	buffer, 128			; input buffer
	defbytes	printbuffer, 128

	; call CheckOptOneArg				; see if 1 arg
	; ifc _dateInvalid				; if error in args

	mov si, word [ argpointer + di ]		; get first arg
	or si, si					; if arg, go parse -->
	jnz _date_26

		; display current date
	lea di, [ _buffer + bp ]
	push di						; address of
	call formatCurrentDate				; get current date

	mov di, _ShowCurrentDate
	push di
	lea di, [ _printbuffer + bp ]
	push di
	call _sprintf
	add sp, ax					; number of arguments passed
	call DisplayLine


		; please enter date
_date_12:
	call DisplayPleaseEnterDate

	lea di, [ _buffer + bp ]
	mov byte [ bufMaxLength + di ], 128
	mov word [ bufActualLength + di ], 0

	mov dx, di					; where buffer
	call _getStdinLine				; read buffer
	;;call CRLF

	mov bl, byte [ _buffer + bufActualLength + bp ]
	and bx, 255
	ifz _dateReturn

	add bx, bp
	mov byte [ _buffer + bufData + bx ], 00		; place a null terminator
	lea si, [ _buffer + bufData + bp ]		; parse text


		; parse arg at [ si ]
_date_26:
	push si						; pointer to start of first arg
	lea si, [ COMPAT_WORD _parsedDate + bp ]	; start of buffer
	lea di, [ COMPAT_WORD _parsedDatePtrs + bp ]
	call _GetDateTemplate

	pop si
	call _GetNumber					; get argument
	mov di, word [ _parsedDatePtrs + bp ]
	mov word [ ss:di ], dx				; store first argument

	cmp byte [ si-1 ], '-'
	je _date_28
	cmp byte [ si-1 ], '/'
	je _date_28
	cmp byte [ si-1 ], '.'
	jne _dateInvalid				; else invalid -->

_date_28:
	call _GetNumber					; get argument
	mov di, word [ _parsedDatePtrs + 2 + bp ]
	mov word [ ss:di ], dx				; store second argument

	cmp byte [ si-1 ], '-'
	je _date_32
	cmp byte [ si-1 ], '/'
	je _date_32
	cmp byte [ si-1 ], '.'
	jne _dateInvalid				; else invalid -->

_date_32:
	call _GetNumber					; get last argument
	mov di, word [ _parsedDatePtrs + 4 + bp ]
	mov word [ ss:di ], dx				; store third argument


		; parse year
	mov ax, word [ _parsedDate + _YEAR + bp ]	; start of buffer
	cmp ax, 1980					; greater than 1980 ?
	jae _date_42					; valid -->
	cmp ax, 80					; less than 80 ?
	jae _date_36
	add ax, 2000					; must be between 2000 - 2099

_date_36:
	cmp ax, 100					; between 80 and 100 ?
	jae _date_38					; no -->
	add ax, 1900

_date_38:
	cmp ax, 1980
	jb _dateInvalid					; if invalid -->
	cmp ax, 2100
	jae _dateInvalid				; if invalid -->

_date_42:
	mov cx, ax					; year
	mov dh, byte [ _parsedDate + _MONTH + bp ]	; month
	mov dl, byte [ _parsedDate + _DAY + bp ]	; day
	Int21 SetDate
	or al, al					; date valid ?
	jnz _dateInvalid				; no -->


		; return
_dateReturn:
	Return


		; invalid date
_dateInvalid:
	mov dx, CmndError_InvalidDate
	call DisplayLine
	jmp _date_12					; re-prompt -->


		; PROMPT [ prompt ]
		;
		; INP:	ss:di-> argument array
		;	ax = number of arguments in array
_Prompt:

	mov si, word [ di ]				; get pointer to arg
	or si, si
	jnz _prompt_08
	mov si, RxDOS_DefaultPrompt

_prompt_08:
	mov di, RxDOS_Prompt
	call CopyString

		; insert prompt=
	mov si, RxDOS_PromptSpec			; locate PROMPT=
	call searchEnvVariable				; environment variable located ?
	jnz _prompt_12					; if not located -->
	call deleteEnvVariable

_prompt_12:
	mov si, RxDOS_PromptSpec			; insert PROMPT=
	call insertEnvVariable
	call DisplayOutEnvSpace				; if error, display message
	jc _prompt_18					; if error -->

	mov si, RxDOS_Prompt
	call insertEnvVariable
	call DisplayOutEnvSpace				; if error, display message

_prompt_18:
	retn


		; TIME [ time ]
		;
		; INP:	ss:di-> argument array
		;	ax = number of arguments in array
_Time:
	entry
	def	_argarray, di				; argument array
	defbytes	parsedTime, sizeTIME		; time structure
	defbytes	buffer, 128			; input buffer
	defbytes	printbuffer, 128

	call CheckOptOneArg				; see if 1 arg
	ifc _timeInvalid				; if error in args

	mov si, word [ argpointer + di ]		; get first arg
	or si, si					; if arg, go parse -->
	jnz _time_26


		; display current time
	lea di, [ _buffer + bp ]
	push di
	call formatCurrentTime				; get current time

	mov di, _ShowCurrentTime
	push di
	lea di, [ _printbuffer + bp ]
	push di
	call _sprintf
	add sp, ax					; # args passed
	call DisplayLine


		; please enter time
_time_12:
	mov dx, _PleaseEnterTime
	call DisplayLine

	lea di, [ _buffer + bp ]
	mov byte [ bufMaxLength + di ], 128
	mov word [ bufActualLength + di ], 0

	mov dx, di					; where buffer
	call _getStdinLine				; read buffer
	;;call CRLF

	mov bl, byte [ _buffer + bufActualLength + bp ]
	and bx, 255
	ifz _timeReturn
	COMPAT_NOP

	add bx, bp
	mov byte [ _buffer + bufData + bx ], 00		; place a null terminator
	lea si, [ _buffer + bufData + bp ]		; parse text


		; parse arg at [ si ]	** must internationalize by matching template **
_time_26:
	xor ax, ax
	mov word [ _parsedTime + _HOURS + bp ], ax
	mov word [ _parsedTime + _MINUTES + bp ], ax
	mov word [ _parsedTime + _SECONDS + bp ], ax
	mov word [ _parsedTime + _HUNDREDTHS + bp ], ax

	call _GetNumber					; get hours
	mov word [ _parsedTime + _HOURS + bp ], dx

	call _checkSeparator
	jc _timeInvalid
	jz _time_36
	call _GetNumber					; get minutes
	mov word [ _parsedTime + _MINUTES + bp ], dx

	call _checkSeparator
	jc _timeInvalid
	jz _time_36
	call _GetNumber					; get seconds
	mov word [ _parsedTime + _SECONDS + bp ], dx

	call _checkSeparator
	jc _timeInvalid
	jz _time_36
	call _GetNumber					; get hundreths of seconds
	mov word [ _parsedTime + _HUNDREDTHS + bp ], dx

_time_36:
	mov dl, byte [ _parsedTime + _HUNDREDTHS + bp ]
	mov dh, byte [ _parsedTime + _SECONDS + bp ]
	mov cl, byte [ _parsedTime + _MINUTES + bp ]
	mov ch, byte [ _parsedTime + _HOURS + bp ]
	Int21 SetTime
	or al, al					; date valid ?
	jnz _timeInvalid				; no -->


		; return
_timeReturn:
	Return


		; invalid time
_timeInvalid:
	mov dx, CmndError_InvalidTime
	call DisplayLine
	jmp _time_12


		; Test time separator
_checkSeparator:

	mov al, byte [ si-1 ]				; get last character processed
	or al, al					; if end of line -->
	jz _checkSeparator_24				; return end of line -->

	cmp al, ' '
	jnz _checkSeparator_06				; skip any spaces -->

	inc si
	jmp short _checkSeparator

_checkSeparator_06:
	_lowerCase al

	cmp al, ':'
	jz _checkSeparator_24				; return valid separator -->
	cmp al, '.'
	jz _checkSeparator_24				; return valid separator -->

	cmp al, 'a'					; am / pm ?
	jz _checkSeparator_12				; yes -->
	cmp al, 'p'					; am / pm ?
	jz _checkSeparator_10				; yes -->

	stc						; anything else is an error
	retn

_checkSeparator_10:
	cmp byte [ _HOURS + bp ], 12
%if 1
	jge _checkSeparator_12
%else
	jae _checkSeparator_12
%endif
	add byte [ _HOURS + bp ], 12

_checkSeparator_12:
	xor ax, ax

_checkSeparator_24:
	or al, al
	retn


		; Get international date template
		;
		; INP:	si-> DayMonthYear buffer
		;	di-> DayMonthYear array of pointers
_GetDateTemplate:
	entry
	def	DayMonthYear, si
	def	DayMonthYearPtrs, di

	mov word [ ss:di ], si
	mov word [ ss:di + 2 ], si
	mov word [ ss:di + 4 ], si			; initialize pointers to base


		; scan date template
	call returnDateTimeTemplate

	xor bx, bx					; argument order
	getarg di, _DayMonthYearPtrs			; start with arg array

_GetDateTemplate_14:
	lodsw						; get characters
	Goto 'd', _GetDateTemplate_Day			; if day -->
	COMPAT_NOP
	Goto 'm', _GetDateTemplate_Month		; if month -->
	COMPAT_NOP
	Goto 'y', _GetDateTemplate_Year			; if year -->
	COMPAT_NOP
	jmp short _GetDateTemplate_Done

_GetDateTemplate_Day:
	add word [ ss:di + bx ], _DAY
	jmp short _GetDateTemplate_SkipToSeparator

_GetDateTemplate_Month:
	add word [ ss:di + bx ], _MONTH
	jmp short _GetDateTemplate_SkipToSeparator

_GetDateTemplate_Year:
	add word [ ss:di + bx ], _YEAR
	; jmp short _GetDateTemplate_SkipToSeparator


		; skip to next argument
_GetDateTemplate_SkipToSeparator:
	lodsb
	or al, al					; end of string ?
	jz _GetDateTemplate_Done			; yes, done -->
	cmp al, 'a'					; none text ?
	jnc _GetDateTemplate_SkipToSeparator		; still on text -->

	inc bx
	inc bx						; advance reference pointer
	jmp short _GetDateTemplate_14			; continue -->


		; done
_GetDateTemplate_Done:
	Return


		; Display get date prompt
DisplayPleaseEnterDate:

	mov dx, _PleaseEnterDate
	call DisplayLine

	mov dl, '('
	Int21 DisplayOutput

	call returnDateTimeTemplate
	mov cx, bx
	sub cx, si					; length of string
	dec cx

DisplayPleaseEnterDate_08:
	lodsb
	mov dl, al
	Int21 DisplayOutput
	loop DisplayPleaseEnterDate_08

	mov dl, ')'
	Int21 DisplayOutput
	mov dl, ':'
	Int21 DisplayOutput
	mov dl, ' '
	Int21 DisplayOutput

	retn


		; Find international date/time template
		;
		; OUT:	si-> date template
		;	bx-> time template
		;	ax = country code
returnDateTimeTemplate:
	entry
	def	countryCode
	def	dateTemplate
	def	timeTemplate
	defbytes	countryInfo, sizeCOUNTRYINFO

	push di
	lea dx, [ COMPAT_WORD _countryInfo + bp ]
	Int21 CountryDependentInfo, 00			; get country info
	mov word [ _countryCode + bp ], bx		; save value


		; locate international template
	mov di, RxDOSIntl_DateTimeTable

returnTemplate_08:
	inc di
	inc di
	cmp bx, word [ di - 2 ]				; is it current entry ?
	jz returnTemplate_12				; yes -->

	mov cx, -1
	xor ax, ax
	repnz scasb					; scan for null terminator

	cmp word [ di ], byte 0				; end of table ?
	jnz returnTemplate_08				; no, continue looking -->

	mov di, RxDOSIntl_DateTimeTable			; use USA if no valid entry


		; compute time template
returnTemplate_12:
	storarg _dateTemplate, di

	mov al, ' '
	mov cx, -1
	repnz scasb					; search for space delimeter

	mov bx, di					; time template address
	getarg si, _dateTemplate			; date template address
	getarg ax, _countrycode				; country code

	pop di
	Return


%if 0

RxDOSCTB - RxDOS country information tables

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

	global FindCountryInfo
	global RxDOS_USA_DefaultUpperCaseFunction
%endif

		; Default USA Upper Case Routine
		; 
		; Usage:
		; al	Contains character. Converted to Upper Case
relocated casemap:
RxDOS_USA_DefaultUpperCaseFunction:

	cmp al, 128
	jb _USA_Default08

	push bx
	xor bx, bx
	mov bl, al					; pointer to
	mov al, byte [ cs:bx + _RxDOS_USA_UpperCaseTable ]
	pop bx

_USA_Default08:
	retf


		; Default USA Upper Case Table
_RxDOS_USA_UpperCaseTable:
		;  128, 129, 130, 131, 132, 133, 134, 135
		db 128, 154, "E", "A", 143, "A", 143, 128

		;  136, 137, 138, 139, 140, 141, 142, 143
		db "E", "E", "E", "I", "I", "I", 142, 143

		;  144, 145, 146, 147, 148, 149, 150, 151
		db 144, 146, 146, "O", 153, "O", "U", "U"

		;  152, 153, 154, 155, 156, 157, 158, 159
		db "Y", 153, 154, 155, 156, 157, 158, 159

		;  160, 161, 162, 163, 164, 165, 166, 167
		db "A", "I", "O", "U", 164, 165, 166, 167

		;  168, 169, 170, 171, 172, 173, 174, 175
		db 168, 169, 170, 171, 172, 173, 174, 175

		;  176, 177, 178, 179, 180, 181, 182, 183
		db 176, 177, 178, 179, 180, 181, 182, 183

		;  184, 185, 186, 187, 188, 189, 190, 191
		db 184, 185, 186, 187, 188, 189, 190, 191

		;  192, 193, 194, 195, 196, 197, 198, 199
		db 192, 193, 194, 195, 196, 197, 198, 199

		;  200, 201, 202, 203, 204, 205, 206, 207
		db 200, 201, 202, 203, 204, 205, 206, 207

		;  208, 209, 210, 211, 212, 213, 214, 215
		db 208, 209, 210, 211, 212, 213, 214, 215

		;  216, 217, 218, 219, 220, 221, 222, 223
		db 216, 217, 218, 219, 220, 221, 222, 223

		;  224, 225, 226, 227, 228, 229, 230, 231
		db 224, 225, 226, 227, 228, 229, 230, 231

		;  232, 233, 234, 235, 236, 237, 238, 239
		db 232, 233, 234, 235, 236, 237, 238, 239

		;  240, 241, 242, 243, 244, 245, 246, 247
		db 240, 241, 242, 243, 244, 245, 246, 247

		;  248, 249, 250, 251, 252, 253, 254, 255
		db 248, 249, 250, 251, 252, 253, 254, 255


		; Country Info
	struc CODEPAGERECORD
ctyinfo_reclength	resw 1
ctyinfo_countrycode	resw 1
ctyinfo_codepage	resw 1
ctyinfo_countryinfo	resb sizeCOUNTRYINFO
	endstruc

sizeCODEPAGERECORD	equ CODEPAGERECORD_size


		; Find country info
		; 
		; Input:
		; ax = country code
		; 
		; Output:
		; cs:si-> country info table
		; dx = code page
		; CY if error (ax will be -1)
	doscode_insure_low_byte_not_0CCh
FindCountryInfo:

	mov si, RxDOS_COUNTRYInfo

FindCountryInfo_08:
	cmp ax, word [ cs:si + ctyinfo_countrycode ]	; matches requested country ?
	jnz FindCountryInfo_12				; yes -->

	mov dx, word [ cs:si + ctyinfo_codepage ]	; set code page
	lea si, [ word ctyinfo_countryinfo + si ]
	clc
	retn

FindCountryInfo_12:
	add si, sizeCODEPAGERECORD			; size of record
	cmp word [ cs:si + ctyinfo_countrycode ], byte -1	; end of table ?
	jnz FindCountryInfo_08				; no -->

	mov ax, -1
	stc
	retn

RxDOS_COUNTRYInfo:

		; United States
	dw sizeCOUNTRYINFO				; size of record
	dw COUNTRY_UNITEDSTATES				; country code
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_MMDDYY					; date format
	db '$', 0, 0, 0, 0				; currency format
	dw ','						; thousands separator
	dw '.'						; decimal separator
	dw '-'						; date separator
	dw ':'						; time separator
	db CURRENCY_BEFORE				; currency bit field
	db 2						; currency places
	db TIME_12HOUR					; time format
	dw casemap, 70h
	dw ','						; data separator

		; Canadian-French
	dw sizeCOUNTRYINFO				; size of record
	dw COUNTRY_CANADIANFRENCH			; country code
	dw CODEPAGE_CANADIANFRENCH			; code page
	dw DATE_DDMMYY					; date format
	db '$', 0, 0, 0, 0				; currency format
	dw ' '						; thousands separator
	dw ','						; decimal separator
	dw '-'						; date separator
	dw ':'						; time separator
	db CURRENCY_BEFORE				; currency bit field
	db 2						; currency places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data separator

		; Latin America
	dw sizeCOUNTRYINFO				; size of record
	dw COUNTRY_LATINAMERICA				; country code
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db '$', 0, 0, 0, 0				; currency format
	dw ','						; thousands separator
	dw '.'						; decimal separator
	dw '/'						; date separator
	dw ':'						; time separator
	db CURRENCY_BEFORE				; currency bit field
	db 2						; currency places
	db TIME_12HOUR					; time format
	dw casemap, 70h
	dw ','						; data separator

		; Russia (CP866)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_RUSSIA				; country
	dw CODEPAGE_CYRILLIC				; code page
	dw DATE_DDMMYY					; date format
	db 20h, 0E0h, 0E3h, 0A1h, 2Eh			;
	dw ' '						; thousands sep
	dw '.'						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Russia (CP437)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_RUSSIA				; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 'r','u', 'b', '.', 0				; rub.
	dw ' '						; thousands sep
	dw '.'						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Russia (CP850)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_RUSSIA				; country
	dw CODEPAGE_MULTILINGUAL			; code page
	dw DATE_DDMMYY					; date format
	db 'r','u', 'b', '.', 0				; rub.
	dw ' '						; thousands sep
	dw '.'						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Russia (CP855)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_RUSSIA				; country
	dw CODEPAGE_SLAVIC_II				; code page
	dw DATE_DDMMYY					; date format
	db 20h, 0E1h, 0E7h, 0A2h, 2Eh			;
	dw ' '						; thousands sep
	dw '.'						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Russia (CP852)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_RUSSIA				; country
	dw CODEPAGE_SLAVIC				; code page
	dw DATE_DDMMYY					; date format
	db 'r','u', 'b', '.', 0				; rub.
	dw ' '						; thousands sep
	dw '.'						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Netherlands
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_NETHERLANDS				; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 9Fh, 0, 0, 0, 0				;
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '-'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Belgium
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_BELGIUM				; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 'B', 'F', 0, 0, 0				; BF
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; France
	dw sizeCOUNTRYINFO				; size of record
	dw COUNTRY_FRANCE				; country code
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 'F', 0, 0, 0, 0				; currency
	dw ' '						; thousands separator
	dw ','						; decimal separator
	dw '.'						; date separator
	dw ':'						; time separator
	db CURRENCY_AFTER + CURRENCY_SPACEBETWEEN	; currency bit field
	db 2						; currency places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data separator

		; Spain (currency single-character)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_SPAIN				; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 9Eh, 0, 0, 0, 0				;
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 0						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Spain (currency string)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_SPAIN				; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 'P', 't', 's', 0, 0				; Pts..
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 0						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Hungary
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_HUNGARY				; country
	dw CODEPAGE_SLAVIC				; code page
	dw DATE_YYMMDD					; date format
	db 'F', 't', 0, 0, 0				; Ft
	dw ' '						; thousands sep
	dw ','						; decimal sep
	dw '-'						; date sep
	dw ':'						; time sep
	db CURRENCY_BEFORE				; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; Serbia/Yugoslavia
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_SERBIA_YUGOSLAVIA			; country
	dw CODEPAGE_SLAVIC				; code page
	dw DATE_YYMMDD					; date format
	db 'D', 'i', 'n', 0, 0				; currency: Din
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '-'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; Italy
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_ITALY				; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 'L', '.', 0, 0, 0				; 'L.'
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '/'						; date sep
	dw '.'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 0						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Switzerland
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_SWITZERLAND				; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 'F', 'r', '.', 0, 0				; Fr.
	dw "'"						; thousands sep
	dw '.'						; decimal sep
	dw '.'						; date sep
	dw ','						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Czech Republic
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_CZECHREPUBLIC			; country
	dw CODEPAGE_SLAVIC				; code page
	dw DATE_YYMMDD					; date format
	db 4Bh, 9Fh, 73h, 0, 0				; K.s
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '-'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; United Kingdom (Great Britain)
	dw sizeCOUNTRYINFO				; size of record
	dw COUNTRY_UNITEDKINGDOM			; country code
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 9Ch, 0, 0, 0, 0				; currency
	dw ','						; thousands separator
	dw '.'						; decimal separator
	dw '/'						; date separator
	dw ':'						; time separator
	db CURRENCY_BEFORE				; currency bit field
	db 2						; currency places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data separator

		; Denmark
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_DENMARK				; country
	dw CODEPAGE_NORDIC				; code page
	dw DATE_DDMMYY					; date format
	db 6Bh, 72h, 0h, 0h, 0				; kr...
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '-'						; date sep
	dw '.'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Sweden
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_SWEDEN				; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 'K', 'r', 0, 0, 0				; Kr
	dw ' '						; thousands sep
	dw ','						; decimal sep
	dw '-'						; date sep
	dw '.'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Norway
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_NORWAY				; country
	dw CODEPAGE_NORDIC				; code page
	dw DATE_DDMMYY					; date format
	db 'K', 'r', 0, 0, 0				; Kr
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '.'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Poland
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_POLAND				; country
	dw CODEPAGE_SLAVIC				; code page
	dw DATE_YYMMDD					; date format
	db 5Ah, 88h, 0, 0, 0				; Z.
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '-'						; date sep
	dw ':'						; time sep
	db CURRENCY_BEFORE				; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; Germany
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_GERMANY				; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 'E', 'U', 'R', 0, 0				; EUR
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '.'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Brazil
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_BRAZIL				; country
	dw CODEPAGE_MULTILINGUAL			; code page
	dw DATE_DDMMYY					; date format
	db 'C', 'r', '$', 0, 0				; Cr$
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_BEFORE				; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; International English
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_INTERNATIONAL_ENGLISH		; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db '$', 0, 0, 0, 0				; $
	dw ','						; thousands sep
	dw '.'						; decimal sep
	dw '-'						; date sep
	dw ':'						; time sep
	db CURRENCY_BEFORE				; currency format
	db 2						; decimal places
	db TIME_12HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; Japan
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_JAPAN				; country
	dw CODEPAGE_JAPAN				; code page
	dw DATE_YYMMDD					; date format
	db 5Ch, 0, 0, 0, 0				; Y
	dw ','						; thousands sep
	dw '.'						; decimal sep
	dw '-'						; date sep
	dw ':'						; time sep
	db CURRENCY_BEFORE				; currency format
	db 0						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; Korea
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_KOREA				; country
	dw CODEPAGE_KOREA				; code page
	dw DATE_YYMMDD					; date format
	db 5Ch, 0, 0, 0, 0				; Y
	dw ','						; thousands sep
	dw '.'						; decimal sep
	dw '.'						; date sep
	dw ':'						; time sep
	db CURRENCY_BEFORE				; currency format
	db 0						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; China
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_CHINA				; country
	dw CODEPAGE_CHINA				; code page
	dw DATE_YYMMDD					; date format
	db 5Ch, 0, 0, 0, 0				; Y
	dw ','						; thousands sep
	dw '.'						; decimal sep
	dw '-'						; date sep
	dw ':'						; time sep
	db CURRENCY_BEFORE				; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; Taiwan
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_TAIWAN				; country
	dw CODEPAGE_TAIWAN				; code page
	dw DATE_YYMMDD					; date format
	db 'N', 'T', '$', 0, 0				; NT$
	dw ','						; thousands sep
	dw '.'						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_BEFORE				; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; Turkey (CP850)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_TURKEY				; country
	dw CODEPAGE_MULTILINGUAL			; code page
	dw DATE_DDMMYY					; date format
	db 'T', 'L', 0, 0, 0				; TL
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db 04						; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; Turkey (CP859)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_TURKEY				; country
	dw CODEPAGE_TURKEY				; code page
	dw DATE_DDMMYY					; date format
	db 'T', 'L', 0, 0, 0				; TL
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db 04						; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

		; Portugal
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_PORTUGAL				; country
	dw CODEPAGE_PORTUGAL				; code page
	dw DATE_DDMMYY					; date format
	db 'E', 's', 'c', '.', 0			; Esc.
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '-'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Iceland
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_ICELAND				; country
	dw CODEPAGE_ICELAND				; code page
	dw DATE_DDMMYY					; date format
	db 0A5h, 4Bh, 72h, 0, 0				; %Kr..
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '.'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep


		; Finland
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_FINLAND				; country
	dw CODEPAGE_UNITEDSTATES			; code page
	dw DATE_DDMMYY					; date format
	db 'm', 'k', 0, 0, 0				; mk
	dw ' '						; thousands sep
	dw ','						; decimal sep
	dw '.'						; date sep
	dw '.'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Middle East/Saudi Arabia (currency 1)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_MIDDLEEAST				; country
	dw CODEPAGE_MIDDLEEAST				; code page
	dw DATE_DDMMYY					; date format
	db 0A4h, 0, 0, 0, 0				;
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 3						; decimal places
	db TIME_12HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Middle East/Saudi Arabia (currency 2)
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_MIDDLEEAST				; country
	dw CODEPAGE_MIDDLEEAST				; code page
	dw DATE_DDMMYY					; date format
	db 0CFh, 0, 0, 0, 0				;
	dw '.'						; thousands sep
	dw ','						; decimal sep
	dw '/'						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN + CURRENCY_AFTER	; currency format
	db 3						; decimal places
	db TIME_12HOUR					; time format
	dw casemap, 70h
	dw ';'						; data sep

		; Israel
	dw sizeCOUNTRYINFO				; length
	dw COUNTRY_ISRAEL				; country
	dw CODEPAGE_MIDDLEEAST				; code page
	dw DATE_DDMMYY					; date format
	db 99h, 0, 0, 0, 0				;
	dw ','						; thousands sep
	dw '.'						; decimal sep
	dw ' '						; date sep
	dw ':'						; time sep
	db CURRENCY_SPACEBETWEEN			; currency format
	db 2						; decimal places
	db TIME_24HOUR					; time format
	dw casemap, 70h
	dw ','						; data sep

_RxDOS_COUNTRY_EndInfo:
	dw -1						; end of country info





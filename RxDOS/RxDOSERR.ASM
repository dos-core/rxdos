
%if 0

RxDOSERR - RxDOS extended error information

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

	global pexterrInvalidFunction
	global pexterrFileNotFound
	global pexterrPathNotFound
	global pexterrIllegalName
	global pexterrNoHandlesAvailable
	global pexterrAccessDenied
	global pexterrInvalidHandle
	global pexterrArenaTrashed
	global pexterrNotEnoughMemory
	global pexterrInvalidBlock
	global pexterrInvalidAccess
	global pexterrInvalidDrive
	global pexterrCurrentDirectory
	global pexterrNoMoreFiles
	global pexterrFileExists
	global pexterrBadReqStruc

	global GetExtErrorCodeValue
	global GetAllExtErrorInfo


		; Extended Error Tables

		; _EXTERRORCODE Structure
	struc _EXTERRORCODE
ExtErrorCodeValue	resw 1
Locus			resb 1
SuggestedAction		resb 1
ErrorClass		resb 1
			resb 1
	endstruc

		; Extended error table macro
		;
		; %1 = Extended error code
		; %2 = Locus
		; %3 = Suggested action
		; %4 = Error class
	%imacro EXTERRORCODE 4.nolist
	istruc _EXTERRORCODE
at ExtErrorCodeValue	, dw %1
at Locus		, db %2
at SuggestedAction	, db %3
at ErrorClass		, db %4
	iend
	%endmacro


pexterrInvalidFunction	EXTERRORCODE errInvalidFunction, ERRLOC_UNK, ERRACT_USER, ERRCLASS_NOTFND

pexterrFileNotFound	EXTERRORCODE errFileNotFound, ERRLOC_DISK, ERRACT_USER, ERRCLASS_NOTFND

pexterrPathNotFound	EXTERRORCODE errPathNotFound, ERRLOC_DISK, ERRACT_USER, ERRCLASS_NOTFND

pexterrIllegalName	EXTERRORCODE errIllegalName, ERRLOC_UNK, ERRACT_USER, ERRCLASS_NOTFND

pexterrNoHandlesAvailable	EXTERRORCODE errNoHandlesAvailable, ERRLOC_UNK, ERRACT_USER, ERRCLASS_OUTRES

pexterrAccessDenied	EXTERRORCODE errAccessDenied, ERRLOC_UNK, ERRACT_USER, ERRCLASS_NOTFND

pexterrInvalidHandle	EXTERRORCODE errInvalidHandle, ERRLOC_UNK, ERRACT_USER, ERRCLASS_NOTFND

pexterrArenaTrashed	EXTERRORCODE errArenaTrashed, ERRLOC_MEM, ERRACT_USER, ERRCLASS_NOTFND

pexterrNotEnoughMemory	EXTERRORCODE errNotEnoughMemory, ERRLOC_MEM, ERRACT_RETRY, ERRCLASS_NOTFND

pexterrInvalidBlock	EXTERRORCODE errInvalidBlock, ERRLOC_UNK, ERRACT_USER, ERRCLASS_NOTFND

pexterrInvalidAccess	EXTERRORCODE errInvalidAccess, ERRLOC_UNK, ERRACT_USER, ERRCLASS_NOTFND

pexterrInvalidDrive	EXTERRORCODE errInvalidDrive, ERRLOC_UNK, ERRACT_USER, ERRCLASS_NOTFND

pexterrCurrentDirectory	EXTERRORCODE errCurrentDirectory, ERRLOC_UNK, ERRACT_USER, ERRCLASS_AUTH

pexterrNoMoreFiles	EXTERRORCODE errNoMoreFiles, ERRLOC_UNK, ERRACT_USER, ERRCLASS_NOTFND

pexterrFileExists	EXTERRORCODE errFileExists, ERRLOC_UNK, ERRACT_USER, ERRCLASS_NOTFND

pexterrBadReqStruc	EXTERRORCODE errBadReqStruc, ERRLOC_UNK, ERRACT_USER, ERRCLASS_APPERR


		; Get Extended Error Info
GetExtErrorCodeValue:
	mov ax, word [ cs:si + ExtErrorCodeValue ]	; get actual error value
	retn


		; Get All Extended Error Info
GetAllExtErrorInfo:
	mov ax, word [ cs:bx + ExtErrorCodeValue ]	; else get error values
	mov ch, byte [ cs:bx + Locus ]
	mov dl, byte [ cs:bx + SuggestedAction ]
	mov dh, byte [ cs:bx + ErrorClass ]
	retn


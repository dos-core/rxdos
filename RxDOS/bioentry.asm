
%if 0

bioentry - RxDOS Basic Input/Output kernel entrypoints

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


		; Reallocated Space
	align 16
RxBIO_DiskBuffer:
	times 8192 + 16 db 0



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
dosentry_to_dosdata_segment:		dw 0
doscode_segment:		dw 0

		align 4
ptrStartBlockedDeviceTable:	dd -1		; -> first UPB


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
		; CON definition
	devheader con, clock, 70h, (DEV_CHAR+ DEV_STDINPUT+ DEV_STDOUTPUT+ DEV_FASTCHARIO), \
		con_strategy, DEVInterrupt, 'CON'

		; CLOCK$ definition
	devheader clock, prn, 70h, (DEV_CHAR+ DEV_CLOCK), \
		clock_strategy, DEVInterrupt, 'CLOCK$'

		; PRN, LPT1, LPT2, LPT3 definitions
	devheader prn, lpt1, 70h, (DEV_CHAR+ DEV_OUTPUTTILLBUSY), \
		prn_strategy, DEVInterrupt, 'PRN'
	devheader lpt1, lpt2, 70h, (DEV_CHAR+ DEV_OUTPUTTILLBUSY), \
		lpt1_strategy, DEVInterrupt, 'LPT1'
	devheader lpt2, lpt3, 70h, (DEV_CHAR+ DEV_OUTPUTTILLBUSY), \
		lpt2_strategy, DEVInterrupt, 'LPT2'
	devheader lpt3, aux, 70h, (DEV_CHAR+ DEV_OUTPUTTILLBUSY), \
		lpt3_strategy, DEVInterrupt, 'LPT3'

		; AUX, COM1, COM2, COM3, COM4 definitions
	devheader aux, com1, 70h, (DEV_CHAR), \
		aux_strategy, DEVInterrupt, 'AUX'
	devheader com1, com2, 70h, (DEV_CHAR), \
		com1_strategy, DEVInterrupt, 'COM1'
	devheader com2, com3, 70h, (DEV_CHAR), \
		com2_strategy, DEVInterrupt, 'COM2'
	devheader com3, com4, 70h, (DEV_CHAR), \
		com3_strategy, DEVInterrupt, 'COM3'
	devheader com4, block, 70h, (DEV_CHAR), \
		com4_strategy, DEVInterrupt, 'COM4'

		; Block Device, pre-initialised to three units
	devheader block, -1, -1, (DEV_REMOVABLEMEDIA+ DEV_LOGICALMAPPING+ DEV_IOCTL), \
		block_strategy, DEVInterrupt, 3, "RXBLOCK"

	align 2
		; Comm LookAhead Buffer
Comm_LookAhead:		times 4 db 0			; COM1, COM2, COM3, COM4

		; CON variables
Con_LookAhead		dw 0
Con_TabPosition		dw 0
Con_ScanCode		db 0


	align 2
		; Strategies
clock_strategy:	relocate DEVStrategy, clock_servicetable

prn_strategy:	relocate DEVStrategy, prn_servicetable, 0
lpt1_strategy:	relocate DEVStrategy, prn_servicetable, 0
lpt2_strategy:	relocate DEVStrategy, prn_servicetable, 1
lpt3_strategy:	relocate DEVStrategy, prn_servicetable, 2

aux_strategy:	relocate DEVStrategy, aux_servicetable, 0
com1_strategy:	relocate DEVStrategy, aux_servicetable, 0
com2_strategy:	relocate DEVStrategy, aux_servicetable, 1
com3_strategy:	relocate DEVStrategy, aux_servicetable, 2
com4_strategy:	relocate DEVStrategy, aux_servicetable, 3

con_strategy:	relocate DEVStrategy, con_servicetable
block_strategy:	relocate DEVStrategy, block_servicetable

DEVInterrupt:	retf


		; Reallocated Space
	align 16
RxBIO_DiskBuffer:
	times 8192 + 16 db 0


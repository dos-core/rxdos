
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


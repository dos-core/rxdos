#! /bin/bash

# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

export NASMENV="$@"

function nasmbin() {
	nasm -Ox -i../MACRO/ -I../bin/ -I../lmacros/ -I../../lmacros/ -d__MAPFILE__=../map/$1.MAP -l../lst/$1.LST -fbin -o../bin/$2.$3 $1.ASM
}
function nasmobj() {
	nasm -Ox -i../MACRO/ -l../lst/$1.LST -fobj -o../obj/$1.OBJ $1.ASM
}

cd "${0%/*}"
toolsdir="${PWD}/../dostools"
((debug)) && echo "toolsdir=\"$toolsdir\""


cd RxAPP
if [ -f RxVDISK.ASM ]; then {
	echo Building RxVDISK
	nasmbin RxVDISK RxVDISK SYS || exit
} fi

if [ -f RxBOOT.ASM ]; then {
	echo Building RxBOOT
	nasmbin RxBOOT RxBOOT SYS || exit
} fi

if [ -f RxMBR.ASM ]; then {
	echo Building RxMBR
	nasmbin RxMBR RxMBR SYS || exit
} fi

if [ -f RxD_BOOT.ASM ]; then {
	echo Building RxD_BOOT
	nasmbin RxD_BOOT RxD_BOOT SYS || exit
	if [ -f ../bin/RxBOOT.SYS ]; then {
	cat ../bin/RxD_BOOT.SYS ../bin/RxBOOT.SYS > ../bin/RxD_BOOT.COM
	} fi
} fi


cd ../RxDOS

if [ -f RxDOS.ASM -a \
	-f RxDOSCCB.ASM -a \
	-f RxDOSDEV.ASM -a \
	-f RxDOSEXE.ASM -a \
	-f RxDOSFAT.ASM -a \
	-f RxDOSFCB.ASM -a \
	-f RxDOSFIL.ASM -a \
	-f RxDOSLFN.ASM -a \
	-f RxDOSF32.ASM -a \
	-f RxDOSIFS.ASM -a \
	-f RxDOSMEM.ASM -a \
	-f RxDOSSFT.ASM -a \
	-f RxDOSSTR.ASM -a \
	-f RxDOSCTB.ASM -a \
	-f RxDOSERR.ASM -a \
	-f RxDOSINI.ASM ]; then {
  if ((!_BUILD_OBJ)); then {
	echo Building RxDOS
	nasmbin RxDOS RxDOS SYS || exit
  } else {
	echo Building RxDOS
	for x in RxDOS RxDOSCCB RxDOSDEV RxDOSEXE RxDOSFAT RxDOSFCB RxDOSFIL \
		RxDOSLFN RxDOSF32 RxDOSIFS RxDOSMEM RxDOSSFT RxDOSSTR \
		RxDOSCTB RxDOSERR RxDOSINI; do
		nasmobj "$x" || exit;
	done

	echo > STACK\$\$.ASM
	echo	segment STACK\$\$ align=16 class=RXDOS use16 stack >> STACK\$\$.ASM
	echo			resw 1 >> STACK\$\$.ASM
	echo >> STACK\$\$.ASM
	nasm -fobj -o../obj/STACK\$\$.OBJ STACK\$\$.ASM || exit
	rm STACK\$\$.ASM

	cd ../obj

	echo "/s /mx /xt +" > warplink.lin
		for x in RxDOS RxDOSCCB RxDOSDEV RxDOSEXE RxDOSFAT RxDOSFCB RxDOSFIL \
			RxDOSLFN RxDOSF32 RxDOSIFS RxDOSMEM RxDOSSFT RxDOSSTR \
			RxDOSCTB RxDOSERR RxDOSINI; do
			echo $x.OBJ + >> warplink.lin
		done

	echo "STACK\$\$.OBJ,RxDOS.EXE,..\\map\\RxDOS.MAP,;" >> warplink.lin

	unix2dos -q warplink.lin
	cd ..
	dosemu -q -dumb -E "doscmd.bat $(realpath "$toolsdir" |
sed -re 's/\//\\/g') WARPLINK.EXE obj @warplink.lin" || exit

#	exe2bin -r -l=0 RxDOS.EXE ..\bin\RxDOS.SYS || exit
#	exe2bin -x -r -l=0 RxDOS.EXE ../bin/RxDOS.SYS || exit
	dosemu -q -dumb -E "doscmd.bat $(realpath "$toolsdir" |
sed -re 's/\//\\/g') X2B_IGNR.COM obj RxDOS.EXE ..\\bin\\RxDOS.SYS" || exit

	cd obj
	rm warplink.lin
	rm STACK\$\$.OBJ
  } fi
} fi


cd ../RxBIO
if [ -f RxBIO.ASM ]; then {
	echo Building RxBIO
	nasmbin RxBIO RxDOS BIN || exit

	cd ../ldosboot
	echo Building RxDOS.COM
	nasm -Ox -i../MACRO/ -I../bin/ -I../lmacros/ -I../../lmacros/ \
	  -d__MAPFILE__=../map/iniload.map -d_MAP=../map/iniload.map \
	  -l../lst/iniload.lst -fbin \
	  -o../bin/RxDOS.COM iniload.asm -D_PAYLOAD_FILE"'RxDOS.BIN'"
} fi


cd ../RxCMD
if [ -f RxCMD.ASM -a \
	-f RxCMDCPY.ASM -a \
	-f RxCMDDIR.ASM -a \
	-f RxCMDFOR.ASM -a \
	-f RxCMDPRM.ASM -a \
	-f RxCMDREN.ASM ]; then
{
  if ((!_BUILD_OBJ)); then {
	echo Building RxCMD
	nasmbin RxCMD RxCMD EXE || exit
  } else {
	echo Building RxCMD
	for x in RxCMD RxCMDCPY RxCMDDIR RxCMDFOR \
	RxCMDPRM RxCMDREN; do
		nasmobj "$x" || exit
	done

	cd ../obj
	echo "/s /mx /xt +" > warplink.lin

	for x in RxCMDCPY RxCMDDIR RxCMDFOR \
	RxCMDPRM RxCMDREN RxCMD; do
		echo "$x.OBJ +" >> warplink.lin
	done
	echo ",..\\bin\\RxCMD.EXE,..\\map\\RxCMD.MAP,;" >> warplink.lin

	unix2dos -q warplink.lin
	cd ..
	dosemu -q -dumb -E "doscmd.bat $(realpath "$toolsdir" |
sed -re 's/\//\\/g') WARPLINK.EXE obj @warplink.lin" || exit

	cd obj
	rm warplink.lin
  } fi
} fi

cd ..


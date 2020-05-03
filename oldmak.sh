#! /bin/bash

# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

function nasmbin() {
	local sourcename="$1"
	local binname="$2"
	local binext="$3"
	shift 3
	nasm -Ox -D_REVISIONID="'$build_revision_id'" -i../MACRO/ \
		-I../bin/ -I../lmacros/ -I../../lmacros/ \
		-d__MAPFILE__=../map/"$sourcename".MAP \
		-l../lst/"$sourcename".LST -fbin \
		-o../bin/"$binname"."$binext" "$sourcename".ASM "$@"
}
function nasmobj() {
	local sourcename="$1"
	shift 1
	nasm -Ox -D_REVISIONID="'$build_revision_id'" -i../MACRO/ \
		-l../lst/"$sourcename".LST -fobj \
		-o../obj/"$sourcename".OBJ "$sourcename".ASM "$@"
}

[ -z "$use_build_revision_id" ] && use_build_revision_id=1

(($use_build_revision_id)) &&
  if [ -z "$build_revision_id" ]; then {
    build_revision_id="hg $(hg id -i)"
  } fi

cd "${0%/*}"
toolsdir="${PWD}/../dostools"
((debug)) && echo "toolsdir=\"$toolsdir\""


cd RxAPP
if [ -f RxVDISK.ASM ]; then {
	echo Building RxVDISK
	nasmbin RxVDISK RxVDISK SYS "$@" || exit
} fi

cd ../ldosboot
echo Building boot12, boot16, boot32
NAME=RXDOS
SUFFIX=""
for FAT in 12 16; do
	nasm -D_COMPAT_LDOS -D_LOAD_NAME="'$NAME'" -D_CHS=1 -D_LBA_SKIP_CHECK \
		-D_USE_PART_INFO=1 -D_QUERY_GEOMETRY=1 -D_FAT$FAT=1 boot.asm \
		-o boot${FAT}${SUFFIX}.bin -D_MAP=boot${FAT}${SUFFIX}.map \
		-l boot${FAT}${SUFFIX}.lst -I../lmacros/ "$@"
	done
nasm -D_COMPAT_LDOS -D_LOAD_NAME="'$NAME'" -D_CHS=1 -D_LBA_SKIP_CHECK \
	-D_USE_PART_INFO=1 -D_QUERY_GEOMETRY=1 boot32.asm \
	-o boot32${SUFFIX}.bin -D_MAP=boot32${SUFFIX}.map \
	-l boot32${SUFFIX}.lst -I../lmacros/ "$@"

cd ../instsect
echo Building instsect.com
nasm instsect.asm -D_MAP=instsect.map -l instsect.lst \
	-I../gopt/ -I../ldosboot/ -I../lmacros/ -o instsect.com "$@"

cd ..
echo Building RxDOS.COM
./mak.sh "$@"

cd RxCMD
if [ -f RxCMD.ASM -a \
	-f RxCMDCPY.ASM -a \
	-f RxCMDDIR.ASM -a \
	-f RxCMDFOR.ASM -a \
	-f RxCMDPRM.ASM -a \
	-f RxCMDREN.ASM ]; then
{
  if ((!_BUILD_OBJ)); then {
	echo Building RxCMD
	nasmbin RxCMD RxCMD EXE "$@" || exit
  } else {
	echo Building RxCMD
	for x in RxCMD RxCMDCPY RxCMDDIR RxCMDFOR \
	RxCMDPRM RxCMDREN; do
		nasmobj "$x" "$@" || exit
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

cd ../doc
echo Building doc
./makdoc

cd ..


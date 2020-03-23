#! /bin/bash

# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.


rootpath=""
miscpath="misc/"

comext="COM"
mapext="MAP"
lstext="LST"
binbigext="BIN"

lstdir="lst/"
mapdir="map/"

ppre="P"
tpre="T"
usuf="U"
csuf="C"
lpre=""

blzext="BLZ"
lz4ext="LZ4"
szext="SZ"
exoext="EXO"
xext="X"
hsext="HS"


function fun_delete_compressed {
  [ "$1" != "silent" ] && echo "Deleting $lpre${build_name}.$comext"
  rm -f ${rootpath}bin/$lpre"$build_name".$comext \
    ${rootpath}${lstdir}$lpre"$build_name"$csuf.$lstext ${rootpath}${mapdir}$lpre"$build_name"$csuf.$mapext
}

. cfg.sh

if [ -n "$LMACROS_DIR" ]; then {
  options_i_lmacros=-I"${LMACROS_DIR%/}"/
} fi

if [ -n "$LDOSBOOT_DIR" ]; then {
  options_i_ldosboot=-I"${LDOSBOOT_DIR%/}"/
} fi

if [ -n "$SCANPTAB_DIR" ]; then {
  options_i_scanptab=-I"${SCANPTAB_DIR%/}"/
} fi

if [ -n "$INSTSECT_DIR" ]; then {
  options_i_instsect=-I"${INSTSECT_DIR%/}"/
} fi

[ -z "$build_name" ] && build_name=RxDOS
reproducedir=${rootpath}tmp/"$build_name".rep

function shellquote() {
  local sp=""
#  local ii=0
  for param; do
    echo -ne "$sp"
#    ((debug)) && echo -ne "$ii:"
#    ((ii += 1))
    printf "%q" "$param"
    sp=" "
  done
  echo
}

if [ "$1" == reproduce ]; then
  shift
  echo Reproducing the "$build_name" build
  if ! [ -f "$reproducedir"/nasmenv ] || \
      ! [ -f "$reproducedir"/options ] || \
      ! [ -f "$reproducedir"/cmdline ] || \
      ! [ -f "$reproducedir"/dt ]; then
    echo Error: Reproduce files not found
    exit 1
  fi
  altervar="havedt reproducing"
  if [ "$1" == alter ]; then
    shift
    altervar="havedt"
    echo Altering the reproduce files
    if [ "$1" == newdt ]; then
      shift
      altervar=""
    fi
  fi
  unset NASMENV
  eval "$(cat "$reproducedir"/nasmenv)"
  unset STACKSIZE
  unset INICOMP_METHOD
  unset INICOMP_EXOMIZER_P
  unset build_options
  unset build_inicomp_options
  unset build_iniload_options
  eval "$(cat "$reproducedir"/options)"
  export use_build_revision_id=0
#  unset use_build_revision_id
  unset use_build_decomp_test
  unset use_build_inicheck
  eval "$(cat "$reproducedir"/usevars)"
  eval "$(printf "%q" "$0") $altervar $(cat "$reproducedir"/cmdline) $(shellquote "$@")"
  exit $?
fi

if (($use_build_revision_id)); then {
  [ -z "$build_revision_id" ] && build_revision_id="hg $(hg id -i)"
  [ -z "$build_revision_id_lmacros" -a -n "$LMACROS_DIR" ] \
    && var="hg $(hg -R "$LMACROS_DIR" id -i)" \
    && [ "$var" != "$build_revision_id" ] \
    && build_revision_id_lmacros="'Uses lmacros:  Revision ID $var',13,10"
  [ -z "$build_revision_id_inicomp" ] \
    && var="hg $(hg -R "$INICOMP_DIR" id -i)" \
    && [ "$var" != "$build_revision_id" ] \
    && build_revision_id_inicomp="'Uses inicomp:  Revision ID $var',13,10"
  [ -z "$build_revision_id_inicheck" ] \
    && var="hg $(hg -R "$INICHECK_DIR" id -i)" \
    && [ "$var" != "$build_revision_id" ] \
    && build_revision_id_inicheck="'Uses inicheck: Revision ID $var',13,10"
  [ -z "$build_revision_id_instsect" ] \
    && var="hg $(hg -R "$INSTSECT_DIR" id -i)" \
    && [ "$var" != "$build_revision_id" ] \
    && build_revision_id_instsect="'Uses instsect: Revision ID $var',13,10"
  [ -z "$build_revision_id_scanptab" ] \
    && var="hg $(hg -R "$SCANPTAB_DIR" id -i)" \
    && [ "$var" != "$build_revision_id" ] \
    && build_revision_id_scanptab="'Uses scanptab: Revision ID $var',13,10"
  [ -z "$build_revision_id_ldosboot" ] \
    && var="hg $(hg -R "$LDOSBOOT_DIR" id -i)" \
    && [ "$var" != "$build_revision_id" ] \
    && build_revision_id_ldosboot="'Uses ldosboot: Revision ID $var',13,10"
} fi

mkdir -p "$reproducedir"

if [ "$1" != havedt ]; then
  nasm ${miscpath}passdt.asm -o ${rootpath}tmp/scratch 2>&1 \
  -D_REVISIONID="'$build_revision_id'" \
  -D_REVISIONID_LMACROS="${build_revision_id_lmacros:-''}" \
  -D_REVISIONID_INSTSECT="${build_revision_id_instsect:-''}" \
  -D_REVISIONID_SYMSNIP="${build_revision_id_symsnip:-''}" \
  -D_REVISIONID_SCANPTAB="${build_revision_id_scanptab:-''}" \
  -D_REVISIONID_INICOMP="${build_revision_id_inicomp:-''}" \
  -D_REVISIONID_INICHECK="${build_revision_id_inicheck:-''}" \
  -D_CHECKSUM="$use_build_inicheck" \
  -D_REVISIONID_LDOSBOOT="${build_revision_id_ldosboot:-''}" \
  | perl -ne 'if (/.*(?:warning: using define )(-[UD].*?)( \[-w\+user\])?$/) { print $1."\n"; };' \
     > "$reproducedir"/dt
else
  shift
fi

if [ "$1" != reproducing ]; then
  export NASMENV
  export -p | grep -E "^declare -x NASMENV=" > "$reproducedir"/nasmenv
  export STACKSIZE
  export INICOMP_METHOD
  export INICOMP_EXOMIZER_P
  export build_options
  export build_inicomp_options
  export build_iniload_options
  export -p | grep -E "^declare -x (build_(|inicomp_|iniload_)options|INICOMP_(EXOMIZER_P|METHOD)|STACKSIZE)=" > "$reproducedir"/options
#  export use_build_revision_id
  export use_build_decomp_test
  export use_build_inicheck
  export -p | grep -E "^declare -x use_build_(decomp_test|inicheck)=" > "$reproducedir"/usevars
  shellquote "$@" > "$reproducedir"/cmdline
else
  shift
fi

# based on https://stackoverflow.com/a/22517974/738287
declare -a dtarray=()
while IFS='' read -r item; do
  dtarray+=("$item")
done < "$reproducedir"/dt

[ -z "$STACKSIZE" ] && STACKSIZE=2048

echo "Creating $build_name.$binbigext"
[ -f ${rootpath}bin/"$build_name".$comext ] && rm ${rootpath}bin/"$build_name".$comext
[ -f ${rootpath}bin/$lpre"$build_name".$comext ] && rm ${rootpath}bin/$lpre"$build_name".$comext
# Delete the file first so in case the actual assembly fails,
#  there doesn't remain a stale result of the shim assembly.
"$NASM" -Ox ldos/init.asm -f bin \
  -D_BIN_FILE_DEFAULT=RXDOS.COM \
  -I ldos/ -I RxDOS/ -I MACRO/ -I bin/ \
  "$options_i_instsect" \
  "$options_i_lmacros" \
  "$options_i_scanptab" \
  -o ${rootpath}tmp/"$build_name".$binbigext \
  -l ${rootpath}${lstdir}"$build_name".$lstext -D_MAP=${rootpath}${mapdir}"$build_name".$mapext \
  -D_REVISIONID="'$build_revision_id'" \
  -D_REVISIONID_LMACROS="${build_revision_id_lmacros:-''}" \
  -D_REVISIONID_INSTSECT="${build_revision_id_instsect:-''}" \
  -D_REVISIONID_SCANPTAB="${build_revision_id_scanptab:-''}" \
  -D_REVISIONID_INICOMP="${build_revision_id_inicomp:-''}" \
  -D_REVISIONID_INICHECK="${build_revision_id_inicheck:-''}" \
  -D_CHECKSUM="$use_build_inicheck" \
  -D_REVISIONID_LDOSBOOT="${build_revision_id_ldosboot:-''}" \
  "${dtarray[@]}" $build_options "$@"
rc=$?

if [ -n "$LDOSBOOT_DIR" ]; then {
  if [ -f "${rootpath}tmp/$build_name.$binbigext" ]; then {
    echo "Creating $lpre${build_name}$usuf.$comext"
    "$NASM" -Ox "${LDOSBOOT_DIR%/}"/iniload.asm -f bin \
      "$options_i_lmacros" \
      "$options_i_ldosboot" \
      "$options_i_scanptab" \
      -D_REVISIONID="'$build_revision_id'" \
      -D_REVISIONID_LMACROS="${build_revision_id_lmacros:-''}" \
      -D_REVISIONID_INSTSECT="${build_revision_id_instsect:-''}" \
      -D_REVISIONID_SCANPTAB="${build_revision_id_scanptab:-''}" \
      -D_REVISIONID_INICOMP="${build_revision_id_inicomp:-''}" \
      -D_REVISIONID_INICHECK="${build_revision_id_inicheck:-''}" \
      -D_CHECKSUM="$use_build_inicheck" \
      -D_REVISIONID_LDOSBOOT="${build_revision_id_ldosboot:-''}" \
      "${dtarray[@]}" \
      -D_INILOAD_SIGNATURE="'Rx'" \
      -I"${INICHECK_DIR%/}"/iniload/ -D_CHECKSUM="$use_build_inicheck" \
      $build_iniload_options -o${rootpath}bin/$lpre"$build_name"$usuf.$comext \
      -l${rootpath}${lstdir}$lpre"$build_name"$usuf.$lstext -D_MAP=${rootpath}${mapdir}$lpre"$build_name"$usuf.$mapext \
      -D_PAYLOAD_FILE="'${rootpath}tmp/$build_name.$binbigext'" -D_EXEC_OFFSET=32 \
      -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
      -D_IMAGE_EXE_MIN_CALC="(((_IMAGE_EXE_AUTO_STACK) + 15) & ~15)" \
    && perl -0777i -pe 's/(Uses inicomp[^\0]*\0)/"\0" x length $1/ge' \
      ${rootpath}bin/$lpre"$build_name"$usuf.$comext \
    && ((use_build_inicheck)) && "$CHECKSUM" ${rootpath}bin/$lpre"$build_name"$usuf.$comext
    ls -lgG ${rootpath}bin/$lpre"$build_name"$usuf.$comext
    if [ -z "$INICOMP_METHOD" -o "$INICOMP_METHOD" == "none" ]; then {
      fun_delete_compressed
    } else {
      winmethod=""
      fun_delete_compressed silent
      for method in $INICOMP_METHOD; do
      	inicomp_additional_memory=0
	inicomp_def_p=""
	inicomp_switch_p=""
      	if [ "$method" == "brieflz" ]; then {
      	  [ -z "$INICOMP_BLZPACK" ] && INICOMP_BLZPACK=blzpack
      	  inicomp_suffix=$blzext
      	  inicomp_option=-D_BRIEFLZ
      	} elif [ "$method" == "lz4" ]; then {
      	  [ -z "$INICOMP_LZ4C" ] && INICOMP_LZ4C=lz4c
      	  inicomp_suffix=$lz4ext
          inicomp_option=-D_LZ4
      	} elif [ "$method" == "snappy" ]; then {
      	  [ -z "$INICOMP_SNZIP" ] && INICOMP_SNZIP=snzip
      	  inicomp_suffix=$szext
      	  inicomp_option=-D_SNAPPY
      	} elif [ "$method" == "exodecr" ]; then {
      	  [ -z "$INICOMP_EXOMIZER" ] && INICOMP_EXOMIZER=exomizer
      	  inicomp_suffix=$exoext
      	  inicomp_option=-D_EXODECR
	  [ -n "$INICOMP_EXOMIZER_P" ] && inicomp_def_p="-D_P=$INICOMP_EXOMIZER_P"
	  [ -n "$INICOMP_EXOMIZER_P" ] && inicomp_switch_p="-P$INICOMP_EXOMIZER_P"
	  [ -n "$INICOMP_EXOMIZER_P" ] && echo "Using P = $INICOMP_EXOMIZER_P"
      	} elif [ "$method" == "x" ]; then {
      	  [ -z "$INICOMP_X" ] && INICOMP_X=x
      	  inicomp_suffix=$xext
      	  inicomp_option=-D_X
      	  inicomp_additional_memory="$(( 4 * 256 * 256 + 16384 ))"
		# 4 * 256 * 256 = CONTEXTSIZE
		# 16384 = threshold for multi-layer decompression
	} elif [ "$method" == "heatshrink" ]; then {
	  [ -z "$INICOMP_HEATSHRINK" ] && INICOMP_HEATSHRINK=heatshrink
	  inicomp_suffix=$hsext
	  inicomp_option=-D_HEATSHRINK
	} elif [ "$method" == "none" ]; then {
	  continue
	} else {
	  echo "Invalid compression method selected: $method"
	  exit 1
	} fi
      mkdir -p ${rootpath}tmp/"$inicomp_suffix"
      rm -f ${rootpath}tmp/"$inicomp_suffix"/"$build_name"."$inicomp_suffix" \
        ${rootpath}tmp/"$inicomp_suffix"/$ppre"$build_name".$binbigext
      echo "Creating $lpre${build_name}.$comext"
      if [ "$method" == "brieflz" ]; then {
        "$INICOMP_BLZPACK" "${rootpath}tmp/$build_name.$binbigext" "${rootpath}tmp/$inicomp_suffix/$build_name.$blzext"
      } elif [ "$method" == "lz4" ]; then {
        "$INICOMP_LZ4C" -9zfk -hc "${rootpath}tmp/$build_name.$binbigext" "${rootpath}tmp/$inicomp_suffix/$build_name.$lz4ext"
      } elif [ "$method" == "snappy" ]; then {
        "$INICOMP_SNZIP" -ck "${rootpath}tmp/$build_name.$binbigext" > "${rootpath}tmp/$inicomp_suffix/$build_name.$szext"
      } elif [ "$method" == "exodecr" ]; then {
        "$INICOMP_EXOMIZER" raw $inicomp_switch_p "${rootpath}tmp/$build_name.$binbigext" -o "${rootpath}tmp/$inicomp_suffix/$build_name.$exoext"
      } elif [ "$method" == "x" ]; then {
        "$INICOMP_X" -9zfk "${rootpath}tmp/$build_name.$binbigext" "${rootpath}tmp/$inicomp_suffix/$build_name.$xext"
      } elif [ "$method" == "heatshrink" ]; then {
	rm -f "${rootpath}tmp/$inicomp_suffix/$build_name.$hsext"
	winmsg=""
	for w in 10 11 12 13 14; do
	  for l in 4 5 6 7 8 9 10 11 12 13 14; do
	    ((l >= w)) && continue
	    if msg="$("$INICOMP_HEATSHRINK" -ve -w $w -l $l "${rootpath}tmp/$build_name.$binbigext" "${rootpath}tmp/$inicomp_suffix/w${w}l$l.bin")"; then
	      if [ ! -f "${rootpath}tmp/$inicomp_suffix/$build_name.$hsext" ] \
		|| (( ( $(stat -c %s "${rootpath}tmp/$inicomp_suffix/w${w}l$l.bin") + 2 ) <= $(stat -c %s "${rootpath}tmp/$inicomp_suffix/$build_name.$hsext") )); then
		echo -ne "!"
		winmsg="$msg"
		printf "\x$(printf "%02X" "$w")\x$(printf "%02X" "$l")" > "${rootpath}tmp/$inicomp_suffix/$build_name.$hsext"
		cat "${rootpath}tmp/$inicomp_suffix/w${w}l$l.bin" >> "${rootpath}tmp/$inicomp_suffix/$build_name.$hsext"
	      else
		echo -ne "."
	      fi
	    fi
	  done
	done
	echo ""
	if [ -z "$winmsg" ]; then
	  echo "Error: Compression failure!"
	  false
	else
	  echo "$winmsg"
	  true
	fi
      } else {
        echo "Internal error!"
        exit 1
      } fi
      rc=$?
      decompsize=0
      (($use_build_decomp_test)) && [ $rc -eq 0 ] \
      && "$NASM" "${INICOMP_DIR%/}"/inicomp.asm "$options_i_lmacros" \
        -I"${INICOMP_DIR%/}"/ "$inicomp_option" \
        "${dtarray[@]}" \
	$inicomp_def_p \
        $build_inicomp_options -o${rootpath}tmp/"$inicomp_suffix"/$tpre"$build_name".$binbigext \
        -l ${rootpath}tmp/"$inicomp_suffix"/$tpre"$build_name".$lstext \
        -D_MAP="${rootpath}tmp/$inicomp_suffix/$tpre$build_name.$mapext" \
        -D_PAYLOAD_FILE="'${rootpath}tmp/$inicomp_suffix/$build_name.$inicomp_suffix'" -D_EXEC_OFFSET=32 \
        -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
        -D_TEST_PROGRAM \
        -D_TEST_PROGRESS \
        -D_TEST_PROGRAM_DECOMPRESSED_SIZE="$(stat -c %s "${rootpath}tmp/$build_name.$binbigext")" \
        -D_INCLUDE_UNCOMPRESSED -D_UNCOMPRESSED_FILE="'${rootpath}tmp/$build_name.$binbigext'" \
      && "$NASM" "${LDOSBOOT_DIR%/}"/iniload.asm "$options_i_lmacros" \
	"$options_i_ldosboot" \
	"$options_i_scanptab" \
        "${dtarray[@]}" \
	-D_INILOAD_SIGNATURE="'Rx'" \
        -I"${INICHECK_DIR%/}"/iniload/ -D_CHECKSUM="$use_build_inicheck" \
        $build_iniload_options -o${rootpath}tmp/"$inicomp_suffix"/$tpre"$build_name".$comext \
        -D_PAYLOAD_FILE="'${rootpath}tmp/$inicomp_suffix/$tpre$build_name.$binbigext'" -D_EXEC_OFFSET=32 \
        -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
        -D_IMAGE_EXE_MIN_CALC="((-512 \
          + $(stat -c %s "${rootpath}tmp/$inicomp_suffix/$build_name.$inicomp_suffix") \
          + $(stat -c %s "${rootpath}tmp/$build_name.$binbigext") \
          + _IMAGE_EXE_AUTO_STACK + 15 \
	  + $inicomp_additional_memory) & ~15)" \
      && decompsize="$(( $( \
        dosemu -K "${PWD}/${rootpath}tmp/$inicomp_suffix" -E $tpre"$build_name".$comext -dumb -quiet 2> /dev/null \
        | tee /dev/stderr | sed -re '/^(about to execute|error:|note:|info:)/Id;s/[\r\n]+$//g' \
        ) * 16 ))"
          # -512 in the iniload build is for inicomp's INIT0
      rc2=$?
      (($use_build_decomp_test)) || rc2=0
      (($use_build_decomp_test)) || decompsize="$(( \
        + $(stat -c %s "${rootpath}tmp/$inicomp_suffix/$build_name.$inicomp_suffix") \
        + $(stat -c %s "${rootpath}tmp/$build_name.$binbigext") \
	+ $inicomp_additional_memory
        + 4096 ))"
        # 4096 is a heuristic guess for larger than size of the decompressor
      size=0
      [ "$decompsize" -gt "$size" ] && size="$decompsize"
      [ $rc2 -eq 0 -a $rc -eq 0 ] \
      && "$NASM" "${INICOMP_DIR%/}"/inicomp.asm "$options_i_lmacros" \
        -I"${INICOMP_DIR%/}"/ "$inicomp_option" \
        "${dtarray[@]}" \
	$inicomp_def_p \
        $build_inicomp_options -o${rootpath}tmp/"$inicomp_suffix"/$ppre"$build_name".$binbigext \
        -D_PAYLOAD_FILE="'${rootpath}tmp/$inicomp_suffix/$build_name.$inicomp_suffix'" -D_EXEC_OFFSET=32 \
        -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
      && "$NASM" -Ox "${LDOSBOOT_DIR%/}"/iniload.asm -f bin \
	"$options_i_lmacros" \
	"$options_i_ldosboot" \
	"$options_i_scanptab" \
	-D_REVISIONID="'$build_revision_id'" \
	-D_REVISIONID_LMACROS="${build_revision_id_lmacros:-''}" \
	-D_REVISIONID_INSTSECT="${build_revision_id_instsect:-''}" \
	-D_REVISIONID_SCANPTAB="${build_revision_id_scanptab:-''}" \
	-D_REVISIONID_INICOMP="${build_revision_id_inicomp:-''}" \
	-D_REVISIONID_INICHECK="${build_revision_id_inicheck:-''}" \
	-D_CHECKSUM="$use_build_inicheck" \
	-D_REVISIONID_LDOSBOOT="${build_revision_id_ldosboot:-''}" \
        "${dtarray[@]}" \
	-D_INILOAD_SIGNATURE="'Rx'" \
        -I"${INICHECK_DIR%/}"/iniload/ -D_CHECKSUM="$use_build_inicheck" \
        $build_iniload_options -o${rootpath}tmp/"$inicomp_suffix"/$lpre"$build_name".$comext \
        -l ${rootpath}tmp/"$inicomp_suffix"/$lpre"$build_name"$csuf.$lstext -D_MAP=${rootpath}tmp/"$inicomp_suffix"/$lpre"$build_name"$csuf.$mapext \
        -D_PAYLOAD_FILE="'${rootpath}tmp/$inicomp_suffix/$ppre$build_name.$binbigext'" -D_EXEC_OFFSET=32 \
        -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
        -D_IMAGE_EXE_MIN_CALC="(( \
          - (payload.actual_end - payload) \
          + "$size" \
          + _IMAGE_EXE_AUTO_STACK + 15) & ~15)" \
      && ((use_build_inicheck)) && "$CHECKSUM" ${rootpath}tmp/$lpre"$inicomp_suffix"/"$build_name".$comext
	if [ -f ${rootpath}tmp/"$inicomp_suffix"/$lpre"$build_name".$comext ]; then
	  if [ ! -f "${rootpath}bin/$lpre$build_name.$comext" ] \
	    || (( $(stat -c %s ${rootpath}tmp/"$inicomp_suffix"/$lpre"$build_name".$comext) <= $(stat -c %s "${rootpath}bin/$lpre$build_name.$comext") )); then
	    winmethod="$method"
	    cp -a ${rootpath}tmp/"$inicomp_suffix"/$lpre"$build_name".$comext ${rootpath}bin
	    cp -a ${rootpath}tmp/"$inicomp_suffix"/$lpre"$build_name"$csuf.$lstext ${rootpath}${lstdir}
	    cp -a ${rootpath}tmp/"$inicomp_suffix"/$lpre"$build_name"$csuf.$mapext ${rootpath}${mapdir}
	  fi
	fi
      done
	if [ -n "$winmethod" ]; then
	  echo "Note: Method $winmethod selected."
	  ls -lgG ${rootpath}bin/$lpre"$build_name".$comext
	else
	  echo Error: No compression method succeeded.
	  false
	fi
    } fi
  } else {
    echo "Deleting $lpre${build_name}$usuf.$comext"
    rm -f ${rootpath}bin/$lpre"$build_name"$usuf.$comext \
      ${rootpath}${lstdir}$lpre"$build_name"$usuf.$lstext ${rootpath}${mapdir}$lpre"$build_name"$usuf.$mapext
    fun_delete_compressed
  } fi
} fi

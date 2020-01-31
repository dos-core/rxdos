#! /bin/bash

# Usage of the works is permitted provided that this
# instrument is retained with the works, so that any entity
# that uses the works is notified of this instrument.
#
# DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

function fun_delete_compressed {
  [ "$1" != "silent" ] && echo "Deleting l${build_name}.com"
  rm -f ../bin/l"$build_name".com \
    ../lst/l"$build_name".lst ../lst/l"$build_name".map
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

[ -z "$build_name" ] && build_name=debug
reproducedir=../tmp/"$build_name".rep

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
  unset build_options
  eval "$(cat "$reproducedir"/options)"
  eval "$(printf "%q" "$0") $altervar $(cat "$reproducedir"/cmdline) $(shellquote "$@")"
  exit $?
fi

mkdir -p "$reproducedir"

if [ "$1" != havedt ]; then
  nasm passdt.asm -o ../tmp/scratch 2>&1 | \
    perl -ne 'if (/.*(?:warning: using define )(-[UD].*?)( \[-w\+user\])?$/) { print $1."\n"; };' \
     > "$reproducedir"/dt
else
  shift
fi

if [ "$1" != reproducing ]; then
  export NASMENV
  export -p | grep -E "^declare -x NASMENV=" > "$reproducedir"/nasmenv
  export build_options
  export -p | grep -E "^declare -x build_options=" > "$reproducedir"/options
  shellquote "$@" > "$reproducedir"/cmdline
else
  shift
fi

# based on https://stackoverflow.com/a/22517974/738287
declare -a dtarray=()
while IFS='' read -r item; do
  dtarray+=("$item")
done < "$reproducedir"/dt

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
  [ -z "$build_revision_id_scanptab" ] \
    && var="hg $(hg -R "$SCANPTAB_DIR" id -i)" \
    && [ "$var" != "$build_revision_id" ] \
    && build_revision_id_scanptab="'Uses scanptab: Revision ID $var',13,10"
  [ -z "$build_revision_id_ldosboot" ] \
    && var="hg $(hg -R "$LDOSBOOT_DIR" id -i)" \
    && [ "$var" != "$build_revision_id" ] \
    && build_revision_id_ldosboot="'Uses ldosboot: Revision ID $var',13,10"
} fi

[ -z "$STACKSIZE" ] && STACKSIZE=2048

echo "Creating $build_name.com"
[ -f ../bin/"$build_name".com ] && rm ../bin/"$build_name".com
# Delete the file first so in case the actual assembly fails,
#  there doesn't remain a stale result of the shim assembly.
"$NASM" iniloadc.asm "$options_i_lmacros" \
  "$options_i_scanptab" \
  -o../tmp/"$build_name"c.mac \
  -D_REVISIONID="'$build_revision_id'" \
  -D_REVISIONID_LMACROS="${build_revision_id_lmacros:-''}" \
  -D_REVISIONID_SCANPTAB="${build_revision_id_scanptab:-''}" \
  -D_REVISIONID_INICOMP="${build_revision_id_inicomp:-''}" \
  -D_REVISIONID_INICHECK="${build_revision_id_inicheck:-''}" \
  -D_CHECKSUM="$use_build_inicheck" \
  -D_REVISIONID_LDOSBOOT="${build_revision_id_ldosboot:-''}" \
  "${dtarray[@]}" $build_options "$@" && \
"$NASM" debug.asm "$options_i_lmacros" \
  "$options_i_scanptab" \
  -o../tmp/"$build_name".big \
  -l../lst/"$build_name".lst -D_MAP=../lst/"$build_name".map \
  -D_REVISIONID="'$build_revision_id'" \
  -D_REVISIONID_LMACROS="${build_revision_id_lmacros:-''}" \
  -D_REVISIONID_SCANPTAB="${build_revision_id_scanptab:-''}" \
  -D_REVISIONID_INICOMP="${build_revision_id_inicomp:-''}" \
  -D_REVISIONID_INICHECK="${build_revision_id_inicheck:-''}" \
  -D_CHECKSUM="$use_build_inicheck" \
  -D_REVISIONID_LDOSBOOT="${build_revision_id_ldosboot:-''}" \
  "${dtarray[@]}" $build_options "$@"
rc=$?
size="$(( $("$TELLSIZE" ../tmp/"$build_name".big) * 16 - $STACKSIZE ))"
if [ $? -eq 0 -a $rc -eq 0 ]; then {
  "$NASM" mzshim.asm "$options_i_lmacros" "${dtarray[@]}" \
    -D_FILE=../tmp/"$build_name".big -o../bin/"$build_name".com \
    -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
    -D_IMAGE_EXE_MIN_CALC="((( - (payload.actual_end - payload) \
      + $size + _IMAGE_EXE_AUTO_STACK) + 15) & ~15)" \
  && perl -0777i -pe 's/(Uses (inicomp|inicheck|ldosboot|scanptab)[^\0]*\0)/"\0" x length $1/ge' \
    ../bin/"$build_name".com
} fi

if [ -n "$LDOSBOOT_DIR" ]; then {
  if [ -n "$INICOMP_METHOD" ]; then {
    if [ "$INICOMP_METHOD" == "lz4" ]; then {
      [ -z "$INICOMP_LZ4C" ] && INICOMP_LZ4C=lz4c
      inicomp_suffix=lz4
      inicomp_option=-D_LZ4
    } elif [ "$INICOMP_METHOD" == "snappy" ]; then {
      [ -z "$INICOMP_SNZIP" ] && INICOMP_SNZIP=snzip
      inicomp_suffix=sz
      inicomp_option=-D_SNAPPY
    } elif [ "$INICOMP_METHOD" == "brieflz" ]; then {
      [ -z "$INICOMP_BLZPACK" ] && INICOMP_BLZPACK=blzpack
      inicomp_suffix=blz
      inicomp_option=-D_BRIEFLZ
    } elif [ "$INICOMP_METHOD" != "none" ]; then {
      echo "Invalid compression method selected: $INICOMP_METHOD"
      exit 1
    } fi
  } fi
  if [ -f "../tmp/$build_name.big" ] \
  && grep -qaEi "^\s*Boot loader\s*$" ../tmp/"$build_name".big; then {
    echo "Creating l${build_name}u.com"
    "$NASM" "${LDOSBOOT_DIR%/}"/iniload.asm "$options_i_lmacros" \
      "$options_i_ldosboot" \
      "$options_i_scanptab" \
      "${dtarray[@]}" \
      -D_INILOAD_CFG="'../tmp/${build_name}c.mac'" \
      -I"${INICHECK_DIR%/}"/iniload/ -D_CHECKSUM="$use_build_inicheck" \
      $build_iniload_options -o../bin/l"$build_name"u.com \
      -l../lst/l"$build_name"u.lst -D_MAP=../lst/l"$build_name"u.map \
      -D_PAYLOAD_FILE="'../tmp/$build_name.big'" -D_EXEC_OFFSET=32 \
      -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
      -D_IMAGE_EXE_MIN_CALC="((( - (payload.actual_end - payload) \
        + $size + _IMAGE_EXE_AUTO_STACK) + 15) & ~15)" \
    && perl -0777i -pe 's/(Uses inicomp[^\0]*\0)/"\0" x length $1/ge' \
      ../bin/l"$build_name"u.com \
    && ((use_build_inicheck)) && "$CHECKSUM" ../bin/l"$build_name"u.com
    if [ -z "$INICOMP_METHOD" -o "$INICOMP_METHOD" == "none" ]; then {
      fun_delete_compressed
    } else {
      fun_delete_compressed silent
      rm -f ../tmp/"$build_name"."$inicomp_suffix" \
        ../tmp/l"$build_name"."$inicomp_suffix"
      echo "Creating l${build_name}.com"
      if [ "$INICOMP_METHOD" == "lz4" ]; then {
        "$INICOMP_LZ4C" -9zfk -hc "../tmp/$build_name.big" "../tmp/$build_name.lz4"
      } elif [ "$INICOMP_METHOD" == "snappy" ]; then {
        "$INICOMP_SNZIP" -ck "../tmp/$build_name.big" > "../tmp/$build_name.sz"
      } elif [ "$INICOMP_METHOD" == "brieflz" ]; then {
        "$INICOMP_BLZPACK" "../tmp/$build_name.big" "../tmp/$build_name.blz"
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
        $build_inicomp_options -o../tmp/t"$build_name"."$inicomp_suffix" \
        -D_PAYLOAD_FILE="'../tmp/$build_name.$inicomp_suffix'" -D_EXEC_OFFSET=32 \
        -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
        -D_TEST_PROGRAM \
        -D_TEST_PROGRAM_DECOMPRESSED_SIZE="$(stat -c %s "../tmp/$build_name.big")" \
      && "$NASM" "${LDOSBOOT_DIR%/}"/iniload.asm "$options_i_lmacros" \
	"$options_i_ldosboot" \
	"$options_i_scanptab" \
        "${dtarray[@]}" \
	-D_INILOAD_CFG="'../tmp/${build_name}c.mac'" \
        -I"${INICHECK_DIR%/}"/iniload/ -D_CHECKSUM="$use_build_inicheck" \
        $build_iniload_options -o../tmp/t"$build_name".com \
        -D_PAYLOAD_FILE="'../tmp/t$build_name.$inicomp_suffix'" -D_EXEC_OFFSET=32 \
        -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
        -D_IMAGE_EXE_MIN_CALC="((-512 \
          + $(stat -c %s "../tmp/$build_name.$inicomp_suffix") \
          + $(stat -c %s "../tmp/$build_name.big") \
          + _IMAGE_EXE_AUTO_STACK + 15) & ~15)" \
      && decompsize="$(( $( \
        dosemu -K "${PWD%/*}/tmp" -E t"$build_name".com -dumb -quiet 2> /dev/null \
        | sed -re '/^(about to execute|error:)/Id;s/[\r\n]+$//g' \
        ) * 16 ))"
          # -512 in the iniload build is for inicomp's INIT0
      rc2=$?
      (($use_build_decomp_test)) || rc2=0
      (($use_build_decomp_test)) || decompsize="$(( \
        + $(stat -c %s "../tmp/$build_name.$inicomp_suffix") \
        + $(stat -c %s "../tmp/$build_name.big") \
        + 4096 ))"
        # 4096 is a heuristic guess for larger than size of the decompressor
      [ "$decompsize" -gt "$size" ] && size="$decompsize"
      [ $rc2 -eq 0 -a $rc -eq 0 ] \
      && "$NASM" "${INICOMP_DIR%/}"/inicomp.asm "$options_i_lmacros" \
        -I"${INICOMP_DIR%/}"/ "$inicomp_option" \
        "${dtarray[@]}" \
        $build_inicomp_options -o../tmp/l"$build_name"."$inicomp_suffix" \
        -D_PAYLOAD_FILE="'../tmp/$build_name.$inicomp_suffix'" -D_EXEC_OFFSET=32 \
        -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
      && "$NASM" "${LDOSBOOT_DIR%/}"/iniload.asm "$options_i_lmacros" \
	"$options_i_ldosboot" \
	"$options_i_scanptab" \
        "${dtarray[@]}" \
	-D_INILOAD_CFG="'../tmp/${build_name}c.mac'" \
        -I"${INICHECK_DIR%/}"/iniload/ -D_CHECKSUM="$use_build_inicheck" \
        $build_iniload_options -o../bin/l"$build_name".com \
        -l../lst/l"$build_name".lst -D_MAP=../lst/l"$build_name".map \
        -D_PAYLOAD_FILE="'../tmp/l$build_name.$inicomp_suffix'" -D_EXEC_OFFSET=32 \
        -D_IMAGE_EXE -D_IMAGE_EXE_AUTO_STACK="$STACKSIZE" -D_IMAGE_EXE_MAX=0 \
        -D_IMAGE_EXE_MIN_CALC="(( \
          - (payload.actual_end - payload) \
          + "$size" \
          + _IMAGE_EXE_AUTO_STACK + 15) & ~15)" \
      && ((use_build_inicheck)) && "$CHECKSUM" ../bin/l"$build_name".com
    } fi
  } else {
    echo "Deleting l${build_name}u.com"
    rm -f ../bin/l"$build_name"u.com \
      ../lst/l"$build_name"u.lst ../lst/l"$build_name"u.map
    fun_delete_compressed
  } fi
} fi

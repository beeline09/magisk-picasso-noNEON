#!/bin/bash
# Проверка отсутствия NEON в нативных бинарях Magisk
# Использование: neon_check.sh <файл1> [файл2 ...]
OD=~/magisk/sdk/ndk/magisk/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump
RE_N="vld[1-4]|vst[1-4]|vtbl|vtst|vq(add|sub|mul|neg|shl|shr|abs|dml)|vzip|vuzp|vtrn|vext\.|vrev|vfma\.f32|vmla\.f32"
RE_D="[,{[:space:]]d(1[6-9]|2[0-9]|3[01])[,}[:space:]]"
FAIL=0
for f in "$@"; do
  [ -f "$f" ] || { echo "$f: НЕТ ФАЙЛА"; continue; }
  N=$($OD -d "$f" 2>/dev/null | grep -cE "$RE_N" || true)
  D=$($OD -d "$f" 2>/dev/null | grep -cE "$RE_D" || true)
  if [ "$N" = "0" ] && [ "$D" = "0" ]; then
    echo "OK   $f: NEON=$N d16+=$D"
  else
    echo "FAIL $f: NEON=$N d16+=$D"
    $OD -d "$f" 2>/dev/null | grep -m3 -E "$RE_N|$RE_D"
    FAIL=1
  fi
done
exit $FAIL

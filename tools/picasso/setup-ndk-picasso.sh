#!/bin/bash
# Установка NDK r30-beta2 в $ANDROID_HOME/ndk/magisk + подмены для Tegra 2 (noNEON)
# Использование: ANDROID_HOME=<путь> tools/picasso/setup-ndk-picasso.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_HOME:?Нужен ANDROID_HOME}"
NDK="$SDK/ndk/magisk"
LLVM="$NDK/toolchains/llvm/prebuilt/linux-x86_64"

if [ -x "$LLVM/bin/clang" ] && [ -f "$NDK/PICASSO_PATCHED" ]; then
  echo "NDK уже установлен и патчен — OK"
  exit 0
fi

mkdir -p "$SDK/ndk"
cd "$SDK/ndk"

if [ ! -d magisk ]; then
  echo "--- Скачиваю NDK r30-beta2 (~2 ГБ)"
  curl -L -o ndk-r30b2.zip https://dl.google.com/android/repository/android-ndk-r30-beta2-linux.zip
  unzip -q ndk-r30b2.zip
  MV=$(ls -d android-ndk-r30* | head -1)
  mv "$MV" magisk
  rm -f ndk-r30b2.zip
fi

"$LLVM/bin/clang" --version | head -1   # должен быть clang 21.0.0
"$NDK/toolchains/rust/bin/rustc" --version  # rustc 1.97.1-nightly

echo "--- Подмена libunwind (чистый, vfpv3-d16, без d16-d31)"
# это ЕДИНСТВЕННЫЙ arm-путь unwind в NDK (проверено по рабочей сборке)
cp "$LLVM/lib/clang/21/lib/linux/arm/libunwind.a" "$LLVM/lib/clang/21/lib/linux/arm/libunwind.a.stock" 2>/dev/null || true
cp "$HERE/prebuilt/libunwind-tegra2.a" "$LLVM/lib/clang/21/lib/linux/arm/libunwind.a"

echo "--- Подмена libclang_rt.builtins (наш чистый compiler-rt набор)"
for B in $(find "$LLVM" -name "libclang_rt.builtins*arm*android*.a"); do
  cp "$B" "$B.stock" 2>/dev/null || true
  cp "$HERE/prebuilt/libaeabi-clean.a" "$B"
  echo "  заменён: $B"
done

touch "$NDK/PICASSO_PATCHED"
echo "SETUP_NDK_PICASSO_OK"

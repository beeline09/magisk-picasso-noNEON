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
  echo "--- Скачиваю NDK r30-beta2 (~0.8 ГБ)"
  curl -L -o ndk-r30b2.zip https://dl.google.com/android/repository/android-ndk-r30-beta2-linux.zip
  unzip -q ndk-r30b2.zip
  MV=$(ls -d android-ndk-r30* | head -1)
  mv "$MV" magisk
  rm -f ndk-r30b2.zip
fi

# Rust: nightly 1.97.1 (8bab26f4f 2026-07-14) + rust-src (для build-std).
# Android NDK не содержит Rust. Дистрибутив собирается 14-го, публикуется в dist/2026-07-15.
if [ ! -x "$NDK/toolchains/rust/bin/rustc" ]; then
  echo "--- Устанавливаю Rust nightly (1.97.1 8bab26f4f 2026-07-14)"
  T=/tmp/rust-inst
  rm -rf $T && mkdir -p $T && cd $T
  curl -sLO https://static.rust-lang.org/dist/2026-07-15/rust-nightly-x86_64-unknown-linux-gnu.tar.xz
  curl -sLO https://static.rust-lang.org/dist/2026-07-15/rust-src-nightly.tar.xz
  tar xf rust-nightly-x86_64-unknown-linux-gnu.tar.xz
  tar xf rust-src-nightly.tar.xz
  RUSTPREFIX="$NDK/toolchains/rust"
  mkdir -p "$RUSTPREFIX"
  ./rust-nightly-x86_64-unknown-linux-gnu/install.sh --prefix="$RUSTPREFIX" --without=rust-docs
  ./rust-src-nightly/install.sh --prefix="$RUSTPREFIX"
  cd - >/dev/null
fi
RV=$("$NDK/toolchains/rust/bin/rustc" --version)
echo "$RV"
case "$RV" in
  *"1.97.1-nightly (8bab26f4f 2026-07-14)"*) : ;;
  *) echo "FATAL: версия rustc отличается от deployed (ожидалась 1.97.1-nightly 8bab26f4f 2026-07-14)"; exit 1 ;;
esac

"$LLVM/bin/clang" --version | head -1   # должен быть clang 21.0.0
"$NDK/toolchains/rust/bin/rustc" --version  # rustc 1.97.1-nightly

# Magisk build.py проверяет ndk/ONDK_VERSION == r30.1 (метка нашей надстройки над NDK)
[ -f "$NDK/ONDK_VERSION" ] || echo "r30.1" > "$NDK/ONDK_VERSION"

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

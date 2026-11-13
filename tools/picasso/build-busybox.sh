#!/bin/bash
# Сборка busybox 1.36.1 на musl (noNEON, VFPv3-D16) для Magisk/Tegra 2
# Использование: build-busybox.sh <путь-к-NDK-magisk> <выходной-файл>
set -e
NDK="${1:?NDK путь}"
OUT="${2:?выходной файл}"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${TMPDIR:-/tmp}/bb-build-$$"
CLANG="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang"
STRIP="$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"

mkdir -p "$WORK" && cd "$WORK"

# 1. musl 1.2.5
if [ ! -d musl-1.2.5 ]; then
  curl -sLO https://musl.libc.org/releases/musl-1.2.5.tar.gz
  tar xzf musl-1.2.5.tar.gz
fi
if [ ! -f ~/musl-arm/lib/libc.a ]; then
  cd musl-1.2.5
  ./configure --target=armv7-linux-musleabi --prefix=~/musl-arm CC=clang
  make -j"$(nproc)" install
  cd ..
fi

# 2. обёртка-компилятор
mkdir -p ~/musl-toolchain/bin
cat > ~/musl-toolchain/bin/arm-linux-musleabi-clang <<EOF
#!/bin/sh
exec $CLANG --target=armv7-linux-musleabi -mthumb -mfpu=vfpv3-d16 \\
  -nostdinc -isystem $HOME/musl-arm/include -isystem $HOME/musl-arm/include/armeabi \\
  "\$@"
EOF
chmod +x ~/musl-toolchain/bin/arm-linux-musleabi-clang

# 3. busybox 1.36.1
if [ ! -d busybox-1.36.1 ]; then
  curl -sLO https://busybox.net/downloads/busybox-1.36.1.tar.bz2
  tar xjf busybox-1.36.1.tar.bz2
fi
cd busybox-1.36.1
cp "$HERE/busybox.config" .config
patch -p1 --forward < "$HERE/busybox-ash-standalone.patch" || true

export PATH=~/musl-toolchain/bin:$PATH
make -j"$(nproc)" CC=arm-linux-musleabi-clang EXTRA_CFLAGS="-mfpu=vfpv3-d16 -mthumb"

# 4. strip
"$STRIP" --strip-all busybox_unstripped -o busybox
cp busybox "$OUT"
echo "BUILDBOX_OK $(md5sum "$OUT")"

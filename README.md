# Magisk v31.1 noNEON для Tegra 2 (Acer Iconia Tab A500/A501)

Fork of [Magisk v31.1](https://github.com/topjohnwu/Magisk) by [topjohnwu](https://github.com/topjohnwu),
patched for NVIDIA Tegra 2 (ARMv7 + VFPv3-D16, **no NEON**).

## Почему форк

Все официальные сборки Magisk содержат NEON-инструкции → SIGILL на Tegra 2.
Этот форк пересобирает все нативные компоненты без NEON.

## Быстрая сборка

```bash
git clone https://github.com/beeline09/magisk-picasso-noNEON
cd magisk-picasso-noNEON

# Требуется: JDK 25, Android SDK (build-tools 37, platform 37.1)
python3 build.py ndk       # скачать ONDK (~2 ГБ)
python3 build.py -r native # бинарники без NEON (~5 мин)

# ⚠️ ОБЯЗАТЕЛЬНО: поместить busybox и bootctl в native/out/armeabi-v7a/
# (pre-built musl busybox — НЕ bionic! — см. раздел "Prerequisites" ниже)
cp ~/magisk-bins/busybox ~/magisk-bins/bootctl native/out/armeabi-v7a/

python3 build.py -r app    # APK = flashable zip
```

## Prerequisites: busybox и bootctl

APK build требует два файла в `native/out/armeabi-v7a/`:

| Файл | Что это | Где взять |
|---|---|---|
| `busybox` | busybox 1.36.1 на **musl** (не bionic!) | Собрать по [инструкции](../../Docs/howto-build-magisk.md) раздел 6 |
| `bootctl` | Заглушка exit(1) — picasso не A/B | `echo 'int main(){return 1;}' > bootctl.c && arm-musl-clang bootctl.c -o bootctl` |

**Почему musl, а не bionic?** Статическая линковка bionic тянет NEON из libm (pow, strtod, qsort) → SIGILL на Tegra 2. Musl — чистый C без NEON.

**Важно:** busybox требует патч ash.c (добавить `standalone` в set -o таблицу) — Magisk's ensure_bb проверяет эту опцию. Детали в howto-build-magisk.md.

## Установка на планшет

1. CWM Recovery → install → `Magisk-v31.1-picasso.zip`
2. Перезагрузка
3. Magisk приложение → Superuser → Grant для приложений

## Что изменено (один коммит `403a6e2` поверх v31.1)

| Область | Изменение |
|---|---|
| Rust target | `armv7-linux-androideabi` + `-neon,-d32,+vfp3d16` |
| NDK флаги | `-mfpu=vfpv3-d16` + `-mattr=-neon,-d32` |
| busybox | Локальная сборка (не с magisk-files — там NEON) |
| Менеджер | `checkUpdate=false`, `versionCode=99999` |
| Установщик | Поиск boot-раздела, конвертация cpio, монтирование ext4 |
| preinit | Симлинк service.d (env_check требует block device) |

## Обновление на новую версию Magisk

```bash
git fetch upstream
git checkout -b picasso-noNEON-v32 upstream/v32.0
git cherry-pick 403a6e2   # наш коммит
# Конфликты — все изменения помечены "PICASSO"
```

## ⚠️ НИКОГДА не обновляйте из приложения!

Официальные обновления содержат NEON → SIGILL → бутлуп на Tegra 2.

## Благодарности

- [**topjohnwu**](https://github.com/topjohnwu) (John Wu) — Magisk v31.1
- [**beeline09**](https://github.com/beeline09) — noNEON порт для Tegra 2

## Лицензия

GPL v3 (наследует Magisk).

---
---

# Оригинальное описание Magisk (ниже)

*Following is the original Magisk README by topjohnwu:*

![](docs/images/logo.png)

[![Downloads](https://img.shields.io/badge/dynamic/json?color=green&label=Downloads&query=totalString&url=https%3A%2F%2Fraw.githubusercontent.com%2Ftopjohnwu%2Fmagisk-files%2Fcount%2Fcount.json&cacheSeconds=1800)](https://raw.githubusercontent.com/topjohnwu/magisk-files/count/count.json)

#### This is not an officially supported Google product

## Introduction

Magisk is a suite of open source software for customizing Android, supporting devices higher than Android 7.0.<br>
Some highlight features:

- **MagiskSU**: Provide root access for applications
- **Magisk Modules**: Modify read-only partitions by installing modules
- **MagiskBoot**: The most complete tool for unpacking and repacking Android boot images
- **Zygisk**: Run code in every Android applications' processes

## Downloads

[Github](https://github.com/topjohnwu/Magisk/releases) is the only source where you can get official Magisk information and downloads.

## Useful Links

- [Installation Instruction](https://topjohnwu.github.io/Magisk/install.html)
- [Building and Development](https://topjohnwu.github.io/Magisk/build.html)
- [Magisk Documentation](https://topjohnwu.github.io/Magisk/)
- [Zygisk module sample](https://github.com/topjohnwu/zygisk-module-sample)

## Bug Reports

**Only bug reports from Debug builds will be accepted.**

For installation issues, upload both boot image and install logs.<br>
For Magisk issues, upload boot logcat or dmesg.<br>
For Magisk app crashes, record and upload the logcat when the crash occurs.

## Translation Contributions

Default string resources for the Magisk app are located here:

- `app/core/src/main/res/values/strings.xml`

Translate each and place them in the respective locations (`[module]/src/main/res/values-[lang]/strings.xml`).

## License

    Magisk, including all git submodules are free software:
    you can redistribute it and/or modify it under the terms of the
    GNU General Public License as published by the Free Software Foundation,
    either version 3 of the License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Magisk v31.1 noNEON — NVIDIA Tegra 2 (Acer Iconia Tab A500/A501, picasso)

Форк [Magisk v31.1](https://github.com/topjohnwu/Magisk) от [topjohnwu](https://github.com/topjohnwu),
пересобранный для NVIDIA Tegra 2: **ARMv7 + VFPv3-D16, БЕЗ NEON**.

Все официальные сборки Magisk содержат NEON-инструкции → SIGILL (крах) на Tegra 2.
Нативные части здесь собраны clang 21 / rustc 1.97-nightly с `target-feature=-neon,-d32,+vfpv3-d16`,
с чистыми заменами `libunwind` и compiler-rt builtins (см. `tools/picasso/`).

> ⚠️ **НИКОГДА не обновляйте из приложения/сети** — официальные апдейты содержат NEON → бутлуп.

## Быстрая сборка (Linux x86_64)

Нужны: `git python3 unzip zip curl openjdk-25-jdk openssl` (JDK 25 обязателен, проверяется build.py).

```bash
# 1. Клонировать (сабмодули обязательны!)
git clone --recursive https://github.com/beeline09/magisk-picasso-noNEON.git
cd magisk-picasso-noNEON

# 2. Android SDK + NDK r30-beta2 (класть НЕ в каталог репо!)
export ANDROID_HOME=~/magisk-sdk           # любой путь вне репо
mkdir -p $ANDROID_HOME
#   build-tools/platforms ставятся при сборке app автоматически (gradle),
#   но licences нужно принять заранее:
#   yes | sdkmanager --licenses (после установки cmdline-tools)
tools/picasso/setup-ndk-picasso.sh          # NDK r30-beta2 -> $ANDROID_HOME/ndk/magisk + подмены

# 3. Нативные бинари (без NEON)
cat > config.prop <<'EOF'
abiList=armeabi-v7a
version=31.1-picasso-noNEON
versionCode=31100
EOF
export JAVA_HOME=/usr/lib/jvm/java-25-openjdk-amd64
python3 build.py -r native
# Результат: native/out/armeabi-v7a/{magisk,magiskboot,magiskinit,magiskpolicy}

# 4. busybox + bootctl (НЕ собираются build.py!)
cp tools/picasso/prebuilt/busybox-1.36.1-musl native/out/armeabi-v7a/busybox
cp tools/picasso/prebuilt/bootctl             native/out/armeabi-v7a/bootctl
# (или собрать busybox с нуля: tools/picasso/build-busybox.sh ~/magisk-sdk/ndk/magisk out)

# 5. Проверка NEON — ОБЯЗАТЕЛЬНО до прошивки!
tools/picasso/neon_check.sh native/out/armeabi-v7a/{magisk,magiskboot,magiskinit,magiskpolicy}
tools/picasso/neon_check.sh native/out/armeabi-v7a/busybox  # busybox должен быть НЕстрипнут (см. ниже)

# 6. APK/установщик (это один и тот же файл: APK = flashable zip)
python3 build.py -r app
# Результат: out/app-release.apk = Magisk-v31.1-picasso.zip

# 7. Удалятор (замена updater-script + JAR-подпись)
python3 tools/picasso/make-uninstaller.py out/app-release.apk remove-magisk.zip tools/picasso/signing
```

## Почему именно эти компоненты

| Компонент | Проблема на Tegra 2 | Решение |
|---|---|---|
| Rust-код | rustc включает NEON по умолчанию | `target-feature=-neon,-d32,+vfpv3-d16` (native/src/.cargo/config.toml) |
| libunwind (NDK) | ассемблер использует d16–d31 | `tools/picasso/prebuilt/libunwind-tegra2.a` кладётся в NDK (см. setup-ndk-picasso.sh) |
| compiler-rt builtins (NDK) | scalbnl и др. с NEON/d16 | `tools/picasso/prebuilt/libaeabi-clean.a` заменяет `libclang_rt.builtins*arm*android*.a` |
| busybox | статик на bionic тянет NEON из libm | сборка на musl 1.2.5, конфиг и ash-патч в `tools/picasso/` |
| bootctl | A/B-утилита не нужна (picasso не A/B) | заглушка `int main(){return 1;}` |

### Критичный патч busybox

В `shell/ash.c` опция `standalone` добавлена в таблицу `optletters_optnames[]` —
Magisk `ensure_bb` проверяет `set -o | grep standalone`.
Патч: `tools/picasso/busybox-ash-standalone.patch`, конфиг: `tools/picasso/busybox.config`.

### Про подпись удалятора

Старые CWM-рекавери ожидают JAR-структуру в zip. `make-uninstaller.py` создаёт
`META-INF/MANIFEST.MF` (SHA1-дайджесты), `CERT.SF`, `CERT.RSA` (PKCS#7, openssl) и
подписывает самоподписанным `CN=picasso` (ключ генерируется при первом запуске в
`tools/picasso/signing/`, в git не попадает).

## Что изменено относительно upstream v31.1

| Область | Изменение |
|---|---|
| Rust target | `armv7-linux-androideabi` + `-neon,-d32,+vfpv3-d16` |
| NDK | r30-beta2 (clang 21.0.0 9f872551, rustc 1.97.1-nightly) + подмены unwind/builtins |
| busybox | musl-сборка (не bionic!), ash standalone |
| Менеджер | `checkUpdate=false` — официальные обновления содержат NEON |
| Установщик | поиск boot без by-name (mmcblk0p2), конвертация легаси-cpio, ext4 |
| preinit | service.d-симлинк для env_check |

Все правки в коде помечены `PICASSO`.

## Установка на планшет

1. CWM Recovery → install → `Magisk-v31.1-picasso.zip`
2. Перезагрузка
3. Magisk → Superuser → Grant (интерактивного su-диалога в v31 нет)

## Известные ограничения

- Нет интерактивного su-диалога — только через менеджер
- `content.jar` Android 7.1 не понимает `--user current`/`--ei` (логи su не долетают)
- env_check требует `-b /sbin/.magisk/device/preinit` — решено service.d-скриптом

## Обновление форка до новой версии Magisk

```bash
git remote add upstream https://github.com/topjohnwu/Magisk.git  # один раз
git fetch upstream
git checkout -b picasso-noNEON-v32 upstream/v32.0
git cherry-pick <picasso-коммиты>   # найти: git log --oneline --grep=picasso
```

## Связанные репозитории

- [picasso-android-kernel](https://github.com/beeline09/picasso-android-kernel) — ядро 3.8.13.28
- [android_picasso](https://github.com/beeline09/android_picasso) — device trees + патчи платформы

## Лицензия

GPL v3. См. [COPYING](COPYING).

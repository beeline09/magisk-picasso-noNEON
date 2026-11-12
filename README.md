# Magisk v31.1 noNEON для Tegra 2 (Acer Iconia Tab A500/A501)

Fork of [Magisk v31.1](https://github.com/topjohnwu/Magisk) by [topjohnwu](https://github.com/topjohnwu),
patched for NVIDIA Tegra 2 (ARMv7 + VFPv3-D16, **no NEON**).

## Почему форк

Все официальные сборки Magisk содержат NEON-инструкции → SIGILL на Tegra 2.
Этот форк пересобирает все нативные компоненты без NEON.

## Как использовать

### Вариант 1: Готовый zip (для пользователей)

Скачайте `Magisk-v31.1-picasso.zip` из [Releases](../../releases) и прошейте через CWM/TWRP.

### Вариант 2: Собрать самостоятельно

```bash
git clone https://github.com/beeline09/magisk-picasso-noNEON
cd magisk-picasso-noNEON

# SDK + ONDK + JDK 25 (см. полная инструкция ниже)
python3 build.py ndk       # скачать ONDK (~2 ГБ)
python3 build.py -r native # бинарники без NEON (~5 мин)
python3 build.py -r app    # APK = flashable zip
```

Полная инструкция сборки: [howto-build-magisk.md](../../tree/main/Docs)

## Что изменено (один коммит поверх v31.1)

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
# В вашем форке:
git fetch upstream
git checkout -b picasso-noNEON-v32 upstream/v32.0
git cherry-pick 403a6e2   # наш коммит

# Конфликты — правьте вручную (все изменения помечены "PICASSO")
```

## ⚠️ НИКОГДА не обновляйте из приложения!

Официальные обновления содержат NEON → SIGILL → бутлуп.

## Что нужно собрать ДО Magisk

Busybox 1.36.1 на musl (bionic-статик содержит NEON в libm).
Подробности в Docs/howto-build-magisk.md, раздел 6.

## Лицензия

GPL v3 (наследует Magisk). Наш коммит: beeline09.

## Благодарности

- [**topjohnwu**](https://github.com/topjohnwu) (John Wu) — Magisk v31.1
- [**beeline09**](https://github.com/beeline09) — noNEON порт для Tegra 2

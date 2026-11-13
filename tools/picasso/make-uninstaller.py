#!/usr/bin/env python3
"""Сборка remove-magisk.zip из app-release.apk + JAR-подпись (openssl).

Использование:
  python3 make-uninstaller.py out/app-release.apk remove-magisk.zip <signing-dir>

<signing-dir> — каталог с picasso.key/picasso.crt (создастся при первом запуске).
Структура подписи повторяет планшетную (MANIFEST.MF + CERT.SF + CERT.RSA).
"""
import hashlib
import base64
import os
import subprocess
import sys
import zipfile

apk, out, sigdir = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(sigdir, exist_ok=True)
key, crt = os.path.join(sigdir, "picasso.key"), os.path.join(sigdir, "picasso.crt")

if not (os.path.exists(key) and os.path.exists(crt)):
    subprocess.run([
        "openssl", "req", "-x509", "-newkey", "rsa:2048", "-keyout", key,
        "-out", crt, "-days", "10000", "-subj", "/CN=picasso", "-nodes"
    ], check=True)

zin = zipfile.ZipFile(apk)
zout = zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED)

manifest = "Manifest-Version: 1.0\r\nCreated-By: picasso-uninstaller\r\n\r\n"
body = []
for info in zin.infolist():
    name = info.filename
    if name == "META-INF/com/google/android/updater-script":
        data = open("scripts/uninstaller.sh", "rb").read()
    elif name.startswith("META-INF/") and (
        name.endswith((".SF", ".RSA", ".DSA")) or name == "META-INF/MANIFEST.MF"
    ):
        continue  # старая подпись выбрасывается
    else:
        data = zin.read(name)
    zi = zipfile.ZipInfo(name, date_time=(2009, 1, 1, 0, 0, 0))
    zi.compress_type = zipfile.ZIP_DEFLATED
    zi.external_attr = 0o644 << 16
    zout.writestr(zi, data)
    if not name.startswith("META-INF/"):
        d = base64.b64encode(hashlib.sha1(data).digest()).decode()
        body.append(f"Name: {name}\r\nSHA1-Digest: {d}\r\n\r\n")
manifest += "".join(body)

mf = subprocess.run(
    ["openssl", "smime", "-sign", "-in", "/dev/stdin", "-signer", crt,
     "-inkey", key, "-outform", "DER", "-noattr"],
    input=manifest.replace("\r\n", "\n").encode(), capture_output=True, check=True
).stdout
# CERT.SF: только заголовок с дайджестом MANIFEST (как в планшетной версии)
mdg = base64.b64encode(hashlib.sha1(manifest.encode()).digest()).decode()
sf = f"Signature-Version: 1.0\r\nSHA1-Digest-Manifest: {mdg}\r\nCreated-By: picasso\r\n\r\n"

for nm, data in (("META-INF/MANIFEST.MF", manifest.encode()),
                 ("META-INF/CERT.SF", sf.encode()),
                 ("META-INF/CERT.RSA", mf)):
    zi = zipfile.ZipInfo(nm, date_time=(2009, 1, 1, 0, 0, 0))
    zi.compress_type = zipfile.ZIP_DEFLATED
    zi.external_attr = 0o644 << 16
    zout.writestr(zi, data)
zout.close()
print(f"UNINSTALLER_OK {out} {os.path.getsize(out)}")

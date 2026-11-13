#!/usr/bin/env python3
"""Патч _start_main в Magisk-бинарях: убрать NEON-обнуление структуры.

Сток (clang, armv7-androideabi): vmov.i32 q8,#0 + vst1.64 {d16,d17},[r3]! + str.w
Патченный (deployed):           mov.w r12,#0 + strd r12,r12,[r3] + strd [r3,#8] + str.w [r3,#0x10]

Использование: patch-crt0.py <файл> [<файл>...]
"""
import sys

# file-порядок байтов (little-endian)
OLD = bytes.fromhex(
    "c0ef5000"   # vmov.i32 q8, #0
    "0e4a"       # ldr r2,[pc,#0x38]
    "6b46"       # mov r3,sp
    "7944"       # add r1,pc
    "4ff0000c"   # mov.w r12,#0
    "7a44"       # add r2,pc
    "43f9cd0a"   # vst1.64 {d16,d17},[r3]!
    "0968"       # ldr r1,[r1]
    "1268"       # ldr r2,[r2]
    "c3f800c0"   # str.w r12,[r3]
)
NEW = bytes.fromhex(
    "4ff0000c"   # mov.w r12,#0
    "0e4a"
    "6b46"
    "7944"
    "c3e900cc"   # strd r12,r12,[r3]
    "7a44"
    "c3e902cc"   # strd r12,r12,[r3,#8]
    "0968"
    "1268"
    "c3f810c0"   # str.w r12,[r3,#0x10]
)

rc = 0
for p in sys.argv[1:]:
    d = open(p, "rb").read()
    n = d.count(OLD)
    if n == 0:
        if d.count(NEW):
            print(f"SKIP {p}: уже патчен")
        else:
            print(f"WARN  {p}: паттерн не найден")
        continue
    d2 = d.replace(OLD, NEW)
    open(p, "wb").write(d2)
    print(f"PATCHED {p}: {n} вхождений")
    rc |= 0
sys.exit(0)

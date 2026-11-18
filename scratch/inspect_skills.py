import os, re

ROOT = r"c:\linhtinh\game defence test\game-test\data\enemies"
enemies = [
    "aegis", "cloaker", "disruptor", "diver", "escort", "glider",
    "jammer", "mender", "mender_elite", "prismling", "rallier",
    "sludge", "sprinter", "static_crawler", "vanguard", "wraith"
]

for name in enemies:
    p = os.path.join(ROOT, f"{name}.tres")
    with open(p, 'r', encoding='utf-8') as fp:
        print(f"================ {name} ================")
        print(fp.read().strip())

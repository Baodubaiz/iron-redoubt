import os, re

ROOT = r"c:\linhtinh\game defence test\game-test\data\levels"
ENEMIES = r"c:\linhtinh\game defence test\game-test\data\enemies"

def check():
    missing = 0
    total = 0
    for i in range(1, 41):
        lvl = f"level_{i:02d}.tres"
        p = os.path.join(ROOT, lvl)
        with open(p, "r", encoding="utf-8") as fp:
            c = fp.read()
            refs = re.findall(r'path="res://data/enemies/([a-zA-Z0-9_]+)\.tres"', c)
            for r in refs:
                total += 1
                ep = os.path.join(ENEMIES, f"{r}.tres")
                if not os.path.exists(ep):
                    print(f"Missing enemy in {lvl}: {r}")
                    missing += 1
    print(f"Checked {total} enemy references across 40 levels. Missing: {missing}")

if __name__ == "__main__":
    check()

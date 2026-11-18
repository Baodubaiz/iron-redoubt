import os

ROOT = r"c:\linhtinh\game defence test\game-test"

def check_indentation():
    print("=== Checking indentation in all .gd files ===")
    mixed_count = 0
    space_indented = []
    for root, dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root or "scratch" in root:
            continue
        for f in files:
            if f.endswith(".gd"):
                path = os.path.join(root, f)
                rel = os.path.relpath(path, ROOT)
                with open(path, "r", encoding="utf-8", errors="ignore") as fp:
                    has_tab = False
                    has_space = False
                    for idx, line in enumerate(fp, 1):
                        stripped = line.lstrip()
                        if not stripped or stripped.startswith("#"):
                            continue
                        indent = line[:len(line) - len(stripped)]
                        if "\t" in indent and " " in indent:
                            print(f"[MIXED INDENT LINE] {rel}:{idx}: line mixes tabs and spaces!")
                            mixed_count += 1
                        elif "\t" in indent:
                            has_tab = True
                        elif " " in indent:
                            has_space = True
                    if has_tab and has_space:
                        # File has both tab lines and space lines
                        space_indented.append(rel)
                        
    print(f"Total lines with mixed tabs and spaces: {mixed_count}")
    if space_indented:
        print(f"Files mixing tab lines and space lines: {len(space_indented)}")
        for si in space_indented:
            print(f"  - {si}")

if __name__ == "__main__":
    check_indentation()

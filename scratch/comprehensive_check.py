import os
import re
import sys

ROOT = r"c:\linhtinh\game defence test\game-test"

errors = []
warnings = []

def log_err(msg):
    errors.append(msg)
    print(f"[ERROR] {msg}")

def log_warn(msg):
    warnings.append(msg)
    print(f"[WARN] {msg}")

# 1. Check all .tscn and .tres files for ExtResource references and missing scripts
def check_resources():
    print("--- Checking all .tscn and .tres references ---")
    ext_res_pat = re.compile(r'path="res://([^"]+)"')
    for root, dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root or "scratch" in root:
            continue
        for f in files:
            if f.endswith((".tscn", ".tres")):
                filepath = os.path.join(root, f)
                with open(filepath, "r", encoding="utf-8", errors="ignore") as fp:
                    content = fp.read()
                    for match in ext_res_pat.findall(content):
                        rel_path = match.replace("/", os.sep)
                        abs_target = os.path.join(ROOT, rel_path)
                        if not os.path.exists(abs_target):
                            log_err(f"{os.path.relpath(filepath, ROOT)} refers to non-existent resource: res://{match}")

# 2. Check all .gd files for parse/syntax sanity
def check_gdscripts():
    print("--- Checking GDScript files ---")
    for root, dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root or "scratch" in root:
            continue
        for f in files:
            if f.endswith(".gd"):
                filepath = os.path.join(root, f)
                rel_path = os.path.relpath(filepath, ROOT)
                with open(filepath, "r", encoding="utf-8", errors="ignore") as fp:
                    lines = fp.readlines()

                in_multiline_str = False
                str_delimiter = ""

                stack = [] # (char, line_num)

                for line_idx, line in enumerate(lines, 1):
                    # Check for unclosed multiline triple quotes
                    i = 0
                    while i < len(line):
                        if not in_multiline_str:
                            if line[i:i+3] in ('"""', "'''"):
                                in_multiline_str = True
                                str_delimiter = line[i:i+3]
                                i += 3
                                continue
                            elif line[i] == '#':
                                break # comment until end of line
                            elif line[i] in ('"', "'"):
                                # single line string
                                q = line[i]
                                i += 1
                                escaped = False
                                closed = False
                                while i < len(line):
                                    c = line[i]
                                    if c == '\\':
                                        escaped = not escaped
                                    elif c == q and not escaped:
                                        closed = True
                                        i += 1
                                        break
                                    elif c == '\n' or c == '\r':
                                        break
                                    else:
                                        escaped = False
                                    i += 1
                                if not closed:
                                    log_err(f"{rel_path}:{line_idx}: Unclosed string literal {q}")
                                continue
                            elif line[i] in '({[':
                                stack.append((line[i], line_idx))
                            elif line[i] in ')}]':
                                if not stack:
                                    log_err(f"{rel_path}:{line_idx}: Unmatched closing delimiter '{line[i]}'")
                                else:
                                    opener, o_line = stack.pop()
                                    expected = {'(': ')', '{': '}', '[': ']'}[opener]
                                    if expected != line[i]:
                                        log_err(f"{rel_path}:{line_idx}: Mismatched delimiter: opened '{opener}' at line {o_line}, closed with '{line[i]}'")
                        else:
                            if line[i:i+3] == str_delimiter:
                                in_multiline_str = False
                                i += 3
                                continue
                        i += 1

                if in_multiline_str:
                    log_err(f"{rel_path}: EOF while inside multiline string {str_delimiter}")
                if stack:
                    for opener, o_line in stack:
                        log_err(f"{rel_path}:{o_line}: Unclosed delimiter '{opener}'")

# 3. Check for specific script logic bugs
def check_logic():
    print("--- Checking common logic issues ---")
    # Check if any preload/load fails
    load_pat = re.compile(r'\b(?:preload|load)\s*\(\s*["\']res://([^"\']+)["\']\s*\)')
    for root, dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root or "scratch" in root:
            continue
        for f in files:
            if f.endswith(".gd"):
                filepath = os.path.join(root, f)
                rel_path = os.path.relpath(filepath, ROOT)
                with open(filepath, "r", encoding="utf-8", errors="ignore") as fp:
                    content = fp.read()
                    for m in load_pat.findall(content):
                        target = os.path.join(ROOT, m.replace("/", os.sep))
                        if not os.path.exists(target):
                            log_err(f"{rel_path} load/preload cannot find: res://{m}")

if __name__ == "__main__":
    check_resources()
    check_gdscripts()
    check_logic()
    print("\n===============================")
    print(f"Summary: {len(errors)} errors, {len(warnings)} warnings")
    print("===============================")

import os
import re
import sys

ROOT = r"c:\linhtinh\game defence test\game-test"

def check_godot3_deprecated():
    print("=== 1. Checking Godot 3 Deprecated Syntax ===")
    patterns = [
        (re.compile(r'\bexport\s+var\b'), "export var (should be @export var)"),
        (re.compile(r'\bonready\s+var\b'), "onready var (should be @onready var)"),
        (re.compile(r'\byield\s*\('), "yield() (should be await)"),
        (re.compile(r'\b\.instance\s*\('), ".instance() (should be .instantiate())"),
        (re.compile(r'\bsetget\b'), "setget (Godot 3 syntax)"),
        (re.compile(r'\.empty\s*\(\s*\)'), ".empty() on String/Array (should be .is_empty())"),
    ]
    found = 0
    for root, dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root or "scratch" in root:
            continue
        for f in files:
            if f.endswith(".gd"):
                path = os.path.join(root, f)
                with open(path, "r", encoding="utf-8", errors="ignore") as fp:
                    for idx, line in enumerate(fp, 1):
                        clean_line = line.split("#")[0]
                        for pat, desc in patterns:
                            if pat.search(clean_line):
                                rel = os.path.relpath(path, ROOT)
                                print(f"[DEPRECATED] {rel}:{idx}: {desc} -> {line.strip()}")
                                found += 1
    print(f"Total deprecated issues: {found}\n")

def check_res_paths():
    print("=== 2. Checking res:// Resource Paths ===")
    res_pat = re.compile(r'res://([a-zA-Z0-9_\-./]+)')
    missing = 0
    checked = 0
    for root, dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root or "scratch" in root:
            continue
        for f in files:
            if f.endswith((".gd", ".tscn", ".tres")):
                path = os.path.join(root, f)
                with open(path, "r", encoding="utf-8", errors="ignore") as fp:
                    content = fp.read()
                    matches = res_pat.findall(content)
                    for m in matches:
                        checked += 1
                        # normalize path
                        target_file = os.path.join(ROOT, m.replace("/", os.sep))
                        if not os.path.exists(target_file):
                            rel = os.path.relpath(path, ROOT)
                            print(f"[MISSING RES] {rel} references missing: res://{m}")
                            missing += 1
    print(f"Checked {checked} res:// references. Missing: {missing}\n")

def check_signals():
    print("=== 3. Checking Signal Definitions vs Emissions ===")
    sig_def_pat = re.compile(r'^\s*signal\s+([a-zA-Z0-9_]+)\s*(?:\(([^)]*)\))?')
    sig_emit_pat = re.compile(r'([a-zA-Z0-9_]+)\.emit\s*\(([^)]*)\)')
    
    signals = {} # sig_name: [list of (file, line, param_count)]
    emissions = [] # (file, line, sig_name, arg_count, args_str)

    for root, dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root or "scratch" in root:
            continue
        for f in files:
            if f.endswith(".gd"):
                path = os.path.join(root, f)
                with open(path, "r", encoding="utf-8", errors="ignore") as fp:
                    for idx, line in enumerate(fp, 1):
                        clean_line = line.split("#")[0]
                        m_sig = sig_def_pat.match(clean_line)
                        if m_sig:
                            name = m_sig.group(1)
                            params_raw = m_sig.group(2)
                            params = [p.strip() for p in params_raw.split(',') if p.strip()] if params_raw else []
                            signals.setdefault(name, []).append((os.path.relpath(path, ROOT), idx, len(params)))
                        
                        for m_emit in sig_emit_pat.finditer(clean_line):
                            name = m_emit.group(1)
                            args_raw = m_emit.group(2)
                            # simple comma split (ignoring commas inside nested func calls for now)
                            args = [a.strip() for a in args_raw.split(',') if a.strip()] if args_raw else []
                            emissions.append((os.path.relpath(path, ROOT), idx, name, len(args), args_raw))
    
    mismatches = 0
    for file, line, name, arg_count, args_str in emissions:
        if name in signals:
            defs = signals[name]
            # check if arg_count matches any def
            matched = any(d[2] == arg_count for d in defs)
            if not matched:
                defs_str = ", ".join([f"{d[0]}:{d[1]} ({d[2]} params)" for d in defs])
                print(f"[SIGNAL MISMATCH] {file}:{line}: {name}.emit({args_str}) passed {arg_count} args, but defined with: {defs_str}")
                mismatches += 1
    print(f"Total signal mismatches: {mismatches}\n")

def check_enemy_defs_and_visuals():
    print("=== 4. Checking Enemies Definitions, Visuals, and Codex ===")
    enemies_dir = os.path.join(ROOT, "data", "enemies")
    enemy_files = [f for f in os.listdir(enemies_dir) if f.endswith(".tres")]
    
    # Check enemy_visual.gd
    ev_path = os.path.join(ROOT, "gameplay", "visuals", "enemy_visual.gd")
    with open(ev_path, "r", encoding="utf-8") as fp:
        ev_content = fp.read()
    
    # Check codex_screen.gd
    codex_path = os.path.join(ROOT, "ui", "menus", "codex_screen.gd")
    with open(codex_path, "r", encoding="utf-8") as fp:
        codex_content = fp.read()

    for ef in enemy_files:
        eid = ef.replace(".tres", "")
        # Check enemy id in visual
        if f'"{eid}"' not in ev_content and f"'{eid}'" not in ev_content:
            print(f"[ENEMY VISUAL MISSING] Enemy '{eid}' is not mapped in enemy_visual.gd!")
        # Check enemy tip in codex
        if f'"{eid}"' not in codex_content and f"'{eid}'" not in codex_content:
            print(f"[ENEMY CODEX MISSING] Enemy '{eid}' has no tip in codex_screen.gd ENEMY_TIP!")
    print(f"Checked {len(enemy_files)} enemy definition files.\n")

def check_towers_defs():
    print("=== 5. Checking Tower Definitions ===")
    towers_dir = os.path.join(ROOT, "data", "towers")
    tower_files = [f for f in os.listdir(towers_dir) if f.endswith(".tres")]
    print(f"Found {len(tower_files)} tower definition files.")
    for tf in tower_files:
        path = os.path.join(towers_dir, tf)
        with open(path, "r", encoding="utf-8") as fp:
            content = fp.read()
            # check that base_cost exists and is positive
            m_cost = re.search(r'base_cost\s*=\s*(\d+)', content)
            if not m_cost:
                print(f"[TOWER DEF] {tf} missing base_cost!")
            else:
                cost = int(m_cost.group(1))
                if cost <= 0:
                    print(f"[TOWER DEF] {tf} invalid base_cost: {cost}")
    print()

def check_return_types():
    print("=== 6. Checking Typed Functions Without Return ===")
    func_pat = re.compile(r'^\s*func\s+([a-zA-Z0-9_]+)\s*\([^)]*\)\s*->\s*([a-zA-Z0-9_]+)\s*:')
    issues = 0
    for root, dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root or "scratch" in root:
            continue
        for f in files:
            if f.endswith(".gd"):
                path = os.path.join(root, f)
                with open(path, "r", encoding="utf-8", errors="ignore") as fp:
                    lines = fp.readlines()
                
                i = 0
                while i < len(lines):
                    line = lines[i]
                    m = func_pat.match(line)
                    if m:
                        fname = m.group(1)
                        ret_type = m.group(2)
                        if ret_type != "void":
                            # get indentation
                            indent = len(line) - len(line.lstrip())
                            # scan function body until next func or class or same/lower indent
                            body_lines = []
                            j = i + 1
                            while j < len(lines):
                                b_line = lines[j]
                                if b_line.strip() == "" or b_line.strip().startswith("#"):
                                    j += 1
                                    continue
                                b_indent = len(b_line) - len(b_line.lstrip())
                                if b_indent <= indent:
                                    break
                                body_lines.append(b_line)
                                j += 1
                            
                            # Check if body has any return statement
                            has_return = any(re.search(r'\breturn\b', bl) for bl in body_lines)
                            has_pass_only = len(body_lines) == 1 and body_lines[0].strip() == "pass"
                            if not has_return and not has_pass_only:
                                rel = os.path.relpath(path, ROOT)
                                print(f"[MISSING RETURN] {rel}:{i+1} func {fname}() -> {ret_type} has no return statement!")
                                issues += 1
                    i += 1
    print(f"Total missing return issues: {issues}\n")

if __name__ == "__main__":
    check_godot3_deprecated()
    check_res_paths()
    check_signals()
    check_enemy_defs_and_visuals()
    check_towers_defs()
    check_return_types()

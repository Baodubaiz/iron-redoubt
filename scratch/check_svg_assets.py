import os, re

ROOT = r"c:\linhtinh\game defence test\game-test"
ICONS_DIR = os.path.join(ROOT, "assets", "ui", "icons")
ART_ENEMIES_DIR = os.path.join(ROOT, "assets", "art", "enemies")

def check_svg_assets():
    print("=== Checking SVG and Art Assets ===")
    icon_pat = re.compile(r'UiKit\.icon\(\s*["\']([a-zA-Z0-9_\-]+)["\']\s*\)')
    missing_icons = set()
    found_icons = 0
    
    for root, dirs, files in os.walk(ROOT):
        if ".git" in root or ".godot" in root or "scratch" in root:
            continue
        for f in files:
            if f.endswith(".gd"):
                p = os.path.join(root, f)
                with open(p, "r", encoding="utf-8", errors="ignore") as fp:
                    content = fp.read()
                    for m in icon_pat.findall(content):
                        found_icons += 1
                        svg_path = os.path.join(ICONS_DIR, f"{m}.svg")
                        if not os.path.exists(svg_path):
                            missing_icons.add(m)
                            
    print(f"Checked {found_icons} UiKit.icon calls. Missing icons: {missing_icons}")
    
    # Check enemy body assets in enemy_visual.gd
    ev_path = os.path.join(ROOT, "gameplay", "visuals", "enemy_visual.gd")
    with open(ev_path, "r", encoding="utf-8") as fp:
        ev_content = fp.read()
    
    # Find all BODY texture paths
    body_svgs = re.findall(r'preload\("res://assets/art/enemies/([a-zA-Z0-9_\-]+)\.svg"\)', ev_content)
    missing_enemy_svg = []
    for es in body_svgs:
        target = os.path.join(ART_ENEMIES_DIR, f"{es}.svg")
        if not os.path.exists(target):
            missing_enemy_svg.append(es)
            
    print(f"Checked {len(body_svgs)} enemy body SVGs in enemy_visual.gd. Missing: {missing_enemy_svg}")

if __name__ == "__main__":
    check_svg_assets()

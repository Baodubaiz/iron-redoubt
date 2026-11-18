"""Lists translatable strings (I18n.t / I18n.f in runtime code + display text in data .tres files)
that are missing from i18n/translations.csv.
Usage (from the project folder):  python tools/i18n/extract_keys.py
Add each missing key with its Vietnamese text to i18n/translations.csv (columns: keys,vi), then
re-import the project. Keys are the English source strings; keep %d / %s / %.1f / %% unchanged."""
import csv, glob, os, re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
os.chdir(ROOT)
EXTRA = ["Shatter", "Grounded", "Conductive", "Meltdown", "Inferno", "Cascade", "Storm Array",
         "Outside the build area", "Too close to the path", "Blocked terrain", "Overlaps another tower",
         "North", "South", "Locked", "Maxed", "Close", "Pulse", "Nova", "Lance", "Beacon", "Settings", "Back",
         "Dmg", "Rate", "Range", "Splash", "Pen", "Beam", "Slow", "Buff", "Chain",
         # region names / descriptions (VisualPalette.MAP), boss telegraph labels, boss phase toasts
         "Circuit", "Delta", "Prism", "Rift", "A tear in the grid. Every mechanic at once, and two bosses.",
         "Summoning!", "Hardening shell!", "Overclocking!", "Launching fighters!", "Cloaking!",
         "Adapting plating!", "Jamming towers!", "Shielding escorts!", "Rift jump!",
         "Warden overclocks — it sprints between shells!", "Carrier cloak field online — keep Beacons close!",
         "Chimera jammer online — towers nearby recharge slower!", "Chimera unstable — plating shifts twice as fast!",
         "Colossus tears the Rift — it jumps ahead!", "Colossus overdrive — its escort speeds up!",
         "Static field!", "Capacitor charging!", "Submerging!", "Raising the fallen!", "Splitting light!", "Prismatic shield!",
         "Dynamo capacitor online — big hits are capped!", "Dynamo overload — it speeds up!",
         "Leviathan calls the fallen back — finish them twice!", "Leviathan dives twice as often!",
         "Refractor prismatic shield — it resists one damage type at a time!", "Charging!", "Healing!"]


def clean(s):
    return s.replace('\\n', '\n').replace('\\"', '"')


def keys():
    out = []
    def add(k):
        if k and k not in out:
            out.append(k)
    for f in glob.glob('**/*.gd', recursive=True):
        if f.startswith(('tests', 'tools', '.godot')):
            continue
        src = open(f, encoding='utf-8').read()
        for m in re.finditer(r'I18n\.[tf]\(\s*"((?:[^"\\]|\\.)*)"', src):
            add(clean(m.group(1)))
        for m in re.finditer(r'I18n\.t\(\[([^\]]*)\]', src):
            for s in re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1)):
                add(clean(s))
    for s in EXTRA:
        add(s)
    # Codex tables: capitalised strings inside its const blocks are display text (ids are lowercase)
    src = open('ui/menus/codex_screen.gd', encoding='utf-8').read()
    for blk in re.findall(r'^const [A-Z_]+ := [\[{].*?(?=\n\n)', src, re.M | re.S):
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', blk):
            t = clean(m.group(1))
            if t[:1].isupper() or t.startswith('x%'):
                add(t)
    for f in sorted(glob.glob('data/**/*.tres', recursive=True)):
        t = open(f, encoding='utf-8').read()
        for m in re.finditer(r'^(display_name|role|description|objective|label) = "((?:[^"\\]|\\.)*)"', t, re.M):
            add(clean(m.group(2)))
    return out


if __name__ == "__main__":
    with open("i18n/translations.csv", encoding="utf-8") as f:
        have = {row[0] for row in csv.reader(f)}
    missing = [k for k in keys() if k not in have]
    print("%d keys, %d missing" % (len(keys()), len(missing)))
    for k in missing:
        print(repr(k))

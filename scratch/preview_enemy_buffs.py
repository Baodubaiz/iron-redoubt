import os, re

ROOT = r"c:\linhtinh\game defence test\game-test\data\enemies"

def calc_preview():
    print(f"{'Enemy':<16} {'HP':<15} {'Speed':<15} {'Armor':<15} {'Shield':<15}")
    print("-" * 75)
    for f in sorted(os.listdir(ROOT)):
        if f.endswith('.tres'):
            eid = f.replace('.tres', '')
            p = os.path.join(ROOT, f)
            with open(p, 'r', encoding='utf-8') as fp:
                c = fp.read()
            m_hp = re.search(r'\bmax_hp\s*=\s*([\d.]+)', c)
            m_spd = re.search(r'\bspeed\s*=\s*([\d.]+)', c)
            m_arm = re.search(r'\barmor\s*=\s*([\d.]+)', c)
            m_shd = re.search(r'\bshield\s*=\s*([\d.]+)', c)
            
            orig_hp = float(m_hp.group(1)) if m_hp else 50.0
            orig_spd = float(m_spd.group(1)) if m_spd else 70.0
            orig_arm = float(m_arm.group(1)) if m_arm else 0.0
            orig_shd = float(m_shd.group(1)) if m_shd else 0.0
            
            new_hp = round(orig_hp * 1.05, 1)
            new_spd = round(orig_spd * 1.05, 1)
            new_arm = round(orig_arm * 1.05, 1) if orig_arm > 0 else 0.0
            new_shd = round(orig_shd * 1.05, 1) if orig_shd > 0 else 0.0
            
            print(f"{eid:<16} {orig_hp}->{new_hp:<8} {orig_spd}->{new_spd:<8} {orig_arm}->{new_arm:<8} {orig_shd}->{new_shd:<8}")

if __name__ == '__main__':
    calc_preview()

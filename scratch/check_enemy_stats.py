import os, re

ROOT = r"c:\linhtinh\game defence test\game-test\data\enemies"
for f in sorted(os.listdir(ROOT)):
    if f.endswith('.tres'):
        p = os.path.join(ROOT, f)
        with open(p, 'r', encoding='utf-8') as fp:
            c = fp.read()
            m_id = re.search(r'id\s*=\s*&?"([^"]+)"', c)
            m_b = re.search(r'bounty\s*=\s*(\d+)', c)
            m_hp = re.search(r'max_hp\s*=\s*([\d.]+)', c)
            m_spd = re.search(r'speed\s*=\s*([\d.]+)', c)
            m_arm = re.search(r'armor\s*=\s*([\d.]+)', c)
            m_shd = re.search(r'shield\s*=\s*([\d.]+)', c)
            
            eid = m_id.group(1) if m_id else f
            b = m_b.group(1) if m_b else '1 (default)'
            hp = m_hp.group(1) if m_hp else '50.0 (default)'
            spd = m_spd.group(1) if m_spd else '70.0 (default)'
            arm = m_arm.group(1) if m_arm else '0.0 (default)'
            shd = m_shd.group(1) if m_shd else '0.0 (default)'
            
            print(f"{eid:<16} bounty={b:<4} hp={hp:<8} spd={spd:<8} armor={arm:<6} shield={shd}")

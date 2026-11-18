import os, re

ROOT = r"c:\linhtinh\game defence test\game-test\data\enemies"
for f in sorted(os.listdir(ROOT)):
    if f.endswith('.tres'):
        p = os.path.join(ROOT, f)
        with open(p, 'r', encoding='utf-8') as fp:
            c = fp.read()
            m_cat = re.search(r'category\s*=\s*(\d+)', c)
            eid = f.replace('.tres', '')
            cat = m_cat.group(1) if m_cat else '0'
            has_skills = 'boss_skills' in c
            has_heal = 'heal_amount' in c
            is_boss = 'is_boss = true' in c
            if cat == '2' or has_skills or has_heal or is_boss:
                print(f"{eid:<16} cat={cat} is_boss={is_boss} skills={has_skills} heal={has_heal}")

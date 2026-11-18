import os, re

ROOT = r"c:\linhtinh\game defence test\game-test\data\enemies"

# Special ability overrides
SKILL_BUFFS = {
    "disruptor.tres": [
        (r'interval\s*=\s*7\.0', 'interval = 6.0'),
        (r'telegraph\s*=\s*1\.2', 'telegraph = 1.0'),
        (r'"duration":\s*3\.5', '"duration": 4.0'),
        (r'"factor":\s*0\.45', '"factor": 0.4'),
        (r'"radius":\s*160\.0', '"radius": 180.0'),
    ],
    "static_crawler.tres": [
        (r'interval\s*=\s*9\.0', 'interval = 8.0'),
        (r'telegraph\s*=\s*1\.5', 'telegraph = 1.2'),
        (r'"duration":\s*4\.0', '"duration": 4.5'),
        (r'"factor":\s*0\.6', '"factor": 0.55'),
        (r'"radius":\s*200\.0', '"radius": 220.0'),
    ],
    "wraith.tres": [
        (r'interval\s*=\s*10\.0', 'interval = 8.5'),
        (r'telegraph\s*=\s*0\.8', 'telegraph = 0.6'),
        (r'"duration":\s*1\.5', '"duration": 2.0'),
        (r'"radius":\s*130\.0', '"radius": 150.0'),
    ],
    "vanguard.tres": [
        (r'interval\s*=\s*10\.0', 'interval = 8.5'),
        (r'telegraph\s*=\s*1\.5', 'telegraph = 1.2'),
        (r'"amount":\s*100\.0', '"amount": 130.0'),
        (r'"duration":\s*5\.0', '"duration": 6.0'),
        (r'"radius":\s*180\.0', '"radius": 200.0'),
    ],
    "rallier.tres": [
        (r'interval\s*=\s*8\.0', 'interval = 7.0'),
        (r'"duration":\s*3\.0', '"duration": 4.0'),
        (r'"radius":\s*150\.0', '"radius": 180.0'),
    ],
    "cloaker.tres": [
        (r'interval\s*=\s*12\.0', 'interval = 10.0'),
        (r'telegraph\s*=\s*1\.2', 'telegraph = 1.0'),
        (r'"duration":\s*4\.0', '"duration": 5.0'),
        (r'"radius":\s*140\.0', '"radius": 160.0'),
    ],
    "mender_elite.tres": [
        (r'heal_amount\s*=\s*35\.0', 'heal_amount = 42.0'),
        (r'heal_radius\s*=\s*160\.0', 'heal_radius = 180.0'),
        (r'heal_interval\s*=\s*2\.0', 'heal_interval = 1.8'),
        (r'interval\s*=\s*8\.0', 'interval = 7.0'),
        (r'"frac":\s*0\.12', '"frac": 0.15'),
        (r'"radius":\s*160\.0', '"radius": 180.0'),
    ],
    "mender.tres": [
        (r'heal_amount\s*=\s*25\.0', 'heal_amount = 30.0'),
        (r'heal_radius\s*=\s*140\.0', 'heal_radius = 160.0'),
        (r'heal_interval\s*=\s*2\.0', 'heal_interval = 1.8'),
    ],
    "aegis.tres": [
        (r'interval\s*=\s*11\.0', 'interval = 9.5'),
        (r'"duration":\s*2\.5', '"duration": 3.0'),
        (r'"factor":\s*0\.75', '"factor": 0.7'),
        (r'"radius":\s*140\.0', '"radius": 160.0'),
    ],
    "escort.tres": [
        (r'"amount":\s*50\.0', '"amount": 65.0'),
        (r'"duration":\s*4\.0', '"duration": 5.0'),
        (r'"radius":\s*120\.0', '"radius": 140.0'),
    ],
    "jammer.tres": [
        (r'interval\s*=\s*9\.0', 'interval = 8.0'),
        (r'"duration":\s*3\.0', '"duration": 3.5'),
        (r'"factor":\s*0\.5', '"factor": 0.45'),
        (r'"radius":\s*160\.0', '"radius": 180.0'),
    ],
    "glider.tres": [
        (r'interval\s*=\s*10\.0', 'interval = 8.5'),
        (r'"duration":\s*3\.0', '"duration": 3.5'),
        (r'"factor":\s*0\.85', '"factor": 0.8'),
        (r'"radius":\s*150\.0', '"radius": 170.0'),
    ],
    "diver.tres": [
        (r'interval\s*=\s*6\.0', 'interval = 5.0'),
        (r'"duration":\s*1\.5', '"duration": 2.0'),
    ],
    "sprinter.tres": [
        (r'interval\s*=\s*5\.0', 'interval = 4.5'),
        (r'"duration":\s*1\.5', '"duration": 2.0'),
        (r'"mult":\s*2\.0', '"mult": 2.2'),
    ],
    "sludge.tres": [
        (r'"duration":\s*3\.2', '"duration": 4.0'),
    ],
    "prismling.tres": [
        (r'interval\s*=\s*5\.0', 'interval = 4.5'),
        (r'"duration":\s*3\.5', '"duration": 4.2'),
    ],
    "monolith.tres": [
        (r'shard_hp\s*=\s*400\.0', 'shard_hp = 420.0'),
    ],
}

def buff_all_enemies():
    for f in sorted(os.listdir(ROOT)):
        if not f.endswith('.tres'):
            continue
        path = os.path.join(ROOT, f)
        with open(path, 'r', encoding='utf-8') as fp:
            text = fp.read()

        # 1. Buff parameters by 5%
        # max_hp
        m_hp = re.search(r'\bmax_hp\s*=\s*([\d.]+)', text)
        if m_hp:
            val = float(m_hp.group(1))
            new_val = round(val * 1.05, 1)
            text = re.sub(r'\bmax_hp\s*=\s*[\d.]+', f'max_hp = {new_val}', text)
        
        # speed
        m_spd = re.search(r'\bspeed\s*=\s*([\d.]+)', text)
        if m_spd:
            val = float(m_spd.group(1))
            new_val = round(val * 1.05, 1)
            text = re.sub(r'\bspeed\s*=\s*[\d.]+', f'speed = {new_val}', text)

        # armor
        m_arm = re.search(r'\barmor\s*=\s*([\d.]+)', text)
        if m_arm:
            val = float(m_arm.group(1))
            if val > 0:
                new_val = round(val * 1.05, 1)
                text = re.sub(r'\barmor\s*=\s*[\d.]+', f'armor = {new_val}', text)

        # shield
        m_shd = re.search(r'\bshield\s*=\s*([\d.]+)', text)
        if m_shd:
            val = float(m_shd.group(1))
            if val > 0:
                new_val = round(val * 1.05, 1)
                text = re.sub(r'\bshield\s*=\s*[\d.]+', f'shield = {new_val}', text)

        # threat_mult
        m_threat = re.search(r'\bthreat_mult\s*=\s*([\d.]+)', text)
        if m_threat:
            val = float(m_threat.group(1))
            new_val = round(val * 1.05, 2)
            text = re.sub(r'\bthreat_mult\s*=\s*[\d.]+', f'threat_mult = {new_val}', text)

        # 2. Apply special skill buffs
        if f in SKILL_BUFFS:
            for pat, repl in SKILL_BUFFS[f]:
                text = re.sub(pat, repl, text)

        with open(path, 'w', encoding='utf-8') as fp:
            fp.write(text)
        print(f"Updated {f}")

if __name__ == '__main__':
    buff_all_enemies()
    print("Done buffing all enemies.")

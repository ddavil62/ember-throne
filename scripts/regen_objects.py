# -*- coding: utf-8 -*-
"""
@fileoverview 35개 배틀 맵의 환경 오브젝트(objects)를 재생성하는 스크립트.
특수 오브젝트는 MAPS.md 기반 수동 정의, 일반 프랍은 tileset별 팔레트로 자동 배치.
"""
import json, os, random

MAPS_DIR = 'data/maps'

# tileset별 일반 프랍 팔레트
PALETTES = {
    'irhen':           {'main': ['tree_oak','rock_medium','fence'],           'accent': ['wildflower','bush_small','rock_small']},
    'irhen_ruins':     {'main': ['rock_large','fallen_log','burnt_stump'],    'accent': ['dead_tree','rock_medium']},
    'silvaren':        {'main': ['ancient_tree','roots','mushroom'],           'accent': ['pine','rock_medium']},
    'belmar':          {'main': ['crate','rope_anchor','lantern'],             'accent': ['rock_small','bush_small']},
    'harben':          {'main': ['hay_bale','farm_cart'],                      'accent': ['tree_small','rock_small','wildflower']},
    'crowfell':        {'main': ['tent','barricade','rock_large'],             'accent': ['rock_medium','weapon_rack','pine']},
    'ascalon':         {'main': ['castle_wall','banner','palace_pillar'],      'accent': ['rock_small']},
    'ascalon_dungeon': {'main': ['palace_pillar','rock_large'],               'accent': ['rock_medium','fallen_log']},
    'ascalon_throne':  {'main': ['palace_pillar','banner'],                   'accent': ['castle_wall']},
    'ashland':         {'main': ['dead_tree','ash_crystal'],                  'accent': ['rock_large','fissure']},
    'ashen-sea':       {'main': ['dead_tree','ash_crystal','fissure'],        'accent': ['rock_large','burnt_stump']},
    'default':         {'main': ['rock_medium','tree_oak'],                   'accent': ['bush_small','wildflower']},
}

# 배틀별 특수 오브젝트 (MAPS.md 기반, 수동 정의)
SPECIAL_OBJECTS = {
    # bridge: belmar 물 지형 배틀
    'battle_02': [
        {'type': 'bridge_intact', 'position': [7,  6]},
        {'type': 'bridge_intact', 'position': [8,  6]},
    ],
    'battle_24': [
        {'type': 'bridge_intact', 'position': [10, 8]},
        {'type': 'bridge_broken',  'position': [14, 8]},
    ],
    # iron_gate: 성문/통로 역할, 맵 가장자리 통로에 최대 2개
    'battle_18': [
        {'type': 'iron_gate', 'position': [0,  7]},   # 서쪽 통로
    ],
    'battle_19': [
        {'type': 'iron_gate', 'position': [0,  8]},
        {'type': 'trap_hidden', 'position': [5,  6]},
        {'type': 'trap_hidden', 'position': [8,  5]},
        {'type': 'trap_hidden', 'position': [11, 7]},
    ],
    'battle_20': [
        {'type': 'iron_gate', 'position': [0,  10]},
        {'type': 'iron_gate', 'position': [19, 10]},
    ],
    'battle_28': [
        {'type': 'iron_gate', 'position': [12, 0]},   # 왕도 외곽 북문
        {'type': 'iron_gate', 'position': [13, 0]},
    ],
    'battle_29': [
        {'type': 'gate_intact', 'position': [12, 0]}, # 왕도 관문
        {'type': 'gate_intact', 'position': [13, 0]},
    ],
    'battle_30': [
        {'type': 'iron_gate', 'position': [0,  12]},
    ],
    'battle_31': [
        {'type': 'iron_gate', 'position': [0,  14]},
    ],
    'battle_32': [
        {'type': 'iron_gate', 'position': [0,  14]},
    ],
    'battle_33': [
        {'type': 'iron_gate', 'position': [0,  10]},
        {'type': 'iron_gate', 'position': [27, 10]},
    ],
    'battle_34': [
        {'type': 'iron_gate', 'position': [0,  11]},
        {'type': 'iron_gate', 'position': [27, 11]},
    ],
    'battle_35': [
        {'type': 'altar',      'position': [16, 2]},  # 최종 의식 제단
        {'type': 'iron_gate',  'position': [0,  12]},
        {'type': 'iron_gate',  'position': [31, 12]},
    ],
    # ward_stone: 결계석 수집 배틀
    'battle_09': [
        {'type': 'ward_stone_active', 'position': [12, 4]},
    ],
    'battle_16': [
        {'type': 'ward_stone_active', 'position': [12, 3]},
    ],
    'battle_21': [
        {'type': 'ward_stone_active', 'position': [12, 4]},
    ],
    'battle_27': [
        {'type': 'ward_stone_active', 'position': [14, 3]},
    ],
}


def get_forbidden(data):
    """아군/적/특수 규칙 위치를 금지 영역으로 수집"""
    forbidden = set()
    W = data['map_size']['width']
    H = data['map_size']['height']
    for pos in data.get('deploy_zones', []):
        x, y = pos
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                if 0 <= x+dx < W and 0 <= y+dy < H:
                    forbidden.add((x+dx, y+dy))
    for ep in data.get('enemy_placements', []):
        x, y = ep['position']
        forbidden.add((x, y))
    for rule in data.get('special_rules', []):
        if 'position' in rule:
            forbidden.add(tuple(rule['position']))
    for vc in data.get('victory_conditions', []):
        if 'target_position' in vc:
            tp = vc['target_position']
            for dx in range(-1, 2):
                for dy in range(-1, 2):
                    forbidden.add((tp[0]+dx, tp[1]+dy))
    return forbidden


def generate_regular_objects(data, palette, forbidden, special_positions):
    """일반 프랍을 tileset 팔레트 기반으로 생성"""
    W = data['map_size']['width']
    H = data['map_size']['height']
    target = max(8, int(W * H * 0.07))

    # 중앙 통로 금지 영역
    center_x_min = W // 3
    center_x_max = 2 * W // 3

    all_forbidden = set(forbidden) | set(special_positions)
    objects = []
    placed = set()
    # scene_id가 없는 배틀은 battle_id에서 숫자 추출하여 시드 생성
    scene_id = data.get('scene_id') or data.get('battle_id', 'battle_0')
    seed_num = int(''.join(c for c in scene_id if c.isdigit()) or '0')
    rng = random.Random(seed_num * 13 + W + H)

    attempts = 0
    while len(objects) < target and attempts < 1000:
        attempts += 1
        x = rng.randint(0, W-1)
        if rng.random() < 0.7:
            y = rng.randint(0, int(H * 0.5))
        else:
            y = rng.randint(int(H * 0.5), int(H * 0.65))

        if (x, y) in all_forbidden or (x, y) in placed:
            continue
        # 중앙 통로 하단 금지
        if center_x_min <= x <= center_x_max and y >= H * 0.33:
            continue

        ptype = rng.choice(palette['main']) if rng.random() < 0.7 else rng.choice(palette['accent'])
        objects.append({'type': ptype, 'position': [x, y]})
        placed.add((x, y))

    return objects


def main():
    for fname in sorted(os.listdir(MAPS_DIR)):
        if not fname.endswith('.json'):
            continue
        bid = fname.replace('.json','')
        path = os.path.join(MAPS_DIR, fname)
        data = json.load(open(path, encoding='utf-8'))

        tileset = data.get('tileset_id', 'default')
        palette = PALETTES.get(tileset, PALETTES['default'])
        forbidden = get_forbidden(data)

        # 특수 오브젝트
        special = SPECIAL_OBJECTS.get(bid, [])
        special_positions = set(tuple(o['position']) for o in special)

        # battle_01은 수동 디자인 유지
        if bid == 'battle_01':
            print(f'{fname}: 기존 유지 (수동 디자인)')
            continue

        regular = generate_regular_objects(data, palette, forbidden, special_positions)
        data['objects'] = regular + special

        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

        sp_summary = [o['type'] for o in special]
        print(f'{fname} [{tileset}]: 일반 {len(regular)}개 + 특수 {len(special)}개 = {len(data["objects"])}개  special={sp_summary if sp_summary else "-"}')


if __name__ == '__main__':
    main()

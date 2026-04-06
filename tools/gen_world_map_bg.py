"""월드맵 배경 이미지 생성기.
PixelLab에서 생성한 32x32 지형 타일을 조합하여 1920x1080 월드맵 배경을 만든다.
"""
import math
import random
from PIL import Image, ImageFilter

# ── 설정 ──

TILE_SIZE = 32
MAP_W, MAP_H = 1920, 1088  # 60*32, 34*32 (마지막에 1080으로 crop)
COLS, ROWS = MAP_W // TILE_SIZE, MAP_H // TILE_SIZE  # 60, 34

TILE_DIR = "../assets/worldmap"

# 타일 인덱스
T_OCEAN = 0
T_COAST = 1
T_GRASS = 2
T_FOREST = 3
T_MOUNTAIN = 4
T_DESERT = 5
T_ASHEN = 6
T_ROAD = 7

# ── 지역 정의 ──

REGIONS = {
    "irhen":     {"cx": 350,  "cy": 200, "terrain": T_GRASS,    "radius": 160},
    "silvaren":  {"cx": 900,  "cy": 180, "terrain": T_FOREST,   "radius": 180},
    "crowfel":   {"cx": 620,  "cy": 450, "terrain": T_MOUNTAIN, "radius": 180},
    "harben":    {"cx": 1100, "cy": 420, "terrain": T_DESERT,   "radius": 160},
    "belmar":    {"cx": 250,  "cy": 500, "terrain": T_COAST,    "radius": 140},
    "ascalon":   {"cx": 1350, "cy": 550, "terrain": T_ROAD,     "radius": 220},
    "ashen_sea": {"cx": 960,  "cy": 800, "terrain": T_ASHEN,    "radius": 180},
}

# 대륙 중심 (대략적으로 지역 중심들의 평균)
CONTINENT_CX = 750
CONTINENT_CY = 450

def dist(x1, y1, x2, y2):
    return math.sqrt((x1 - x2) ** 2 + (y1 - y2) ** 2)

def is_land(px, py):
    """대륙 형태 판별. 타원형 대륙 + 지역 근접 보너스."""
    # 기본 타원 (가로 넓고 세로 좁음)
    dx = (px - CONTINENT_CX) / 750.0
    dy = (py - CONTINENT_CY) / 420.0
    ellipse_val = dx * dx + dy * dy

    # 지역 근처면 육지 확률 높임
    region_bonus = 0.0
    for r in REGIONS.values():
        d = dist(px, py, r["cx"], r["cy"])
        if d < r["radius"] * 1.8:
            region_bonus = max(region_bonus, 0.4 * (1.0 - d / (r["radius"] * 1.8)))

    # 약간의 노이즈
    noise = random.uniform(-0.08, 0.08)

    return (ellipse_val + noise - region_bonus) < 1.0

def get_terrain(px, py):
    """해당 픽셀 좌표의 지형 타입을 결정."""
    if not is_land(px, py):
        return T_OCEAN

    # 가장 가까운 지역 찾기
    best_terrain = T_GRASS  # 기본: 초원
    best_dist = float("inf")

    for r in REGIONS.values():
        d = dist(px, py, r["cx"], r["cy"])
        # 지역 반경 내 가중치
        weighted_d = d / (r["radius"] * 1.2)
        if weighted_d < best_dist:
            best_dist = weighted_d
            best_terrain = r["terrain"]

    # 해안선 처리: 육지이지만 바다와 인접하면 해안 타일 사용
    # (바다 가장자리에서 일정 거리 이내)
    return best_terrain

def main():
    random.seed(42)  # 재현 가능한 결과

    # 타일 로드
    tiles = {}
    for i in range(8):
        tiles[i] = Image.open(f"{TILE_DIR}/tile_{i}.png").convert("RGBA")

    # 지형 맵 생성 (각 셀의 지형 타입)
    terrain_map = [[T_OCEAN] * COLS for _ in range(ROWS)]

    for row in range(ROWS):
        for col in range(COLS):
            px = col * TILE_SIZE + TILE_SIZE // 2
            py = row * TILE_SIZE + TILE_SIZE // 2
            terrain_map[row][col] = get_terrain(px, py)

    # 해안선 처리: 바다와 인접한 육지 셀을 해안으로 변환
    coast_map = [row[:] for row in terrain_map]
    for row in range(ROWS):
        for col in range(COLS):
            if terrain_map[row][col] != T_OCEAN:
                # 주변 8방향에 바다가 있으면 해안
                has_ocean = False
                for dr in [-1, 0, 1]:
                    for dc in [-1, 0, 1]:
                        nr, nc = row + dr, col + dc
                        if 0 <= nr < ROWS and 0 <= nc < COLS:
                            if terrain_map[nr][nc] == T_OCEAN:
                                has_ocean = True
                if has_ocean:
                    coast_map[row][col] = T_COAST

    # 캔버스 생성 및 타일 배치
    canvas = Image.new("RGBA", (MAP_W, MAP_H), (10, 8, 15, 255))

    for row in range(ROWS):
        for col in range(COLS):
            t = coast_map[row][col]
            tile = tiles[t]

            # 타일 변형 (회전/미러링으로 반복감 줄이기)
            variant = (row * 7 + col * 13) % 4
            if variant == 1:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT)
            elif variant == 2:
                tile = tile.transpose(Image.FLIP_TOP_BOTTOM)
            elif variant == 3:
                tile = tile.transpose(Image.FLIP_LEFT_RIGHT).transpose(Image.FLIP_TOP_BOTTOM)

            canvas.paste(tile, (col * TILE_SIZE, row * TILE_SIZE))

    # 1080 높이로 crop
    canvas = canvas.crop((0, 0, 1920, 1080))

    # 약간의 블러로 타일 경계 부드럽게
    # (너무 강하면 픽셀아트 느낌이 사라지므로 최소한만)
    bg_blurred = canvas.filter(ImageFilter.GaussianBlur(radius=0.5))
    # 원본과 블러를 50:50 합성 (경계만 부드럽게, 디테일 유지)
    canvas = Image.blend(canvas, bg_blurred, 0.3)

    # 전체적으로 약간 어둡게 (노드와 UI가 위에 올라가므로)
    from PIL import ImageEnhance
    enhancer = ImageEnhance.Brightness(canvas)
    canvas = enhancer.enhance(0.65)

    # 비네팅 효과 (가장자리 어둡게)
    vignette = Image.new("RGBA", (1920, 1080), (0, 0, 0, 0))
    for y in range(1080):
        for x in range(1920):
            dx = (x - 960) / 960.0
            dy = (y - 540) / 540.0
            d = math.sqrt(dx * dx + dy * dy)
            alpha = int(min(255, max(0, (d - 0.6) * 200)))
            vignette.putpixel((x, y), (0, 0, 0, alpha))

    canvas = Image.alpha_composite(canvas.convert("RGBA"), vignette)

    # 저장
    out_path = f"{TILE_DIR}/world_map_bg.png"
    canvas.save(out_path, "PNG")
    print(f"월드맵 배경 생성 완료: {out_path} ({canvas.size[0]}x{canvas.size[1]})")

if __name__ == "__main__":
    main()

"""
Wang 타일셋 PNG → 오버레이 PNG 변환 스크립트

각 픽셀이 wang_0(순수 하위 지형)과 얼마나 가까운지 절대 거리로 판별한다.
  - wang_0 과 매우 가까운 픽셀 (하위 지형 fill)   → 투명
  - 다른 픽셀 (절벽 아트, 상위 지형)              → 불투명 유지

핵심 원칙:
  비율(d0/(d0+d15)) 대신 절대 거리(d0)를 기준으로 삼는다.
  절벽 아트는 wang_0 과도 다르고 wang_15 과도 달라 d0 가 크므로 불투명 유지된다.
  이전 방식(비율 0.5 → 반투명)의 문제를 해결한다.

Wang Atlas 좌표 (128×128 PNG):
  wang_0  (순수 하위): Rect2(64, 32, 32, 32)  → arr[32:64, 64:96]
  wang_15 (순수 상위): Rect2( 0, 96, 32, 32)  → arr[96:128, 0:32]
"""

import numpy as np
from PIL import Image
import os
import glob
import sys

# ── Wang Atlas 좌표 ──
WANG0_X,  WANG0_Y  = 64, 32   # wang_0  Rect2(64, 32, 32, 32)
WANG15_X, WANG15_Y =  0, 96   # wang_15 Rect2(0,  96, 32, 32)
TILE = 32  # 타일 한 변 크기 (픽셀)

# ── 절대 거리 임계값 (0~255 스케일) ──
# wang_0 와의 유클리드 거리가 이보다 작으면 → 하위 지형 fill → 투명
# lower_base_tile_id 체인 없이 독립 생성된 타일은 lower terrain 픽셀이
# 같은 타일셋 내에서도 최대 d0≈20 편차가 생길 수 있다.
LOWER_SOLID  = 18.0   # 이 이하  → 완전 투명  (하위 지형 fill 픽셀)
LOWER_FADE   = 40.0   # 이 이하  → 점진 투명  (절벽 경계 그림자)
# 20 초과인 픽셀(절벽 아트, 상위 지형)은 무조건 불투명


def make_overlay(input_path: str) -> str:
    """
    주어진 타일셋 PNG를 처리해 _ov.png 오버레이 파일을 생성한다.

    절벽 아트는 wang_0 과 색상이 크게 달라 d0 > 45 → 불투명 유지.
    하위 지형 fill 은 wang_0 과 거의 동일해 d0 < 18 → 완전 투명.

    Args:
        input_path: 원본 PNG 경로
    Returns:
        생성된 _ov.png 파일 경로
    """
    img = Image.open(input_path).convert("RGBA")
    arr = np.array(img, dtype=np.float32)

    H, W = arr.shape[:2]
    if H != 128 or W != 128:
        raise ValueError(f"Expected 128×128, got {W}×{H}")

    # ── wang_0 기준 타일 추출 (32×32 RGB) ──
    wang0 = arr[WANG0_Y : WANG0_Y + TILE, WANG0_X : WANG0_X + TILE, :3]

    # ── 공간 기준 색상 배열 구성 ──
    # ref0[y, x] = wang0[y%32, x%32] — 같은 위치의 하위 지형 기준색
    ry = np.arange(H) % TILE
    rx = np.arange(W) % TILE
    ref0 = wang0[np.ix_(ry, rx)]   # (H, W, 3)

    curr = arr[:, :, :3]  # (H, W, 3)

    # ── wang_0 와의 절대 유클리드 거리 ──
    d0 = np.sqrt(np.sum((curr - ref0) ** 2, axis=2))  # (H, W), 단위: 0~255

    # ── 거리에 따른 alpha 결정 ──
    #   d0 < LOWER_SOLID  → 0.0 (완전 투명: 순수 하위 지형 fill)
    #   d0 < LOWER_FADE   → 점진 페이드 (절벽 그림자)
    #   d0 >= LOWER_FADE  → 1.0 (완전 불투명: 절벽 아트 / 상위 지형)
    alpha = np.where(
        d0 < LOWER_SOLID,
        0.0,
        np.where(
            d0 < LOWER_FADE,
            (d0 - LOWER_SOLID) / (LOWER_FADE - LOWER_SOLID),
            1.0
        )
    )

    # ── 기존 알파 채널에 곱함 ──
    result = arr.copy()
    result[:, :, 3] = (result[:, :, 3] * alpha).astype(np.uint8)

    # ── 저장 ──
    stem = os.path.splitext(input_path)[0]
    output_path = stem + "_ov.png"
    Image.fromarray(result.astype(np.uint8)).save(output_path)
    return output_path


def main():
    root = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "tilesets")
    root = os.path.normpath(root)

    pattern = os.path.join(root, "**", "*.png")
    pngs = [p for p in glob.glob(pattern, recursive=True)
            if not p.endswith("_ov.png")]

    if not pngs:
        print("PNG 파일을 찾을 수 없습니다:", pattern)
        sys.exit(1)

    print(f"총 {len(pngs)}개 파일 처리 시작\n")
    ok = 0
    for path in sorted(pngs):
        rel = os.path.relpath(path, root)
        try:
            out = make_overlay(path)
            rel_out = os.path.relpath(out, root)
            print(f"  OK  {rel}  →  {rel_out}")
            ok += 1
        except Exception as e:
            print(f"  ERR {rel}: {e}")

    print(f"\n완료: {ok}/{len(pngs)}")


if __name__ == "__main__":
    main()

# Ember Throne

정통 판타지 택티컬 RPG. Steam PC 타겟.

## 기술 스택

| 항목 | 내용 |
|------|------|
| 엔진 | Godot 4.6.2 (GDScript) |
| 플랫폼 | Steam (Windows / Linux / macOS) |
| 해상도 | 16:9 기본, 울트라와이드 대응 |
| 입력 | 키보드 + 마우스 |
| 장르 | 택티컬 RPG (그리드 기반 턴제) |
| 레퍼런스 | 파랜드 택틱스, 창세기전 2/3, 택틱스 오우거, FE 창성 |

## 아트 파이프라인

### 개요

```
[SD Forge]                [PixelLab]                 [Godot]
컨셉/일러스트 생성  ──→  도트 스프라이트 변환  ──→  게임에 적용
(512x512~1024x1024)     (32x32~64x64 도트)
```

### 에셋별 파이프라인

| 에셋 유형 | SD Forge | PixelLab | 최종 형태 | 비고 |
|-----------|----------|----------|-----------|------|
| 캐릭터 초상화 | O (생성) | X | 일러스트 256x256 | 대화창, 메뉴에서 사용 |
| 전투 유닛 스프라이트 | O (포즈 레퍼런스) | O (도트화 + 방향) | 도트 48x48, 8방향 | create_character + animate_character |
| 맵 타일 | O (배경 레퍼런스) | O (타일셋 변환) | 32x32 타일 | create_topdown_tileset |
| 스킬 이펙트 | X | X | Godot 파티클 | 엔진 내장 파티클 시스템 |
| UI | O (9-slice 원본) | X | 가변 크기 | NinePatchRect 노드 사용 |
| 맵 오브젝트 | O (레퍼런스) | O | 도트 | create_map_object |

### SD Forge 설정

- 서버: `http://192.168.219.100:7860`
- 기본 모델: DreamShaper 8 (빠른 생성, 판타지 캐릭터에 강함)
- 고품질: SDXL Base 1.0 (초상화, 컨셉아트)
- 프롬프트 스타일: `medieval fantasy, detailed, game asset` 계열
- 네거티브: `blurry, low quality, bad anatomy, modern, sci-fi`

### PixelLab 설정

- MCP 연동: `.mcp.json`에 설정됨 (Claude Code에서 직접 호출)
- 캐릭터: `create_character()` → `animate_character()`
- 타일셋: `create_topdown_tileset()` / `create_isometric_tile()`
- 맵 오브젝트: `create_map_object()`
- 스타일 통일: 첫 캐릭터/타일 생성 후 style_images로 일관성 유지

### 아트 스타일 가이드

- **도트 크기**: 캐릭터 48px, 타일 32px
- **카메라**: low top-down (쿼터뷰가 아닌 탑다운 경사)
- **윤곽선**: single color black outline
- **셰이딩**: basic shading ~ medium shading
- **디테일**: medium detail
- **색감**: 따뜻한 판타지 톤, 채도 중간, 어두운 장면에서도 캐릭터 가독성 유지
- **비례**: 캐릭터는 chibi~default 사이 (2.5~3등신)

## 디렉토리 구조 (예정)

```
ember-throne/
├── CLAUDE.md              # 이 파일
├── project.godot          # Godot 프로젝트 설정
├── docs/
│   ├── STORY.md           # 스토리 요약 (완료)
│   ├── PROJECT.md         # 프로젝트 기획서 (예정)
│   ├── CHANGELOG.md       # 변경 이력
│   └── GAME-DESIGN.md     # 게임 디자인 문서 (전투, 성장, 밸런스)
├── scenes/                # Godot 씬 파일
│   ├── battle/            # 전투 씬
│   ├── world/             # 월드맵 씬
│   ├── dialogue/          # 대화 씬
│   ├── ui/                # UI 씬
│   └── main/              # 메인 메뉴, 로딩 등
├── scripts/               # GDScript
│   ├── battle/            # 전투 로직
│   ├── data/              # 데이터 관리
│   ├── ui/                # UI 로직
│   └── utils/             # 유틸리티
├── assets/
│   ├── sprites/           # 캐릭터/유닛 스프라이트 (PixelLab 출력)
│   ├── tilesets/          # 맵 타일셋 (PixelLab 출력)
│   ├── portraits/         # 캐릭터 초상화 (SD 출력)
│   ├── ui/                # UI 에셋 (SD 출력)
│   ├── objects/           # 맵 오브젝트 (PixelLab 출력)
│   └── audio/             # BGM, SFX
├── data/
│   ├── characters/        # 캐릭터 스탯/스킬 정의 (JSON/Resource)
│   ├── maps/              # 맵 데이터
│   ├── items/             # 아이템 데이터
│   └── dialogue/          # 대화 스크립트
└── tests/                 # 테스트
    └── screenshots/       # 스크린샷 (테스트용)
```

## 코드 컨벤션

- GDScript 스타일 가이드 준수 (Godot 공식)
- 한국어 주석, 한국어 UI
- i18n: 모든 유저 노출 텍스트는 한국어(ko) + 영어(en) 동시 준비
- 씬 이름: snake_case (battle_scene.tscn)
- 스크립트 이름: snake_case (battle_manager.gd)
- 시그널 이름: snake_case (unit_moved, turn_ended)
- 상수: UPPER_SNAKE_CASE
- 클래스: PascalCase

## 스토리 참조

- 전체 스토리: `docs/STORY.md`
- 4막 구조, 플레이어블 12인, 멀티 엔딩 2개
- 3개 러브라인 + 4개 비극 서사

## Steam 연동 (예정)

- GodotSteam 플러그인 사용
- 업적, 클라우드 세이브, 리더보드
- 스토어 페이지 에셋 준비 필요

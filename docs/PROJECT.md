# Ember Throne 기획서

> 최종 업데이트: 2026-04-07

## 프로젝트 개요

정통 판타지 택티컬 RPG. 그리드 기반 턴제 전투, 12인의 고유 캐릭터, 정치극 서사, 멀티 엔딩 구조. Steam PC 타겟.

## 기술 스택

| 항목 | 기술 |
|------|------|
| 엔진 | Godot 4.6.2 (GDScript) |
| 플랫폼 | Steam (Windows / Linux / macOS) |
| 해상도 | 16:9 기본, 울트라와이드 대응 |
| 입력 | 키보드 + 마우스 |
| 아트 스타일 | 도트 스프라이트 (캐릭터 48px, 타일 32px) + SD/PixelLab 파이프라인 |

## 아키텍처

### 디렉토리 구조

```
ember-throne/
├── scenes/          # Godot 씬 (.tscn)
│   ├── battle/      # 전투 씬
│   ├── world/       # 월드맵 씬
│   ├── dialogue/    # 대화 씬
│   ├── ui/          # UI 씬 (상점, 거점)
│   └── main/        # 메인 메뉴
├── scripts/
│   ├── autoload/    # 글로벌 매니저 (EventBus, DataManager, SaveManager 등)
│   ├── battle/      # 전투 로직 (턴, 그리드, 전투 계산, AI, VFX, 경험치)
│   ├── dialogue/    # 대화 시스템
│   ├── story/       # 스토리/전직/유대 시스템
│   ├── systems/     # 파티/인벤토리/장비/난이도 매니저
│   ├── ui/          # UI 로직
│   └── world/       # 월드맵/진행 관리
├── data/
│   ├── characters/  # 캐릭터 스탯/스킬 JSON (12인)
│   ├── enemies/     # 적 유닛 JSON (18종)
│   ├── maps/        # 전투 맵 JSON (35전)
│   └── world/       # 월드맵 노드 JSON
├── assets/
│   ├── sprites/     # 캐릭터 스프라이트 (14종, 8방향)
│   ├── tilesets/    # 맵 타일셋 (6지역 18종)
│   ├── portraits/   # 초상화
│   ├── ui/          # UI 에셋 (9-slice)
│   └── shaders/     # 셰이더
├── docs/            # 기획 문서
└── tests/           # 비주얼 리그레션 테스트
```

### 핵심 모듈

| 모듈 | 파일 | 역할 |
|------|------|------|
| 전투 씬 | `scripts/battle/battle_scene.gd` | 전투 흐름 총괄 |
| 턴 관리 | `scripts/battle/turn_manager.gd` | 플레이어/적 페이즈 전환 |
| 그리드 시스템 | `scripts/battle/grid_system.gd` | 이동/공격 범위 계산 |
| 전투 계산기 | `scripts/battle/combat_calculator.gd` | 데미지/명중/회피 공식 |
| 경험치 시스템 | `scripts/battle/experience_system.gd` | EXP 공식 (level * 100) |
| 스킬 시스템 | `scripts/battle/skill_system.gd` | 스킬 실행/쿨다운 |
| AI 컨트롤러 | `scripts/battle/ai/ai_controller.gd` | 적 AI 의사결정 |
| 승리/패배 조건 | `scripts/battle/victory_condition_checker.gd` | JSON 기반 6종 조건 판별 (rout, escape, survive, unit_death, turn_limit, hp_threshold) |
| 무기 상성 | `scripts/battle/weapon_triangle.gd` | 검>도끼>창>검 삼각 |
| 대화 시스템 | `scripts/dialogue/dialogue_manager.gd` | 스토리 대화 진행 |
| 스토리 매니저 | `scripts/story/story_manager.gd` | 막별 진행/이벤트 |
| 전직 시스템 | `scripts/story/class_change_system.gd` | 스토리 연동 전직 |
| 유대 시스템 | `scripts/story/bond_system.gd` | 캐릭터 유대 관계 |
| 월드맵 | `scripts/world/world_map.gd` | 거점 이동/진행 |
| 세이브 매니저 | `scripts/autoload/save_manager.gd` | 세이브/로드 |
| 데이터 매니저 | `scripts/autoload/data_manager.gd` | JSON 데이터 로딩 |

## 기능 목록

| 기능 | 설명 | 상태 |
|------|------|------|
| 턴제 전투 | 플레이어/적 페이즈 그리드 전투 | 완료 |
| 전투 AI | 6종 AI 패턴 + 보스 AI | 완료 |
| 승리/패배 조건 | 데이터 드리븐 6종 조건 판별 (VictoryConditionChecker), EventBus 연동 | 완료 |
| 전투 UI | HUD, 액션 메뉴, 데미지 프리뷰, 범위 오버레이, 전투 결과 | 완료 |
| 컷인 연출 | 스킬 컷인 오버레이 + VFX | 완료 |
| 경험치/레벨업 | level * 100 공식, 레벨 차이 보정 | 완료 |
| 출격 편성 | 12인 중 8명 선택, 카엘 고정 | 완료 |
| 대화 시스템 | 대화창, 선택지, CG 뷰어 | 완료 |
| 스토리 매니저 | 4막 진행, 이벤트 트리거 | 완료 |
| 전직 시스템 | 스토리 연동 자동 전직 | 완료 |
| 유대 시스템 | 13쌍 유대, 인접 보정, 이벤트 | 완료 |
| 월드맵 | 6지역 30+ 거점, 유랑 전투 해금 | 완료 |
| 상점/거점 | 장비 구매, 대장간 소재 교환 | 완료 |
| 인벤토리/장비 | 소비/무기/방어구/악세서리 관리 | 완료 |
| 난이도 | Normal/Hard 2단계, AI 차이 | 완료 |
| 세이브/로드 | 다중 슬롯, 오토세이브 | 완료 |
| CG 갤러리 | 이벤트 CG 회상 | 완료 |
| 옵션 | 사운드/화면 설정 | 완료 |

## 기획 문서

| 문서 | 설명 |
|------|------|
| [GAME-DESIGN.md](GAME-DESIGN.md) | 게임 디자인 총괄 (문서 맵 포함) |
| [BATTLE-SYSTEM.md](BATTLE-SYSTEM.md) | 전투 시스템 상세 |
| [CHARACTERS.md](CHARACTERS.md) | 12인 캐릭터, 클래스, 스킬 88종 |
| [ENEMIES.md](ENEMIES.md) | 적 유닛 18종, 보스 메카닉, AI 패턴 |
| [ITEMS-EQUIPMENT.md](ITEMS-EQUIPMENT.md) | 아이템/장비 115종 |
| [MAPS.md](MAPS.md) | 35전 맵 디자인, 16종 지형 |
| [DIFFICULTY.md](DIFFICULTY.md) | 난이도 2단계 설계 |
| [UI-FLOW.md](UI-FLOW.md) | UI 플로우 |
| [WORLD-PROGRESSION.md](WORLD-PROGRESSION.md) | 월드맵, 유대, 세이브, CG, BGM/SE |
| [SKILL-ANIMATIONS.md](SKILL-ANIMATIONS.md) | 스킬 연출, 컷인, 이펙트 |
| [STORY.md](STORY.md) | 세계관, 4막 서사, 엔딩 |
| [LEVEL-DESIGN.md](LEVEL-DESIGN.md) | 레벨 밸런스, EXP/골드 흐름, 35전 밸런스 시트 |
| [PORTRAIT-SPEC.md](PORTRAIT-SPEC.md) | 초상화 사양 |
| [SCRIPT-ACT1~4.md](SCRIPT-ACT1.md) | 막별 대본 |

## 알려진 제약사항

- 캐릭터 합류 레벨(`data/characters/*.json`의 `join_level`)이 LEVEL-DESIGN.md 기획값과 5인 불일치 -- 별도 Coder 작업에서 JSON 일괄 갱신 예정
- battle_XX.json의 일부 수치(적 레벨 상한, 난이도 등급)가 기획 문서와 차이 -- LEVEL-DESIGN.md 확정 후 JSON 동기화 예정
- battle_34.json 보스전 페이즈가 2단계로 구현되어 있으나 기획은 3페이즈 -- 추후 구현 필요
- VCC defeat `turn_limit_exceeded` 분기의 null 안전성 미보완 -- 현재 배틀 데이터에 해당 케이스 없으나 별도 작업 필요

## 향후 계획

- 캐릭터 합류 레벨 JSON 일괄 갱신 (LEVEL-DESIGN.md 기준)
- battle_XX.json 밸런스 수치 동기화
- battle_34 3페이즈 보스전 구현
- Steam 연동 (GodotSteam: 업적, 클라우드 세이브)
- 스토어 페이지 에셋 준비

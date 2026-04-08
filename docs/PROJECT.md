# Ember Throne 기획서

> 최종 업데이트: 2026-04-09

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
| 경험치 시스템 | `scripts/battle/experience_system.gd` | EXP 공식 (level * 100), 벤치 EXP 계산 |
| 파티 매니저 | `scripts/systems/party_manager.gd` | 파티 관리, gain_exp/레벨업, EXP 공식 (level * 100) |
| 스킬 시스템 | `scripts/battle/skill_system.gd` | 스킬 실행/쿨다운 |
| 스킬 실행기 | `scripts/battle/skill_executor.gd` | guaranteed_crit 조건 파싱 포함 |
| AI 컨트롤러 | `scripts/battle/ai/ai_controller.gd` | 적 AI 의사결정 |
| 오디오 매니저 | `scripts/autoload/audio_manager.gd` | BGM 별칭 테이블 + SFX 배선 + EventBus 자동 연결 |
| 승리/패배 조건 | `scripts/battle/victory_condition_checker.gd` | JSON 기반 6종 조건 판별 (rout, escape, survive, unit_death, turn_limit, hp_threshold) |
| 무기 상성 | `scripts/battle/weapon_triangle.gd` | 검>도끼>창>검 삼각 |
| 대화 시스템 | `scripts/dialogue/dialogue_manager.gd` | 스토리 대화 진행 |
| 스토리 매니저 | `scripts/story/story_manager.gd` | 막별 진행/이벤트 |
| 전직 시스템 | `scripts/story/class_change_system.gd` | 스토리 연동 전직 |
| 유대 시스템 | `scripts/story/bond_system.gd` | 캐릭터 유대 관계 |
| 월드맵 | `scripts/world/world_map.gd` | 거점 이동/진행 |
| 세이브 매니저 | `scripts/autoload/save_manager.gd` | 세이브/로드 + Steam Cloud 미러링 |
| 데이터 매니저 | `scripts/autoload/data_manager.gd` | JSON 데이터 로딩 |
| Steam 매니저 | `scripts/autoload/steam_manager.gd` | GodotSteam 래퍼 + 업적 15개 + Cloud |
| 튜토리얼 오버레이 | `scripts/battle/tutorial_overlay.gd` | 전투 튜토리얼 4단계 안내 |
| 크레딧 화면 | `scripts/ui/credits_screen.gd` | 엔딩 크레딧 롤 |
| 로딩 화면 | `scripts/ui/loading_screen.gd` | 씬 전환 로딩 + 팁 |

## 기능 목록

| 기능 | 설명 | 상태 |
|------|------|------|
| 턴제 전투 | 플레이어/적 페이즈 그리드 전투 | 완료 |
| 전투 AI | 6종 AI 패턴 + 보스 AI | 완료 |
| 승리/패배 조건 | 데이터 드리븐 6종 조건 판별 (VictoryConditionChecker), EventBus 연동 | 완료 |
| 전투 UI | HUD, 액션 메뉴, 데미지 프리뷰, 범위 오버레이, 전투 결과 | 완료 |
| 컷인 연출 | 스킬 컷인 오버레이 + VFX | 완료 |
| 경험치/레벨업 | level * 100 공식, 레벨 차이 보정, 벤치 유닛 50% EXP | 완료 |
| 골드 경제 | 적 처치 gold_reward + battle rewards.gold 지급, 세이브/로드 연동 | 완료 |
| 출격 편성 | 12인 중 8명 선택, 카엘 고정 | 완료 |
| 대화 시스템 | 대화창, 선택지, CG 뷰어 | 완료 |
| 스토리 매니저 | 4막 진행, 이벤트 트리거, CHARACTER_JOINS LEVEL-DESIGN.md 기준 동기화 완료 | 완료 |
| 전직 시스템 | 스토리 연동 자동 전직 | 완료 |
| 유대 시스템 | 13쌍 유대, 인접 보정, 이벤트 | 완료 |
| 월드맵 | 6지역 30+ 거점, 유랑 전투 해금 | 완료 |
| 상점/거점 | 장비 구매, 대장간 소재 교환 | 완료 |
| 인벤토리/장비 | 소비/무기/방어구/악세서리 관리 | 완료 |
| 난이도 | Normal/Hard 2단계, AI 차이, Hard 적 스케일링(레벨+1, 스탯 배율) | 완료 |
| 클리어 보너스 EXP | 보스/특수 전투 rewards.exp_bonus -> 참전 유닛 flat EXP 지급 | 완료 |
| 세이브/로드 | 다중 슬롯, 오토세이브 | 완료 |
| CG 갤러리 | 이벤트 CG 회상 | 완료 |
| 튜토리얼 | battle_01 4단계 오버레이 + 행동 차단 | 완료 |
| 맵 이벤트 런타임 | wave_spawn/dialogue/terrain_change 3종 트리거 | 완료 |
| 크레딧 롤 | 엔딩 에필로그 후 스크롤 + 스킵 | 완료 |
| 엔딩 CG 연출 | 엔딩 A/B별 에필로그 CG + 텍스트 분기 | 완료 |
| 미니맵 | 전투 HUD 도트맵 (아군 파랑/적 빨강) | 완료 |
| 로딩 화면 | 씬 전환 팁 + 일러스트 | 완료 |
| 턴 순서 바 | SPD 기반 행동 순서 아이콘 | 완료 |
| 대미지 팝업 | 일반/크리티컬/회복/회피 4종 팝업 | 완료 |
| 스탯 비교 | 장비 교체 시 빨강/초록 색상 | 완료 |
| 반격 표시 | can_counter 판정 + 데미지 프리뷰 | 완료 |
| 본드 알림 | 유대 레벨업 배너 (큐 시스템) | 완료 |
| Steam 연동 | GodotSteam 래퍼 + graceful fallback | 완료 |
| 업적 시스템 | 15개 업적 (막 클리어, 엔딩, 풀 파티, CG 등) | 완료 |
| Steam Cloud 세이브 | 로컬-Cloud 미러링 | 완료 |
| 게임패드 지원 | D-pad, Stick, A/B/Start/LB/RB 매핑 | 완료 |
| 키 리바인드 | 옵션에서 키 재설정 + ConfigFile 저장 | 완료 |
| 데모 모드 | DEMO_MODE + 데모 종료 화면 | 완료 |
| BGM 시스템 | 16트랙, 61개 시맨틱 ID → 파일 별칭 매핑, 전투 시 맵 JSON 기반 자동 전환 | 완료 |
| SFX 시스템 | 39종, EventBus 자동 배선 (damage/heal/death/levelup/skill 등 9종) | 완료 |
| 옵션 | 사운드/화면/키 설정 | 완료 |

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
| [STEAM-STORE.md](STEAM-STORE.md) | Steam 스토어 설명 (한/영) |
| `assets/audio/AUDIO-CREDITS.md` | 오디오 라이선스 귀속 표기 |

## 알려진 제약사항

- Steam App ID 480 (Spacewar) 테스트용 -- 실제 ID 발급 후 교체 필요
- Steam Cloud timestamp 비교 미구현 -- 로컬 세이브 존재 시 Cloud 무시 (Phase 6 QA MEDIUM)
- 키 리바인드 중 ESC 캡처 가능 -- 취소 메커니즘 없음 (Phase 6 QA LOW)
- 엔딩 CG 이미지 미존재 (ending_a_cg.png, ending_b_cg.png) -- 자동 스킵 처리
- VCC defeat `turn_limit_exceeded` 분기의 null 안전성 미보완
- 활성 유닛 EXP가 BattleUnit에만 반영되고 PartyManager에 동기화되지 않는 아키텍처 이슈
- `spend_gold()` 음수 amount 미검증 (Phase 2 QA M1)
- `init_default_party()`의 seria/rinen이 CHARACTER_JOINS와 불일치 (Phase 2 QA M2)
- `refresh_minimap()` 매 호출 시 ColorRect 생성/파괴 -- 대규모 맵에서 성능 우려 (Phase 5 QA LOW)

## 향후 계획

- 전 전투 35개 밸런스 플레이테스트 (Phase 7)
- Steam 스토어 페이지 캡슐 아트/트레일러 (Phase 8-1, 8-3)
- 엔딩 CG 이미지 제작
- Steam 실제 App ID 발급 및 교체
- spend_gold() 음수 가드 추가 (상점 구현 시)
- 전투 EXP -> PartyManager 동기화 + 사망 유닛 EXP 정책 확립
- 보너스 EXP 대상 확장 검토

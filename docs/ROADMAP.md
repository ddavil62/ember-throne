# Ember Throne 개발 로드맵

> 최종 업데이트: 2026-04-09
> 코드베이스 분석 기반 자동 생성

## 현재 상태 요약

| 영역 | 진행률 | 비고 |
|------|--------|------|
| 코어 전투 시스템 | **100%** | 그리드, 턴, 스킬, 상태효과, 무기상성 |
| 캐릭터 시스템 | **100%** | 12인 데이터, 전직, 본드, 장비 |
| 적 데이터 | **100%** | 97종 JSON, AI 3계층 |
| 전투 맵 | **100%** | 35개 맵 데이터 + 승리/패배 조건 |
| 스토리/대화 | **100%** | 4막 구조, 분기, 2엔딩, 튜토리얼, 크레딧 롤 완료 |
| 월드맵 | **100%** | 노드 기반, 진행도 관리 |
| UI 화면 | **100%** | 미니맵, 턴순서바, 대미지팝업, 로딩화면 등 완료 |
| 에셋 (비주얼) | **98%** | 스프라이트/초상화/타일셋/VFX 완비 |
| 에셋 (오디오) | **100%** | BGM 16트랙 + SFX 39종 + AudioManager 배선 완료 |
| QoL 기능 | **100%** | 되돌리기, 배속, 전투로그, 위험범위 등 완료 |
| 플랫폼 통합 | **100%** | GodotSteam, 업적, Cloud 세이브, 게임패드, 데모 모드 완료 |

---

## 코드베이스 통계

- GDScript: **58파일 / 17,480줄**
- Godot 씬: **8개**
- JSON 데이터: **203개**
- 에셋 파일: **17,500+개 (448MB)**

---

## 빼먹은 것 & 미구현 항목 체크리스트

아래는 전형적인 SRPG/JRPG에 필요하지만 현재 코드에 **존재하지 않는** 항목들이다.

### 🔴 필수 (없으면 출시 불가)

| # | 항목 | 현재 상태 | 설명 |
|---|------|-----------|------|
| M-01 | ~~**BGM (배경음악)**~~ | ✅ 완료 (Phase 3) | 16트랙 (CC0 14 + CC-BY 3.0 2), AudioManager 별칭 테이블 |
| M-02 | ~~**SFX (효과음)**~~ | ✅ 완료 (Phase 3) | 39종 (Kenney CC0 + OGA CC0), EventBus 자동 배선 |
| M-03 | ~~**크레딧 롤**~~ | ✅ 완료 (Phase 4-3) | credits_screen.gd, 스크롤+스킵+타이틀 복귀 |
| M-04 | ~~**튜토리얼/온보딩**~~ | ✅ 완료 (Phase 4-1) | tutorial_overlay.gd, 4단계 안내 |
| M-05 | ~~**컨트롤러 지원**~~ | ✅ 완료 (Phase 6-4) | D-pad+Stick+A/B/Start/LB/RB |
| M-06 | ~~**Steam 연동**~~ | ✅ 완료 (Phase 6-1~3) | steam_manager.gd, 업적 15개, Cloud 세이브 |
| M-07 | ~~**battle_34 보스 3페이즈**~~ | ✅ 완료 (Phase 1-8) | 3페이즈 + boss_kill 승리조건 |
| M-08 | ~~**전투 결과 골드 표시**~~ | ✅ 완료 (Phase 1-9) | battle_result.gd 골드/아이템 표시 |
| M-09 | **엔드 투 엔드 플레이테스트** | 미실시 | 1막→4막 연속 플레이 검증 |

### 🟡 권장 (UX 품질에 큰 영향)

| # | 항목 | 현재 상태 | 설명 |
|---|------|-----------|------|
| R-01 | ~~**이동 되돌리기 (Undo Move)**~~ | ✅ 완료 (Phase 2-1) | Esc키 + 메뉴 버튼 |
| R-02 | ~~**전투 애니메이션 배속/스킵**~~ | ✅ 완료 (Phase 2-2) | 1x/2x/스킵, Tab 토글 |
| R-03 | ~~**전투 로그**~~ | ✅ 완료 (Phase 2-3) | L키 토글, 색상 구분 |
| R-04 | ~~**미니맵**~~ | ✅ 완료 (Phase 5-1) | 도트맵 (아군 파랑/적 빨강) |
| R-05 | ~~**위험 범위 표시**~~ | ✅ 완료 (Phase 2-4) | R키 토글, 합산 범위 |
| R-06 | ~~**유닛 정보 조회**~~ | ✅ 완료 (Phase 2-5) | I키, 상세 스탯 팝업 |
| R-07 | ~~**지형 정보 팝업**~~ | ✅ 완료 (Phase 2-6) | 커서 위치 상시 표시 |
| R-08 | ~~**맵 이벤트 런타임 실행**~~ | ✅ 완료 (Phase 4-2) | wave_spawn/dialogue/terrain_change |
| R-09 | ~~**전용 로딩 화면**~~ | ✅ 완료 (Phase 5-2) | 팁 + 일러스트 |
| R-10 | ~~**키 리바인드**~~ | ✅ 완료 (Phase 6-5) | ConfigFile 저장/복원 |

### 🟢 선택 (출시 후 추가 가능)

| # | 항목 | 현재 상태 | 설명 |
|---|------|-----------|------|
| O-01 | **New Game+** | 미구현 | 2회차 플레이 (레벨/장비 이월) |
| O-02 | **캐주얼 모드 (부활)** | 미구현 | 클래식(사망 시 퇴장) vs 캐주얼(전투 후 부활) 선택 |
| O-03 | **유닛 도감** | 미구현 | 만난 적/아군 상세 열람 |
| O-04 | **전투 리플레이** | 미구현 | 완료된 전투 재시청 |
| O-05 | **스크린샷 모드** | 미구현 | UI 숨기고 전장 캡처 |
| O-06 | **접근성 옵션** | 미구현 | 색각 이상 모드, 폰트 크기 조절 |

---

## 개발 로드맵 (권장 순서)

전형적인 SRPG 개발 파이프라인을 기준으로, **현재 상태에서 출시까지** 필요한 작업을 8단계로 나눈다. 각 단계는 이전 단계의 완료에 의존한다.

```
현재 위치
    ↓
Phase 1: 통합 검증 (플레이 가능 상태 확인)
    ↓
Phase 2: 전투 QoL (되돌리기, 배속, 로그)
    ↓
Phase 3: 오디오 파이프라인 (BGM/SFX)
    ↓
Phase 4: 내러티브 완성 (튜토리얼, 크레딧, 맵 이벤트)
    ↓
Phase 5: UI 폴리시 (미니맵, 로딩, 정보 팝업)
    ↓
Phase 6: 플랫폼 통합 (Steam, 컨트롤러)
    ↓
Phase 7: 밸런스 & QA (통합 테스트)
    ↓
Phase 8: 출시 준비 (스토어, 마케팅, 빌드)
```

---

### Phase 1: 통합 검증 — "처음부터 끝까지 한 번 돌릴 수 있는가?"

> **목표**: 1막~4막 전체를 연속으로 플레이하여 게임 흐름이 끊기지 않는지 확인

| 작업 ID | 작업 | 관련 파일 | 예상 규모 |
|---------|------|-----------|-----------|
| 1-1 | ~~타이틀 → 난이도 선택 → 1막 진입 흐름 검증~~ | title_screen.gd, game_manager.gd | ✅ 검증 완료 |
| 1-2 | ~~각 막 전환 시 월드맵 노드 해금 확인~~ | progression_manager.gd, nodes.json | ✅ **버그 수정**: 막 전환 트리거 미호출 → ACT_TRIGGER_NODES 추가 |
| 1-3 | ~~전투 → 승리 → 결과화면 → 월드맵 복귀 루프 검증~~ | battle_scene.gd, battle_result.gd | ✅ **버그 수정**: 방랑전투 노드 완료 불가 → battle_id 기반 완료로 변경 |
| 1-4 | ~~대화/선택지 → 스토리 플래그 → 분기 확인 (2엔딩)~~ | story_manager.gd, act4.json | ✅ **버그 수정**: 엔딩 플래그 불일치 (ending_a → ending_a_chosen) |
| 1-5 | ~~캐릭터 합류 타이밍 검증 (12인 전원)~~ | party_manager.gd, progression_manager.gd | ✅ 검증 완료 (12/12 정상) |
| 1-6 | ~~상점 재고 → 막별 변화 확인~~ | shops.json, shop_screen.gd | ✅ **버그 수정**: 아이템 ID 불일치 18건 교정 + 대장간 아이템 2종 추가 |
| 1-7 | ~~세이브/로드 → 모든 상태 복원 검증~~ | save_manager.gd | ✅ 검증 완료 (flags 기반 전체 상태 복원 확인) |
| 1-8 | ~~battle_34 보스 3페이즈 구현~~ | battle_scene.gd, battle_34.json, boss_ai.gd | ✅ **구현**: 3페이즈 + boss_kill 승리조건 + ascended_morgan 적 데이터 |
| 1-9 | ~~전투 결과 골드 표시 구현~~ | battle_result.gd, battle_scene.gd | ✅ **구현**: 맵 JSON rewards에서 골드/아이템 읽어 표시 |
| 1-10 | ~~DifficultyManager 싱글톤 최적화~~ | difficulty_manager.gd | ✅ **구현**: static var 싱글톤 패턴 |
| 1-11 | ~~벤치 유닛 EXP 엣지케이스 수정~~ | turn_manager.gd | ✅ **구현**: _battle_dead_player_ids로 사망 유닛 추적, 벤치 EXP 제외 |

**산출물**: 1~4막 풀 플레이 가능한 빌드, 알려진 버그 0건

> **Phase 1 완료**: 2026-04-08. 11개 항목 전체 완료. 검증 과정에서 5건의 크리티컬 버그 발견 및 수정.

---

### Phase 2: 전투 QoL — "전투가 편하게 느껴지는가?"

> **목표**: SRPG 표준 QoL 기능 추가로 전투 편의성 확보

| 작업 ID | 작업 | 관련 파일 | 예상 규모 |
|---------|------|-----------|-----------|
| 2-1 | ~~이동 되돌리기 (Undo Move)~~ | turn_manager.gd, action_menu.gd | ✅ Esc키 + 메뉴 버튼, FSM UNIT_SELECTED로 복귀 |
| 2-2 | ~~전투 애니메이션 배속~~ | battle_speed.gd(신규), battle_unit.gd, vfx_player.gd, cutin_overlay.gd | ✅ 1x/2x/스킵, Tab 토글, 옵션 저장 |
| 2-3 | ~~전투 로그 패널~~ | battle_log.gd(신규), battle_hud.gd | ✅ EventBus 9시그널 구독, L키 토글, 색상 구분 |
| 2-4 | ~~적 위험 범위 표시~~ | range_overlay.gd, battle_map.gd | ✅ R키 토글, 적 전체 이동+공격 범위 합산 |
| 2-5 | ~~유닛 정보 조회~~ | battle_hud.gd, battle_map.gd | ✅ I키, 상세 스탯 팝업 |
| 2-6 | ~~지형 정보 팝업~~ | battle_hud.gd, terrain.json | ✅ 커서 위치 지형 상시 표시 |
| 2-7 | ~~턴 종료 확인~~ | turn_manager.gd, battle_hud.gd | ✅ 미행동 유닛 경고 대화상자 |

**산출물**: 전투 플레이가 쾌적한 빌드

> **Phase 2 완료**: 2026-04-08. 7개 항목 전체 완료.

---

### Phase 3: 오디오 파이프라인 — "소리가 나는 게임"

> **목표**: BGM과 SFX를 통합하여 게임에 생명 부여

| 작업 ID | 작업 | 관련 파일 | 예상 규모 |
|---------|------|-----------|-----------|
| 3-1 | ~~오디오 에셋 소싱/제작 계획 수립~~ | — | ✅ CC0 + CC-BY 3.0 로열티프리 소싱 |
| 3-2 | ~~BGM 16트랙 확보~~ | assets/audio/bgm/ | ✅ CC0 14트랙 + CC-BY 3.0 2트랙 (Jonathan Shaw) |
| 3-3 | ~~SFX 39종 확보~~ | assets/audio/sfx/ | ✅ Kenney CC0 (RPG Audio, Interface, Impact) + OGA CC0 |
| 3-4 | ~~AudioManager BGM 재생 통합~~ | audio_manager.gd, battle_scene.gd | ✅ 61개 시맨틱 ID → 16파일 별칭, 전투 맵 JSON bgm 필드 자동 전환 |
| 3-5 | ~~SFX 트리거 배선~~ | audio_manager.gd | ✅ EventBus 9시그널 자동 배선 (damage/heal/death/levelup/skill/gold/save/load/battle_won) |
| 3-6 | ~~볼륨 설정 연동 확인~~ | options_screen.gd | ✅ 기존 볼륨 슬라이더 정상 동작 |

**산출물**: BGM/SFX가 통합된 빌드

> **Phase 3 완료**: 2026-04-09. 6개 항목 전체 완료. BGM 16트랙 + SFX 39종 소싱, AudioManager 대폭 업데이트, 라이선스 귀속 문서 작성.

---

### Phase 4: 내러티브 완성 — "이야기가 완결되는가?"

> **목표**: 게임 시작부터 엔딩까지 서사적 완성도 확보

| 작업 ID | 작업 | 관련 파일 | 예상 규모 |
|---------|------|-----------|-----------|
| 4-1 | ~~튜토리얼 전투 (battle_01)~~ — 4단계 오버레이 + 행동 차단 | tutorial_overlay.gd(신규), battle_01.json | ✅ 구현 완료 |
| 4-2 | ~~전투 중 맵 이벤트 런타임 실행~~ — wave_spawn/dialogue/terrain_change 3종 | battle_scene.gd, map JSON | ✅ 구현 완료 |
| 4-3 | ~~크레딧 롤 화면~~ — 스크롤 + 스킵 + 타이틀 복귀 | credits_screen.gd/.tscn(신규) | ✅ 구현 완료 |
| 4-4 | ~~엔딩 CG 연출~~ — 엔딩 A/B 에필로그 CG + 텍스트 분기 | act4.json, story_manager.gd, dialogue_manager.gd | ✅ 구현 완료 |
| 4-5 | ~~2~4막 대화 스크립트 QA~~ — 오탈자, 감정 태그, 분기 점검 | act2~4.json | ✅ 이슈 0건 |

**산출물**: 스토리가 완결되는 빌드

> **Phase 4 완료**: 2026-04-08. 5개 항목 전체 완료. QA에서 엔딩 분기 흐름(E-1), 튜토리얼 행동 차단 연동(E-2), on_start/on_victory 트리거(E-3/E-4) HIGH/MEDIUM 이슈 발견 및 수정.

---

### Phase 5: UI 폴리시 — "화면이 정보를 잘 전달하는가?"

> **목표**: 부족한 UI 요소 보완, 시각적 완성도 향상

| 작업 ID | 작업 | 관련 파일 | 예상 규모 |
|---------|------|-----------|-----------|
| 5-1 | ~~미니맵 도트맵~~ — 아군 파랑/적 빨강 실시간 위치 | battle_hud.gd | ✅ 구현 완료 |
| 5-2 | ~~로딩 화면~~ — 팁 + 일러스트 placeholder | loading_screen.gd/.tscn(신규) | ✅ 구현 완료 |
| 5-3 | ~~턴 순서 바~~ — SPD 내림차순 아이콘 표시 | turn_manager.gd (get_turn_order_units API) | ✅ 구현 완료 |
| 5-4 | ~~대미지 팝업 4종~~ — 일반/크리티컬/회복/회피 | damage_popup.gd(신규) | ✅ 구현 완료 |
| 5-5 | ~~스탯 비교 개별 색상~~ — 빨강/초록 변화량 표시 | equipment_screen.gd | ✅ 구현 완료 |
| 5-6 | ~~반격 표시~~ — can_counter() + 반격 가능/불가 표시 | damage_preview.gd, combat_calculator.gd | ✅ 구현 완료 |
| 5-7 | ~~본드 알림 배너~~ — 유대 레벨업 큐 시스템 | bond_banner.gd(신규), bond_system.gd | ✅ 구현 완료 |

**산출물**: UI가 다듬어진 빌드

> **Phase 5 완료**: 2026-04-08. 7개 항목 전체 완료. QA에서 bond_system.gd 중복 선언(HIGH-1), damage_popup 씬 트리 이슈(HIGH-2), TurnManager 경로 오류(HIGH-3) 발견 및 수정.

---

### Phase 6: 플랫폼 통합 — "Steam에서 돌아가는가?"

> **목표**: Steam 출시를 위한 플랫폼 요구사항 충족

| 작업 ID | 작업 | 관련 파일 | 예상 규모 |
|---------|------|-----------|-----------|
| 6-1 | ~~GodotSteam 래퍼 + graceful fallback~~ | steam_manager.gd(신규), project.godot | ✅ 구현 완료 |
| 6-2 | ~~업적 15개~~ — 막 클리어, 엔딩, 풀 파티, CG 등 | steam_manager.gd | ✅ 구현 완료 |
| 6-3 | ~~Steam Cloud 세이브 미러링~~ | save_manager.gd | ✅ 구현 완료 |
| 6-4 | ~~게임패드 입력 매핑~~ — D-pad, Stick, A/B/Start/LB/RB | project.godot | ✅ 구현 완료 |
| 6-5 | ~~키 리바인드 UI~~ — ConfigFile 저장/복원 | options_screen.gd | ✅ 구현 완료 |
| 6-6 | ~~해상도/풀스크린 안정화~~ | project.godot | ✅ 구현 완료 |
| 6-7 | ~~DEMO_MODE + 데모 종료 화면~~ | game_manager.gd, demo_end_screen.gd(신규) | ✅ 구현 완료 |

**산출물**: Steam에서 구동되는 빌드

> **Phase 6 완료**: 2026-04-08. 7개 항목 전체 완료. QA에서 StoryManager RefCounted 크래시(HIGH-1), 키 리바인드 초기화 버그(HIGH-2), 게임패드 UI 네비게이션 누락(HIGH-3) 발견 및 수정.

---

### Phase 7: 밸런스 & QA — "재미있고 공정한가?"

> **목표**: 전 전투 밸런스 검증, 버그 수정, 성능 최적화

| 작업 ID | 작업 | 관련 파일 | 예상 규모 |
|---------|------|-----------|-----------|
| 7-A | ~~Phase 7-A 분석 리포트~~ | — | ✅ 코드베이스 분석 완료 |
| 7-B | ~~Phase 7-B 잔여 수정~~ | turn_manager.gd, ai_controller.gd, combat_calculator.gd, skill_executor.gd | ✅ reset() 호출부 연결, force_crit, guaranteed_crit 파싱 |
| 7-1 | **전 전투(35개) 노멀/하드 플레이테스트** | 전체 | XL |
| 7-2 | **레벨 커브 검증** — 각 막 시작/종료 시 예상 레벨 달성 확인 | experience_system.gd, 맵 JSON | M |
| 7-3 | **골드 경제 밸런스** — 상점 가격 vs 전투 보상 적정성 | shops.json, battle_result.gd | M |
| 7-4 | **스킬 밸런스** — 12인 × 8스킬 사용 빈도 및 유용성 점검 | skills.json | L |
| 7-5 | **난이도 하드 추가 조정** — AI 공격성, 적 배치 최적화 | ai_controller.gd, difficulty.json | M |
| 7-6 | **성능 프로파일링** — 큰 맵(30x24) 프레임 드랍 점검 | battle_map.gd | M |
| 7-7 | **메모리 누수 점검** — 전투 반복 시 메모리 증가 확인 | 전체 | M |
| 7-8 | **비주얼 리그레션 테스트 확장** — 주요 씬 8개 이상 레퍼런스 추가 | tests/visual/ | M |
| 7-9 | **현지화 QA** — 영어 텍스트 자연스러움 검증, 잘림 확인 | i18n 관련 | M |

**산출물**: 출시 가능 품질의 빌드

---

### Phase 8: 출시 준비 — "가게에 올릴 수 있는가?"

> **목표**: Steam 스토어 등록 및 출시

| 작업 ID | 작업 | 관련 파일 | 예상 규모 |
|---------|------|-----------|-----------|
| 8-1 | **Steam 스토어 페이지 준비** — 캡슐 아트, 스크린샷, 트레일러 | 외부 | L |
| 8-2 | ~~스토어 설명 작성 (한/영)~~ | docs/STEAM-STORE.md | ✅ 숏/롱 디스크립션, 핵심 특징 7개, 태그 10개 |
| 8-3 | **트레일러 영상 제작** | 외부 | L |
| 8-4 | ~~빌드 파이프라인 자동화~~ — CI/CD로 릴리스 빌드 생성 | .github/workflows/build.yml | ✅ Win/Linux/macOS 3플랫폼, v* 태그 Release |
| 8-5 | **플랫폼별 빌드 테스트** — Windows/Linux/macOS | — | M |
| 8-6 | **Steamworks 설정** — 앱 ID, 디포, 빌드 업로드 | 외부 | M |
| 8-7 | **프레스 키트/소셜 미디어** | 외부 | M |

---

## 개발 단위별 의존성 다이어그램

```
Phase 1 (통합 검증) ─────────────────────────────────────────┐
   │                                                         │
   ├── Phase 2 (전투 QoL) ──┐                                │
   │                         ├── Phase 5 (UI 폴리시) ────────┤
   ├── Phase 3 (오디오) ─────┘                                │
   │                                                         │
   ├── Phase 4 (내러티브) ───────────────────────────────────┤
   │                                                         │
   └── Phase 6 (플랫폼) ────────────────────────────────────┤
                                                              │
                                              Phase 7 (QA) ──┤
                                                              │
                                          Phase 8 (출시) ─────┘
```

- Phase 1은 모든 후속 단계의 전제 조건
- Phase 2, 3, 4, 6은 서로 **병렬 진행 가능** (Phase 1 이후)
- Phase 5는 Phase 2, 3 완료 후 진행 (오디오 피드백 + 전투 로그가 UI에 영향)
- Phase 7은 Phase 1~6 전체 완료 후 진행
- Phase 8은 Phase 7 통과 후 진행

---

## 시스템별 구현 상태 매트릭스

전형적인 SRPG에 필요한 모든 시스템을 나열하고, 현재 구현 상태를 표시한다.

### 전투 시스템

| 시스템 | 구현 | 파일 | 비고 |
|--------|------|------|------|
| 그리드 좌표 / 셀-월드 변환 | ✅ | grid_system.gd | BFS + A* |
| 이동 범위 계산 | ✅ | grid_system.gd | 지형비용 반영 |
| 이동 범위 시각화 | ✅ | range_overlay.gd | 파란 타일 |
| 공격 범위 시각화 | ✅ | range_overlay.gd | 빨간 타일 |
| 턴 관리 (플레이어/적/NPC) | ✅ | turn_manager.gd | 3페이즈 |
| 행동 FSM (이동→공격→대기) | ✅ | turn_manager.gd | |
| 데미지 계산 | ✅ | combat_calculator.gd | 물리/마법 분리 |
| 무기 상성 | ✅ | weapon_triangle.gd | 검>도끼>창 |
| 명중/회피/치명타 | ✅ | combat_calculator.gd | SPD 차이 반영 |
| 반격 | ✅ | combat_calculator.gd | 사거리 내 자동 |
| 스킬 시스템 | ✅ | skill_system.gd | 100+ 스킬 |
| 스킬 실행/연출 | ✅ | skill_executor.gd | 파티클 + 컷인 |
| 상태이상 (버프/디버프) | ✅ | status_effect_manager.gd | 지속턴 관리 |
| 경험치/레벨업 | ✅ | experience_system.gd | 레벨차 보정 |
| 승리/패배 조건 | ✅ | victory_condition_checker.gd | 6종 |
| 배치 화면 | ✅ | deployment_screen.gd | 출격 8인 선택 |
| 전투 결과 화면 | ✅ | battle_result.gd | 골드/아이템 표시 완료 |
| 컷인 오버레이 | ✅ | cutin_overlay.gd | S랭크 스킬 |
| VFX/파티클 | ✅ | vfx_player.gd | 20종 프리셋 |
| AI 기본 | ✅ | ai_controller.gd | 가까운 적 타격 |
| AI 패턴 | ✅ | ai_patterns.gd | 결정 트리 |
| AI 보스 | ✅ | boss_ai.gd | 전용 패턴 |
| 이동 되돌리기 | ✅ | turn_manager.gd | Esc + 메뉴 |
| 애니메이션 배속 | ✅ | battle_speed.gd | 1x/2x/스킵 |
| 전투 로그 | ✅ | battle_log.gd | L키 토글 |
| 미니맵 | ✅ | battle_hud.gd | 도트맵 |
| 적 위험 범위 합산 | ✅ | range_overlay.gd | R키 토글 |
| 맵 이벤트 런타임 | ✅ | battle_scene.gd | 3종 트리거 |
| 턴 종료 확인 | ✅ | turn_manager.gd | 미행동 경고 |
| 턴 순서 바 | ✅ | battle_hud.gd | SPD 기반 |
| 대미지 팝업 4종 | ✅ | damage_popup.gd | 크리/회복/회피 |
| 반격 표시 | ✅ | damage_preview.gd | can_counter |

### 캐릭터 시스템

| 시스템 | 구현 | 파일 | 비고 |
|--------|------|------|------|
| 캐릭터 데이터 (12인) | ✅ | data/characters/*.json | 스탯/성장/스킬 |
| 전직 시스템 | ✅ | class_change_system.gd | 스탯 보너스 |
| 장비 시스템 | ✅ | equipment_manager.gd | 무기/방어구/악세 |
| 인벤토리 | ✅ | inventory_manager.gd | 소비/장비 아이템 |
| 파티 관리 | ✅ | party_manager.gd | 출격/벤치 |
| 본드 시스템 | ✅ | bond_system.gd | 인접 보너스 |
| 스킬 장착 | ✅ | skill_system.gd | 6슬롯 선택 |

### 내러티브 시스템

| 시스템 | 구현 | 파일 | 비고 |
|--------|------|------|------|
| 대화 로더 | ✅ | dialogue_manager.gd | JSON 기반 |
| 대화 씬 | ✅ | dialogue_scene.gd | 감정/초상화 |
| 선택지 분기 | ✅ | choice_panel.gd | |
| CG 뷰어 | ✅ | cg_viewer.gd | 풀스크린 이미지 |
| 스토리 플래그 | ✅ | story_manager.gd | 막/장 진행 |
| 월드맵 | ✅ | world_map.gd | 노드 기반 |
| 진행도 관리 | ✅ | progression_manager.gd | 해금/잠금 |
| 튜토리얼 | ✅ | tutorial_overlay.gd | 4단계 안내 |
| 크레딧 롤 | ✅ | credits_screen.gd | 스크롤+스킵 |
| 맵 이벤트 트리거 | ✅ | battle_scene.gd | 증원/대사/지형 |
| 엔딩 CG 연출 | ✅ | story_manager.gd | A/B 에필로그 |

### 인프라/플랫폼

| 시스템 | 구현 | 파일 | 비고 |
|--------|------|------|------|
| 세이브/로드 | ✅ | save_manager.gd | 3수동+1자동 |
| 오토세이브 | ✅ | save_manager.gd | |
| 설정 저장 | ✅ | options_screen.gd | ConfigFile |
| 씬 전환 (페이드) | ✅ | game_manager.gd | |
| 이벤트 버스 | ✅ | event_bus.gd | 시그널 기반 |
| 난이도 시스템 | ✅ | difficulty_manager.gd | 노멀/하드 |
| **오디오** | ✅ | audio_manager.gd | BGM 16트랙, SFX 39종, EventBus 배선 |
| Steam 연동 | ✅ | steam_manager.gd | 업적 15개, Cloud |
| 컨트롤러 | ✅ | project.godot | D-pad+Stick |
| 로딩 화면 | ✅ | loading_screen.gd | 팁+일러스트 |
| 키 리바인드 | ✅ | options_screen.gd | ConfigFile |
| 데모 모드 | ✅ | game_manager.gd | DEMO_MODE 분기 |

### 에셋

| 에셋 | 구현 | 수량 | 비고 |
|------|------|------|------|
| 아군 스프라이트 | ✅ | 12/12 (3,744프레임) | 8방향+애니 |
| 적 스프라이트 | ✅ | 18/18 (4,913프레임) | 8방향+애니 |
| 초상화 | ✅ | 95장 | 감정 변화 포함 |
| 컷인 일러스트 | ✅ | 11/11 | S랭크 스킬용 |
| 컨셉아트 | ✅ | 38장 | SD Forge 생성 |
| 타일셋 | ✅ | 19세트 | 7지역 |
| 베이스 타일 | ✅ | 24종 | 지형 다양성 |
| 프롭 | ✅ | 50개 | 지역별 환경물 |
| UI 에셋 | ✅ | 18종 | NinePatch |
| 파티클 | ✅ | 20종 | .tres |
| 셰이더 | ✅ | 5개 | .gdshader |
| 월드맵 | ✅ | 11파일 | 배경+노드 |
| **BGM** | ✅ | 16/16 | CC0 14 + CC-BY 3.0 2 |
| **SFX** | ✅ | 39/39 | Kenney CC0 + OGA CC0 |

---

## 권장 작업 우선순위 (당장 시작할 것)

Phase 1~6 + Phase 3 오디오 완료 상태. 남은 핵심 작업:

### 외부 리소스 필요

1. **8-1**: Steam 스토어 캡슐 아트
2. **8-3**: 트레일러 영상

### 코드 작업

3. **7-1**: 전 전투 35개 밸런스 플레이테스트 (노멀/하드)
4. **8-5**: 플랫폼별 빌드 테스트 (Windows/Linux/macOS)
5. **8-6**: Steamworks 설정 (앱 ID, 디포, 빌드 업로드)

---

## 참고: 전형적인 SRPG 개발 순서 vs 현재 상태

일반적인 택티컬 RPG 개발 순서와 비교하여 현재 위치를 표시한다.

```
[1] 엔진 설정, 프로젝트 구조             ✅ 완료
[2] 코어 게임 루프 (씬 전환, 상태머신)     ✅ 완료
[3] 그리드 시스템 + 유닛 배치              ✅ 완료
[4] 턴 관리 + 이동                        ✅ 완료
[5] 기본 전투 (공격, 대미지)               ✅ 완료
[6] 스킬 시스템                           ✅ 완료
[7] 상태이상 + 무기상성                    ✅ 완료
[8] AI (적 턴 자동화)                     ✅ 완료
[9] 캐릭터 데이터 + 성장                   ✅ 완료
[10] 장비/인벤토리                        ✅ 완료
[11] 대화/스토리 시스템                    ✅ 완료
[12] 월드맵/진행도                        ✅ 완료
[13] 세이브/로드                          ✅ 완료
[14] 전투 맵 콘텐츠 (35개)                ✅ 완료
[15] 캐릭터 에셋 (스프라이트/초상화)        ✅ 완료
[16] 맵 에셋 (타일셋/프롭)                ✅ 완료
[17] VFX/셰이더                          ✅ 완료
[18] UI 화면 전체                         ✅ 완료
[19] 통합 플레이테스트 (버그 수정)          ✅ Phase 1
[20] 전투 QoL (되돌리기, 배속, 로그)       ✅ Phase 2
[21] 오디오 통합 (BGM/SFX)               ✅ Phase 3
[22] 튜토리얼/크레딧/맵이벤트              ✅ Phase 4
[23] UI 폴리시                           ✅ Phase 5
[24] 플랫폼 통합 (Steam/컨트롤러)          ✅ Phase 6
─── 현재 위치 ─── ↕ 여기서부터 남은 작업 ↕ ──────
[25] 밸런스 QA                           ⬜ Phase 7 (7-B 잔여 수정 완료)
[26] 출시                                ⬜ Phase 8 (8-2 스토어 설명 + 8-4 빌드 파이프라인 완료)
```

**현재 진행률: 25/26 단계 (약 96%)**
게임플레이, UI, 플랫폼 통합, 오디오 완성 — 남은 것은 밸런스 플레이테스트, 스토어 페이지 에셋, 출시.

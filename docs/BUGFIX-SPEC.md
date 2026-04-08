# Ember Throne 잔여 버그 수정 스펙

> 작성일: 2026-04-09
> 우선순위: HIGH → MEDIUM → LOW 순서로 처리
> 출처: Purposer 최종 검증 결과 (세션 2026-04-09)
> 다음 세션에서 이 파일을 coder 에이전트에 전달해서 작업 시작할 것

---

## 배경

Phase 3/7-B/8-4 완료 후 Purposer PARTIAL 판정.
플레이테스트 전 수정 필요한 버그 총 5건 (HIGH 2, MEDIUM 2, LOW 2).
MEDIUM-2(Steam App ID)만 사용자 직접 수행 필요, 나머지는 Claude 자동 처리 가능.

---

## HIGH-1: EXP 동기화 버그

### 현상
전투 중 유닛 EXP가 `BattleUnit` 인스턴스에만 반영되고
`PartyManager` 영구 파티 데이터에 동기화되지 않는다.
전투 종료 후 세이브 → 로드 시 전투에서 올린 레벨이 초기화됨.

### 관련 파일
- `scripts/battle/experience_system.gd`
- `scripts/battle/battle_scene.gd`
- `scripts/data/party_manager.gd`

### 수정 방향
전투 종료 시점(`_on_result_confirmed()` 또는 `battle_won` 시그널)에서
`PartyManager`로 각 유닛의 최종 레벨/EXP를 동기화하는 코드 추가.
`BattleUnit.unit_id` → `PartyManager` 캐릭터 찾기 → `current_level`, `current_exp` 덮어쓰기.

### 완료 기준
- `battle_scene.gd` 또는 `experience_system.gd`에 PartyManager 동기화 호출 존재
- 전투 후 세이브/로드해도 레벨 유지됨

---

## HIGH-2: init_default_party() 파티 구성 불일치

### 현상
`PartyManager.init_default_party()`에 seria, rinen이 초기 파티 멤버로 포함되어 있으나
스토리 `CHARACTER_JOINS` 합류 타이밍과 불일치.
타이틀 없이 battle_01 직접 진입 시 잘못된 캐릭터 배치 가능.

### 관련 파일
- `scripts/data/party_manager.gd` — `init_default_party()` 메서드
- `scripts/story/story_manager.gd` 또는 `scripts/world/progression_manager.gd` — `CHARACTER_JOINS` 상수

### 수정 방향
`CHARACTER_JOINS` 기준 1막 시작 시점 합류 캐릭터만 `init_default_party()`에 포함.
seria, rinen이 1막 이후 합류라면 초기 파티에서 제거.

### 완료 기준
- `init_default_party()` 구성이 `CHARACTER_JOINS` 1막 초기 멤버와 일치
- battle_01 직접 진입 시 올바른 캐릭터 배치

---

## MEDIUM-1: 엔딩 CG 플레이스홀더 이미지 생성

### 현상
`ending_a_cg.png`, `ending_b_cg.png` 미존재로 엔딩 CG 씬 공백 스킵.
게임 감정적 클라이맥스가 비어 있음.

### 수정 방향
1. 코드에서 엔딩 CG 파일 경로 확인 (정확한 파일명 및 저장 위치)
2. SD Forge API (`http://192.168.219.100:7860`, SDXL Base 1.0)로 플레이스홀더 생성
   - 엔딩 A (리넨 희생): `fantasy SRPG game CG, two characters farewell, sacrifice, twilight, emotional, 1024x576`
   - 엔딩 B (기억 상실): `fantasy SRPG game CG, character new journey, dawn light, hopeful, bittersweet, 1024x576`
3. 서버 꺼져 있으면 단색(검정) PNG 플레이스홀더로 대체
4. 코드가 기대하는 경로에 저장, visual_change: art → Art Director 모드2 검수 필요

### 완료 기준
- 엔딩 A/B 씬 진행 시 CG 이미지가 표시됨 (공백 없음)

---

## MEDIUM-2: Steam App ID 교체 (사용자 직접 수행)

**Claude 자동 수정 불가.**

Steamworks 파트너 등록($100) 완료 후:
1. `steam_manager.gd` 또는 `project.godot`에서 App ID `480` → 실제 발급 ID로 교체
2. 프로젝트 루트 `steam_appid.txt` 파일도 동일하게 교체
3. Steam 클라이언트 실행 중 테스트하여 앱 인식 확인

---

## LOW-1: turn_limit_exceeded 패배 분기 null 안전성

### 현상
전투 패배 조건 `turn_limit_exceeded` 처리 분기에 null 체크 누락.
특정 유닛 상태 조합에서 런타임 오류 가능성.

### 관련 파일
- `scripts/battle/turn_manager.gd` 또는 `scripts/battle/battle_condition_checker.gd`

### 수정 방향
`turn_limit_exceeded` 처리 코드 탐색 → null 가능 변수에 null 가드 추가
(`if x == null: return` 또는 GDScript `?.` 연산자 활용).

### 완료 기준
- turn_limit_exceeded 패배 시 런타임 오류 없이 결과 화면 정상 전환

---

## LOW-2: refresh_minimap() 성능 패치

### 현상
`battle_hud.gd`의 `refresh_minimap()`이 매 호출마다 전체 ColorRect 삭제/재생성.
30×24 대형 맵(720셀)에서 매 유닛 이동 시 불필요한 노드 생성/파괴 반복.

### 관련 파일
- `scripts/battle/ui/battle_hud.gd` — `refresh_minimap()` 메서드

### 수정 방향
ColorRect 풀링 (최초 1회 생성, 이후 위치/색상만 갱신) 또는
`_minimap_dirty` 플래그로 변경분만 업데이트.

### 완료 기준
- `refresh_minimap()` 내부에서 기존 ColorRect 재사용
- 30×24 맵 유닛 이동 시 노드 재생성 횟수 감소

---

## 실행 순서

```
[Claude 자동]
HIGH-1 EXP 동기화
HIGH-2 init_default_party 교정
    ↓ 동시 실행 가능
MEDIUM-1 엔딩 CG 생성 (SD Forge + Art Director 모드2)
LOW-1 null 안전성
LOW-2 minimap 성능
    ↓
커밋 + 푸시
    ↓
Purposer 최종 검증
    ↓
[사용자]
MEDIUM-2 Steam App ID 교체
7-C 플레이테스트 실시
```

---

## 다음 세션 시작 시 전달 컨텍스트

- **스펙 파일**: `C:/antigravity/ember-throne/docs/BUGFIX-SPEC.md` (이 파일)
- **리포트 저장 경로**: `C:/antigravity/.claude/specs/2026-04-09-ember-throne-bugfix-report.md`
- **프로젝트 경로**: `C:/antigravity/ember-throne/`
- **현재 브랜치**: `main` (최신 커밋 60d0cad)
- **visual_change**: `none` (MEDIUM-1만 `art`, Art Director 모드2 필요)
- **pipeline**: `quick` (단일 버그 수정들, Planner 생략 가능)

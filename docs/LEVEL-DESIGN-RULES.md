# Ember Throne 레벨 디자인 금지 규칙

> 레벨 디자이너 에이전트 전용. 과거 실수를 재발하지 않기 위한 규칙 목록.
> 새로운 실수가 발생할 때마다 이 파일에 추가한다.

---

## ⛔ 절대 금지 사항

### 기존 JSON 수정 시

| 금지 행위 | 이유 | 대안 |
|-----------|------|------|
| 기존 `battle_type` 변경 | `rout`는 35전 중 18개가 사용하는 유효한 타입. 임의 변경 시 승리 조건 로직 깨짐 | MAPS.md 재확인 후 명백한 오기일 때만 변경 (리포트에 근거 명시) |

### Prop / 오브젝트 배치

| 금지 행위 | 이유 | 대안 |
|-----------|------|------|
| `bridge_intact` / `bridge_broken`을 물 없는 맵에 배치 | 물 지형 없는 맵에 다리는 논리적으로 불가 | MAPS.md에서 "다리", "물 지형", "crossing" 키워드 확인 후에만 배치 |
| `iron_gate`를 맵 내부에 3개 이상 배치 | ascalon 성문은 통로 역할, 내부 남용 시 이동 경로 차단 | ascalon 계열 틸셋에서 맵 가장자리(외벽) 최대 2개 |
| `ward_stone_active`를 MAPS.md 근거 없이 배치 | 결계석 수집은 스토리 이벤트, 임의 배치 시 서사 흐름 파괴 | battle_09, 16, 21, 27 전용. MAPS.md "결계석" 키워드 확인 필수 |
| `altar`를 ritual 타입이 아닌 배틀에 배치 | 의식 배틀(battle_35)에만 존재하는 특수 오브젝트 | battle_type이 `ritual`이거나 MAPS.md "제단" 명시 배틀만 |
| `trap_hidden`을 MAPS.md 근거 없이 배치 | 함정 배틀(battle_19)의 전술 특성 오염 | MAPS.md "함정", "trap" 명시 배틀만 |
| `gate_intact`를 관문 배틀 외에 배치 | 성문 돌파 이벤트(battle_29) 전용 | MAPS.md "성문", "관문" 명시 배틀만 |
| Prop `z_index`를 타입별 기준값 없이 임의 지정 | 바위/우물 등이 나무 위로 겹쳐 보이는 렌더링 오류 발생 | 아래 **Prop Z-Order 기준표** 참조 |

### Prop Z-Order 기준표

Prop 배치 시 `z_index`는 반드시 아래 기준을 따른다. 같은 레이어 내에서는 `y좌표`가 클수록(화면 아래쪽) 앞에 그려지므로 별도 조정 불필요.

| 레이어 | z_index | 해당 Prop 종류 |
|--------|---------|----------------|
| 지면 장식 (바닥 밀착) | 0 | `floor_crack`, `blood_pool`, `rune_floor` 등 |
| 저층 오브젝트 | 10 | `rock_small`, `stump`, `campfire`, `well`, `barrel`, `crate` |
| 중층 오브젝트 | 20 | `rock_large`, `bush`, `fence`, `statue_small` |
| 고층 오브젝트 | 30 | `tree`, `pillar`, `statue_large`, `ward_stone_active`, `altar` |
| 구조물 | 40 | `bridge_intact`, `bridge_broken`, `iron_gate`, `gate_intact`, `trap_hidden` |

> **규칙**: 나무(`tree`)는 z_index 30, 바위(`rock`)·우물(`well`)은 z_index 10~20. 나무가 항상 바위/우물보다 앞에 그려져야 한다.

---

## ✅ 유효한 battle_type 목록

기존 JSON에 아래 값이 있으면 **절대 변경하지 않는다.**

| 타입 | 설명 | 35전 중 사용 수 |
|------|------|----------------|
| `rout` | 적 전멸 (가장 기본, 가장 빈번) | 18개 |
| `annihilation` | 적 전멸 (`rout`와 동의어, 신규 배틀용) | 소수 |
| `escape` | 지정 유닛 탈출 | - |
| `protect` | NPC/거점 보호 | - |
| `defense` | 거점 방어 | - |
| `boss` | 보스 격파 | - |
| `capture` | 거점 점령 | - |
| `ritual` | 의식 오브젝트 파괴 | battle_35 |

---

## 📋 배틀별 특수 오브젝트 확정 목록

MAPS.md 기반으로 확정된 배틀별 특수 오브젝트. 이 목록 외 배틀에 특수 오브젝트를 추가하려면 반드시 MAPS.md를 재확인하고 근거를 리포트에 명시한다.

| 배틀 | 특수 오브젝트 | MAPS.md 근거 |
|------|-------------|-------------|
| battle_02 (벨마르 부두) | `bridge_intact` 1~2개 | "다리와 물 지형을 이용해 적의 접근을 차단" |
| battle_09 (2막 결계석) | `ward_stone_active` 1개 | 결계석 수집 배틀 |
| battle_16 (3막 결계석) | `ward_stone_active` 1개 | 결계석 수집 배틀 |
| battle_19 (함정 배틀) | `trap_hidden` 2~4개 | 함정 전문가 등장 |
| battle_21 (4막 결계석 전) | `ward_stone_active` 1개 | 결계석 수집 배틀 |
| battle_24 (벨마르 해상) | `bridge_intact` 1개 + `bridge_broken` 1개 | "다리를 파괴하면 적의 접근 경로를 차단할 수 있다" |
| battle_27 (최종 결계석) | `ward_stone_active` 1개 | 결계석 수집 배틀 |
| battle_29 (관문 돌파) | `gate_intact` 1~2개 | 성문/관문 돌파 이벤트 |
| battle_35 (최종 의식) | `altar` 1개 | ritual 타입, 최종 보스 의식 배틀 |

---

## 🔍 작업 시작 전 반드시 확인할 것

1. **기존 JSON이 있으면** → `battle_type`, `map_size`, `scene_id`는 변경 전 이 파일 금지 목록을 먼저 대조
2. **특수 오브젝트 배치 시** → 위 "배틀별 특수 오브젝트 확정 목록"에 없으면 MAPS.md 재확인
3. **iron_gate 배치 시** → ascalon 계열 틸셋인지 + 가장자리 위치인지 + 2개 이하인지 확인

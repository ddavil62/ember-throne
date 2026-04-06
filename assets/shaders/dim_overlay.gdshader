// @fileoverview 화면 어두워짐(Dim Overlay) 셰이더.
// 컷신 진입, 스킬 연출 시 배경을 어둡게 처리하여 전경 연출에 집중시킨다.
// ColorRect에 적용하여 사용한다. dim_opacity를 Tween으로 제어한다.
shader_type canvas_item;

// ── Uniforms ──

/// 어두워짐 정도 (0.0 = 완전 투명, 1.0 = 완전 검은색)
uniform float dim_opacity : hint_range(0.0, 1.0) = 0.0;

/// 내부 페이드 속도. 셰이더 자체적으로 부드러운 전환을 원할 때 사용.
/// 0이면 즉시 반영, 양수이면 목표값으로 서서히 수렴한다.
/// 대부분의 경우 코드에서 Tween으로 dim_opacity를 직접 제어하므로 0 권장.
uniform float fade_speed : hint_range(0.0, 5.0) = 0.0;

void fragment() {
	// 검은색 오버레이 + alpha 제어
	COLOR = vec4(0.0, 0.0, 0.0, dim_opacity);
}

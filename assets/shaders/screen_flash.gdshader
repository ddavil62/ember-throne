// @fileoverview 전체 화면 색상 플래시 셰이더.
// 크리티컬 히트, 번개 스킬, 필살기 발동 시 화면 전체를 순간적으로 밝게 물들인다.
// ColorRect에 적용하여 사용한다.
shader_type canvas_item;

// ── Uniforms ──

/// 플래시 색상 (RGBA). 기본값: 흰색
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

/// 플래시 최대 강도 (0.0 = 투명, 1.0 = 완전 불투명)
uniform float flash_intensity : hint_range(0.0, 1.0) = 1.0;

/// 플래시 진행도 (0.0 = 시작, 1.0 = 완전 소멸). 코드에서 Tween으로 제어한다.
uniform float flash_progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// progress가 0에서 1로 갈수록 intensity가 감소하는 페이드아웃 곡선
	// ease-out 느낌을 위해 제곱 감쇠 적용
	float fade = flash_intensity * (1.0 - flash_progress) * (1.0 - flash_progress);

	COLOR = vec4(flash_color.rgb, flash_color.a * fade);
}

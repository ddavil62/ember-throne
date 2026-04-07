/// @fileoverview 전투 셀 하이라이트 셰이더.
/// 대각선 방향으로 흐르는 투톤 그라데이션 + 테두리 펄스 효과를 제공한다.
/// ColorRect 또는 Sprite2D의 ShaderMaterial로 사용한다.
shader_type canvas_item;

/// 하이라이트 주색 (modulate로 덮어쓸 수 있음)
uniform vec4 color_a : source_color = vec4(0.4, 0.7, 1.0, 1.0);   // 밝은 색
uniform vec4 color_b : source_color = vec4(0.15, 0.4, 0.85, 1.0); // 어두운 색

/// 그라데이션이 흐르는 속도 (UV 단위/초)
uniform float flow_speed : hint_range(0.1, 3.0) = 0.6;
/// 그라데이션 줄무늬 주파수
uniform float stripe_freq : hint_range(1.0, 8.0) = 3.5;

/// 전체 alpha 기준값
uniform float base_alpha : hint_range(0.0, 1.0) = 0.45;
/// 펄스 진폭 (base_alpha에서 ±)
uniform float pulse_amp : hint_range(0.0, 0.4) = 0.12;
/// 펄스 속도 (Hz)
uniform float pulse_speed : hint_range(0.2, 4.0) = 1.2;

/// 테두리 두께 (UV 0~1 기준)
uniform float border_uv : hint_range(0.0, 0.15) = 0.06;
/// 테두리 alpha 배율
uniform float border_boost : hint_range(1.0, 4.0) = 2.5;

void fragment() {
	vec2 uv = UV;

	// ── 흐르는 대각선 그라데이션 ──
	// UV.x + UV.y 방향 (45도)으로 줄무늬가 흘러감
	float wave = sin((uv.x + uv.y) * stripe_freq - TIME * flow_speed);
	float t = wave * 0.5 + 0.5;  // 0~1 정규화

	vec4 grad_color = mix(color_b, color_a, t);

	// ── 전체 alpha 펄스 ──
	float pulse = sin(TIME * pulse_speed * TAU) * pulse_amp;
	float alpha = clamp(base_alpha + pulse, 0.0, 1.0);

	// ── 테두리 강조 ──
	// UV가 가장자리(border_uv 이내)면 alpha를 높임
	float edge_x = min(uv.x, 1.0 - uv.x);
	float edge_y = min(uv.y, 1.0 - uv.y);
	float edge = min(edge_x, edge_y);
	float border_factor = 1.0 - smoothstep(0.0, border_uv, edge);
	alpha = clamp(alpha + border_factor * (border_boost - 1.0) * base_alpha, 0.0, 1.0);

	COLOR = vec4(grad_color.rgb, alpha);
}

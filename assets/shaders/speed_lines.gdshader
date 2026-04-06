// @fileoverview 집중선(Speed Lines) 셰이더.
// 필살기 컷인 배경에 중심점에서 방사형으로 퍼지는 속도선을 렌더링한다.
// ColorRect에 적용하여 사용한다.
shader_type canvas_item;

// ── Uniforms ──

/// 집중선 색상. 기본값: 밝은 노란색
uniform vec4 line_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);

/// 배경 색상. 기본값: 짙은 남색
uniform vec4 bg_color : source_color = vec4(0.05, 0.02, 0.15, 1.0);

/// 방사선 개수. 값이 클수록 촘촘한 선
uniform float line_count : hint_range(4.0, 64.0) = 24.0;

/// 선 회전/이동 속도. 값이 클수록 빠르게 움직인다
uniform float line_speed : hint_range(0.0, 10.0) = 3.0;

/// 방사 중심점 (UV 좌표계 0~1). 기본값: 화면 중앙
uniform vec2 center = vec2(0.5, 0.5);

/// 선 두께 비율 (0~1). 0에 가까우면 얇은 선, 1에 가까우면 굵은 선
uniform float line_thickness : hint_range(0.0, 1.0) = 0.4;

void fragment() {
	// 중심점으로부터의 방향 벡터
	vec2 dir = UV - center;

	// 극좌표 각도 계산 (-PI ~ PI)
	float angle = atan(dir.y, dir.x);

	// 시간에 따라 각도를 회전시켜 애니메이션 효과
	float animated_angle = angle + TIME * line_speed;

	// 방사형 반복 패턴 생성
	// sin을 사용하여 각도 방향으로 줄무늬를 만든다
	float pattern = sin(animated_angle * line_count);

	// 선 두께에 따라 이진화 — smoothstep으로 약간의 안티앨리어싱
	float threshold = 1.0 - line_thickness;
	float line_mask = smoothstep(threshold - 0.05, threshold + 0.05, pattern);

	// 중심에서 멀수록 선이 더 선명하게 보이도록 그라디언트 적용
	float dist = length(dir) * 2.0;
	float radial_fade = smoothstep(0.0, 0.5, dist);

	// 최종 색상: 배경색과 선 색상을 마스크 기반으로 혼합
	float final_mask = line_mask * radial_fade;
	COLOR = mix(bg_color, line_color, final_mask);
}

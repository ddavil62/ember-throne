// @fileoverview 캐릭터 외곽 발광(Glow Outline) 셰이더.
// 버프 상태, 필살기 준비, 선택된 유닛 등을 시각적으로 강조한다.
// Sprite2D의 Material에 적용하여 사용한다.
shader_type canvas_item;

// ── Uniforms ──

/// 외곽선 발광 색상. 기본값: 금색
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.2, 1.0);

/// 외곽선 두께 (px). 1~4 사이 권장
uniform float glow_width : hint_range(1.0, 4.0) = 2.0;

/// 밝기 맥동 속도. 0이면 맥동 없이 고정 발광
uniform float pulse_speed : hint_range(0.0, 10.0) = 3.0;

/// 외곽선 활성화 여부. false이면 원본 스프라이트만 렌더링
uniform bool enabled = true;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	if (!enabled) {
		COLOR = tex_color;
		return;
	}

	// 텍셀 크기 계산 (텍스처 해상도 기반)
	vec2 texel = vec2(1.0) / vec2(textureSize(TEXTURE, 0));

	// 인접 픽셀 alpha 샘플링으로 외곽선 감지
	// glow_width에 비례하여 주변 범위를 넓힌다
	float max_alpha = 0.0;
	int steps = int(ceil(glow_width));

	for (int x = -steps; x <= steps; x++) {
		for (int y = -steps; y <= steps; y++) {
			if (x == 0 && y == 0) continue;

			// 원형 범위 체크 — 사각형이 아닌 둥근 외곽선
			float dist = length(vec2(float(x), float(y)));
			if (dist > glow_width) continue;

			vec2 offset = vec2(float(x), float(y)) * texel;
			float neighbor_alpha = texture(TEXTURE, UV + offset).a;
			max_alpha = max(max_alpha, neighbor_alpha);
		}
	}

	// 현재 픽셀이 투명하고 인접에 불투명 픽셀이 있으면 = 외곽선 영역
	float outline_mask = max_alpha * (1.0 - tex_color.a);

	// sin 기반 밝기 맥동 (0.5 ~ 1.0 범위)
	float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed);

	// 외곽선 색상 합성
	vec4 outline = vec4(glow_color.rgb, glow_color.a * outline_mask * pulse);

	// 원본 텍스처 위에 외곽선을 합성 (외곽선은 투명 영역에만 그려진다)
	COLOR = mix(outline, tex_color, tex_color.a);
}

shader_type canvas_item;
// Мягкий кинематографичный фильтр с цветами палитры.
// Палитра НЕ заменяет цвета, а плавно подкрашивает картинку, поэтому нет ступенек и "тонов".
// Порядок: лёгкая резкость -> экспозиция/контраст/тон -> палитра (мягко) -> виньетка -> тонкое зерно.
// Параметры крутятся в Инспекторе (узел Screen -> Material -> Shader Parameters).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

// 1 = без пикселизации (чёткая картинка). 2 = лёгкий ретро-вид, 3+ = заметные пиксели.
uniform float pixel_size : hint_range(1.0, 8.0) = 1.0;
// Яркость перед обработкой.
uniform float exposure : hint_range(0.3, 3.0) = 1.3;
// Контраст вокруг средних тонов (1 = без изменений).
uniform float contrast : hint_range(0.5, 1.5) = 1.05;
// Мягкая резкость деталей (0 = выкл).
uniform float detail : hint_range(0.0, 1.5) = 0.3;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
// Тёплый фильтр: множитель на R, G, B. Значения рядом с 1 дают лёгкий оттенок.
uniform vec3 warm_tint : source_color = vec3(1.03, 0.99, 0.93);
// Насколько цвета подтягиваются к палитре: 0 = совсем нет, 1 = почти полностью.
uniform float palette_strength : hint_range(0.0, 1.0) = 0.4;
// Мягкость притяжения к палитре: меньше = цвета липнут к палитре сильнее, больше = размытее.
uniform float palette_softness : hint_range(0.05, 1.0) = 0.3;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;
// Едва заметное зерно (сильнее в тенях). 0 = выкл. Также убирает полосы в тёмных градиентах.
uniform float grain_strength : hint_range(0.0, 0.1) = 0.012;
uniform float grain_speed : hint_range(0.0, 60.0) = 24.0;

const vec3 PALETTE[14] = vec3[14](
	vec3(16.0, 11.0, 42.0),     // #100b2a
	vec3(42.0, 33.0, 58.0),     // #2a213a
	vec3(49.0, 71.0, 67.0),     // #314743
	vec3(101.0, 133.0, 109.0),  // #65856d
	vec3(173.0, 202.0, 154.0),  // #adca9a
	vec3(236.0, 254.0, 202.0),  // #ecfeca
	vec3(88.0, 45.0, 39.0),     // #582d27
	vec3(151.0, 65.0, 51.0),    // #974133
	vec3(214.0, 118.0, 84.0),   // #d67654
	vec3(93.0, 52.0, 65.0),     // #5d3441
	vec3(163.0, 104.0, 91.0),   // #a3685b
	vec3(255.0, 179.0, 121.0),  // #ffb379
	vec3(255.0, 230.0, 169.0),  // #ffe6a9
	vec3(255.0, 255.0, 255.0)   // #ffffff
);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 tap(vec2 uv) {
	return textureLod(screen_tex, uv, 0.0).rgb * exposure;
}

// Плавное притяжение к палитре: средневзвешенное по близости цвета (без жёсткого выбора одного цвета)
vec3 soft_palette(vec3 c) {
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	float s2 = palette_softness * palette_softness;
	for (int i = 0; i < 14; i++) {
		vec3 p = PALETTE[i] / 255.0;
		vec3 d = c - p;
		float dist2 = dot(d * d, vec3(0.5, 1.0, 0.35));
		float w = exp(-dist2 / s2);
		acc += p * w;
		wsum += w;
	}
	return wsum > 0.0001 ? acc / wsum : c;
}

void fragment() {
	vec2 uv;
	vec2 st = max(pixel_size, 1.0) * SCREEN_PIXEL_SIZE;
	if (pixel_size > 1.001) {
		vec2 cell = floor(FRAGCOORD.xy / pixel_size);
		uv = (cell * pixel_size + 0.5 * pixel_size) * SCREEN_PIXEL_SIZE;
	} else {
		uv = SCREEN_UV;
	}

	// 1. Лёгкая резкость (unsharp mask)
	vec3 c0 = tap(uv);
	vec3 blur = (tap(uv + vec2(st.x, 0.0)) + tap(uv - vec2(st.x, 0.0))
		+ tap(uv + vec2(0.0, st.y)) + tap(uv - vec2(0.0, st.y))) * 0.25;
	vec3 c = c0 + (c0 - blur) * detail;

	// 2. Насыщенность, тёплый тон, контраст
	c = mix(vec3(lum(c)), c, saturation);
	c *= warm_tint;
	c = (c - 0.4) * contrast + 0.4;
	c = max(c, vec3(0.0));

	// 3. Мягкая палитра: подкрашиваем, а не заменяем
	c = mix(c, soft_palette(clamp(c, 0.0, 1.0)), palette_strength);

	// 4. Виньетка
	vec2 q = UV - 0.5;
	c *= 1.0 - dot(q, q) * vignette_strength * 2.0;

	// 5. Тонкое зерно + микродизеринг против полос в тёмных градиентах
	float g = hash(FRAGCOORD.xy + floor(TIME * grain_speed) * 17.0)
		+ hash(FRAGCOORD.xy * 1.37 + floor(TIME * grain_speed) * 31.0) - 1.0;
	c += g * grain_strength * (1.0 - 0.5 * lum(c));
	c += g / 255.0;

	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}

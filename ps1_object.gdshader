shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Простой плоский матовый материал для 3D-объектов (без искажения вершин).
// Весь PS1-вид теперь делает фильтр камеры (ps1_filter.gdshader).

uniform vec4 albedo : source_color = vec4(1.0);
// Свечение (глаза мобов и т.п.)
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;
// Только для призраков в редакторе: полупрозрачность "сеткой" вместо плавной.
uniform float ghost : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	EMISSION = emission_color.rgb * emission_energy;
	if (ghost > 0.5) {
		ALPHA = mod(floor(FRAGCOORD.x) + floor(FRAGCOORD.y), 2.0);
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
}

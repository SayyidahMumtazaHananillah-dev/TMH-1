shader_type canvas_item;

float random(float x) {
	return fract(sin(x * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// =========================
	// GLITCH
	// =========================

	float glitch_time = floor(TIME * 4.0);
	float glitch_random = random(glitch_time);

	if (glitch_random > 0.68) {
		float line = floor(uv.y * 45.0);
		float offset = (random(line + glitch_time) - 0.5) * 0.018;
		uv.x += offset;
	}

	vec4 tex = texture(TEXTURE, uv);

	// =========================
	// BACKGROUND GELAP
	// =========================

	tex.rgb *= 0.48;

	// =========================
	// DESATURASI
	// =========================

	float gray = dot(
		tex.rgb,
		vec3(0.299, 0.587, 0.114)
	);

	tex.rgb = mix(
		tex.rgb,
		vec3(gray),
		0.30
	);

	// =========================
	// SISI GELAP
	// =========================

	float side = abs(uv.x - 0.5) * 2.0;

	float darkness = smoothstep(
		0.20,
		0.90,
		side
	);

	tex.rgb *= 1.0 - darkness * 0.78;

	// =========================
	// CAHAYA DARI ATAS
	// =========================

	float top = 1.0 - uv.y;

	float light = smoothstep(
		0.02,
		0.70,
		top
	);

	// Fokus cahaya di tengah
	float center_light =
		1.0 - abs(uv.x - 0.5) * 2.0;

	center_light = smoothstep(
		0.0,
		0.85,
		center_light
	);

	light *= center_light;

	// =========================
	// RANDOM LAMPU 1 / 0
	// =========================

	// Ganti angka setiap sekitar 0.8 detik
	float lamp_step = floor(TIME * 1.25);

	// Random menentukan lampu hidup atau mati
	float lamp_random = random(lamp_step);

	float lamp_power = 0.0;

	if (lamp_random > 0.45) {
		lamp_power = 1.0;
	}

	light *= lamp_power;

	// =========================
	// CAHAYA KUNING
	// =========================

	vec3 yellow_light =
		vec3(1.0, 0.58, 0.20);

	tex.rgb +=
		yellow_light *
		light *
		0.30;

	// =========================
	// HALO LAMPU
	// =========================

	float halo =
		1.0 - distance(
			uv,
			vec2(0.5, 0.03)
		);

	halo = smoothstep(
		0.0,
		0.85,
		halo
	);

	tex.rgb +=
		vec3(1.0, 0.60, 0.25) *
		halo *
		0.07 *
		lamp_power;

	// =========================
	// VIGNETTE
	// =========================

	vec2 center = uv - vec2(0.5);

	float vignette =
		1.0 - dot(center, center) * 2.0;

	tex.rgb *= vignette;

	// =========================
	// NOISE
	// =========================

	float noise = random(
		uv.x * 1000.0 +
		uv.y * 800.0 +
		TIME * 8.0
	);

	noise =
		(noise - 0.5) * 0.025;

	tex.rgb += noise;

	// =========================
	// SCANLINE
	// =========================

	float scanline =
		sin(uv.y * 600.0) * 0.015;

	tex.rgb -= scanline;

	COLOR = tex;
}
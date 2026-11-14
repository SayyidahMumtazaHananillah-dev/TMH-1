shader_type canvas_item;

// ===== Suasana =====
uniform vec4 moon_color : source_color = vec4(0.62, 0.78, 1.0, 1.0);
uniform float ambient : hint_range(0.3, 1.0) = 0.62;          // terang dasar lorong (makin kecil makin gelap)
uniform float vignette_strength : hint_range(0.0, 0.8) = 0.35; // pinggiran gambar lebih gelap
uniform vec3 shadow_tint = vec3(0.85, 0.95, 1.1);              // area gelap sedikit kebiruan

// ===== Cahaya bulan =====
uniform float light_strength : hint_range(0.0, 2.0) = 0.8;     // bercak cahaya di lantai/loker
uniform float beam_strength : hint_range(0.0, 1.0) = 0.25;     // sinar dari jendela
uniform float window_glow : hint_range(0.0, 1.0) = 0.3;
uniform float dust_strength : hint_range(0.0, 2.0) = 1.0;
uniform float fog_strength : hint_range(0.0, 0.5) = 0.12;

// ===== Animasi (tipis) =====
uniform float cloud_speed : hint_range(0.0, 0.2) = 0.03;
uniform float cloud_depth : hint_range(0.0, 1.0) = 0.3;        // seberapa redup saat awan lewat
uniform float exit_flicker : hint_range(0.0, 1.0) = 0.6;

// ===== Posisi (UV 0..1) =====
uniform vec2 pool_center = vec2(0.45, 0.69);
uniform vec2 pool_size = vec2(0.13, 0.12);
uniform vec2 beam_origin = vec2(0.88, 0.22);
uniform vec2 moon_pos = vec2(0.625, 0.437);
uniform vec2 exit_pos = vec2(0.615, 0.46);
uniform float window_threshold : hint_range(0.3, 0.95) = 0.62;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.0, 9.0);
		a *= 0.5;
	}
	return v;
}

vec3 screen(vec3 a, vec3 b) {
	return 1.0 - (1.0 - a) * (1.0 - b);
}

float dust(vec2 uv, float scale, float speed, float seed) {
	vec2 g = uv * scale;
	g.y -= TIME * speed;
	g.x += sin(TIME * 0.3 + seed) * 0.4;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash21(id + seed);
	vec2 off = (vec2(hash21(id + seed + 3.1), hash21(id + seed + 7.7)) - 0.5) * 0.6;
	float d = length(f - off);
	float twinkle = 0.5 + 0.5 * sin(TIME * (0.8 + h * 2.0) + h * 40.0);
	return (1.0 - smoothstep(0.0, 0.07, d)) * step(0.6, h) * twinkle;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 base = tex.rgb;
	float aspect = TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x;
	vec2 auv = UV * vec2(aspect, 1.0);

	// --- Awan lewat: terang sinar naik turun pelan ---
	float c = fbm(auv * 1.6 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.3));
	float cloud = smoothstep(0.30, 0.70, c);
	float breathe = 0.5 + 0.5 * sin(TIME * 0.35);
	float moon_i = mix(1.0 - cloud_depth, 1.0, cloud) * (0.94 + 0.06 * breathe);

	// --- Mask area yang kena cahaya ---
	vec2 drift = vec2(sin(TIME * 0.15) * 0.004, cos(TIME * 0.11) * 0.003);
	vec2 pc = (UV - pool_center + drift) / pool_size;
	float pool = 1.0 - smoothstep(0.55, 1.0, max(abs(pc.x), abs(pc.y)));

	float region = smoothstep(0.55, 0.7, UV.x) * (1.0 - smoothstep(0.55, 0.7, UV.y));
	float winmask = smoothstep(window_threshold, window_threshold + 0.12, base.b) * region;

	// --- Sinar dari jendela ---
	vec2 p = (UV - beam_origin) * vec2(aspect, 1.0);
	vec2 dir = normalize(vec2(-1.0, 0.62));
	vec2 perp = vec2(-dir.y, dir.x);
	float along = dot(p, dir);
	float across = dot(p, perp);
	float stripes = smoothstep(0.35, 0.8, fbm(vec2(across * 6.0 + sin(TIME * 0.1) * 0.3, TIME * 0.04)));
	float fade = smoothstep(-0.05, 0.15, along) * (1.0 - smoothstep(0.2, 1.1, along));
	float beam = stripes * fade * beam_strength * moon_i;

	// --- Gelapkan lorong, kecuali area yang kena cahaya ---
	float vig = 1.0 - vignette_strength * smoothstep(0.3, 0.95, length((UV - vec2(0.5, 0.5)) * vec2(1.0, 1.15)));
	vec3 dark = base * ambient * vig * shadow_tint;
	float lit = clamp(max(pool, winmask) * mix(0.55, 1.0, moon_i), 0.0, 1.0);
	vec3 col = mix(dark, base, lit);

	// --- Tambah cahaya bulan di bercak lantai/loker ---
	float lum = dot(base, vec3(0.299, 0.587, 0.114));
	col += moon_color.rgb * pool * moon_i * light_strength * (0.12 + lum * 0.7);

	// --- Kilau jendela ---
	col += moon_color.rgb * winmask * window_glow * (moon_i - 0.5);

	// --- Sinar ---
	col = screen(col, moon_color.rgb * beam);

	// --- Kabut tipis di ujung lorong ---
	vec2 fp = (UV - vec2(0.62, 0.5)) * vec2(aspect * 0.9, 1.8);
	float fmask = exp(-dot(fp, fp) * 10.0);
	float fn = fbm(auv * 3.0 + vec2(TIME * 0.02, -TIME * 0.01));
	col = screen(col, vec3(0.45, 0.6, 0.8) * fog_strength * fmask * fn * 2.0);

	// --- Debu hanya terlihat di area bercahaya ---
	float dmask = clamp(beam * 4.0 + pool * 0.8 + fmask * 0.4, 0.0, 1.0);
	float d1 = dust(auv, 40.0, 0.012, 1.0);
	float d2 = dust(auv, 70.0, 0.02, 5.0) * 0.7;
	col += moon_color.rgb * (d1 + d2) * dmask * dust_strength * 0.9;

	// --- Halo bulan (kecil) ---
	vec2 mp = (UV - moon_pos) * vec2(aspect, 1.0);
	float halo = exp(-dot(mp, mp) * 1500.0) * (0.85 + 0.15 * sin(TIME * 0.5));
	col += moon_color.rgb * halo * 0.2 * moon_i;

	// --- Tanda EXIT (kecil, kedip jarang) ---
	vec2 ep = (UV - exit_pos) * vec2(aspect, 1.0);
	float esign = exp(-dot(ep, ep) * 25000.0);
	float r = hash21(vec2(floor(TIME * 10.0), 3.0));
	float flick = r > 0.95 ? 0.2 : 1.0;
	col += vec3(0.2, 1.0, 0.6) * esign * 0.3 * mix(1.0, flick, exit_flicker);

	COLOR = vec4(col, tex.a);
}
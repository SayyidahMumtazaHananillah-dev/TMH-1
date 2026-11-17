shader_type canvas_item;

void fragment() {
	float dist = distance(UV, vec2(0.5));
	float alpha = 1.0 - smoothstep(0.46, 0.5, dist);
	COLOR.a *= alpha;
}
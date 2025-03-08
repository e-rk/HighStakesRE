uniform sampler2DArray layers: source_color, repeat_disable;
uniform int ticks;

const float sec_per_tick = 1.0 / 64.0;

void fragment() {
	float sec_per_frame = float(ticks) * sec_per_tick;
	int layer_count = textureSize(layers, 0).z;
	int t = int(floor(TIME / sec_per_frame)) % layer_count;
	vec4 tex = texture(layers, vec3(UV.x, UV.y, float(t)));
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}
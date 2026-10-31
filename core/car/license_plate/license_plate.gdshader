shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;


uniform sampler2D plate_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D text_texture : source_color, filter_linear_mipmap, repeat_disable, hint_default_transparent;
instance uniform float lamp_lit = 0.0;

void fragment() {
	vec4 text_color = texture(text_texture, UV);
	vec3 plate_color = texture(plate_texture, UV).rgb;
	ALBEDO = mix(plate_color, text_color.rgb, text_color.a);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float lamp = 1.0 - UV.y;
	EMISSION = ALBEDO * lamp * lamp_lit;
}

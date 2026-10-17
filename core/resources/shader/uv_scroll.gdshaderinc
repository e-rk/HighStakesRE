render_mode blend_mix, depth_prepass_alpha, diffuse_burley, specular_schlick_ggx;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float uv_scroll = 0.0;
uniform bool vertex_color_use_as_albedo = true;

void vertex() {
	UV.y += fract(TIME * uv_scroll);
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = mix(
				pow((COLOR.rgb + vec3(0.055)) * (1.0 / (1.0 + 0.055)), vec3(2.4)),
				COLOR.rgb * (1.0 / 12.92),
				lessThan(COLOR.rgb, vec3(0.04045)));
	}
}

void fragment() {
	vec4 color = albedo * texture(texture_albedo, UV);
	if (vertex_color_use_as_albedo) {
		color *= COLOR;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	METALLIC = metallic;
}

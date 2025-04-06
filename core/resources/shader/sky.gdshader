shader_type sky;
uniform sampler2D CloudTexture : source_color, hint_default_black;
uniform sampler2D CloudSubtractTexture : source_color;
uniform samplerCube background_texture : source_color, hint_default_black, filter_linear;
uniform sampler2D earth_gradient : source_color, hint_default_black;
uniform float cloud_speed = 0.010000;
uniform float cloud_scale = 0.12000;
uniform vec3 sun_side_color: source_color;
uniform vec3 top_side_color: source_color;
uniform vec3 opposite_side_color: source_color;
uniform vec3 ambient_color: source_color;

group_uniforms Sun;
uniform sampler2D sun_texture : source_color, repeat_disable, hint_default_transparent;
uniform float sun_radius = 0.1;
uniform bool sun_additive = false;
uniform bool sun_rotates = false;

vec4 make_cloud(sampler2D tex, vec3 uv, float scale, float speed)
{
	vec2 uv_flat = uv.xz * scale / uv.y;
	vec2 uv_offset = fma(vec2(TIME), vec2(speed), uv_flat);
	vec4 color;
	if (uv.y > 0.0) {
		color = texture(tex, uv_offset);
		color.rgb *= ambient_color.rgb;
	} else {
		color = vec4(0.0);
	}
	return color;
}

float eyedir_coord_to_factor(float coord)
{
	return 0.5 * coord + 0.5;
}

vec3 make_sky_gradient(vec3 uv)
{
	vec3 sundir_xz = normalize(vec3(LIGHT0_DIRECTION.x, 0.0, LIGHT0_DIRECTION.z));
	vec3 uv_xz = normalize(vec3(uv.x, 0.0, uv.z));
	float dist = distance(uv_xz, sundir_xz);
	const float half = sqrt(2.0);
	const float transition = 0.6;
	float interp = smoothstep(half - transition, half + transition, dist);
	vec3 bottom_color = mix(sun_side_color, opposite_side_color, interp);
	const float top_height = 0.25;
	const float top_transition = 0.2;
	float interp2 = smoothstep(top_height - top_transition, top_height + top_transition, uv.y);
	return mix(bottom_color, top_side_color, interp2) * step(0.0, uv.y);
}

vec4 make_earth_gradient(sampler2D tex, vec3 uv)
{
	vec4 color;
	float distance_from_sun = distance(uv, LIGHT0_DIRECTION);
	color = texture(tex, vec2(0.5 * distance_from_sun)) * step(0, uv.y);
	return color;
}

vec2 eyedir_to_sun_uv(vec3 eyedir, vec3 sun_dir, float sun_size)
{
	vec3 up_ = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(sun_dir, up_));
	vec3 up = cross(sun_dir, right);
	eyedir = eyedir / sun_size;
	float v = dot(up, eyedir);
	float u = dot(right, eyedir);
	return (vec2(u, v) + 1.0) / 2.0;
}

vec4 make_sun(vec3 uv)
{
	float fact = 0.05;

	if (LIGHT0_ENABLED) {
		float dir = dot(uv, LIGHT0_DIRECTION);
		vec2 uv = eyedir_to_sun_uv(uv, LIGHT0_DIRECTION, sun_radius);
		vec4 color = texture(sun_texture, uv) * step(0, dir);
		const float TRANSITION = 0.2;
		float dist = distance(vec2(0.5), uv);
		color = color * smoothstep(0.5 + TRANSITION, 0.5 - TRANSITION, dist);
		return color;
	}
	return vec4(0.0);
}

void sky() {
	vec4 cloud = make_cloud(CloudTexture, EYEDIR, cloud_scale, cloud_speed);
	vec3 gradient = make_sky_gradient(EYEDIR);
	vec4 ground = make_earth_gradient(earth_gradient, EYEDIR);
	vec3 adjust = vec3(EYEDIR.x, EYEDIR.y, EYEDIR.z);
	vec4 background = texture(background_texture, adjust);
	vec4 sun = make_sun(EYEDIR);
	vec3 blended = cloud.xyz + (1.0 - cloud.x) * gradient.xyz;
	vec3 sky;
	if (sun_additive) {
		sky = gradient + ground.xyz + sun.xyz * sun.a;
	} else {
		sky = mix(gradient + ground.xyz, sun.xyz, sun.a);
	}
	sky = cloud.xyz + (1.0 - cloud.x) * sky.xyz;
	COLOR = mix(sky, background.xyz * ambient_color, background.a);
}

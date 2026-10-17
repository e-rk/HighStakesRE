shader_type sky;

group_uniforms Strip;
uniform sampler2D panorama_texture : hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform bool hrz_has_pmx = false;
uniform bool hrz_mirror = true;
uniform float hrz_radius = 1500.0;
uniform float hrz_angle = 0.0;
uniform float hrz_bottom_y_off = -1200.0;
uniform float hrz_gouraud_middle = 1200.0;
uniform float hrz_gouraud_height = 1800.0;
uniform float hrz_pmx_bottom = 1150.0;
uniform float hrz_pmx_top = 1350.0;
uniform vec2 pmx_atlas_v = vec2(0.0, 1.0);
uniform vec3 sun_side_color : source_color = vec3(0.74, 0.65, 0.31);
uniform vec3 top_side_color : source_color = vec3(0.19, 0.47, 0.86);
uniform vec3 opposite_side_color : source_color = vec3(0.19, 0.41, 0.6);
uniform vec3 earth_bottom : source_color = vec3(0.62, 0.32, 0.12);
uniform vec3 earth_top : source_color = vec3(0.18, 0.14, 0.005);
uniform vec3 fog_color : source_color = vec3(0.24, 0.24, 0.26);
uniform float horizon_haze : hint_range(0.0, 1.0) = 0.0;
uniform float band_smoothness : hint_range(0.0, 1.0) = 1.0;
uniform float horizon_softness : hint_range(0.0, 0.2) = 0.02;
uniform float panorama_sharpness : hint_range(0.0, 1.0) = 0.75;

group_uniforms Clouds;
uniform sampler2D sky_texture : hint_default_transparent, filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_noise : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_field_texture : hint_default_white, filter_linear, repeat_disable;
uniform int cloud_type = 1;
uniform float cloud_nimbus = 0.8;
uniform bool cloud_fog = true;
uniform float cloud_visual_height = 500.0;
uniform float cloud_wind_speed = 10.0;
uniform float cloud_wind_direction = 100.0;
uniform float cloud_y_offset = -100.0;
uniform float cloud_height = 750.0;
uniform vec2 cloud_uv_scale = vec2(1.0);
uniform float cloud_detail : hint_range(0.0, 1.0) = 1.0;
uniform float cloud_relief : hint_range(0.0, 2.0) = 0.8;
uniform float cloud_silver_lining : hint_range(0.0, 2.0) = 0.6;

group_uniforms Lightning;
uniform int lightning_chance = 0;
uniform int lightning_off_ticks = 0;
uniform float lightning_glow : hint_range(0.0, 4.0) = 1.0;
uniform float lightning_flash : hint_range(0.0, 4.0) = 1.0;

group_uniforms Sun;
uniform sampler2D sun_texture : repeat_disable, filter_linear, hint_default_transparent;
uniform float sun_world_radius = 250.0;
uniform bool sun_additive = false;
uniform bool sun_in_front = false;

const float DOME_RADIUS = 3000.0;
const float DOME_CURVE = PI / (2.0 * DOME_RADIUS);
const float DOME_CELL = 450.0;
const float TICKS_PER_SECOND = 64.0;
const float BOLT_LIFETIME = 24.0;
const float BOLT_STEP = 40.0;
const int BOLT_SEGMENTS = 40;
const vec3 BOLT_COLOR = vec3(0.886, 0.886, 1.0);

vec3 to_gamma(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

uint hash_u(uint x) {
	x = x * 747796405u + 2891336453u;
	x = ((x >> ((x >> 28u) + 4u)) ^ x) * 277803737u;
	return (x >> 22u) ^ x;
}

float hash(uint a, uint b) {
	return float(hash_u(a ^ hash_u(b))) / 4294967296.0;
}

vec3 soft_clip(vec3 c) {
	const float KNEE = 0.8;
	vec3 over = max(c - KNEE, vec3(0.0)) / (1.0 - KNEE);
	return min(c, vec3(KNEE)) + (1.0 - KNEE) * (1.0 - exp(-over));
}

float interleaved_gradient_noise(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

vec3 camera_forward(vec3 dir, vec3 dir_dx, vec3 dir_dy, vec2 fragcoord, vec2 size) {
	vec2 side = 1.0 - 2.0 * mod(floor(fragcoord), 2.0);
	vec3 chord_x = side.x * dir_dx;
	vec3 chord_y = side.y * dir_dy;
	vec2 pixel = (fragcoord - 0.5 * size) * side;
	float gx = dot(chord_x, chord_x);
	float gy = dot(chord_y, chord_y);
	float sx = gx * (1.0 - 0.25 * gx);
	float sy = gy * (1.0 - 0.25 * gy);
	float a = sx + sy;
	if (a < 1e-12) {
		return vec3(0.0);
	}
	float b = 2.0 - sx * (2.0 * pixel.x + 1.0) - sy * (2.0 * pixel.y + 1.0);
	float squared = (b + sqrt(max(b * b - 4.0 * a * dot(pixel, pixel), 0.0))) / (2.0 * a);
	float len = sqrt(squared);
	float len_x = sqrt(max(squared + 2.0 * pixel.x + 1.0, 0.0));
	float len_y = sqrt(max(squared + 2.0 * pixel.y + 1.0, 0.0));
	vec3 right = len * chord_x + (2.0 * pixel.x + 1.0) / (len_x + len) * (dir + chord_x);
	vec3 up = len * chord_y + (2.0 * pixel.y + 1.0) / (len_y + len) * (dir + chord_y);
	return normalize(len * dir - pixel.x * right - pixel.y * up);
}

vec4 texture_bicubic(sampler2D tex, vec2 uv, vec4 bounds) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 texel = uv * size - 0.5;
	vec2 f = fract(texel);
	vec2 base = floor(texel);
	vec2 f2 = f * f;
	vec2 f3 = f2 * f;
	vec2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
	vec2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
	vec2 w3 = f3 / 6.0;
	vec2 w2 = 1.0 - w0 - w1 - w3;
	vec2 g0 = w0 + w1;
	vec2 g1 = w2 + w3;
	vec2 p0 = (base - 0.5 + w1 / g0) / size;
	vec2 p1 = (base + 1.5 + w3 / g1) / size;
	vec2 lo = bounds.xy;
	vec2 hi = bounds.zw;
	vec4 top = g0.x * textureLod(tex, clamp(vec2(p0.x, p0.y), lo, hi), 0.0)
			+ g1.x * textureLod(tex, clamp(vec2(p1.x, p0.y), lo, hi), 0.0);
	vec4 bottom = g0.x * textureLod(tex, clamp(vec2(p0.x, p1.y), lo, hi), 0.0)
			+ g1.x * textureLod(tex, clamp(vec2(p1.x, p1.y), lo, hi), 0.0);
	return g0.y * top + g1.y * bottom;
}

float horizon_ring_weight(float pano) {
	float segment = pano * 16.0;
	vec2 index = mod(floor(segment) + vec2(0.0, 1.0), 16.0);
	vec2 entry = min(index, 15.0 - index) / 8.0;
	float classic = mix(entry.x, entry.y, fract(segment));
	float away = 1.0 - abs(2.0 * fract(pano + 1.0 / 32.0) - 1.0);
	float smooth_weight = 0.875 * (0.5 - 0.5 * cos(PI * away));
	return mix(classic, smooth_weight, band_smoothness);
}

float band_ease(float t) {
	t = clamp(t, 0.0, 1.0);
	return mix(t, smoothstep(0.0, 1.0, t), band_smoothness);
}

float dome_hit(float slope, float base) {
	float top = base + cloud_height;
	if (top <= 0.0 || DOME_RADIUS * slope < base) {
		return -1.0;
	}
	float rho = top / (slope + cloud_height / DOME_RADIUS);
	for (int i = 0; i < 3; i++) {
		float g = rho * slope - base - cloud_height * cos(DOME_CURVE * rho);
		float dg = max(slope + cloud_height * DOME_CURVE * sin(DOME_CURVE * rho), 0.001);
		rho = clamp(rho - g / dg, 0.0, DOME_RADIUS);
	}
	return rho;
}

float dome_footprint(float rho, float slope, float pixel_angle) {
	float steepness = max(slope + cloud_height * DOME_CURVE * sin(DOME_CURVE * rho), 0.05);
	return pixel_angle * rho * max((1.0 + slope * slope) / steepness, sqrt(1.0 + slope * slope));
}

vec3 dome_point(vec2 p) {
	float y = cloud_y_offset - POSITION.y + cloud_height * cos(length(p) * DOME_CURVE);
	return vec3(-p.x, y, p.y);
}

vec2 cloud_uv(vec2 p) {
	vec2 camera = vec2(-POSITION.x, POSITION.z);
	float parallax = cloud_visual_height > 0.0 ? 1.0 / cloud_visual_height : 0.0;
	float angle = radians(cloud_wind_direction);
	vec2 wind = vec2(cos(angle), sin(angle)) * cloud_wind_speed * 0.00003 * TICKS_PER_SECOND;
	return (p + DOME_RADIUS) / DOME_CELL * cloud_uv_scale + camera * parallax + wind * TIME;
}

float cloud_field(vec2 p) {
	return textureLod(cloud_field_texture, ((p + DOME_RADIUS) / DOME_CELL + 0.5) / 13.0, 0.0).r;
}

vec2 lightning_state() {
	if (lightning_chance <= 0 || lightning_off_ticks <= 0) {
		return vec2(0.0, BOLT_LIFETIME);
	}
	float tick = TIME * TICKS_PER_SECOND;
	float window = floor(tick / float(lightning_off_ticks));
	bool strikes = hash(uint(window), 5369127u) * 100.0 < float(lightning_chance);
	return vec2(window + 1.0, strikes ? tick - window * float(lightning_off_ticks) : BOLT_LIFETIME);
}

float bolt_intensity(float age) {
	return age < BOLT_LIFETIME ? clamp(2.0 * (1.0 - age / BOLT_LIFETIME), 0.0, 1.0) : 0.0;
}

vec2 bolt_origin(uint seed) {
	return (vec2(hash(seed, 1u), hash(seed, 2u)) - 0.5) * 1500.0;
}

vec2 bolt_jitter(uint roll, int remaining, float age) {
	float amplitude = (1.0 - float(remaining) / float(BOLT_SEGMENTS)) * 3.0;
	uint walk = hash_u(roll + uint(age));
	return (vec2(float(walk % 65536u), float(walk >> 16u)) / 65535.0 - 0.5) * amplitude * sqrt(age) * 1.6;
}

vec2 bolt_turn(vec2 direction, uint roll, bool wide) {
	const float TURN_COS[5] = float[5](1.0, 0.98769, 0.95106, 0.89101, 0.80902);
	const float TURN_SIN[5] = float[5](0.0, 0.15643, 0.30902, 0.45399, 0.58779);
	int steps = int(roll % 5u) - 2;
	int index = abs(steps) * (wide ? 2 : 1);
	float c = TURN_COS[index];
	float s = TURN_SIN[index] * float(sign(steps));
	return vec2(direction.x * c - direction.y * s, direction.x * s + direction.y * c);
}

bool near_segment(vec2 p, vec2 a, vec2 b, float reach) {
	vec2 ab = b - a;
	vec2 off = p - a - ab * clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	return dot(off, off) < reach * reach;
}

float segment_distance(vec2 a, vec2 b, vec3 dir, vec3 e1, vec3 e2, float pixels_per_radian) {
	vec3 from = dome_point(a);
	vec3 to = dome_point(b);
	float da = dot(from, dir);
	float db = dot(to, dir);
	if (min(da, db) < 1.0) {
		return 1e6;
	}
	vec2 qa = vec2(dot(from, e1), dot(from, e2)) / da;
	vec2 qb = vec2(dot(to, e1), dot(to, e2)) / db;
	vec2 ab = qb - qa;
	float t = clamp(dot(-qa, ab) / max(dot(ab, ab), 1e-12), 0.0, 1.0);
	return length(qa + ab * t) * pixels_per_radian;
}

vec2 bolt(vec2 p, float reach, vec3 dir, float pixels_per_radian, uint seed, float age) {
	vec3 e1 = normalize(cross(dir, abs(dir.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
	vec3 e2 = cross(e1, dir);
	vec2 point = bolt_origin(seed);
	vec2 direction = point / max(length(point), 1e-3);
	vec2 previous = point;
	int fork = 30;
	vec2 nearest = vec2(1e6);
	for (int remaining = BOLT_SEGMENTS; remaining >= 1; remaining--) {
		uint roll = hash_u(seed * 64u + uint(remaining));
		direction = bolt_turn(direction, roll, false);
		point += BOLT_STEP * direction;
		if (distance(p, point) > float(remaining) * BOLT_STEP + reach) {
			break;
		}
		vec2 current = point + bolt_jitter(roll, remaining, age);
		if (remaining < BOLT_SEGMENTS && near_segment(p, previous, current, reach)) {
			nearest.x = min(nearest.x, segment_distance(previous, current, dir, e1, e2, pixels_per_radian));
		}
		if (remaining == fork) {
			if ((roll >> 8u) % uint(remaining) == 0u) {
				fork = 0;
			} else {
				fork = int(float(fork) * 0.75);
				int side_length = remaining / 2;
				vec2 side_point = point;
				vec2 side_direction = direction;
				vec2 side_previous = current;
				for (int left = side_length; left >= 1; left--) {
					uint side_roll = hash_u(roll + uint(left) * 7919u);
					side_direction = bolt_turn(side_direction, side_roll, left == side_length);
					side_point += BOLT_STEP * side_direction;
					if (distance(p, side_point) > float(left) * BOLT_STEP + reach) {
						break;
					}
					vec2 side_current = side_point + bolt_jitter(side_roll, left, age);
					if (near_segment(p, side_previous, side_current, reach)) {
						nearest.y = min(nearest.y, segment_distance(side_previous, side_current, dir, e1, e2, pixels_per_radian));
					}
					side_previous = side_current;
				}
			}
		}
		previous = current;
	}
	vec2 core = exp(-nearest * nearest / 1.5);
	vec2 halo = 1.0 / (1.0 + nearest * nearest / 30.0);
	return core * 2.0 + halo * 0.35 * lightning_glow;
}

vec4 cloud_layer(vec2 p, float footprint, vec3 dir, vec3 strike) {
	vec2 uv = cloud_uv(p);
	float field = cloud_field(p);
	float rho = length(p);
	float texels = footprint / DOME_CELL * max(cloud_uv_scale.x, cloud_uv_scale.y) * 512.0;

	vec2 slow = vec2(
		textureLod(cloud_noise, uv * 0.09, 3.0).r,
		textureLod(cloud_noise, uv * 0.09 + vec2(0.37, 0.61), 3.0).r
	) - 0.5;
	float fine_lod = log2(max(texels * 0.6, 1.0));
	vec2 fine = vec2(
		textureLod(cloud_noise, uv * 0.6, fine_lod).r,
		textureLod(cloud_noise, uv * 0.6 + vec2(0.71, 0.13), fine_lod).r
	) - 0.5;
	vec2 uv_bent = uv + (slow * 0.5 + fine * 0.1) * cloud_detail;
	vec4 texel = texture_bicubic(sky_texture, uv_bent, vec4(-1e6, -1e6, 1e6, 1e6));
	float density = luma(texel.rgb) * texel.a;

	vec4 average = textureLod(sky_texture, vec2(0.5), 16.0);
	texel = max(average + (texel - average) * (1.0 + 0.7 * cloud_detail), vec4(0.0));
	texel.a = min(texel.a, 1.0);
	texel.rgb *= 1.0 + fine.x * 0.3 * cloud_detail;

	float shade = 1.0;
	vec3 lining = vec3(0.0);
	if (LIGHT0_ENABLED) {
		vec2 sun_way = vec2(-LIGHT0_DIRECTION.x, LIGHT0_DIRECTION.z);
		float flat_length = length(sun_way);
		if (flat_length > 0.001) {
			vec2 toward_sun = uv_bent + sun_way / flat_length * 0.09 * cloud_uv_scale;
			vec4 neighbour = textureLod(sky_texture, toward_sun, 0.0);
			float neighbour_density = luma(neighbour.rgb) * neighbour.a;
			float relief = (density - neighbour_density) / (density + neighbour_density + 0.02);
			shade += clamp(relief * 2.0, -0.4, 0.8) * cloud_relief * cloud_detail;
		}
		float towards = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		float relative = clamp(0.5 * density / max(luma(average.rgb) * average.a, 0.01), 0.0, 1.0);
		lining = to_gamma(LIGHT0_COLOR) * pow(towards, 16.0) * 4.0 * relative * (1.0 - relative) * field
				* 0.5 * cloud_silver_lining * cloud_detail;
	}

	vec2 from_root = p - strike.xy;
	float flash = strike.z * exp(-dot(from_root, from_root) / (600.0 * 600.0));
	float lit = max(field, flash);
	float coverage = cloud_type == 2 ? texel.a * field : min(2.0 * luma(texel.rgb), 1.0);
	vec3 flash_light = BOLT_COLOR * flash * coverage * 0.5 * lightning_flash;

	float rim = 1.0 - smoothstep(0.8, 1.0, rho / DOME_RADIUS);
	float haze = cloud_fog ? horizon_haze * smoothstep(0.3, 1.0, rho / DOME_RADIUS) : 0.0;

	vec3 color = texel.rgb * lit * shade + lining + flash_light;
	if (cloud_type == 2) {
		return vec4(mix(color, to_gamma(fog_color), haze), clamp(texel.a * field, 0.0, 1.0) * rim);
	}
	return vec4(color * rim * (1.0 - haze), 0.0);
}

vec4 sun_sprite(vec3 dir) {
	if (!LIGHT0_ENABLED) {
		return vec4(0.0);
	}
	float facing = dot(dir, LIGHT0_DIRECTION);
	vec3 flat_cross = cross(LIGHT0_DIRECTION, vec3(0.0, 1.0, 0.0));
	if (facing <= 0.0 || dot(flat_cross, flat_cross) < 1e-6) {
		return vec4(0.0);
	}
	vec3 right = normalize(flat_cross);
	vec3 up = cross(LIGHT0_DIRECTION, right);
	float flat_length = sqrt(max(1.0 - LIGHT0_DIRECTION.y * LIGHT0_DIRECTION.y, 0.0));
	float half_size = sun_world_radius * flat_length / (sqrt(2.0) * DOME_RADIUS);
	vec2 offset = vec2(dot(right, dir), dot(up, dir)) / (facing * max(half_size, 1e-5));
	vec4 color = textureLod(sun_texture, offset * 0.5 + 0.5, 0.0);
	color *= step(max(abs(offset.x), abs(offset.y)), 1.0) * (1.0 - smoothstep(0.85, 1.0, length(offset)));
	return color;
}

vec3 blend_sun(vec3 color, vec4 sun) {
	return sun_additive ? color + sun.rgb * sun.a : mix(color, sun.rgb, sun.a);
}

void sky() {
	vec3 dir_dx = dFdxFine(EYEDIR);
	vec3 dir_dy = dFdyFine(EYEDIR);
	vec2 uv_step = vec2(dFdx(SCREEN_UV.x), dFdy(SCREEN_UV.y));
	bool flat_view = AT_CUBEMAP_PASS || AT_HALF_RES_PASS || AT_QUARTER_RES_PASS
			|| abs(uv_step.x) < 1e-9 || abs(uv_step.y) < 1e-9;

	vec2 flat_dir = EYEDIR.xz;
	float flat_length = max(length(flat_dir), 1e-5);
	vec2 forward = flat_dir / flat_length;
	if (!flat_view) {
		vec2 size = round(FRAGCOORD.xy / mix(SCREEN_UV, 1.0 - SCREEN_UV, lessThan(uv_step, vec2(0.0))));
		vec2 solved = camera_forward(EYEDIR, dir_dx, dir_dy, FRAGCOORD.xy, size).xz;
		vec2 candidate = dot(solved, solved) > 1e-4 ? normalize(solved) : forward;
		if (dot(flat_dir, candidate) > 1e-4
				&& abs(dot(flat_dir, vec2(-candidate.y, candidate.x))) <= PI * dot(flat_dir, candidate)) {
			forward = candidate;
		}
	}
	float depth = dot(flat_dir, forward);
	float across = dot(flat_dir, vec2(-forward.y, forward.x)) / depth;
	float wall_y = hrz_radius * EYEDIR.y / depth;
	float pano = fract(hrz_angle + (atan(-forward.x, forward.y) + across) / TAU);

	float horizon_y = hrz_bottom_y_off + hrz_gouraud_middle;
	float sky_height = max(hrz_gouraud_height - hrz_gouraud_middle, 0.001);
	vec3 ring = mix(to_gamma(sun_side_color), to_gamma(opposite_side_color), horizon_ring_weight(pano));
	vec3 color = mix(ring, to_gamma(top_side_color), band_ease((wall_y - horizon_y) / sky_height));

	vec4 sun = sun_sprite(EYEDIR);
	if (!sun_in_front) {
		color = blend_sun(color, sun);
	}

	vec2 lightning = lightning_state();
	float strike = bolt_intensity(lightning.y);
	uint seed = uint(lightning.x);
	vec2 origin = bolt_origin(seed);
	float slope = EYEDIR.y / flat_length;
	float pixel_angle = max(length(dir_dx), 1e-7);
	float dome_base = cloud_y_offset - POSITION.y;
	float rho = dome_hit(slope, dome_base);
	if (rho >= 0.0) {
		vec2 heading = vec2(-flat_dir.x, flat_dir.y) / flat_length;
		vec2 p = rho * heading;
		if (cloud_type != 0) {
			float sagged = rho;
			for (int i = 0; i < 2; i++) {
				float sag = 0.5 * cloud_height * cloud_nimbus * cloud_field(sagged * heading);
				float hit = dome_hit(slope, dome_base - sag);
				sagged = hit >= 0.0 ? hit : sagged;
			}
			vec4 cloud = cloud_layer(sagged * heading, dome_footprint(sagged, slope, pixel_angle), EYEDIR, vec3(origin, strike));
			vec3 clouded = cloud_type == 2 ? mix(color, cloud.rgb, cloud.a) : color + cloud.rgb;
			color = mix(clouded, soft_clip(clouded), cloud_detail);
		}
		float reach = 30.0 * dome_footprint(rho, slope, pixel_angle) + 20.0;
		if (strike > 0.0 && !flat_view && distance(p, origin) < float(BOLT_SEGMENTS) * BOLT_STEP + reach) {
			vec2 glow = bolt(p, reach, EYEDIR, 1.0 / pixel_angle, seed, lightning.y);
			color += BOLT_COLOR * (glow.x + 0.6 * glow.y) * strike;
		}
	}

	if (sun_in_front) {
		color = blend_sun(color, sun);
	}

	vec3 haze_color = to_gamma(fog_color);
	float earth_mix = band_ease((wall_y - hrz_bottom_y_off) / max(hrz_gouraud_middle, 0.001));
	vec3 earth = mix(mix(to_gamma(earth_bottom), to_gamma(earth_top), earth_mix), haze_color, horizon_haze);
	float seam = horizon_softness * sky_height;
	float above = seam > 0.0 ? smoothstep(-seam, seam, wall_y - horizon_y) : step(horizon_y, wall_y);
	color = mix(earth, color, above);

	float pmx_bottom = hrz_bottom_y_off + hrz_pmx_bottom;
	float pmx_v = 1.0 - (wall_y - pmx_bottom) / max(hrz_pmx_top - hrz_pmx_bottom, 0.001);
	float segment = pano * 16.0;
	float tile = hrz_mirror ? 8.0 - abs(segment - 8.0) : segment;
	vec2 pmx_texel = 0.5 / vec2(textureSize(panorama_texture, 0));
	vec4 pmx_bounds = vec4(
		hrz_mirror ? pmx_texel.x : -1e6,
		pmx_atlas_v.x + pmx_texel.y,
		hrz_mirror ? 1.0 - pmx_texel.x : 1e6,
		pmx_atlas_v.x + pmx_atlas_v.y - pmx_texel.y
	);
	vec2 pmx_uv = vec2(tile / 8.0, pmx_atlas_v.x + clamp(pmx_v, 0.0, 1.0) * pmx_atlas_v.y);
	vec4 pmx = texture_bicubic(panorama_texture, pmx_uv, pmx_bounds);
	float edge = mix(0.5, clamp(fwidth(pmx.a), 0.02, 0.5), panorama_sharpness);
	float pmx_alpha = smoothstep(0.5 - edge, 0.5 + edge, pmx.a);
	if (hrz_has_pmx && pmx_v >= 0.0 && pmx_v <= 1.0) {
		color = mix(color, mix(pmx.rgb, haze_color, horizon_haze), pmx_alpha);
	}

	color += (interleaved_gradient_noise(FRAGCOORD.xy) - 0.5) / 255.0;
	COLOR = to_linear(max(color, vec3(0.0)));
}

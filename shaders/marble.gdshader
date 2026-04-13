shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

// Matiz acumulado vindo do script (0..1). O script é a fonte da verdade,
// pra que a luz Omni e o turbilhão fiquem sempre na mesma cor.
uniform float hue_offset = 0.0;
uniform float swirl_speed : hint_range(0.0, 8.0) = 1.2;
uniform float glow_strength : hint_range(0.0, 5.0) = 1.6;
uniform float saturation : hint_range(0.0, 1.0) = 0.7;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);

varying vec3 v_local;

// Hash e ruído de valor 3D (rápido, sem texturas).
vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7,  74.7)),
	         dot(p, vec3(269.5, 183.3, 246.1)),
	         dot(p, vec3(113.5, 271.9, 124.6)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(dot(hash3(i + vec3(0,0,0)), f - vec3(0,0,0)),
	                   dot(hash3(i + vec3(1,0,0)), f - vec3(1,0,0)), u.x),
	               mix(dot(hash3(i + vec3(0,1,0)), f - vec3(0,1,0)),
	                   dot(hash3(i + vec3(1,1,0)), f - vec3(1,1,0)), u.x), u.y),
	           mix(mix(dot(hash3(i + vec3(0,0,1)), f - vec3(0,0,1)),
	                   dot(hash3(i + vec3(1,0,1)), f - vec3(1,0,1)), u.x),
	               mix(dot(hash3(i + vec3(0,1,1)), f - vec3(0,1,1)),
	                   dot(hash3(i + vec3(1,1,1)), f - vec3(1,1,1)), u.x), u.y), u.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.3);
		a *= 0.5;
	}
	return v;
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	// Coordenada interna normalizada (assume SphereMesh raio 0.5).
	vec3 p = v_local / 0.185;
	float r = length(p);

	// Twist: rotaciona xz com ângulo dependente de y, criando o turbilhão.
	float ang = TIME * swirl_speed + p.y * 3.5;
	float cs = cos(ang);
	float sn = sin(ang);
	p.xz = mat2(vec2(cs, -sn), vec2(sn, cs)) * p.xz;

	// Camadas de fbm em movimento, somadas pra dar a sensação de florescer.
	float n1 = fbm(p * 4.5 + vec3(0.0, TIME * 0.35, 0.0));
	float n2 = fbm(p * 2.2 - vec3(TIME * 0.2, 0.0, TIME * 0.15));
	float n  = pow(max(n1 * 0.7 + n2 * 0.5 + 0.25, 0.0), 1.7);

	// Núcleo brilhante, decai pra borda.
	float core = smoothstep(1.05, 0.0, r);

	// Fresnel pra um halo de borda fino.
	vec3 nrm = normalize(NORMAL);
	vec3 vw  = normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(nrm, vw), 0.0, 1.0), 2.8);

	vec3 col = hsv2rgb(vec3(fract(hue_offset), saturation, 1.0)) * tint;

	float intensity = n * core * glow_strength + fres * 0.7;
	ALBEDO = col * intensity;
	ALPHA  = clamp(intensity, 0.0, 1.0);
}

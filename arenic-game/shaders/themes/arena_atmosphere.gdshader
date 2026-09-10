shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix, depth_draw_never;

uniform vec4 base_100 : source_color;
uniform vec4 base_300 : source_color;
uniform vec4 primary : source_color;
uniform vec4 secondary : source_color;
uniform vec4 accent : source_color;
uniform int style = 0;
uniform float scale = 3.0;
uniform vec2 drift;
uniform float coverage = .5;
uniform float vignette = .4;
uniform float speed = 1.0;
uniform bool foreground = false;
uniform float atmosphere_time = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
#include "res://shaders/themes/arena_regions.gdshaderinc"

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float field(vec2 p) {
	float value = 0.0;
	float weight = .57;
	for (int i=0; i<3; i++) { value += noise(p)*weight; p = p*2.07+vec2(17.1,9.2); weight *= .48; }
	return value;
}
void vertex() {
	region_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 pixel = floor(UV * vec2(1254.0,589.0));
	vec2 uv = (pixel+.5) / vec2(1254.0,589.0);
	vec2 p = (uv-.5) * vec2(2.129,1.0);
	float t = atmosphere_time * speed;
	vec2 flow = p*scale + drift*t;
	float f = field(flow);
	if (style == 0) f = field(flow*vec2(.7,2.5)+vec2(sin(flow.y*.7+t*.05)*.3,0));
	if (style == 1) f = field(flow+vec2(field(flow*.8+t*.025),field(flow*.7-t*.018))*.9);
	if (style == 2) f = field(flow*vec2(2.0,.55));
	if (style == 3) { float a=atan(p.y,p.x)+length(p)*4.0+t*.03; f=field(vec2(cos(a),sin(a))*length(p)*scale); }
	if (style == 5) f = smoothstep(.3,.7,sin(p.x*4.0+p.y*2.0-t*.12)*.5+.5)*field(flow);
	if (style == 6) f *= .72 + .28*sin(t*.85+length(p)*4.0);
	if (style == 7) f = field(flow)*(.6+.4*(1.0-smoothstep(.0,1.3,length(p-vec2(-.75,-.2)))));
	if (style == 10) f = (.5+.5*sin(length(p)*33.0-t*.65+f*3.0))*.65;
	float border = 1.0-smoothstep(.04,.36,min(min(uv.x,1.0-uv.x),min(uv.y,1.0-uv.y)));
	float regional_mix = arena_region_mix(region_world_xz);
	float cloud = smoothstep(1.0-coverage-.17,1.0-coverage+.28,f);
	if (!foreground) {
		vec3 base = mix(base_300.rgb,base_100.rgb,.25);
		base = mix(base,primary.rgb,cloud*.30*strength);
		base = mix(base,secondary.rgb,smoothstep(.68,.9,f)*.16*strength);
		ALBEDO = base*(1.0-border*vignette*.32);
		if (regional_mix > 0.0) {
			ArenaRegionSample regional = arena_region_sample(region_world_xz);
			ALBEDO = mix(ALBEDO, regional.backdrop_color, regional_mix);
		}
		ALPHA = 1.0;
	} else {
		// Fixed, sparse cells: no particle allocation or accumulation over time.
		vec2 dust_uv = pixel / vec2(43.0,37.0) + drift*t*2.0;
		if (style == 4) dust_uv.y += t*.08;
		vec2 dust_cell = floor(dust_uv);
		vec2 local = fract(dust_uv);
		vec2 center = vec2(hash21(dust_cell+7.0),hash21(dust_cell+31.0))*.7+.15;
		vec2 delta = abs(local-center)*vec2(43.0,37.0);
		float mote = step(delta.x, .65)*step(delta.y,style==9 ? 3.0 : .65);
		mote *= step(.88,hash21(dust_cell))*(.35+.65*pow(.5+.5*sin(t*.6+hash21(dust_cell)*12.0),2.0));
		float veil = cloud * .10;
		if (style == 8) veil *= .4;
		if (style == 6) veil *= 1.3;
		ALBEDO = mix(primary.rgb,accent.rgb,clamp(mote+f*.2,0.0,1.0));
		// Center is clear, and actors render above this presentation-only veil.
		ALPHA = border * (veil + mote*.42) * strength;
		if (overview_mix > 0.0 && regions_ready) {
			// Perimeter voices no longer outline nine rectangles from above.
			ALPHA *= (1.0 - regional_mix) * (1.0 - overview_mix * 0.7);
		}
	}
}

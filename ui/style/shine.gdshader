shader_type canvas_item;
// Light sweep across text/icons (menu logo). Presentation only.
uniform float sweep = -1.0;      // 0..1 position of the band, outside = off
uniform float width_px = 600.0;  // horizontal extent the sweep travels across
uniform float offset_px = 0.0;   // this item's x inside that extent (multi-label logos)
varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float x = (lp.x + offset_px + lp.y * 0.45) / width_px;
	float band = 1.0 - smoothstep(0.0, 0.07, abs(x - sweep));
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), band * 0.8);
}

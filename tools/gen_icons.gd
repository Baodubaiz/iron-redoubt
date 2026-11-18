extends SceneTree
## Renders the app icon (res://icon.svg) and the Android launcher icons (PNG) from the Iron Redoubt
## "reactor core" design (B1, chosen 2026-11-13): cyan hexagon frame, glowing reactor core with four
## couplings, orange corner marks.
##   godot --headless --path . -s res://tools/gen_icons.gd
## Outputs res://icon.svg and res://export/icons/: icon_192.png, adaptive_fg_432.png, adaptive_bg_432.png,
## adaptive_mono_432.png

const DEFS := """<defs><radialGradient id="bg" cx="0.5" cy="0.5" r="0.75"><stop offset="0" stop-color="#1B2242"/><stop offset="1" stop-color="#070B16"/></radialGradient>
<radialGradient id="core"><stop offset="0" stop-color="#FFFFFF"/><stop offset="0.35" stop-color="#9CF0FF"/><stop offset="1" stop-color="#38D9F5"/></radialGradient>
<radialGradient id="gl"><stop offset="0" stop-color="#38D9F5" stop-opacity="0.6"/><stop offset="1" stop-color="#38D9F5" stop-opacity="0"/></radialGradient>
<linearGradient id="m" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6A7590"/><stop offset="1" stop-color="#222A40"/></linearGradient></defs>"""

## Artwork in a 512 box (no background).
const ART := """<polygon points="256,70 417,163 417,349 256,442 95,349 95,163" fill="#101A30" stroke="#38D9F5" stroke-width="14" stroke-linejoin="round"/>
<circle cx="256" cy="256" r="150" fill="url(#gl)"/>
<circle cx="256" cy="256" r="112" fill="url(#m)" stroke="#B9C4D4" stroke-width="8"/>
<g stroke="#38D9F5" stroke-width="10" fill="#141C28"><rect x="240" y="128" width="32" height="30" rx="6"/><rect x="240" y="354" width="32" height="30" rx="6"/><rect x="128" y="240" width="30" height="32" rx="6"/><rect x="354" y="240" width="30" height="32" rx="6"/></g>
<circle cx="256" cy="256" r="74" fill="#0B1020" stroke="#38D9F5" stroke-width="6"/>
<path d="M256,182 A74,74 0 0 1 330,256 M256,330 A74,74 0 0 1 182,256" fill="none" stroke="#9CF0FF" stroke-width="12"/>
<circle cx="256" cy="256" r="40" fill="url(#core)"/>
<path d="M130,420 L170,380 M382,420 L342,380 M130,92 L170,132 M382,92 L342,132" stroke="#FFAA45" stroke-width="12" stroke-linecap="round"/>"""

## Single-colour silhouette for Android themed icons.
const MONO_ART := """<polygon points="256,70 417,163 417,349 256,442 95,349 95,163" fill="none" stroke="#fff" stroke-width="22" stroke-linejoin="round"/>
<circle cx="256" cy="256" r="112" fill="none" stroke="#fff" stroke-width="16"/>
<circle cx="256" cy="256" r="44" fill="#fff"/>
<g fill="#fff"><rect x="240" y="128" width="32" height="30" rx="6"/><rect x="240" y="354" width="32" height="30" rx="6"/><rect x="128" y="240" width="30" height="32" rx="6"/><rect x="354" y="240" width="30" height="32" rx="6"/></g>"""

const SVG := """<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">%s</svg>"""
## Adaptive icons: Android masks to a circle/squircle; the safe zone is the central 66%, so the
## artwork is scaled to 85% of the canvas (its hexagon fits inside the safe circle).
const SAFE := """<g transform="translate(38.4,38.4) scale(0.85)">%s</g>"""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://export/icons")
	var full := SVG % (DEFS + """<rect width="512" height="512" rx="96" fill="url(#bg)"/>""" + ART)
	var f := FileAccess.open("res://icon.svg", FileAccess.WRITE)
	f.store_string(full)
	f.close()
	_render(full, 192, "res://export/icons/icon_192.png")
	_render(SVG % (DEFS + SAFE % ART), 432, "res://export/icons/adaptive_fg_432.png")
	_render(SVG % (DEFS + """<rect width="512" height="512" fill="url(#bg)"/>"""), 432, "res://export/icons/adaptive_bg_432.png")
	_render(SVG % (SAFE % MONO_ART), 432, "res://export/icons/adaptive_mono_432.png")
	print("gen_icons: done")
	quit(0)


func _render(svg: String, size: int, path: String) -> void:
	var img := Image.new()
	var err := img.load_svg_from_string(svg, float(size) / 512.0)
	if err != OK:
		push_error("svg render failed: %s" % path)
		return
	if img.get_width() != size:
		img.resize(size, size, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)

@tool
extends Control
class_name BannerArt
## The artwork of a street banner (the roadblock hung across the skyway), drawn at 1024 x 640 and baked to a texture
## by tools/editor/build_banners.gd. Three styles, one per era:
##   "gaslight"  the Past: a cloth banner like London's jubilee and music-hall bills, deep cloth, gilt double frame
##               with corner scrolls, a fat serif headline, a fringe and tassels
##   "carnival"  the Present: a samba-school flag (the gyronny of triangles in the school's colours), a medallion,
##               a script headline, the Copacabana wave along the hem, a fringe of coloured tassels
##   "led"       the Future: an LED mesh panel, dot matrix and scanlines, neon edge tubes and corner brackets
## Open scenes/gfx_banner/banner_art.tscn in the editor to try words and colours; the city list is data/banners.json.

const W := 1024
const H := 640

@export_enum("gaslight", "carnival", "led") var style := "gaslight":
	set(v):
		style = v
		queue_redraw()
## the small line along the top, the headline, the line under it
@export var top := "ROYAL ALHAMBRA · LEICESTER SQUARE":
	set(v):
		top = v
		queue_redraw()
@export var headline := "GRAND VARIETY":
	set(v):
		headline = v
		queue_redraw()
@export var sub := "Every Evening at Eight":
	set(v):
		sub = v
		queue_redraw()
## cloth (or panel), second colour, trim (gilt, tassels, neon), lettering
@export var cloth := Color("7a1424"):
	set(v):
		cloth = v
		queue_redraw()
@export var second := Color("0f2a4a"):
	set(v):
		second = v
		queue_redraw()
@export var trim := Color("e8bf62"):
	set(v):
		trim = v
		queue_redraw()
@export var ink := Color("fff3d6"):
	set(v):
		ink = v
		queue_redraw()

var _abril: Font = preload("res://fonts/AbrilFatface-Regular.ttf")
var _lobster: Font = preload("res://fonts/Lobster-Regular.ttf")
var _bungee: Font = preload("res://fonts/Bungee-Regular.ttf")
var _syncopate: Font = preload("res://fonts/Syncopate-Bold.ttf")
var _outfit: Font = preload("res://fonts/Outfit.ttf")
var _playfair: FontVariation


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	_playfair = FontVariation.new()
	_playfair.base_font = preload("res://fonts/PlayfairDisplay.ttf")
	_playfair.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}


func _draw() -> void:
	match style:
		"gaslight":
			_gaslight()
		"carnival":
			_carnival()
		_:
			_led()


# ------------------------------------------------------------------ the Past: a gilt-framed cloth bill

func _gaslight() -> void:
	var body := Rect2(0, 34, W, 470)
	var deep := cloth.darkened(0.45)
	# the hem along the top, with its brass grommets, sewn over the cable
	draw_rect(Rect2(0, 0, W, 40), deep)
	for i in 9:
		var x := 56.0 + i * (W - 112.0) / 8.0
		draw_circle(Vector2(x, 20), 9, trim.darkened(0.25))
		draw_circle(Vector2(x, 20), 5, deep.darkened(0.5))
	# the cloth: lit in the middle, falling off to the edges, with a faint woven damask of lozenges
	_vgrad(body, cloth.lightened(0.08), cloth.darkened(0.18))
	for gy in range(0, 10):
		for gx in range(0, 17):
			var c := Vector2(30 + gx * 61 + (30 if gy % 2 else 0), 60 + gy * 46)
			if body.has_point(c):
				_lozenge(c, 9, 14, Color(1, 1, 1, 0.035))
	_vignette(body, 0.38)
	# the scalloped valance under the cloth, then the gold fringe and three tassels
	var n := 12
	var sw := float(W) / n
	for i in n:
		var cx := sw * (i + 0.5)
		draw_rect(Rect2(i * sw, body.end.y - 2, sw, 28), cloth.darkened(0.25))
		draw_circle(Vector2(cx, body.end.y + 26), sw / 2.0, cloth.darkened(0.25))
		draw_arc(Vector2(cx, body.end.y + 26), sw / 2.0 - 5, 0.15, PI - 0.15, 18, trim, 3.0, true)
	var fy := body.end.y + 26 + sw / 2.0 - 6
	for i in 220:
		var x := 6.0 + i * (W - 12.0) / 219.0
		var len := 46.0 + 7.0 * sin(i * 0.9) + 4.0 * sin(i * 2.3)
		draw_line(Vector2(x, fy - 4), Vector2(x + 1.5, fy + len), trim.darkened(0.15 + 0.2 * float(i % 3 == 0)), 2.2, true)
	for tx in [W * 0.18, W * 0.5, W * 0.82]:
		_tassel(Vector2(tx, fy - 10))
	# the gilt double frame with scrolls in the corners
	var f1 := body.grow(-26)
	var f2 := body.grow(-38)
	draw_rect(f1, trim, false, 5.0, true)
	draw_rect(f2, trim.darkened(0.2), false, 2.0, true)
	for c in [f1.position, Vector2(f1.end.x, f1.position.y), f1.end, Vector2(f1.position.x, f1.end.y)]:
		_corner_scroll(c, f1.get_center())
	# the words: a letter-spaced line on top, the fat gilt headline, a rule with a diamond, the line under it
	_text_spaced(_playfair, top, Vector2(W / 2.0, 122), 25, 6.0, ink.darkened(0.08))
	_gilt_headline(_abril, headline, Vector2(W / 2.0, 268), 132, f2.size.x - 90)
	var ry := 318.0
	draw_line(Vector2(W / 2.0 - 230, ry), Vector2(W / 2.0 - 26, ry), trim, 3.0, true)
	draw_line(Vector2(W / 2.0 + 26, ry), Vector2(W / 2.0 + 230, ry), trim, 3.0, true)
	_lozenge(Vector2(W / 2.0, ry), 12, 16, trim)
	_lozenge(Vector2(W / 2.0, ry), 5, 7, cloth)
	for s in [-1, 1]:
		_star(Vector2(W / 2.0 + s * 262, ry), 11, trim)
	_text_center(_playfair, sub, Vector2(W / 2.0, 398), 44, ink)


func _gilt_headline(font: Font, text: String, at: Vector2, px: int, max_w: float) -> void:
	## fat letters in gilt: a dark cast shadow, a deep gold edge, the bright face, a light along the top
	var size := _fit(font, text, px, max_w)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(at.x - w / 2.0, at.y)
	draw_string_outline(font, p + Vector2(5, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, Color(0, 0, 0, 0.45))
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 12, cloth.darkened(0.6))
	draw_string(font, p + Vector2(0, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, trim.darkened(0.35))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, trim)
	draw_string(font, p - Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(trim.lightened(0.45), 0.35))


func _corner_scroll(c: Vector2, centre: Vector2) -> void:
	## a gilt corner piece: a rosette, two arms ending in lozenges, a quarter arc and a fan of three leaves
	var d: Vector2 = (centre - c).sign()
	for axis in [Vector2(d.x, 0), Vector2(0, d.y)]:
		draw_line(c + axis * 14, c + axis * 74, trim, 3.0, true)
		_lozenge(c + axis * 80, 5, 5, trim)
	var a0 := atan2(0.0, d.x)
	var a1 := atan2(d.y, 0.0)
	if absf(a1 - a0) > PI:
		a1 += TAU * signf(a0 - a1)
	draw_arc(c, 40, a0, a1, 16, trim, 2.5, true)
	draw_arc(c, 50, a0, a1, 16, Color(trim, 0.55), 1.5, true)
	var diag := d.normalized()
	for k in [-1, 0, 1]:
		var dir := diag.rotated(k * 0.42)
		var tip := c + dir * 32
		var side := dir.orthogonal() * 4.5
		draw_colored_polygon(PackedVector2Array([c + dir * 12, tip - dir * 9 + side, tip, tip - dir * 9 - side]), trim)
	draw_circle(c, 10, trim)
	draw_circle(c, 5.5, cloth.darkened(0.35))
	draw_circle(c, 2.5, trim.lightened(0.3))


func _tassel(top_pt: Vector2) -> void:
	draw_circle(top_pt, 12, trim.darkened(0.1))
	draw_rect(Rect2(top_pt.x - 8, top_pt.y + 6, 16, 10), trim.darkened(0.3))
	for k in 13:
		var x := top_pt.x - 15 + k * 2.5
		draw_line(Vector2(x, top_pt.y + 14), Vector2(x + (k - 6) * 0.6, top_pt.y + 78), trim.darkened(0.05 + 0.15 * (k % 2)), 2.0, true)


# ------------------------------------------------------------------ the Present: a samba-school flag

func _carnival() -> void:
	var body := Rect2(0, 30, W, 452)
	draw_rect(Rect2(0, 0, W, 36), second.darkened(0.35))
	for i in 9:
		var x := 56.0 + i * (W - 112.0) / 8.0
		draw_circle(Vector2(x, 18), 8, Color(0.92, 0.92, 0.95))
		draw_circle(Vector2(x, 18), 4, second.darkened(0.6))
	# the gyronny: triangles radiating from the medallion in the school's two colours
	var cen := Vector2(W / 2.0, body.position.y + 146)
	draw_rect(body, cloth)
	var wedges := 20
	for i in wedges:
		if i % 2 == 1:
			continue
		var a0 := TAU * i / wedges - PI / 2
		var a1 := TAU * (i + 1) / wedges - PI / 2
		var poly := PackedVector2Array([cen, cen + Vector2(cos(a0), sin(a0)) * 1400, cen + Vector2(cos(a1), sin(a1)) * 1400])
		draw_colored_polygon(_clip_poly(poly, body), second)
	_vignette(body, 0.32)
	# a sunburst of light behind the medallion and a scatter of confetti and sequins
	for r in range(220, 0, -20):
		draw_circle(cen, r, Color(1, 0.95, 0.75, 0.035))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(headline)
	var confetti := [trim, ink, Color("ff4f9a"), Color("3fd0ff"), Color("ffe14a")]
	for i in 70:
		var p := Vector2(rng.randf_range(20, W - 20), rng.randf_range(body.position.y + 14, body.end.y - 110))
		if p.distance_to(cen) < 100 or (p.y > 250 and p.y < 370 and absf(p.x - W / 2.0) < 330):
			continue
		var c: Color = confetti[i % confetti.size()]
		if i % 3 == 0:
			draw_circle(p, rng.randf_range(3, 6), c)
		else:
			var ang := rng.randf() * PI
			var v := Vector2(cos(ang), sin(ang)) * rng.randf_range(5, 9)
			draw_line(p - v, p + v, c, 4.0, true)
	# the medallion: a white rim, the school's star with a crown of rays
	draw_circle(cen + Vector2(3, 5), 80, Color(0, 0, 0, 0.25))
	draw_circle(cen, 78, ink)
	draw_circle(cen, 69, second)
	draw_circle(cen, 64, cloth.lightened(0.1))
	for k in 24:
		var ang := TAU * k / 24.0
		draw_line(cen + Vector2(cos(ang), sin(ang)) * 42, cen + Vector2(cos(ang), sin(ang)) * (59 if k % 2 == 0 else 53), trim, 3.5, true)
	_star(cen, 37, trim)
	_star(cen, 17, ink)
	# the words: the school's name in block capitals, the headline in a carnival script, the line under it
	_text_spaced(_bungee, top, Vector2(W / 2.0, 66), 26, 3.0, ink, Color(0, 0, 0, 0.55))
	var size := _fit(_lobster, headline, 132, W - 140)
	var w := _lobster.get_string_size(headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(W / 2.0 - w / 2.0, 352)
	draw_string_outline(_lobster, p + Vector2(6, 8), headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 18, Color(0, 0, 0, 0.4))
	draw_string_outline(_lobster, p, headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 16, second.darkened(0.55))
	draw_string_outline(_lobster, p, headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, ink)
	draw_string(_lobster, p, headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size, trim)
	# the Copacabana wave along the hem (black and white stones), the line under it on a band
	var band := Rect2(0, body.end.y - 96, W, 96)
	draw_rect(band, Color(0.96, 0.95, 0.92))
	var pts := PackedVector2Array()
	for k in 129:
		var x := k * W / 128.0
		pts.append(Vector2(x, band.position.y + 50 + sin(x / W * TAU * 5.0) * 26))
	pts.append(Vector2(W, band.end.y))
	pts.append(Vector2(0, band.end.y))
	draw_colored_polygon(pts, Color(0.08, 0.08, 0.09))
	var sub_band := Rect2(W / 2.0 - 300, band.position.y - 30, 600, 58)
	_round_rect(sub_band, 29, second.darkened(0.25))
	_round_rect(sub_band.grow(-5), 24, second)
	_text_center(_outfit, sub, sub_band.get_center() + Vector2(0, 13), 34, ink)
	# a zigzag hem of pennant points, each with a coloured tassel
	var n := 16
	var sw := float(W) / n
	for i in n:
		var x0 := i * sw
		var tri := PackedVector2Array([Vector2(x0, body.end.y - 1), Vector2(x0 + sw, body.end.y - 1), Vector2(x0 + sw / 2, body.end.y + 44)])
		draw_colored_polygon(tri, cloth if i % 2 == 0 else second)
		var tip := Vector2(x0 + sw / 2, body.end.y + 44)
		var tc: Color = confetti[i % confetti.size()]
		draw_circle(tip, 7, tc)
		for k in 7:
			draw_line(tip + Vector2(-6 + k * 2, 4), tip + Vector2(-8 + k * 2.7, 52), tc.darkened(0.1 * (k % 2)), 2.0, true)


# ------------------------------------------------------------------ the Future: an LED mesh panel

func _led() -> void:
	var r := Rect2(8, 8, W - 16, 560)
	var ch := 34.0
	var shape := PackedVector2Array([r.position + Vector2(ch, 0), Vector2(r.end.x - ch, r.position.y), Vector2(r.end.x, r.position.y + ch),
		r.end - Vector2(0, ch), r.end - Vector2(ch, 0), Vector2(r.position.x + ch, r.end.y), Vector2(r.position.x, r.end.y - ch), r.position + Vector2(0, ch)])
	draw_colored_polygon(shape, Color(0.02, 0.025, 0.05))
	# a deep glow of the panel's colour, the dot matrix and the scanlines
	for k in 10:
		var g := r.grow(-k * 22)
		draw_rect(g, Color(cloth, 0.022))
	for y in range(int(r.position.y) + 12, int(r.end.y) - 8, 9):
		for x in range(int(r.position.x) + 14, int(r.end.x) - 10, 9):
			draw_rect(Rect2(x, y, 3, 3), Color(cloth.lightened(0.3), 0.07))
	for y in range(int(r.position.y), int(r.end.y), 4):
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(0, 0, 0, 0.22), 1.0)
	# neon tubes round the edge, brackets in the corners, a strip of chevrons and a level meter
	_neon_poly(shape, cloth, 5.0)
	var inner := r.grow(-26)
	for c in [inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]:
		var d: Vector2 = (inner.get_center() - c).sign()
		_neon_line(c, c + Vector2(d.x * 70, 0), second, 4.0)
		_neon_line(c, c + Vector2(0, d.y * 46), second, 4.0)
	_text_spaced(_outfit, top, Vector2(W / 2.0, 104), 28, 10.0, Color(second.lightened(0.35), 0.95))
	# the headline: lit letters with a bloom
	var size := _fit(_syncopate, headline, 108, inner.size.x - 80)
	var w := _syncopate.get_string_size(headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := Vector2(W / 2.0 - w / 2.0, 296)
	for k in [26, 16, 8]:
		draw_string_outline(_syncopate, p, headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size, k, Color(cloth, 0.13))
	draw_string_outline(_syncopate, p, headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, cloth.lightened(0.2))
	draw_string(_syncopate, p, headline, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	_text_spaced(_outfit, sub, Vector2(W / 2.0, 380), 38, 4.0, ink.darkened(0.08))
	var cy := 470.0
	for k in 12:
		var x := W / 2.0 - 330 + k * 26
		var a := 0.25 + 0.75 * (k / 11.0)
		draw_polyline(PackedVector2Array([Vector2(x, cy - 16), Vector2(x + 14, cy), Vector2(x, cy + 16)]), Color(trim, a), 6.0, true)
	for k in 14:
		var hgt: float = 8.0 + 26.0 * absf(sin(k * 1.7 + headline.length()))
		draw_rect(Rect2(W / 2.0 + 60 + k * 19, cy + 16 - hgt, 12, hgt), Color(second, 0.85))
	# under the panel: the cable tray and the hanging pixel drips of the mesh edge
	draw_rect(Rect2(60, r.end.y + 8, W - 120, 10), Color(0.25, 0.27, 0.32))
	for k in 46:
		var x := 80.0 + k * (W - 160.0) / 45.0
		var len: float = 16.0 + 24.0 * absf(sin(k * 0.77))
		draw_line(Vector2(x, r.end.y + 18), Vector2(x, r.end.y + 18 + len), Color(cloth, 0.55), 3.0)
		draw_rect(Rect2(x - 3, r.end.y + 18 + len, 6, 6), Color(cloth.lightened(0.4), 0.9))


func _neon_poly(pts: PackedVector2Array, c: Color, wdt: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	for k in [5.0, 3.2, 2.0]:
		draw_polyline(closed, Color(c, 0.12), wdt * k, true)
	draw_polyline(closed, c, wdt, true)
	draw_polyline(closed, c.lightened(0.6), wdt * 0.4, true)


func _neon_line(a: Vector2, b: Vector2, c: Color, wdt: float) -> void:
	for k in [4.0, 2.4]:
		draw_line(a, b, Color(c, 0.14), wdt * k, true)
	draw_line(a, b, c, wdt, true)
	draw_line(a, b, c.lightened(0.6), wdt * 0.4, true)


# ------------------------------------------------------------------ shared drawing

func _vgrad(r: Rect2, top_c: Color, bottom_c: Color) -> void:
	var steps := 48
	for k in steps:
		var t := k / float(steps - 1)
		var mid := 1.0 - absf(t - 0.42) * 1.6
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y * k / steps, r.size.x, r.size.y / steps + 1), top_c.lerp(bottom_c, t).lightened(maxf(mid, 0.0) * 0.06))


func _vignette(r: Rect2, strength: float) -> void:
	for k in 14:
		var g := k * 6.0
		var a := strength * pow(1.0 - k / 14.0, 2.0) * 0.18
		draw_rect(Rect2(r.position.x + g, r.position.y + g, r.size.x - 2 * g, r.size.y - 2 * g), Color(0, 0, 0, a), false, 6.0)


func _lozenge(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0)]), col)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var ang := -PI / 2 + k * PI / 5
		pts.append(c + Vector2(cos(ang), sin(ang)) * (r if k % 2 == 0 else r * 0.42))
	draw_colored_polygon(pts, col)


func _round_rect(r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _fit(font: Font, text: String, px: int, max_w: float) -> int:
	var s := px
	while s > 20 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x > max_w:
		s -= 2
	return s


func _text_center(font: Font, text: String, at: Vector2, px: int, col: Color) -> void:
	var s := _fit(font, text, px, W - 140)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	draw_string(font, Vector2(at.x - w / 2.0, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)


func _text_spaced(font: Font, text: String, at: Vector2, px: int, spacing: float, col: Color, shadow := Color(0, 0, 0, 0)) -> void:
	## small capitals with air between the letters, centred
	var widths := []
	var total := 0.0
	for ch in text:
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		widths.append(cw)
		total += cw + spacing
	total -= spacing
	var x := at.x - total / 2.0
	var i := 0
	for ch in text:
		if shadow.a > 0.0:
			draw_string(font, Vector2(x + 2, at.y + 3), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, shadow)
		draw_string(font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
		x += widths[i] + spacing
		i += 1


func _clip_poly(poly: PackedVector2Array, r: Rect2) -> PackedVector2Array:
	var box := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var out := Geometry2D.intersect_polygons(poly, box)
	return out[0] if out.size() > 0 else PackedVector2Array()

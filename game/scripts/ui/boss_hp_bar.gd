extends Control

## Professional boss HP bar for a 320x480 space shooter.
## Public API: show_bar(hp, max_val), update_hp(hp), hide_bar(), set_boss_name(name)

# ------------------------------------------------------------------
# Constants
# ------------------------------------------------------------------
const BAR_WIDTH: float = 260.0
const BAR_HEIGHT: float = 8.0
const BAR_X: float = (320.0 - BAR_WIDTH) / 2.0  # centered
const BAR_Y_TARGET: float = 16.0
const BAR_CORNER_RADIUS: float = 4.0

const ENTRANCE_DURATION: float = 0.3
const ENTRANCE_START_Y: float = -20.0

const FLASH_DURATION: float = 0.15
const HP_LERP_SPEED: float = 3.0
const WARNING_THRESHOLD: float = 0.3
const BLINK_SPEED: float = 5.0  # full cycles per second

# ------------------------------------------------------------------
# State
# ------------------------------------------------------------------
var max_hp: float = 1.0
var target_hp: float = 1.0          # the real HP value we animate toward
var display_hp: float = 1.0         # smoothly interpolated value shown on bar
var bar_visible: bool = false

var flash_timer: float = 0.0        # counts down from FLASH_DURATION
var flash_intensity: float = 0.0    # 1 -> 0 over the flash

var entrance_timer: float = 0.0     # counts up to ENTRANCE_DURATION
var bar_y_offset: float = ENTRANCE_START_Y

var boss_name: String = "BOSS"
var blink_accumulator: float = 0.0  # drives WARNING blink

# ------------------------------------------------------------------
# Public interface
# ------------------------------------------------------------------
func show_bar(hp: float, max_val: float) -> void:
	max_hp = max(max_val, 1.0)
	target_hp = clampf(hp, 0.0, max_hp)
	display_hp = target_hp  # snap on first show
	bar_visible = true
	visible = true
	entrance_timer = 0.0
	bar_y_offset = ENTRANCE_START_Y
	flash_timer = 0.0
	flash_intensity = 0.0
	blink_accumulator = 0.0


func update_hp(hp: float) -> void:
	target_hp = clampf(hp, 0.0, max_hp)
	flash_timer = FLASH_DURATION
	flash_intensity = 1.0


func hide_bar() -> void:
	bar_visible = false
	visible = false


func set_boss_name(new_name: String) -> void:
	boss_name = new_name

# ------------------------------------------------------------------
# Process
# ------------------------------------------------------------------
func _process(delta: float) -> void:
	if not bar_visible:
		return

	# Smooth HP transition
	if not is_equal_approx(display_hp, target_hp):
		display_hp = lerp(display_hp, target_hp, clampf(delta * HP_LERP_SPEED, 0.0, 1.0))
		if absf(display_hp - target_hp) < 0.01:
			display_hp = target_hp

	# Flash fade
	if flash_timer > 0.0:
		flash_timer -= delta
		flash_intensity = clampf(flash_timer / FLASH_DURATION, 0.0, 1.0)
	else:
		flash_intensity = 0.0

	# Entrance slide-in
	if entrance_timer < ENTRANCE_DURATION:
		entrance_timer = minf(entrance_timer + delta, ENTRANCE_DURATION)
		var t: float = entrance_timer / ENTRANCE_DURATION
		# Ease-out quad
		t = 1.0 - (1.0 - t) * (1.0 - t)
		bar_y_offset = lerpf(ENTRANCE_START_Y, BAR_Y_TARGET, t)
	else:
		bar_y_offset = BAR_Y_TARGET

	# Blink accumulator for WARNING
	blink_accumulator += delta * BLINK_SPEED

	queue_redraw()

# ------------------------------------------------------------------
# Draw
# ------------------------------------------------------------------
func _draw() -> void:
	if not bar_visible:
		return

	var hp_ratio: float = clampf(display_hp / max_hp, 0.0, 1.0)
	var fill_width: float = BAR_WIDTH * hp_ratio
	var bar_rect := Rect2(BAR_X, bar_y_offset, BAR_WIDTH, BAR_HEIGHT)
	var fill_rect := Rect2(BAR_X, bar_y_offset, fill_width, BAR_HEIGHT)

	# --- Boss name label ---
	_draw_boss_name(bar_rect)

	# --- Background (dark, semi-transparent, rounded) ---
	var bg_color := Color(0.03, 0.03, 0.1, 0.8)
	_draw_rounded_rect(bar_rect, bg_color, true)

	# --- Outer glow (cyan neon, low opacity) ---
	var glow_rect := Rect2(
		bar_rect.position.x - 1.0,
		bar_rect.position.y - 1.0,
		bar_rect.size.x + 2.0,
		bar_rect.size.y + 2.0
	)
	_draw_rounded_rect(glow_rect, Color(0.2, 0.6, 1.0, 0.15), false, 1.0)

	# --- HP fill with gradient ---
	if fill_width > 0.5:
		_draw_gradient_fill(fill_rect, hp_ratio)

	# --- White flash overlay on hit ---
	if flash_intensity > 0.0 and fill_width > 0.5:
		var flash_color := Color(1.0, 1.0, 1.0, flash_intensity * 0.7)
		_draw_rounded_rect(fill_rect, flash_color, true)

	# --- Thin cyan border ---
	_draw_rounded_rect(bar_rect, Color(0.3, 0.7, 1.0, 0.45), false, 1.0)

	# --- WARNING label ---
	if hp_ratio > 0.0 and hp_ratio < WARNING_THRESHOLD:
		_draw_warning_label(bar_rect)


# ------------------------------------------------------------------
# Draw helpers
# ------------------------------------------------------------------

## Draws a rounded rectangle. If `filled` is true, draws a filled shape.
## Otherwise draws just the outline with the given line width.
func _draw_rounded_rect(rect: Rect2, color: Color, filled: bool = true, line_w: float = 1.0) -> void:
	var r := BAR_CORNER_RADIUS
	# Clamp radius so it never exceeds half the bar dimension
	r = minf(r, rect.size.x * 0.5)
	r = minf(r, rect.size.y * 0.5)

	# Build a rounded-rect polygon (16 segments per corner is plenty)
	var points := PackedVector2Array()
	var seg := 6  # segments per quarter-circle
	var cx: float
	var cy: float

	# Top-left corner
	cx = rect.position.x + r
	cy = rect.position.y + r
	for i in range(seg + 1):
		var angle: float = PI + (PI * 0.5) * (float(i) / float(seg))
		points.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))

	# Top-right corner
	cx = rect.position.x + rect.size.x - r
	cy = rect.position.y + r
	for i in range(seg + 1):
		var angle: float = -PI * 0.5 + (PI * 0.5) * (float(i) / float(seg))
		points.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))

	# Bottom-right corner
	cx = rect.position.x + rect.size.x - r
	cy = rect.position.y + rect.size.y - r
	for i in range(seg + 1):
		var angle: float = 0.0 + (PI * 0.5) * (float(i) / float(seg))
		points.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))

	# Bottom-left corner
	cx = rect.position.x + r
	cy = rect.position.y + rect.size.y - r
	for i in range(seg + 1):
		var angle: float = PI * 0.5 + (PI * 0.5) * (float(i) / float(seg))
		points.append(Vector2(cx + cos(angle) * r, cy + sin(angle) * r))

	if filled:
		draw_colored_polygon(points, color)
	else:
		# Close the loop for polyline
		points.append(points[0])
		draw_polyline(points, color, line_w, true)


## Draws the HP fill bar as a horizontal gradient (green -> yellow -> red)
## mapped to the current hp_ratio so the colour shifts as HP drops.
func _draw_gradient_fill(rect: Rect2, hp_ratio: float) -> void:
	# Determine the fill colour based on hp_ratio using a smooth gradient.
	# ratio 1.0 = green, 0.5 = yellow, 0.0 = red
	var color_left: Color   # colour at the left edge of the filled portion
	var color_right: Color  # colour at the right edge (always the "current hp" colour)

	color_right = _hp_ratio_to_color(hp_ratio)
	# The left edge is slightly more "healthy" coloured to give a gradient feel.
	color_left = _hp_ratio_to_color(clampf(hp_ratio + 0.15, 0.0, 1.0))

	# We draw vertical slices (1px each) to create a smooth horizontal gradient.
	# For performance with a max 260px bar this is fine.
	var slices := int(rect.size.x)
	if slices < 1:
		return

	var r := BAR_CORNER_RADIUS
	r = minf(r, rect.size.x * 0.5)
	r = minf(r, rect.size.y * 0.5)

	for i in range(slices):
		var t: float = float(i) / maxf(float(slices - 1), 1.0)
		var col: Color = color_left.lerp(color_right, t)
		var x: float = rect.position.x + float(i)
		var slice_rect := Rect2(x, rect.position.y, 1.0, rect.size.y)

		# Crude rounded clipping: shrink top/bottom near the edges
		var dist_from_left: float = float(i)
		var dist_from_right: float = rect.size.x - float(i) - 1.0
		var edge_dist: float = minf(dist_from_left, dist_from_right)
		if edge_dist < r:
			var inset: float = r - sqrt(maxf(r * r - (r - edge_dist) * (r - edge_dist), 0.0))
			slice_rect.position.y += inset
			slice_rect.size.y -= inset * 2.0

		draw_rect(slice_rect, col)


## Maps an HP ratio (0..1) to a colour on the green-yellow-red gradient.
func _hp_ratio_to_color(ratio: float) -> Color:
	ratio = clampf(ratio, 0.0, 1.0)
	if ratio > 0.5:
		# Green to Yellow (ratio 1.0 -> 0.5)
		var t: float = (ratio - 0.5) / 0.5  # 1 at full, 0 at half
		return Color(
			lerpf(1.0, 0.15, t),   # R: yellow(1) -> green(0.15)
			lerpf(0.9, 1.0, t),    # G: yellow(0.9) -> green(1)
			lerpf(0.1, 0.3, t),    # B: low
			1.0
		)
	else:
		# Yellow to Red (ratio 0.5 -> 0.0)
		var t: float = ratio / 0.5  # 1 at half, 0 at empty
		return Color(
			1.0,                    # R stays 1
			lerpf(0.15, 0.9, t),   # G: red(0.15) -> yellow(0.9)
			lerpf(0.1, 0.1, t),    # B: low
			1.0
		)


## Draws the boss name label centered above the bar.
func _draw_boss_name(bar_rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return

	var font_size := UIColors.FONT_SMALL
	var text_width: float = font.get_string_size(boss_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var text_x: float = bar_rect.position.x + (bar_rect.size.x - text_width) * 0.5
	var text_y: float = bar_rect.position.y - 3.0  # 3px above bar top

	# Black outline (draw text offset in 4 directions)
	var outline_color := Color(0.0, 0.0, 0.0, 0.9)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, Vector2(text_x + offset.x, text_y + offset.y), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, outline_color)

	# White main text
	draw_string(font, Vector2(text_x, text_y), boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## Draws a blinking red "WARNING" label above the boss name.
func _draw_warning_label(bar_rect: Rect2) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return

	var font_size := UIColors.FONT_TINY
	var label_text := "WARNING"
	var text_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var text_x: float = bar_rect.position.x + (bar_rect.size.x - text_width) * 0.5
	var text_y: float = bar_rect.position.y - 13.0

	# Blink: use sine wave for smooth on/off
	var alpha: float = (sin(blink_accumulator * TAU) + 1.0) * 0.5  # 0..1
	alpha = clampf(alpha * 1.4, 0.0, 1.0)  # sharpen the blink

	var warning_color := Color(1.0, 0.15, 0.15, alpha)

	# Small black shadow
	draw_string(font, Vector2(text_x + 1.0, text_y + 1.0), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.0, 0.0, 0.0, alpha * 0.6))
	draw_string(font, Vector2(text_x, text_y), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, warning_color)

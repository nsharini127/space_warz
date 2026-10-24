extends Node2D

# Spawned per lightning strike, self-destructs

var chains: Array = []  # Array of Vector2 positions
var lifetime: float = 0.15
var timer: float = 0.0
var jitter_seed: float = 0.0


func setup(chain_positions: Array):
	chains = chain_positions
	z_index = 8
	jitter_seed = randf() * 100.0


func _process(delta: float):
	timer += delta
	if timer >= lifetime:
		queue_free()
		return
	queue_redraw()


func _draw():
	if chains.size() < 2:
		return

	var alpha = 1.0 - (timer / lifetime)
	var base_col = Color(0.3, 0.6, 1.0, alpha)
	var bright_col = Color(0.7, 0.9, 1.0, alpha)

	for i in range(chains.size() - 1):
		var from = to_local(chains[i])
		var to = to_local(chains[i + 1])
		_draw_lightning_segment(from, to, base_col, bright_col)


func _draw_lightning_segment(from: Vector2, to: Vector2, base_col: Color, bright_col: Color):
	# Create jagged line with random offsets
	var points: Array = [from]
	var segments = 5
	var dir = to - from
	var perp = Vector2(-dir.y, dir.x).normalized()

	for i in range(1, segments):
		var t = float(i) / segments
		var mid = from.lerp(to, t)
		var jitter = perp * randf_range(-6, 6)
		points.append(mid + jitter)
	points.append(to)

	# Draw glow (wider, dimmer)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], base_col, 3.0)

	# Draw core (narrow, bright)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], bright_col, 1.0)

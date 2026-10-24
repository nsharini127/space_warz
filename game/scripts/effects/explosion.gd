extends Node2D


var lifetime: float = 0.4
var timer: float = 0.0
var particles: Array = []
var base_color: Color = Color(1.0, 0.6, 0.1)  # Orange default
var explosion_size: float = 1.0  # Scale multiplier (bigger for bosses)


func setup(color: Color = Color(1.0, 0.6, 0.1), size_mult: float = 1.0):
	base_color = color
	explosion_size = size_mult
	_generate_particles()


func _ready():
	if particles.is_empty():
		_generate_particles()


func _generate_particles():
	particles.clear()
	var count = int(8 * explosion_size)
	for i in range(count):
		var angle = randf() * TAU
		var speed = randf_range(30, 80) * explosion_size
		var p = {
			"offset": Vector2.ZERO,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"size": randf_range(2.0, 5.0) * explosion_size,
			"color": base_color.lerp(Color.WHITE, randf() * 0.4),
		}
		particles.append(p)


func _process(delta: float):
	timer += delta
	if timer >= lifetime:
		queue_free()
		return
	var progress = timer / lifetime
	for p in particles:
		p.offset += p.velocity * delta
		p.size = lerpf(p.size, 0.0, progress * 0.5)
	queue_redraw()


func _draw():
	var progress = clampf(timer / lifetime, 0.0, 1.0)
	var alpha = 1.0 - progress

	# Central flash (first 30% of lifetime)
	if progress < 0.3:
		var flash_alpha = (0.3 - progress) / 0.3
		draw_circle(Vector2.ZERO, 8.0 * explosion_size * (1.0 - progress), Color(1, 1, 1, flash_alpha * 0.8))

	# Orange/yellow explosion core
	if progress < 0.6:
		var core_t = progress / 0.6
		var core_radius = 4.0 * explosion_size + core_t * 12.0 * explosion_size
		var core_alpha = (1.0 - core_t) * 0.7
		draw_circle(Vector2.ZERO, core_radius, Color(base_color.r, base_color.g, base_color.b, core_alpha))

	# Particles
	for p in particles:
		var c = p.color
		c.a = alpha
		draw_circle(p.offset, maxf(p.size, 0.5), c)

	# Expanding ring
	if progress > 0.1 and progress < 0.6:
		var ring_radius = 12.0 * explosion_size * progress * 2.0
		var ring_alpha = (0.6 - progress) / 0.5 * 0.4
		draw_arc(Vector2.ZERO, ring_radius, 0, TAU, 24, Color(base_color.r, base_color.g, base_color.b, ring_alpha), 1.5)

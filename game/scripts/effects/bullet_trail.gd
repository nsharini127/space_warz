extends Line2D


var max_points: int = 6
var target: Node2D = null


func _ready():
	width = 1.5
	z_index = -1
	default_color = Color(1, 0.3, 0.5, 0.6)

	var grad = Gradient.new()
	grad.set_color(0, Color(1, 0.3, 0.5, 0.6))
	grad.set_color(1, Color(1, 0.3, 0.5, 0.0))
	gradient = grad


func setup(t: Node2D, col: Color):
	target = t
	default_color = col
	if gradient:
		gradient.set_color(0, Color(col.r, col.g, col.b, 0.6))
		gradient.set_color(1, Color(col.r, col.g, col.b, 0.0))


func _process(_delta: float):
	if !target or !is_instance_valid(target):
		queue_free()
		return

	global_position = Vector2.ZERO
	global_rotation = 0

	add_point(target.global_position)
	while get_point_count() > max_points:
		remove_point(0)

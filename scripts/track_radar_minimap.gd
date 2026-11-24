class_name TrackRadarMinimap
extends Control

@export var track_waypoints: TrackWaypoints
@export var closed_loop: bool = true

@export_group("Aparência do Traçado")
@export var padding: float = 12.0
@export var track_outline_color: Color = Color("#48528c")
@export var track_line_color: Color = Color("#2c3363")
@export var track_line_width: float = 6.0
@export var track_outline_width: float = 10.0

@export_group("Marcadores dos Karts")
@export var show_rivals: bool = true
@export var player_color: Color = Color("#f7ce3e")
@export var player_border_color: Color = Color("#14172b")
@export var player_radius: float = 5.5
@export var rival_color: Color = Color("#b8c0e0")
@export var rival_border_color: Color = Color("#14172b")
@export var rival_radius: float = 3.5

var _race_manager: RaceManager
var _world_points: PackedVector2Array = PackedVector2Array()
var _bounds_min: Vector2 = Vector2.ZERO
var _bounds_max: Vector2 = Vector2.ONE


func setup(race_manager: RaceManager, waypoints: TrackWaypoints = null) -> void:
	_race_manager = race_manager
	if waypoints != null:
		track_waypoints = waypoints
	refresh_track_shape()


func set_track_from_waypoints(waypoints: TrackWaypoints) -> void:
	track_waypoints = waypoints
	refresh_track_shape()


func refresh_track_shape() -> void:
	_world_points = _collect_world_points()
	if _world_points.size() < 2:
		return

	var min_pt: Vector2 = _world_points[0]
	var max_pt: Vector2 = _world_points[0]

	for pt in _world_points:
		min_pt.x = minf(min_pt.x, pt.x)
		min_pt.y = minf(min_pt.y, pt.y)
		max_pt.x = maxf(max_pt.x, pt.x)
		max_pt.y = maxf(max_pt.y, pt.y)

	_bounds_min = min_pt
	_bounds_max = max_pt
	queue_redraw()


func _collect_world_points() -> PackedVector2Array:
	if track_waypoints != null and is_instance_valid(track_waypoints):
		return track_waypoints.get_waypoint_positions()
	return PackedVector2Array()


func _process(_delta: float) -> void:
	if not visible:
		return

	if track_waypoints == null or not is_instance_valid(track_waypoints):
		track_waypoints = _find_waypoints_in_tree(get_tree().current_scene)

	if _world_points.size() < 2 and track_waypoints != null:
		refresh_track_shape()

	queue_redraw()


func _find_waypoints_in_tree(root: Node) -> TrackWaypoints:
	if root == null:
		return null
	if root is TrackWaypoints:
		return root as TrackWaypoints

	for child in root.get_children():
		var found := _find_waypoints_in_tree(child)
		if found != null:
			return found

	return null


func _draw() -> void:
	if _world_points.size() < 2:
		return

	var mapped_pts := PackedVector2Array()
	mapped_pts.resize(_world_points.size())
	for i in _world_points.size():
		mapped_pts[i] = _world_to_radar(_world_points[i])

	if closed_loop and mapped_pts.size() >= 2:
		mapped_pts.append(mapped_pts[0])

	if track_outline_width > track_line_width:
		draw_polyline(mapped_pts, track_outline_color, track_outline_width, true)
	draw_polyline(mapped_pts, track_line_color, track_line_width, true)

	var active_player: Kart = _get_player_kart()

	if show_rivals:
		for rival in _get_rival_karts(active_player):
			if rival == null or not is_instance_valid(rival):
				continue
			var rival_pos: Vector2 = _world_to_radar(rival.global_position)
			draw_circle(rival_pos, rival_radius + 1.0, rival_border_color)
			draw_circle(rival_pos, rival_radius, rival_color)

	if active_player != null and is_instance_valid(active_player):
		var player_pos: Vector2 = _world_to_radar(active_player.global_position)
		draw_circle(player_pos, player_radius + 1.5, player_border_color)
		draw_circle(player_pos, player_radius, player_color)


func _get_player_kart() -> Kart:
	if _race_manager != null and _race_manager.kart != null:
		return _race_manager.kart

	for node in get_tree().get_nodes_in_group("race_kart"):
		var kart := node as Kart
		if kart != null and is_instance_valid(kart):
			return kart
	return null


func _get_rival_karts(player_kart: Kart) -> Array[Kart]:
	var rivals: Array[Kart] = []

	if _race_manager != null:
		for racer in _race_manager._all_karts():
			if racer != null and is_instance_valid(racer) and racer != player_kart:
				rivals.append(racer)

	if not rivals.is_empty():
		return rivals

	for node in get_tree().get_nodes_in_group("race_kart"):
		var kart := node as Kart
		if kart == null or not is_instance_valid(kart) or kart == player_kart:
			continue
		if not rivals.has(kart):
			rivals.append(kart)

	return rivals


func _world_to_radar(world_pos: Vector2) -> Vector2:
	var world_span: Vector2 = _bounds_max - _bounds_min
	var safe_w: float = maxf(world_span.x, 1.0)
	var safe_h: float = maxf(world_span.y, 1.0)

	var avail_w: float = maxf(size.x - padding * 2.0, 1.0)
	var avail_h: float = maxf(size.y - padding * 2.0, 1.0)

	var uniform_scale: float = minf(avail_w / safe_w, avail_h / safe_h)
	var drawn_w: float = safe_w * uniform_scale
	var drawn_h: float = safe_h * uniform_scale

	var offset_x: float = (size.x - drawn_w) * 0.5
	var offset_y: float = (size.y - drawn_h) * 0.5

	return Vector2(
		offset_x + (world_pos.x - _bounds_min.x) * uniform_scale,
		offset_y + (world_pos.y - _bounds_min.y) * uniform_scale
	)

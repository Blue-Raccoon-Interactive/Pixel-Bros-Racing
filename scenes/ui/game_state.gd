extends Node

const KART_SCENES: Array[PackedScene] = [
	preload("res://scenes/karts/kart_01.tscn"),
	preload("res://scenes/karts/kart_02.tscn"),
	preload("res://scenes/karts/kart_03.tscn"),
	preload("res://scenes/karts/kart_04.tscn"),
	preload("res://scenes/karts/kart_05.tscn"),
	preload("res://scenes/karts/kart_06.tscn"),
	preload("res://scenes/karts/kart_07.tscn"),
	preload("res://scenes/karts/kart_08.tscn"),
	
	# ... até kart_08
]

const TRACKS := [
	{"name": "Autódromo", "path": "res://scenes/tracks/track_01.tscn"},
	{"name": "Deserto", "path": "res://scenes/tracks/track_02.tscn"},
	{"name": "Cidade Noturna", "path": "res://scenes/tracks/track_03.tscn"},
]

var selected_kart: int = 3
var selected_track: int = 1
var has_selection: bool = false

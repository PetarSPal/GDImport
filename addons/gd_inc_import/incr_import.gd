@tool
extends EditorPlugin

var dock: Node
var default 

func _enter_tree() -> void:
	dock = preload("res://addons/gd_inc_import/import_dock.tscn").instantiate()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, dock)

func _de_child(x: Node):
	for child in x.get_children():
		if is_instance_valid(child):
			_de_child(child)
			x.remove_child(child)

func _exit_tree() -> void:
	remove_control_from_docks(dock)
	_de_child(dock)
	dock.free()

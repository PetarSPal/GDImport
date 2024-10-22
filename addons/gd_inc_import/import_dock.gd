@tool
extends Control
const FILE_DIALOG = preload("res://addons/gd_inc_import/file_dialog.tscn")
var file_dialog: FileDialog
var dest_dialog: FileDialog
var files: PackedStringArray
var dir: String
var godot: String
var batch_size: int = 10
@onready var current_project = ProjectSettings.globalize_path("res://").trim_suffix("/")
@onready var select_files: Button = $VBoxContainer/HBoxContainer/SelectFiles
@onready var select_destination: Button = $VBoxContainer/HBoxContainer/SelectDestination
@onready var import_files: Button = $VBoxContainer/HBoxContainer2/ImportFiles
@onready var batch: SpinBox = $VBoxContainer/HBoxContainer2/Batch
@onready var filenames_list: RichTextLabel = $VBoxContainer/FilenamesList
@onready var current_desination: RichTextLabel = $VBoxContainer/CurrentDesination
@onready var godot_destination: RichTextLabel = $VBoxContainer/godotDestination
const timeout = 1500

func _ready() -> void:
	batch.value_changed.connect(func(v: float): batch_size = int(v))
	select_files.pressed.connect(_on_select_files)
	select_destination.pressed.connect(_on_select_destination)
	import_files.pressed.connect(_on_import_files)

func _on_select_files() -> void:
	filenames_list.clear()
	file_dialog = FILE_DIALOG.instantiate()
	file_dialog.files_selected.connect(_on_submit_selection)
	file_dialog.show()
	add_child(file_dialog)

	
func _on_submit_selection(files: PackedStringArray) -> void:
	self.files = files
	for file in files:
		filenames_list.add_text(file + "\n")
	file_dialog.hide()
	remove_child(file_dialog)
	file_dialog.queue_free()
	
func _on_select_destination() -> void:
	current_desination.clear()
	godot_destination.clear()
	self.dir = ""
	self.godot = ""
	dest_dialog = FILE_DIALOG.instantiate()
	dest_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dest_dialog.dir_selected.connect(_on_submit_destination)
	dest_dialog.show()
	add_child(dest_dialog)

func _on_submit_destination(dir: String):
	if dir.begins_with(current_project):
		push_error("Cannot import incrementally to currently running project, run plugin as separate project.")
		return
	if godot and not dir.begins_with(godot):
		push_error("Destination must be located in destination project!")
		return
	if not _find_godot(dir):
		push_error("Destination is not godot project subfolder, missing project.godot file!")
		return
	self.dir = dir
	current_desination.add_text(dir)
	dest_dialog.hide()
	remove_child(dest_dialog)
	dest_dialog.queue_free()

func _find_godot(projdir: String) -> bool:
	if FileAccess.file_exists(projdir + "/" + "project.godot"):
		self.godot = projdir
		godot_destination.add_text(projdir)
		print("Found project dir: " + projdir)
		return true
	else:
		var slash := projdir.rfind("/")
		if not slash:
			return false
		var back := projdir.substr(0, slash)
		return _find_godot(back)

func _wait(id: int) -> int:
	var waiting: int = 0
	await get_tree().create_timer(1.).timeout
	while OS.is_process_running(id):
		if waiting >= timeout:
			return 1
		waiting += 1
		await get_tree().create_timer(0.2).timeout
	return 0

func _on_import_files():
	var destination := dir
	var amount := batch_size
	var current_project = ProjectSettings.globalize_path("res://")
	if destination.begins_with(current_project):
		push_error("Cannot import incrementally to currently running project, run plugin as separate project.")
		return
	if not destination:
		push_error("Destination was not provided: " + destination)
		return
	if not files:
		push_error("Files were not provided: " + str(files))
		return
	if not DirAccess.dir_exists_absolute(destination):
		push_error("Destination not found: " + destination)
		return
	var filecount: int = 0
	var noovercount: int = 0
	var tmpfilecount := 0
	print("--- Import Started ---")
	for step: int in range(amount, files.size()+amount, amount):
		for file in files.slice(max(0, step-amount),min(step,files.size())):
			var dest_file := destination + "/" + file.get_file()
			if FileAccess.file_exists(dest_file):
				push_error(dest_file + " file already exists, overwrite currently disabled!")
				noovercount += 1
				continue
			else:
				DirAccess.copy_absolute(file, dest_file)
				filecount += 1
				tmpfilecount += 1
				print("successfully copied: " + file + " to: " + dest_file)
		var new_inst := OS.create_instance(PackedStringArray(["--path", godot, "--headless", "--import"]))
		await _wait(new_inst)
		var err = OS.get_process_exit_code(new_inst)
		if err != OK:
			push_error("Detached Godot running with id" + str(new_inst) + "terminated with RC: " + str(err))
		else:
			print("Successfully imported batch of " + str(tmpfilecount) + " files.")
		tmpfilecount = 0
	print("Import completed. Selected: " + str(files.size()) + " Imported: " + str(filecount) + " Could not overwrite: " + str(noovercount))
	print("--- Import Ended ---")
		

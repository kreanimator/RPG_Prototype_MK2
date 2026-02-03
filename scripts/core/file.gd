extends Node

const SAVE_PATH: String = "user://"
var file_name : String = "save.json"
var data : Dictionary
var access: FileAccess
var encryption: Encryption

func _ready() -> void:
	encryption = ResourceLoader.load("res://resources/encryption.tres")

func load_json_file(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	assert(FileAccess.file_exists(file_path), "File with path: " + file_path + " does not exists!")
	var json = file.get_as_text()
	var json_object = JSON.new()
	json_object.parse(json)
	data = json_object.data
	return data
	
func write_json_file(file_path: String, data_to_write: Dictionary):
	if FileAccess.file_exists(file_path):
		print("File exists. Writing to it!")
	else:
		print("File does not exists writing to it")
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file: 
		var json_text = JSON.stringify(data_to_write, "\t")
		file.store_string(json_text)
		print("Data written to the file!")
	else:
		printerr("Failed to open or create a file!")
		
func new_game(ng_data : Dictionary) -> void:
	data = ng_data
	save_game()
	
func save_game() -> void:
	access = FileAccess.open_encrypted_with_pass(SAVE_PATH + file_name, FileAccess.WRITE, encryption.key)
	access.store_string(JSON.stringify(data))
	prints("Game was successfully saved to: " + SAVE_PATH + file_name)
	access.close()
	
func load_game() -> void:
	if FileAccess.file_exists(SAVE_PATH + file_name):
		access = FileAccess.open_encrypted_with_pass(SAVE_PATH + file_name, FileAccess.READ, encryption.key)
		data = JSON.parse_string(access.get_as_text())
		Utils.print_formatted_dict("Game data successfully loaded", data, "FileManager")
		access.close()

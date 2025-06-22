extends Control

@onready var texture_rect : TextureRect = $TextureRect

var dir_path = ""
var currfile = ""
var files = []

var drag_offset = Vector2(0, 0)
var dragging = false

func _ready():
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	dir_path = config.get_value("general", "last_dir", "")
	if dir_path != "":
	#	print("Loaded last directory: ", dir_path)
		$FileDialog.current_dir = dir_path

var scale_strength = 1.2
var smoothing_speed = 5
var new_scale = Vector2(1, 1)

func _process(delta):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		$FileDialog.visible = true

	if Input.is_action_just_pressed("left_click"):
		dragging = true
		drag_offset = get_global_mouse_position() - texture_rect.global_position

	if dragging:
		texture_rect.global_position = get_global_mouse_position() - drag_offset

	if Input.is_action_just_released("left_click"):
		dragging = false

	var mouse_local_pos = texture_rect.get_local_mouse_position() 
	

	if Input.is_action_just_pressed("scroll_up"):
		texture_rect.pivot_offset = mouse_local_pos
		new_scale = texture_rect.scale * scale_strength
		var mouse_global = get_global_mouse_position()
		texture_rect.global_position = mouse_global - (mouse_local_pos * texture_rect.scale)

	if Input.is_action_just_pressed("scroll_down"):
		texture_rect.pivot_offset = mouse_local_pos
		new_scale = texture_rect.scale / scale_strength
		var mouse_global = get_global_mouse_position()
		texture_rect.global_position = mouse_global - (mouse_local_pos * texture_rect.scale)
	
	texture_rect.scale = texture_rect.scale.lerp(new_scale, 0.2)
	
	if Input.is_action_just_pressed("reset"):
		dragging = false
		new_scale = Vector2(1, 1)
		texture_rect.scale = Vector2(1, 1)
		texture_rect.position = Vector2(0, 0)
		
	if Input.is_action_just_pressed("ui_left"):
		var file_count = files.size()
		var index = files.find(currfile)
		if index - 1 == -1:
			_on_file_dialog_file_selected(dir_path + "/" + files[file_count - 1])
		else:
			_on_file_dialog_file_selected(dir_path + "/" + files[index - 1])
		
	if Input.is_action_just_pressed("ui_right"):
		var file_count = files.size()
		var index = files.find(currfile)
		if index + 1 == file_count:
			_on_file_dialog_file_selected(dir_path + "/" + files[0])
		else:
			_on_file_dialog_file_selected(dir_path + "/" + files[index + 1])



func detect_image_type(buffer: PackedByteArray) -> String:
	# PNG files start with: 89 50 4E 47 0D 0A 1A 0A
	if buffer.size() >= 8:
		if buffer[0] == 0x89 and buffer[1] == 0x50 and buffer[2] == 0x4E and buffer[3] == 0x47:
			return "png"
		# JPEG files start with: FF D8
		elif buffer[0] == 0xFF and buffer[1] == 0xD8:
			return "jpg"
		# BMP files start with: 42 4D
		elif buffer[0] == 0x42 and buffer[1] == 0x4D:
			return "bmp"
	return "unknown"


func _on_file_dialog_file_selected(path: String) -> void:
	dragging = false
	new_scale = Vector2(1, 1)
	texture_rect.scale = Vector2(1, 1)
	texture_rect.position = Vector2(0, 0)
	
	var img = Image.new()
	var err = img.load(path)
	var temp_file_path = ""
	print(path)
	currfile = path.get_file()
	
	if err != OK:
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var data = file.get_buffer(file.get_length())
			file.close()
			
			var temp_file
			var image_type = detect_image_type(data)
			if image_type == "png":
				temp_file = FileAccess.create_temp(FileAccess.WRITE, "temp_img", ".png", true)
			elif image_type == "jpg":
				temp_file = FileAccess.create_temp(FileAccess.WRITE, "temp_img", ".jpg", true)
			else:
				print("Unsupported image type for temporary file")
				return
			
			if temp_file:
				temp_file.store_buffer(data)
				temp_file.flush()
				
				err = img.load(temp_file.get_path())
				temp_file_path = temp_file.get_path()
				temp_file.close()
				
				if err != OK:
					print("Failed to load image from temporary file")
					return
			else:
				print("Failed to create temporary file")
				return
		else:
			print("Failed to open original file for reading")
			return
	
	var texture = ImageTexture.create_from_image(img)
	texture_rect.texture = texture
	
	# Delete the temporary file if it was created
	if temp_file_path != "":
		var file_del = FileAccess.open(temp_file_path, FileAccess.WRITE)
		var dir = DirAccess.open(temp_file_path.get_base_dir())
		if file_del:
			file_del.close()
			var err_del = dir.remove(temp_file_path)
			if err_del != OK:
				print("Failed to delete temporary file: ", temp_file_path)
		else:
			# If FileAccess.open fails, try DirAccess.remove directly
			var err_del = dir.remove(temp_file_path)
			if err_del != OK:
				print("Failed to delete temporary file: ", temp_file_path)
	
	
	
	# Get directory of the selected image
	dir_path = path.get_base_dir()
	#print("Directory of selected image: ", dir_path)
	
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	
	config.set_value("general", "last_dir", dir_path)
	config.save("user://settings.cfg")
	
	# Open the directory
	var dir = DirAccess.open(dir_path)
	if dir:
		files.clear()
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var file = FileAccess.open(dir_path + "/" + file_name, FileAccess.READ)
				if file:
					var data = file.get_buffer(file.get_length())
					file.close()
					
					var temp_file
					var image_type = detect_image_type(data)
					
					if image_type == "png" or image_type == "jpg":
						print(file_name)
						files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

		#print("Image files in directory:")
		#for f in files:
		#	print(f)
	else:
		print("Failed to open directory: ", dir_path)

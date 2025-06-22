extends ImageFormatLoaderExtension
class_name MyCustomImageLoader

# Return type must be PackedStringArray
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["bvsx"])  # your custom extension(s)

# Return type must be Error, parameters: (Image, FileAccess, int, float)
func _load_image(image: Image, fileaccess: FileAccess, flags: int, scale: float) -> Error:
	var data = fileaccess.get_buffer(fileaccess.get_length())
	var temp_img = Image.new()
	var err = temp_img.load_png_from_buffer(data)
	if err == OK:
		image.copy_from(temp_img)
		return OK
	else:
		push_error("Failed to load PNG data from custom extension")
		return err

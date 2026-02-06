extends ImageTexture
class_name CarTexture

@export var color_set: CarColorSet:
	set(value):
		color_set = value
		self._on_color_changed()
	get:
		return color_set

@export var base_image: Image:
	set(value):
		base_image = value
		self._on_base_image_changed()
	get:
		return base_image

var work_image: Image


static func create_from_base_image(image: Image) -> CarTexture:
	var texture = CarTexture.new()
	texture.base_image = image
	return texture


func _on_base_image_changed():
	self.work_image = self.base_image.duplicate(true)
	self.set_image(self.work_image)


func _on_color_changed():
	# Why do it this convoluted way?
	# Context: Which color is applied to what part is determined by alpha channel of a given
	#          albedo texture pixel.
	# Back to why:
	# - The coloring needs to be pixel perfect
	# - The shader attempt gave bad results due to interpolation
	if self.base_image:
		var sizes = self.work_image.get_size()
		var data = self.base_image.get_data()
		for i in sizes.x:
			for j in sizes.y:
				var pixel_color = base_image.get_pixel(i, j)
				var alpha = data[(4 * (j * sizes.x + i) + 3)]
				if 223 <= alpha && alpha <= 230:
					pixel_color.a = 1.0
					self.work_image.set_pixel(i, j, pixel_color * color_set.primary)
				elif 160 <= alpha && alpha <= 182:
					pixel_color.a = 1.0
					self.work_image.set_pixel(i, j, pixel_color * color_set.interior)
				elif 96 <= alpha && alpha <= 118:
					pixel_color.a = 1.0
					self.work_image.set_pixel(i, j, pixel_color * color_set.secondary)
				elif 32 <= alpha && alpha <= 46:
					pixel_color.a = 1.0
					self.work_image.set_pixel(i, j, pixel_color * color_set.driver)
		self.work_image.generate_mipmaps(true)
		self.update(self.work_image)

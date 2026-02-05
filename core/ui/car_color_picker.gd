extends HBoxContainer

@export var colors: Array[CarColorSet] = []:
	set(value):
		colors = value
		self._set_picker_colors()
	get():
		return colors
		
@export var selected_color_set: CarColorSet = null

@onready var color_picker_button: ColorPickerButton = %ColorPickerButton

var color_picker

signal color_changed;

func _set_picker_colors():
	if self.color_picker:
		for color in self.color_picker.get_presets():
			self.color_picker.erase_preset(color)
		var primary_colors = self.colors.map(func (x): return x.primary)
		for color in primary_colors:
			self.color_picker.add_preset(color)
		if primary_colors:
			self.color_picker.color = primary_colors[0]

func _on_color_picker_button_color_changed(color: Color) -> void:
	var color_set = self._get_closest_color_set(color)
	if not color_set:
		return
	color_set = color_set.duplicate(true)
	color_set.primary = color
	selected_color_set = color_set
	self.color_changed.emit()


func _on_color_picker_button_picker_created() -> void:
	color_picker = self.color_picker_button.get_picker()
	self._set_picker_colors()

func _get_closest_color_set(color: Color) -> CarColorSet:
	var distance = INF
	var closest: CarColorSet
	for c in self.colors.duplicate():
		var d = self._color_distance(color, c.primary)
		if d < distance:
			distance = d
			closest = c
	return closest

func _color_distance(a: Color, b: Color) -> float:
	var dh = min(abs(a.h - b.h), 1 - abs(a.h - b.h))
	var ds = abs(a.s - b.s)
	var dv = abs(a.v - b.v)
	return dh**2 + ds**2 + dv**2

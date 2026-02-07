extends HBoxContainer

@export var colors: Array[CarColorSet] = []:
	set(value):
		colors = value
		self._set_picker_colors()
	get():
		return colors
		
@export var selected_color_set: CarColorSet:
	set(value):
		selected_color_set = value
		self.color_picker_button.color = value.primary
	get:
		return selected_color_set

@onready var color_picker_button: ColorPickerButton = %ColorPickerButton

signal color_changed;

func _set_picker_colors():
	var primary_colors = self.colors.map(func (x): return x.primary)
	var color_picker = self.color_picker_button.get_picker()
	for color in color_picker.get_presets():
		color_picker.erase_preset(color)
	for color in primary_colors:
		color_picker.add_preset(color)

func _on_color_picker_button_color_changed(color: Color) -> void:
	var color_set = self._get_closest_color_set(color)
	if not color_set:
		return
	color_set = color_set.duplicate(true)
	color_set.primary = color
	selected_color_set = color_set
	self.color_changed.emit()

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

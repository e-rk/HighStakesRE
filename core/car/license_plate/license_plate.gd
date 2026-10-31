@tool
class_name LicensePlate
extends MeshInstance3D

const max_text_length = 8

@export var text: String:
	set(value):
		text = value
		if self.viewport:
			self.text_label.text = value.to_upper().left(max_text_length)
			self.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

@export_range(0.0, 1.0, 0.1) var light: float = 0.0:
	set(value):
		light = value
		self.set_instance_shader_parameter(&"lamp_lit", value)

@onready var text_label: Label = %Text
@onready var viewport: SubViewport = $SubViewport

func _ready() -> void:
	self.text_label.text = self.text.to_upper().left(max_text_length)

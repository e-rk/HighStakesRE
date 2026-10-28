extends PanelContainer
class_name DamageMeter

@export_range(0.0, 1.0, 0.01) var warning_threshold := 0.33
@export_range(0.0, 1.0, 0.01) var critical_threshold := 0.67

@export var light_fill: StyleBoxFlat
@export var warning_fill: StyleBoxFlat
@export var critical_fill: StyleBoxFlat

@onready var engine_label: Label = %Engine
@onready var engine_bar: ProgressBar = %EngineBar
@onready var engine_value: Label = %EngineValue
@onready var steering_label: Label = %Steering
@onready var steering_bar: ProgressBar = %SteeringBar
@onready var steering_value: Label = %SteeringValue
@onready var body_label: Label = %Body
@onready var body_bar: ProgressBar = %BodyBar
@onready var body_value: Label = %BodyValue
@onready var suspension_label: Label = %Suspension
@onready var suspension_bar: ProgressBar = %SuspensionBar
@onready var suspension_value: Label = %SuspensionValue


func _damage_color(percentage: float) -> StyleBoxFlat:
	if percentage < self.warning_threshold:
		return self.light_fill
	if percentage < self.critical_threshold:
		return self.warning_fill
	return self.critical_fill


func _set_value(label: Label, bar: ProgressBar, value: Label, percentage: float) -> void:
	bar.value = percentage
	value.text = "%d%%" % int(percentage * 100)
	var fill := self._damage_color(percentage)
	bar.add_theme_stylebox_override(&"fill", fill)
	value.add_theme_color_override(&"font_color", fill.bg_color)
	label.add_theme_color_override(&"font_color", fill.bg_color)


func set_damage(damage: Car.CarDamage) -> void:
	self._set_value(self.engine_label, self.engine_bar, self.engine_value, damage.engine)
	self._set_value(self.steering_label, self.steering_bar, self.steering_value, damage.steering.reduce(func (a, x): return a + x, 0))
	self._set_value(self.body_label, self.body_bar, self.body_value, damage.body)
	self._set_value(self.suspension_label, self.suspension_bar, self.suspension_value, damage.suspension.reduce(func(a, x): return a + x, 0))

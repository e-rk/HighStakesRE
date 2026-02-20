extends Control

@onready var rpm_meter = %RpmMeter
@onready var gears = %Gears

var visible_gears: CarTypes.Gear = CarTypes.Gear.GEAR_6


func gear_to_node(gear: CarTypes.Gear) -> Label:
	var gear_str = ""
	match gear:
		CarTypes.Gear.REVERSE:
			gear_str = "R"
		CarTypes.Gear.NEUTRAL:
			gear_str = "N"
		CarTypes.Gear.GEAR_1:
			gear_str = "1"
		CarTypes.Gear.GEAR_2:
			gear_str = "2"
		CarTypes.Gear.GEAR_3:
			gear_str = "3"
		CarTypes.Gear.GEAR_4:
			gear_str = "4"
		CarTypes.Gear.GEAR_5:
			gear_str = "5"
		CarTypes.Gear.GEAR_6:
			gear_str = "6"
		_:
			gear_str = "N"
	return get_node("%" + gear_str)


func set_rpm(rpm: float):
	rpm_meter.text = "%.1f" % (rpm / 1000)


func set_gear(gear: CarTypes.Gear):
	for child in gears.get_children():
		child.set("theme_override_colors/font_color", Color.GRAY)
	var node = gear_to_node(gear)
	node.set("theme_override_colors/font_color", Color.WHITE)


func set_max_gear(gear: CarTypes.Gear):
	if gear == self.visible_gears:
		return
	for i in (CarTypes.Gear.GEAR_6 + 1):
		if i > gear:
			self.gear_to_node(i).hide()
		else:
			self.gear_to_node(i).show()
	self.visible_gears = gear

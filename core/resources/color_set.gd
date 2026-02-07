extends Resource
class_name CarColorSet

@export var primary: Color
@export var secondary: Color
@export var driver: Color
@export var interior: Color

static func from_colors(primary: Color,
						secondary: Color,
						driver: Color,
						interior: Color) -> CarColorSet:
	var ret = CarColorSet.new()
	ret.primary = primary
	ret.secondary = secondary
	ret.driver = driver
	ret.interior = interior
	return ret

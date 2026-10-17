extends Resource
class_name CarManifest

@export var car_class := CarDatabase.CarClass.NONE
@export var police := false
@export var colors: Array[CarColorSet]

extends HBoxContainer
class_name CarPicker

signal car_selected

@export var selected_car: String = ""

@onready var car_selection: OptionButton = $CarSelection


func _ready():
	CarDB.database_updated.connect(self._on_car_database_updated)


func set_selected_car(uuid: String):
	self.selected_car = uuid
	self._show_selected_car()


const CLASS_GROUPS: Dictionary[CarDatabase.CarClass, String] = {
	CarDatabase.CarClass.AAA: "AAA",
	CarDatabase.CarClass.AA: "AA",
	CarDatabase.CarClass.A: "A",
	CarDatabase.CarClass.B: "B",
	CarDatabase.CarClass.NONE: "None",
}


static func _car_class(car: CarDatabase.CarData) -> CarDatabase.CarClass:
	return car.manifest.car_class if car.manifest else CarDatabase.CarClass.NONE


func _on_car_database_updated():
	car_selection.clear()
	var first_car := -1
	for group in CLASS_GROUPS:
		var cars := CarDB.cars.values().filter(func(car): return _car_class(car) == group)
		if cars.is_empty():
			continue
		car_selection.add_separator(CLASS_GROUPS[group])
		for car in cars:
			car_selection.add_item(car.name)
			car_selection.set_item_metadata(car_selection.item_count - 1, car.uuid)
			if first_car < 0:
				first_car = car_selection.item_count - 1
	if first_car < 0:
		return
	if CarDB.get_car_by_uuid(self.selected_car):
		self._show_selected_car()
	else:
		car_selection.select(first_car)
		self.selected_car = car_selection.get_selected_metadata()
		self.car_selected.emit()


func _show_selected_car():
	for i in car_selection.item_count:
		if car_selection.get_item_metadata(i) == self.selected_car:
			car_selection.select(i)
			return


func _on_car_selection_item_selected(index):
	selected_car = car_selection.get_item_metadata(index)
	self.car_selected.emit()

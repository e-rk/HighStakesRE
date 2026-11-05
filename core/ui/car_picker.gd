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


func _on_car_database_updated():
	car_selection.clear()
	for car in CarDB.cars.values():
		car_selection.add_item(car.name)
		car_selection.set_item_metadata(car_selection.item_count - 1, car.uuid)
	if car_selection.item_count == 0:
		return
	if CarDB.get_car_by_uuid(self.selected_car):
		self._show_selected_car()
	else:
		car_selection.select(0)
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

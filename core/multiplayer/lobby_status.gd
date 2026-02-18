extends Node

@onready var player_list = $PlayerList

var tree_root: TreeItem
var tree_items: Dictionary


func _ready():
	player_list.set_column_title(0, "Player name")
	player_list.set_column_title(1, "Car")
	player_list.set_column_title(2, "Status")
	tree_root = player_list.create_item()
	player_list.hide_root = true


func set_player_data(data: PlayerData):
	if not self.tree_items.has(data.get_player_id()):
		var ti = self.player_list.create_item()
		self.tree_items[data.get_player_id()] = ti
	self._set_player_data(data)


func remove_player_data(data: PlayerData):
	var id = data.get_player_id()
	var ti = self.tree_items[id]
	self.tree_items.erase(id)
	ti.free()


func _set_player_data(data: PlayerData):
	var ti = self.tree_items[data.get_player_id()]
	ti.set_text(0, data.player_name)
	ti.set_text(1, data.car_uuid.get_basename().get_file())
	ti.set_text(2, Constants.player_status_to_str(data.player_status))

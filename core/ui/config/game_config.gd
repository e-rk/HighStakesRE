class_name UiGameConfig
extends Control

@export var config := GameConfig.new()

signal config_error
signal config_changed

const game_config_path = "user://last.game.tres"

var settings_restored := false

@onready var track_picker = %TrackPicker
@onready var rule_configurator = %RuleConfigurator
@onready var opponents = $HBoxContainer/NumOpponents
@onready var opponent_class: OptionButton = %OpponentClass


func _ready():
	if ResourceLoader.exists(self.game_config_path):
		var saved = ResourceLoader.load(self.game_config_path, "", ResourceLoader.CACHE_MODE_IGNORE) as GameConfig
		if saved:
			self._restore(saved)
	self.settings_restored = true


func _restore(saved: GameConfig):
	if saved.track:
		track_picker.set_config(saved.track)
	if saved.rules is RaceRules:
		rule_configurator.select_mode(saved.rules.get_script().mode_uuid())
	opponents.value = saved.num_opponents
	config.num_opponents = saved.num_opponents
	var class_index := opponent_class.get_item_index(saved.opponent_class)
	if class_index >= 0:
		opponent_class.select(class_index)
		config.opponent_class = saved.opponent_class


func _save():
	if not self.settings_restored or not self.is_multiplayer_authority():
		return
	ResourceSaver.save(self.config, self.game_config_path)


func _on_rule_configurator_rules_changed(rules):
	config.rules = rules
	self._save()


func _on_track_picker_track_selected(track):
	config.track = track
	self._save()


func disable():
	track_picker.disable()
	rule_configurator.disable()
	opponents.editable = false
	opponent_class.disabled = true


func enable():
	track_picker.enable()
	rule_configurator.enable()
	opponents.editable = true
	opponent_class.disabled = false


func _on_num_opponents_value_changed(value: float) -> void:
	config.num_opponents = opponents.value
	self._save()


func _on_opponent_class_item_selected(index: int) -> void:
	config.opponent_class = opponent_class.get_item_id(index) as GameConfig.OpponentClass
	self._save()

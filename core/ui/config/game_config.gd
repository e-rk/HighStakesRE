class_name UiGameConfig
extends Control

@export var config := GameConfig.new()

signal config_error
signal config_changed

@onready var track_picker = %TrackPicker
@onready var rule_configurator = %RuleConfigurator
@onready var opponents = $HBoxContainer/NumOpponents
@onready var opponent_class: OptionButton = %OpponentClass


func _on_rule_configurator_rules_changed(rules):
	config.rules = rules


func _on_track_picker_track_selected(track):
	config.track = track


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


func _on_opponent_class_item_selected(index: int) -> void:
	config.opponent_class = opponent_class.get_item_id(index) as GameConfig.OpponentClass

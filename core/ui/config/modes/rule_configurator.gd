extends Control

const rules_extension := ".rules.tres"
const last_save_prefix := "user://last"

@onready var mode_selector: SyncableOptionButton = %ModeSelector
@onready var configurator: PopupPanel = %Configurator
@onready var configurator_container: Control = %ConfiguratorContainer
@onready var rule_configurator = null
@onready var load_dialog: FileDialog = $LoadDialog
@onready var save_dialog: FileDialog = $SaveDialog
@onready var configure_button: Button = %ConfigureButton

signal rules_changed


func format_extension(mode, prefix = ""):
	var mode_namespace = mode.get_namespace()
	return prefix + "." + mode_namespace + rules_extension


func get_last_save_path(mode):
	return self.format_extension(mode, self.last_save_prefix)


func apply_config():
	var rules = rule_configurator.config
	if self.is_multiplayer_authority():
		self.save_current_config(self.get_last_save_path(rules))
	self.rules_changed.emit(rule_configurator.config.duplicate(true))


func save_current_config(path: String):
	var rules = rule_configurator.config
	ResourceSaver.save(rules, path)


func restore_config():
	var mode = self.get_current_mode()
	self.load_config(self.get_last_save_path(mode))


func load_config(path: String):
	if not ResourceLoader.exists(path):
		return
	var config = load(path) as RaceRules
	if config:
		rule_configurator.config = config.duplicate(true)


func get_current_mode() -> GDScript:
	var mode_name = self.get_current_uuid()
	return GameModeDB.get_mode_by_uuid(mode_name)


func get_current_uuid() -> String:
	return mode_selector.get_selected_uuid()


func select_mode(mode_uuid: String):
	if mode_selector.has_syncable_item(mode_uuid):
		mode_selector.set_by_uuid(mode_uuid)


func set_mode(mode_uuid: String):
	if rule_configurator:
		rule_configurator.queue_free()
		rule_configurator = null
	var mode = GameModeDB.get_mode_by_uuid(mode_uuid)
	var scene = mode.get_config_interface()
	configurator.title = "%s configuration" % mode.mode_display_name()
	configurator_container.add_child(scene)
	configurator.child_controls_changed()
	rule_configurator = scene
	self.restore_config()
	self.apply_config()


func disable():
	mode_selector.disabled = true
	configure_button.disabled = true


func enable():
	mode_selector.disabled = false
	configure_button.disabled = false


func _ready():
	configurator.popup_window = false
	for mode in GameModeDB.get_all_modes():
		mode_selector.add_syncable_item(mode.mode_display_name(), mode.mode_uuid())
	mode_selector.settle_selection()


func _on_configure_button_pressed():
	configurator.show()


func _on_set_button_pressed():
	self.apply_config()
	configurator.hide()


func _on_cancel_button_pressed():
	configurator.hide()


func _on_configurator_popup_hide():
	self.restore_config()


func _on_on_demand_synchronizer_on_demand_synchronized():
	self.apply_config()


func _on_mode_selector_syncable_item_selected(unique_name):
	self.set_mode(unique_name)


func _on_load_button_pressed():
	var mode = self.get_current_mode()
	load_dialog.clear_filters()
	load_dialog.add_filter(self.format_extension(mode, "*"), mode.mode_display_name())
	load_dialog.show()


func _on_load_dialog_file_selected(path: String):
	self.load_config(path)
	self.apply_config()


func _on_save_dialog_file_selected(path):
	self.save_current_config(path)


func _on_save_button_pressed():
	var mode = self.get_current_mode()
	save_dialog.clear_filters()
	save_dialog.add_filter(self.format_extension(mode, "*"), mode.mode_display_name())
	save_dialog.show()

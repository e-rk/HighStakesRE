extends PanelContainer
class_name PursuitTicketStatus

@onready var container: GridContainer = %TicketContainer

class RowData:
	var name_label: Label
	var tickets_label: Label
	var speed_label: Label
	var laps_label: Label

class RacerStatus:
	var name: String
	var color: Color
	var tickets: int
	var speed_kph: int
	var laps: int

var rows: Array[RowData]


func _ready() -> void:
	self._clear_all()


func update(data: Array[RacerStatus], num_tickets: int, num_laps: int) -> void:
	var cnt := data.size()
	if rows.size() != cnt:
		self._reconstruct(cnt)
	for i in cnt:
		var d := data[i]
		var row := rows[i]
		var color := d.color
		# Limits for visual clarity
		color.v = max(0.35, color.v)
		color.s = min(0.75, color.s)
		row.name_label.text = d.name
		row.name_label.add_theme_color_override(&"font_color", color)
		row.tickets_label.text = "%d/%d" % [d.tickets, num_tickets]
		row.speed_label.text = str(d.speed_kph)
		row.laps_label.text = "%d/%d" % [min(d.laps, num_laps), num_laps]


func _reconstruct(cnt: int) -> void:
	self._clear_all()
	for i in cnt:
		var row := RowData.new()
		row.name_label = Label.new()
		row.tickets_label = Label.new()
		row.speed_label = Label.new()
		row.laps_label = Label.new()
		self.rows.append(row)
		self.container.add_child(row.name_label)
		self.container.add_child(row.tickets_label)
		self.container.add_child(row.speed_label)
		self.container.add_child(row.laps_label)


func _clear_all() -> void:
	for row in self.rows:
		row.name_label.queue_free()
		row.tickets_label.queue_free()
		row.speed_label.queue_free()
		row.laps_label.queue_free()
	self.rows.clear()

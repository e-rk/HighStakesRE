extends RigidBody3D
class_name TrackObject


func _ready() -> void:
	self.sleeping = false
	self.post_ready.call_deferred()


func post_ready() -> void:
	self.sleeping = true

extends Resource
class_name CarPerformance

@export var mass: float
@export var torque_curve: Array[float]
@export var manual_gear_efficiency: Array
@export var manual_velocity_to_rpm_ratio: Array
@export var manual_number_of_gears: CarTypes.Gear
@export var front_drive_ratio: float
@export var engine_redline_rpm: int
@export var engine_minimum_rpm: int
@export var aerodynamic_downforce_multiplier: float
@export var maximum_velocity: float
@export var spoiler_function_type: bool
@export var turn_in_ramp: float
@export var turn_out_ramp: float
@export var minimum_steering_acceleration: float
@export var maximum_braking_deceleration: float
@export var front_bias_brake_ratio: float
@export var lateral_acceleration_grip_multiplier: float
@export var front_grip_bias: float
@export var has_abs: bool
@export var understeer_gradient: float
@export var turning_circle_radius: float
@export var gas_off_factor: float
@export var shift_blip_in_rpm: Array[int]
@export var brake_blip_in_rpm: Array[int]
@export var gear_shift_delay: int
@export var g_transfer_factor: float
@export var brake_decreasing_curve: Array[float]
@export var brake_increasing_curve: Array[float]


func gear_efficiency(gear) -> float:
	return manual_gear_efficiency[gear]


func gear_velocity_to_rpm(gear) -> float:
	return manual_velocity_to_rpm_ratio[gear]


func max_gear() -> CarTypes.Gear:
	return ((manual_number_of_gears as int) - 1) as CarTypes.Gear


func engine_min_rpm() -> int:
	return engine_minimum_rpm


func downforce_mult() -> float:
	return aerodynamic_downforce_multiplier


func max_velocity() -> float:
	return maximum_velocity


func has_spoiler() -> bool:
	return spoiler_function_type


func front_brake_bias() -> float:
	return clampf(front_bias_brake_ratio, 0.3, 0.75)


func lateral_grip_multiplier() -> float:
	return lateral_acceleration_grip_multiplier

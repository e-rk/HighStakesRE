extends Resource
class_name HandlingModel

func extract(params: Dictionary) -> Dictionary:
	return {
		"linear_velocity": params["linear_velocity"],
		"angular_velocity": params["angular_velocity"],
		"gear": params["gear"],
		"rpm": params["rpm"],
		"current_steering": params["current_steering"],
		"lost_grip": params["lost_grip"],
		"handbrake_accumulator": params["handbrake_accumulator"],
		"force": params["force"],
		"gear_shift_counter": params["gear_shift_counter"],
		"shifted_down": params["shifted_down"],
		"g_transfer": params["g_transfer"],
		"throttle": params["throttle"],
		"brake": params["brake"],
		"has_contact_with_ground": params["has_contact_with_ground"],
	}

func extend(f: Callable) -> Callable:
	return func(params: Dictionary) -> Dictionary:
		var value = f.call(params)
		var result = params.duplicate(true)
		if value.has("linear_velocity"):
			result["linear_velocity"] = value["linear_velocity"]
		if value.has("angular_velocity"):
			result["angular_velocity"] = value["angular_velocity"]
		if value.has("gear"):
			result["gear"] = value["gear"]
		if value.has("rpm"):
			result["rpm"] = value["rpm"]
		if value.has("current_steering"):
			result["current_steering"] = value["current_steering"]
		if value.has("lost_grip"):
			result["lost_grip"] = value["lost_grip"]
		if value.has("handbrake_accumulator"):
			result["handbrake_accumulator"] = value["handbrake_accumulator"]
		if value.has("force"):
			result["force"] = value["force"]
		if value.has("gear_shift_counter"):
			result["gear_shift_counter"] = value["gear_shift_counter"]
		if value.has("shifted_down"):
			result["shifted_down"] = value["shifted_down"]
		if value.has("g_transfer"):
			result["g_transfer"] = value["g_transfer"]
		if value.has("throttle"):
			result["throttle"] = value["throttle"]
		if value.has("brake"):
			result["brake"] = value["brake"]
		if value.has("has_contact_with_ground"):
			result["has_contact_with_ground"] = value["has_contact_with_ground"]
		if value.has("steering"):
			result["steering"] = value["steering"]
		return result

func integrate(f: Callable) -> Callable:
	return func(params: Dictionary) -> Dictionary:
		var value = f.call(params)
		var linear_velocity = params["linear_velocity"]
		var angular_velocity = params["angular_velocity"]
		var timestep = params["timestep"]
		if value.has("linear_acceleration"):
			linear_velocity += value["linear_acceleration"] * timestep
		if value.has("angular_acceleration"):
			angular_velocity += value["angular_acceleration"] * timestep
		value["linear_velocity"] = linear_velocity
		value["angular_velocity"] = angular_velocity
		return value

func enable_if(predicate: Callable, f: Callable) -> Callable:
	return func(params: Dictionary) -> Dictionary:
		if predicate.call(params):
			return f.call(params)
		return extract(params)

func either(predicate: Callable, true_f: Callable, false_f: Callable) -> Callable:
	return func(params: Dictionary) -> Dictionary:
		if predicate.call(params):
			return true_f.call(params)
		return false_f.call(params)

func neg(predicate: Callable) -> Callable:
	return func(params: Dictionary) -> bool:
		return not predicate.call(params)

func compose(f: Callable, g: Callable) -> Callable:
	return func(params: Dictionary) -> Dictionary:
		var result = extend(g).call(params)
		return extract.call(extend(f).call(result))

func make_pipeline(composer: Callable, func_array: Array) -> Callable:
	var last_idx = func_array.size() - 1
	var i = last_idx - 1
	var f = func_array[last_idx]
	while i >= 0:
		var g = func_array[i]
		f = composer.call(f, g)
		i -= 1
	return f

func make_model_pipeline(func_array: Array) -> Callable:
	return make_pipeline(compose, func_array)

func process(params: Dictionary) -> Dictionary:
	return extract(params)

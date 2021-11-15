extends RigidBody

var skid_steer = true
# control variables
export var enginePower : float = 280.0
export var steering_rate : float = 0.0
var max_steering_rate : float = 1.0
var steering_angle : float = 0.0
var max_steering_angle : float = 0.8
var throttle = 0.0
var max_throttle = 50.0

# currently, raycast driver expects this array to exist in the controller script
var ray_wheels : Array = []
var drivePerRay : float = enginePower

var count : int = 0

func handle4WheelDrive(delta) -> void:
	# 4WD with front wheel steering
	if Input.is_action_pressed("ui_up"):
		if throttle < 0.0:
			throttle *= 0.9
		throttle += 0.4
	if Input.is_action_pressed("ui_down"):
		if throttle > 0.0:
			throttle *= 0.9
		throttle -= 0.4
	throttle = clamp(throttle, -max_throttle, max_throttle)

	if Input.is_action_pressed("ui_left"):
		steering_rate += 0.1
	if Input.is_action_pressed("ui_right"):
		steering_rate -= 0.1

	steering_rate = clamp(steering_rate, -max_steering_rate, max_steering_rate)
	steering_angle += steering_rate * delta
	steering_angle = clamp(steering_angle, -max_steering_angle, max_steering_angle)

	var drive = global_transform.basis.z * throttle * delta

	if (count % 30 == 0):
		# print("%s, %s" % [throttle, drive])
		print("%s, %s" % [steering_rate, steering_angle])

	if not skid_steer:
		var steering_angle_deg = rad2deg(steering_angle)
		# TODO(lucasw) figure out spin center, calculate per wheel angle relative to that
		get_node("FL_ray").rotation_degrees.y = steering_angle_deg
		get_node("RL_ray").rotation_degrees.y = -steering_angle_deg

		get_node("FR_ray").rotation_degrees.y = steering_angle_deg
		get_node("RR_ray").rotation_degrees.y = -steering_angle_deg
		
		for ray_wheel in ray_wheels:
			ray_wheel.applyDriveForce(drive)
	else:
		var left_throttle = throttle - steering_angle/max_steering_angle * max_throttle
		var right_throttle = throttle + steering_angle/max_steering_angle * max_throttle
		var max_abs_throttle = max(abs(left_throttle), abs(right_throttle))
		if max_abs_throttle > max_throttle:
			var fr = max_throttle / max_abs_throttle
			left_throttle *= fr
			right_throttle *= fr

		var left_drive = global_transform.basis.z * left_throttle * delta
		get_node("FL_ray").applyDriveForce(left_drive)
		get_node("RL_ray").applyDriveForce(left_drive)

		var right_drive = global_transform.basis.z * right_throttle * delta
		get_node("FR_ray").applyDriveForce(right_drive)
		get_node("RR_ray").applyDriveForce(right_drive)

	steering_angle *= 0.99
	throttle *= 0.99
	count += 1

func _ready() -> void:
	# setup array of drive elements and setup drive power
	for node in get_children():
		if node is RayCast:
			node.rotation_degrees.y = 0.0
			print(node.name)
			ray_wheels.append(node)
	drivePerRay = enginePower / ray_wheels.size()
	print("Found ", ray_wheels.size(), " raycasts connected to wheeled vehicle, setting to provide ", drivePerRay, " power each.")

func _physics_process(delta) -> void:
	handle4WheelDrive(delta)

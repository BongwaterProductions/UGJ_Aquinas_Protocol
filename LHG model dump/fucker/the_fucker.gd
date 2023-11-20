#@tool
extends CharacterBody3D

#var target = null
var player = null
var CanSeeTarget = false
var CanSeePlayer = false
var rng = RandomNumberGenerator.new()

@export var player_path : NodePath
@onready var mode = 'chase'
@onready var chimneys = []

@onready var nav = $NavigationAgent3D
@onready var down_ray_path = $RayCast3D
@onready var playerVisionRay = $CollisionShape3D/PlayerVisionChecker
@onready var goingToVisionRay = $CollisionShape3D/GoingToVisionChecker
@onready var GoingTo = $GoingTo
@onready var GoingToGrounder = $GoingTo/GoingtoGrounder
@onready var mesh = $"the fucker"
@onready var animator = $"the fucker/AnimationPlayer"
@onready var up_ray_path = $CeilingRayCast
@onready var ray = down_ray_path
@onready var label = $Label

@onready var base_transform = 0.0

@export_range(0, 10, 0.001) var AIR_CONTROL = 1.0
@export_range(0, 1, 0.001) var GROUND_ACCELERATION = 0.2
@export_range(0, 1, 0.001) var GROUND_DECELERATION = 0.2

@export_range(0, 100, 0.001) var RUN_SPEED = 7.5
@export_range(0, 15, 0.001) var WALK_SPEED = 3.0
@onready var SPEED = RUN_SPEED
@onready var direction = Vector3(1.0, 0.0, 0.0)

@export_range(0, 250, 0.001) var view_distance = 35.0
@export_range(0, 250, 0.001) var sniffing_distance = 5.0
@export_range(0, 250, 0.001) var h_FOV = 90.0
@export_range(0, 250, 0.001) var up_FOV = 45.0
@export_range(0, 250, 0.001) var down_FOV = 90.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var gravity_direction = ProjectSettings.get_setting("physics/3d/default_gravity_vector")

func findLookAtRotation(src,fin):
	var z = fin.z-src.z
	var rx = atan2(fin.y - src.y,z)
	var ry = atan2(fin.x-src.x * cos(rx),z)
	var rz = atan2(cos(rx),sin(rx)*sin(ry))
	var o = Vector3(rx,ry,rz)
	return o

func align_with_y(xform, new_y):
	xform.basis.y = new_y
	xform.basis.x = -xform.basis.z.cross(new_y)
	xform.basis = xform.basis.orthonormalized()
	return xform

func CanSee(thing, ray, isPlayer=false):
	if (global_position-thing.global_position).length()>sniffing_distance:
		var Sees = ray.get_collider()==null or ray.get_collider()==thing or ray.get_collider()==player
		if isPlayer:
			print(Sees)
		if isPlayer:
			Sees = ray.get_collider()==thing
		if (global_position-thing.global_position).length()>view_distance:
			Sees = false
			
		if isPlayer:
			print(Sees)
		
		var selfXY = global_position
		selfXY.y = 0.0
		
		var thingXY = thing.global_position
		thingXY.y = 0.0
		
		var guh = global_position - thing.global_position
		var lookDir = atan2(-guh.x, -guh.z)
		var lookAtRot = Vector3(0.0, lookDir, 0.0)
		lookAtRot = lookAtRot - mesh.global_rotation + Vector3(0.0, deg_to_rad(180.0), 0.0)
		if mesh.global_rotation.y < 0:
			lookAtRot.y -= deg_to_rad(360)
		var fov = h_FOV / 2.0
		if (!(rad_to_deg(lookAtRot.y) > fov)) and (!(rad_to_deg(lookAtRot.y) < 0-fov)):
			'ok'
		else:
			Sees = false
			
		if isPlayer:
			print(Sees)
			print(!(rad_to_deg(lookAtRot.y) > fov))
			print(!(rad_to_deg(lookAtRot.y) < 0-fov))
			
		if isPlayer:
			print()
			
		return Sees
	else:
		return true

func _ready():
	#target = get_node(player)
	player = get_node(player_path)
	base_transform = global_transform
	base_transform.basis.x = Vector3.ZERO
	base_transform.basis.y = Vector3.ZERO

func _physics_process(delta):
	var anim_speed = (velocity.length()/7.5)*4.5
	animator.play("Running", -1.0, anim_speed)
	
	goingToVisionRay.target_position = (Vector3(Vector3(0.0, 0.0, 0.0)-(goingToVisionRay.global_position)))+GoingTo.global_position
	playerVisionRay.target_position = (Vector3(Vector3(0.0, 0.0, 0.0)-(playerVisionRay.global_position)))+player.global_position
	
	CanSeeTarget = CanSee(GoingTo, goingToVisionRay)
		
	CanSeePlayer = CanSee(player, playerVisionRay, true)

	label.text = str(CanSeePlayer)
	
	if Input.is_action_just_pressed("door"):
		retreat()
		
	if not is_on_floor():
		velocity.y -= gravity * delta
	if (GoingTo.global_position - global_position).length() > 2.0:
		ray.force_raycast_update()
		nav.set_target_position(GoingTo.global_transform.origin)
		var next_nav_point = nav.get_next_path_position()
		direction = (next_nav_point - global_transform.origin)
		direction = direction.normalized()
		
	else:
		direction = Vector3.ZERO
	
	if true:
		if direction:
			velocity.x = lerp(velocity.x, direction.x*SPEED, delta*GROUND_ACCELERATION*20)
			velocity.y = lerp(velocity.y, direction.y*SPEED, delta*GROUND_ACCELERATION*20)
			velocity.z = lerp(velocity.z, direction.z*SPEED, delta*GROUND_ACCELERATION*20)
		else:
			velocity.x = lerp(velocity.x, direction.x*SPEED, delta*GROUND_DECELERATION*20)
			velocity.y = lerp(velocity.y, direction.y*SPEED, delta*GROUND_DECELERATION*20)
			velocity.z = lerp(velocity.z, direction.z*SPEED, delta*GROUND_DECELERATION*20)
	else:
		velocity.x = lerp(velocity.x, velocity.x+direction.x, delta*AIR_CONTROL*20)
		velocity.y = lerp(velocity.y, velocity.y+direction.y, delta*AIR_CONTROL*20)
		velocity.z = lerp(velocity.z, velocity.z+direction.z, delta*AIR_CONTROL*20)

	move_and_slide()
	
	var norm = ray.get_collision_normal()
	var guh = align_with_y(Transform3D(), norm)
	var lookdir = atan2(-velocity.x, -velocity.z)
	guh.basis = guh.basis.rotated(norm, lookdir)
	mesh.global_transform.basis = lerp(mesh.global_transform.basis, guh.basis, delta*5.0*(velocity.length()/7.5))
		
	var pos = ray.get_collision_point()
	mesh.global_transform.origin = lerp(mesh.global_transform.origin, pos, delta*5.0*(velocity.length()/7.5))
	mesh.scale = Vector3(1.0, 1.0, 1.0)
	
	
	if mode == 'chase':
		SPEED = RUN_SPEED
		if CanSeePlayer:
			GoingTo.global_position = player.global_position
		if (global_position-player.global_position).length() < 1.2:
			get_tree().quit()
		
	if mode == 'search':
		if velocity.length() < 2.0:
			var randomNumber = rng.randf_range(0, global.lastFrameTime*2500)
			if randomNumber < 0.025:
				var randoPos = global_position
				randoPos.x += rng.randf_range(-20.0, 20.0)
				randoPos.y += rng.randf_range(0.0, 20.0)
				randoPos.z += rng.randf_range(-20.0, 20.0)
				GoingTo.global_position = randoPos
				SPEED = WALK_SPEED
				
	decideMode()
		
	GoingToGrounder.force_update_transform()
	GoingToGrounder.force_raycast_update()
	if GoingToGrounder.is_colliding():
		GoingTo.global_position = GoingToGrounder.get_collision_point()+Vector3(0.0, 1.0, 0.0)

func retreat():
	print('guh')

func decideMode():
	if CanSeeTarget and !CanSeePlayer:
		mode = 'search'
	elif CanSeePlayer:
		await get_tree().create_timer(0.5).timeout
		mode = 'chase'

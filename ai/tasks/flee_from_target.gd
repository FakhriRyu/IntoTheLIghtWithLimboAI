@tool
extends BTAction
## Kabur menjauhi target selama durasi tertentu (flee behavior)
## Setelah selesai flee, set cooldown agar tidak langsung flee lagi
## Returns RUNNING saat sedang berlari menjauh
## Returns SUCCESS setelah durasi flee selesai (dan set cooldown)
## Returns FAILURE jika target tidak valid

## Blackboard variable yang menyimpan target (Node2D)
@export var target_var: StringName = &"target"

## Kecepatan flee (lebih cepat dari normal untuk kabur)
@export var flee_speed: float = 150.0

## Durasi flee dalam detik
@export var flee_duration: float = 2.0

## Durasi cooldown setelah flee (dalam detik)
## Selama cooldown, CheckLowHP akan return FAILURE
@export var cooldown_duration: float = 5.0

## Blackboard variable untuk menyimpan waktu cooldown berakhir
@export var cooldown_var: StringName = &"flee_cooldown_end"

## Timer internal
var flee_elapsed: float = 0.0


func _generate_name() -> String:
	return "FleeFrom %s (%.1fs, cd:%.1fs)" % [LimboUtility.decorate_var(target_var), flee_duration, cooldown_duration]


func _enter() -> void:
	# Reset timer saat masuk task
	flee_elapsed = 0.0


func _tick(delta: float) -> Status:
	var target: Node2D = blackboard.get_var(target_var, null)
	
	if not is_instance_valid(target):
		return FAILURE
	
	# Update timer
	flee_elapsed += delta
	
	# Cek apakah durasi flee sudah selesai
	if flee_elapsed >= flee_duration:
		# Stop movement
		if agent is CharacterBody2D:
			agent.velocity.x = 0
		
		# Set cooldown di blackboard (waktu sekarang + cooldown duration)
		var cooldown_end_time = Time.get_ticks_msec() / 1000.0 + cooldown_duration
		blackboard.set_var(cooldown_var, cooldown_end_time)
		
		return SUCCESS
	
	# Bergerak menjauhi target (arah kebalikan dari target)
	var direction = target.global_position.direction_to(agent.global_position)
	var velocity = direction * flee_speed
	
	# Update posisi agent
	if agent is CharacterBody2D:
		agent.velocity.x = velocity.x
		agent.move_and_slide()
		
		# Flip sprite berdasarkan arah gerak (hadap ke arah kabur)
		if agent.has_method("update_facing"):
			agent.update_facing(velocity.x)
		else:
			# Fallback untuk agent yang tidak punya method update_facing
			var sprite = agent.get_node_or_null("Sprite2D")
			if sprite and sprite is Sprite2D:
				sprite.flip_h = velocity.x < 0
	
	return RUNNING


func _exit() -> void:
	# Stop movement dan reset timer
	if agent is CharacterBody2D:
		agent.velocity.x = 0
	flee_elapsed = 0.0

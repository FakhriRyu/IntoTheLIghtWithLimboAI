extends Area2D

## Hitbox SkullWolf. Hanya aktif saat serigala menerkam (lihat
## ai/tasks/wolf_charge_attack.gd), jadi menyentuh serigala tidak lagi
## langsung melukai. Satu terkaman melukai maksimal sekali.

@export var damage: int = 2
## Selalu aktif seperti contact damage lama. Hanya untuk varian skull_wolf_fsm
## yang belum memakai terkaman.
@export var contact_always_on: bool = false

var active: bool = false
var _already_hit: bool = false


func _ready() -> void:
	set_active(contact_always_on)


func set_active(is_active: bool) -> void:
	active = is_active
	_already_hit = false
	set_deferred("monitoring", is_active)
	set_deferred("monitorable", is_active)
	for child in get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", not is_active)


func _physics_process(_delta: float) -> void:
	if not active or _already_hit or not monitoring:
		return
	# Serigala yang sudah mati tidak boleh melukai, walau masih ada di layar
	# selama animasi mati berjalan
	var wolf := get_parent()
	if wolf and "is_dead" in wolf and wolf.is_dead:
		return

	for area in get_overlapping_areas():
		if area is GameHurtbox:
			area.take_damage(damage, global_position)
			if OS.is_debug_build():
				print("SkullWolf hit player for ", damage, " damage")
			# contact_always_on tetap melukai berulang seperti dulu
			if not contact_always_on:
				_already_hit = true
			else:
				set_physics_process(false)
				get_tree().create_timer(1.0).timeout.connect(set_physics_process.bind(true))
			break

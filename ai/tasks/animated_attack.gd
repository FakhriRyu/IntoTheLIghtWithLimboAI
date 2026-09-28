@tool
extends BTAction
## Memainkan animasi serangan dan memanggil method agent pada detik tertentu
## Dipakai agar proyektil/trap muncul di tengah animasi, bukan di akhirnya,
## tanpa perlu menambah call-method track di AnimationPlayer
## Returns RUNNING selama animasi berjalan
## Returns SUCCESS setelah durasi selesai (dan set cooldown jika diisi)
## Returns FAILURE jika AnimationPlayer atau animasi tidak ditemukan

## Path ke AnimationPlayer milik agent
@export var animation_player_path: NodePath = ^"AnimationPlayer"

## Nama animasi serangan yang dimainkan
@export var animation: StringName = &""

## Nama method pada agent yang dipanggil saat serangan dilepas
## (mis. "shoot_arrow" atau "spawn_trap")
@export var attack_method: StringName = &""

## Detik ke berapa (sejak animasi mulai) method serangan dipanggil
@export var fire_time: float = 0.0

## Nama method pada agent untuk memunculkan indikator peringatan (opsional).
## Dipanggil dengan satu argumen: jeda (detik) sampai serangan benar-benar dilepas,
## mis. "show_arrow_warning"
@export var telegraph_method: StringName = &""

## Detik ke berapa indikator peringatan dimunculkan (biasanya 0.0 = awal animasi)
@export var telegraph_time: float = 0.0

## Durasi total task. 0 berarti memakai panjang animasi
@export var duration: float = 0.0

## Durasi cooldown setelah serangan selesai (detik). 0 berarti tanpa cooldown
@export var cooldown_duration: float = 0.0

## Blackboard variable untuk menyimpan waktu cooldown berakhir
@export var cooldown_var: StringName = &"attack_cooldown_end"

var animation_player: AnimationPlayer

## Timer internal
var elapsed: float = 0.0
## Penanda agar method serangan hanya dipanggil sekali per eksekusi
var fired: bool = false
## Penanda agar indikator peringatan hanya dimunculkan sekali per eksekusi
var telegraphed: bool = false


func _generate_name() -> String:
	var warn := ""
	if not telegraph_method.is_empty():
		warn = " +warn:%s()" % telegraph_method
	return "AnimatedAttack \"%s\" ➜%s() @%.1fs%s (cd:%.1fs)" % [animation, attack_method, fire_time, warn, cooldown_duration]


func _setup() -> void:
	if animation_player_path:
		animation_player = agent.get_node_or_null(animation_player_path)


func _enter() -> void:
	elapsed = 0.0
	fired = false
	telegraphed = false

	# Boss berhenti bergerak saat menyerang
	if agent is CharacterBody2D:
		agent.velocity.x = 0

	if animation_player != null and animation_player.has_animation(animation):
		animation_player.play(animation)


func _tick(delta: float) -> Status:
	if animation_player == null or not animation_player.has_animation(animation):
		return FAILURE

	elapsed += delta

	# Munculkan indikator peringatan lebih dulu supaya player sempat bereaksi
	if not telegraphed and not telegraph_method.is_empty() and elapsed >= telegraph_time:
		telegraphed = true
		if agent.has_method(telegraph_method):
			agent.call(telegraph_method, maxf(fire_time - telegraph_time, 0.0))

	# Lepaskan serangan tepat di tengah animasi
	if not fired and elapsed >= fire_time:
		fired = true
		if agent.has_method(attack_method):
			agent.call(attack_method)

	# Durasi efektif: pakai panjang animasi kalau duration tidak diisi
	var total_duration: float = duration
	if total_duration <= 0.0:
		total_duration = animation_player.get_animation(animation).length

	if elapsed >= total_duration:
		# Pastikan serangan tetap keluar walau fire_time melebihi durasi
		if not fired and agent.has_method(attack_method):
			agent.call(attack_method)
			fired = true

		if cooldown_duration > 0.0:
			var cooldown_end_time: float = Time.get_ticks_msec() / 1000.0 + cooldown_duration
			blackboard.set_var(cooldown_var, cooldown_end_time)

		return SUCCESS

	return RUNNING


func _exit() -> void:
	if agent is CharacterBody2D:
		agent.velocity.x = 0

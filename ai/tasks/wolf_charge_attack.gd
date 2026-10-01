@tool
extends BTAction
## Serangan menerkam SkullWolf dalam tiga tahap, supaya tidak ada lagi
## sentuhan yang langsung melukai tanpa peringatan:
##   1. CHARGE  : diam menunduk dan berdenyut merah. Garis merah (seperti panah
##                Norc'Thex) menunjukkan jalur terkaman. Arah terkunci di awal,
##                jadi player bisa menghindar dengan menjauh, melompat, atau dash.
##   2. LUNGE   : melesat lurus sejauh lunge_distance. Hitbox hanya menyala di sini.
##   3. RECOVER : terengah-engah diam sejenak, terbuka untuk dipukul.
## Returns RUNNING selama ketiga tahap, SUCCESS setelah recover selesai,
## FAILURE kalau agent tidak punya method terkaman.
## Cooldown dicatat ke blackboard setiap tugas berakhir (termasuk saat dibatalkan).

enum Phase { CHARGE, LUNGE, RECOVER }

## Blackboard variable yang menyimpan target (Node2D)
@export var target_var: StringName = &"target"

## Lama mengumpulkan tenaga = lama garis peringatan terlihat (detik)
@export var charge_time: float = 0.8

## Jarak terkaman, juga panjang garis peringatan (px)
@export var lunge_distance: float = 140.0

## Kecepatan saat melesat (px/dtk)
@export var lunge_speed: float = 320.0

## Lama terengah-engah setelah terkaman (detik)
@export var recover_time: float = 0.9

## Jeda sebelum boleh menerkam lagi, dihitung dari akhir tugas (detik)
@export var cooldown_duration: float = 1.5

## Blackboard variable untuk menyimpan waktu cooldown berakhir
@export var cooldown_var: StringName = &"wolf_attack_cd"

var _phase: Phase = Phase.CHARGE
var _elapsed: float = 0.0
var _dir: float = 1.0
var _lunge_start_x: float = 0.0


func _generate_name() -> String:
	return "WolfChargeAttack charge:%.1fs lunge:%.0fpx recover:%.1fs (cd:%.1fs)" % [
		charge_time, lunge_distance, recover_time, cooldown_duration]


func _enter() -> void:
	_phase = Phase.CHARGE
	_elapsed = 0.0

	var target: Node2D = blackboard.get_var(target_var, null)
	if is_instance_valid(target):
		_dir = signf(target.global_position.x - agent.global_position.x)
	if _dir == 0.0:
		_dir = agent.facing_dir() if agent.has_method("facing_dir") else 1.0

	if agent is CharacterBody2D:
		agent.velocity.x = 0.0
	if agent.has_method("begin_charge"):
		agent.begin_charge(_dir, charge_time, lunge_distance)


func _tick(delta: float) -> Status:
	if not agent.has_method("begin_lunge"):
		return FAILURE

	_elapsed += delta
	match _phase:
		Phase.CHARGE:
			agent.velocity.x = 0.0
			if _elapsed >= charge_time:
				_phase = Phase.LUNGE
				_elapsed = 0.0
				_lunge_start_x = agent.global_position.x
				agent.begin_lunge()

		Phase.LUNGE:
			agent.velocity.x = _dir * lunge_speed
			var travelled: float = absf(agent.global_position.x - _lunge_start_x)
			# berhenti saat sudah sejauh garis peringatan, menabrak tembok, atau di tepi jurang
			var blocked: bool = agent.is_on_wall() and _elapsed > 0.05
			var edge: bool = agent.is_on_floor() and not agent.has_floor_ahead(_dir)
			if travelled >= lunge_distance or blocked or edge:
				_phase = Phase.RECOVER
				_elapsed = 0.0
				agent.velocity.x = 0.0
				agent.begin_recover()

		Phase.RECOVER:
			agent.velocity.x = 0.0
			if _elapsed >= recover_time:
				return SUCCESS

	return RUNNING


func _exit() -> void:
	if agent is CharacterBody2D:
		agent.velocity.x = 0.0
	if agent.has_method("cancel_attack"):
		agent.cancel_attack()
	if cooldown_duration > 0.0:
		blackboard.set_var(cooldown_var, Time.get_ticks_msec() / 1000.0 + cooldown_duration)

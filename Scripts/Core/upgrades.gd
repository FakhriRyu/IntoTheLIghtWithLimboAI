class_name Upgrades
extends RefCounted
## Daftar upgrade roguelike yang ditawarkan saat naik level / membuka relik.
## Tiap entri: id unik, nama, deskripsi, rarity, batas tumpukan, dan efek.
## Efek berupa [nama_stat, nilai] yang DITAMBAHKAN ke RunState.stats per tumpukan.
## Kunci opsional "heal" / "light" langsung memulihkan HP / cahaya saat dipilih.

enum Rarity { COMMON, RARE, EPIC }

const RARITY_NAMES := ["Biasa", "Langka", "Epik"]
const RARITY_COLORS := [Color(0.78, 0.8, 0.86), Color(0.35, 0.7, 1.0), Color(1.0, 0.72, 0.2)]
## Bobot peluang tiap rarity muncul di satu kartu
const RARITY_WEIGHTS := [60.0, 30.0, 10.0]

const ALL: Array[Dictionary] = [
	{
		"id": "tajam", "name": "Bilah Tajam", "rarity": Rarity.COMMON, "max": 3,
		"desc": "+1 damage untuk semua tebasan.",
		"effects": [["damage_bonus", 1]],
	},
	{
		"id": "jantung", "name": "Jantung Baja", "rarity": Rarity.COMMON, "max": 4,
		"desc": "+2 HP maksimal dan pulihkan 2 HP.",
		"effects": [["max_hp_bonus", 2]], "heal": 2,
	},
	{
		"id": "angin", "name": "Langkah Angin", "rarity": Rarity.COMMON, "max": 3,
		"desc": "+10% kecepatan lari.",
		"effects": [["speed_mult", 0.1]],
	},
	{
		"id": "kilat", "name": "Dash Kilat", "rarity": Rarity.COMMON, "max": 3,
		"desc": "Cooldown dash -20%.",
		"effects": [["dash_cd_mult", -0.2]],
	},
	{
		"id": "sumbu", "name": "Sumbu Awet", "rarity": Rarity.COMMON, "max": 3,
		"desc": "Cahaya meredup 15% lebih lambat.",
		"effects": [["decay_mult", -0.15]],
	},
	{
		"id": "lentera", "name": "Lentera Besar", "rarity": Rarity.COMMON, "max": 3,
		"desc": "+25 cahaya maksimal dan radius cahaya +15%.",
		"effects": [["max_light_bonus", 25], ["radius_mult", 0.15]], "light": 25,
	},
	{
		"id": "magnet", "name": "Tangan Cahaya", "rarity": Rarity.COMMON, "max": 2,
		"desc": "Radius tarik pickup +60%.",
		"effects": [["magnet_mult", 0.6]],
	},
	{
		"id": "haus", "name": "Haus Cahaya", "rarity": Rarity.RARE, "max": 2,
		"desc": "Tiap tebasan yang mengenai musuh memulihkan 2 cahaya.",
		"effects": [["light_on_hit", 2]],
	},
	{
		"id": "pemburu", "name": "Insting Pemburu", "rarity": Rarity.RARE, "max": 2,
		"desc": "+30% XP dari semua sumber.",
		"effects": [["xp_mult", 0.3]],
	},
	{
		"id": "darah", "name": "Darah Bulan", "rarity": Rarity.RARE, "max": 2,
		"desc": "25% peluang pulih 1 HP setiap membunuh musuh.",
		"effects": [["kill_heal_chance", 0.25]],
	},
	{
		"id": "bayang", "name": "Kulit Bayangan", "rarity": Rarity.RARE, "max": 2,
		"desc": "Waktu kebal setelah terkena serangan +0,5 dtk.",
		"effects": [["immunity_bonus", 0.5]],
	},
	{
		"id": "surya", "name": "Pamungkas Surya", "rarity": Rarity.EPIC, "max": 1,
		"desc": "Tebasan ke-3 combo +2 damage dan memulihkan 5 cahaya.",
		"effects": [["finisher_bonus", 2], ["finisher_light", 5]],
	},
	{
		"id": "sinar", "name": "Sinar Terakhir", "rarity": Rarity.EPIC, "max": 1,
		"desc": "Sekali per area: saat cahaya padam, kamu bertahan dengan 30 cahaya.",
		"effects": [["last_light", 1]],
	},
]


static func get_by_id(id: String) -> Dictionary:
	for u in ALL:
		if u["id"] == id:
			return u
	return {}

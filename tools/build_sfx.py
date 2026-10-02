#!/usr/bin/env python3
"""Olah sampel rekaman CC0 jadi SFX siap pakai: buang hening di depan,
geser nada, lapiskan beberapa sampel, potong, lalu normalisasi puncak.

Sumber (semua CC0, lihat Assets/audio/CREDITS.md) diekstrak ke satu folder:
  creature/   80 CC0 creature SFX (rubberduck)        80-CC0-creature-SFX_0.zip
  rpgsfx/     80 CC0 RPG SFX (rubberduck)             80-CC0-RPG-SFX_0.zip
  sword/      20 Sword Sound Effects (StarNinjas)     sword_-_starninjas_1.zip
  goblins/    Goblins Sound Pack (artisticdude)       goblins_0.zip
  swishes/    Swishes Sound Pack (artisticdude)       swishes.zip
  wolf/       Wolf Monster Sound (CaveboyTup), Dog Growl (bonebrah), Dog Grunt (qubodup)
  kenney/     Kenney RPG Audio (Audio/*.ogg)
  boss/       Norc'Thex: crow.ogg (fvcalderan), crow_caw.wav (zeroisnotnull),
              wings_flap_large.ogg (AntumDeluge), teleport.wav (Ogrebane),
              172206__fins__teleport.wav (fins), dark_magic/*.flac (qubodup),
              Bow.wav (artisticdude), arrow-grab-from-quiver-01.wav (Vehicle)

Pemakaian:  python3 tools/build_sfx.py <folder_sumber>
Keluaran:   Assets/audio/sfx/real/*.wav  (butuh ffmpeg)
"""
import os, re, subprocess, sys, tempfile

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "Assets", "audio", "sfx", "real")
OLD_SFX = os.path.join(ROOT, "Assets", "audio", "sfx")
SR = 44100
PEAK_DB = -1.0


def L(path, gain=0.0, delay=0.0, pitch=1.0, length=None):
    """Satu lapisan: file, gain (dB), jeda (detik), pengali nada, panjang maks (detik)."""
    return dict(path=path, gain=gain, delay=delay, pitch=pitch, length=length)


# nama keluaran -> (lapisan..., panjang total maks)
RECIPES = {
    # --- pedang: ayunan
    "sword_swing_0": ([L("sword/sword.3.ogg", length=0.45)], 0.45),
    "sword_swing_1": ([L("sword/sword.4.ogg", length=0.45)], 0.45),
    "sword_swing_2": ([L("sword/sword.6.ogg", length=0.45)], 0.45),
    "sword_swing_heavy_0": ([L("sword/sword.1.ogg", pitch=0.88, length=0.6)], 0.6),
    "sword_swing_heavy_1": ([L("sword/sword.7.ogg", pitch=0.88, length=0.6)], 0.6),
    # --- pedang: menyayat musuh (sayatan + bobot daging)
    "sword_hit_0": ([L("kenney/knifeSlice.ogg"), L("kenney/chop.ogg", gain=-7)], 0.45),
    "sword_hit_1": ([L("kenney/knifeSlice2.ogg"), L("kenney/chop.ogg", gain=-7, pitch=0.9)], 0.45),
    "sword_hit_2": ([L("rpgsfx/blade_01.ogg"), L("kenney/chop.ogg", gain=-8, pitch=1.1)], 0.4),
    "sword_hit_heavy_0": ([L("rpgsfx/blade_03.ogg", pitch=0.9),
                           L("old/kenney/impactPunch_heavy_000.ogg", gain=-5)], 0.6),
    "sword_hit_heavy_1": ([L("kenney/knifeSlice2.ogg", pitch=0.85),
                           L("old/kenney/impactPunch_heavy_001.ogg", gain=-5)], 0.6),
    # --- player
    "step_0": ([L("kenney/footstep00.ogg")], 0.3),
    "step_1": ([L("kenney/footstep01.ogg")], 0.3),
    "step_2": ([L("kenney/footstep02.ogg")], 0.3),
    "step_3": ([L("kenney/footstep03.ogg")], 0.3),
    "jump": ([L("old/femaleJump.mp3"), L("swishes/swish-9.wav", gain=-8, pitch=0.9)], 0.4),
    "land": ([L("kenney/footstep05.ogg", pitch=0.8), L("kenney/dropLeather.ogg", gain=-4)], 0.4),
    "dash": ([L("swishes/swish-9.wav", pitch=0.75), L("swishes/swish-7.wav", gain=-4, delay=0.04, pitch=0.85)], 0.45),
    "player_hurt": ([L("old/femaleHurt.mp3"), L("old/kenney/impactPunch_medium_000.ogg", gain=-6)], 0.6),
    "player_death": ([L("old/femaleHurt.mp3", pitch=0.8),
                      L("old/kenney/impactPunch_heavy_000.ogg", gain=-3)], 1.0),
    # --- goblin: cempreng, cerewet
    "goblin_attack_0": ([L("goblins/goblin-4.wav")], 0.6),
    "goblin_attack_1": ([L("goblins/goblin-15.wav")], 0.6),
    "goblin_attack_2": ([L("goblins/goblin-9.wav")], 0.6),
    "goblin_hurt_0": ([L("goblins/goblin-1.wav")], 0.4),
    "goblin_hurt_1": ([L("goblins/goblin-5.wav")], 0.4),
    "goblin_hurt_2": ([L("goblins/goblin-11.wav")], 0.4),
    "goblin_death_0": ([L("goblins/goblin-3.wav")], 1.0),
    "goblin_death_1": ([L("goblins/goblin-12.wav")], 1.0),
    # --- serigala
    "wolf_growl_0": ([L("wolf/wolf_monster_5.mp3")], 1.4),
    "wolf_growl_1": ([L("wolf/dog-growl.ogg", pitch=0.85)], 0.9),
    "wolf_lunge_0": ([L("creature/barking_01.ogg", pitch=0.85), L("swishes/swish-9.wav", gain=-6, pitch=0.8)], 0.6),
    "wolf_lunge_1": ([L("creature/barking_02.ogg", pitch=0.85), L("swishes/swish-7.wav", gain=-6, pitch=0.8)], 0.6),
    "wolf_hurt_0": ([L("wolf/dog-frieda-grunt-96khz-01.flac", pitch=1.1)], 0.5),
    "wolf_hurt_1": ([L("creature/barking_02.ogg", pitch=1.3)], 0.45),
    "wolf_death_0": ([L("creature/howl.ogg", pitch=0.85)], 1.2),
    "wolf_death_1": ([L("wolf/wolf_monster_6.mp3", pitch=0.95)], 1.5),
    # --- orc: berat, menggeram
    "orc_attack_0": ([L("creature/grunt_02.ogg", pitch=0.85)], 0.7),
    "orc_attack_1": ([L("creature/grunt_04.ogg", pitch=0.85)], 0.7),
    "orc_attack_2": ([L("creature/troll_03.ogg", pitch=0.9)], 0.7),
    "orc_hurt_0": ([L("creature/hurt_02.ogg", pitch=0.8)], 0.6),
    "orc_hurt_1": ([L("creature/hurt_03.ogg", pitch=0.8)], 0.6),
    "orc_death_0": ([L("creature/monster_04.ogg", pitch=0.85)], 1.5),
    "orc_death_1": ([L("creature/monster_07.ogg", pitch=0.85)], 1.4),
    # --- katak
    "frog_croak": ([L("creature/burble_01.ogg")], 0.8),
    "frog_hurt": ([L("creature/burp_02.ogg", pitch=1.2)], 0.6),
    "frog_death": ([L("creature/burble_02.ogg", pitch=0.85)], 1.0),
    # --- bos Norc'Thex: makhluk gagak bertopeng tengkorak, bersenjata crossbow
    "boss_crossbow_load": ([L("boss/arrow-grab-from-quiver-01.wav"), L("kenney/metalClick.ogg", gain=-4, delay=0.25)], 0.6),
    "boss_crossbow": ([L("kenney/metalClick.ogg", pitch=0.8), L("boss/Bow.wav", delay=0.01),
                       L("swishes/swish-5.wav", gain=-8, delay=0.04, pitch=1.2)], 0.55),
    "boss_scream": ([L("boss/crow.ogg", pitch=0.62), L("boss/crow_caw.wav", gain=-2, delay=0.05, pitch=0.5),
                     L("boss/wings_flap_large.ogg", gain=-6, length=0.5)], 1.2),
    "boss_hurt_0": ([L("boss/crow.ogg", pitch=0.8, length=0.35)], 0.35),
    "boss_hurt_1": ([L("boss/crow_caw.wav", pitch=0.7, length=0.4)], 0.4),
    "boss_vanish": ([L("boss/dark_magic/fout-02.flac"), L("boss/wings_flap_large.ogg", gain=-5, length=0.5)], 1.1),
    "boss_appear": ([L("boss/172206__fins__teleport.wav", pitch=0.7), L("boss/wings_flap_large.ogg", gain=-6, length=0.5)], 0.8),
    "boss_death": ([L("boss/crow.ogg", pitch=0.5), L("boss/crow_caw.wav", gain=-3, delay=0.25, pitch=0.42),
                    L("boss/dark_magic/fout-01.flac", gain=-3, delay=0.4)], 2.6),
    "trap_snap": ([L("rpgsfx/metal_01.ogg"), L("rpgsfx/chain_01.ogg", gain=-6)], 0.6),
}


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def build(name, layers, max_len, src):
    args = ["ffmpeg", "-y", "-hide_banner"]
    chains, labels = [], []
    for i, ly in enumerate(layers):
        path = ly["path"]
        path = os.path.join(OLD_SFX, path[4:]) if path.startswith("old/") else os.path.join(src, path)
        if not os.path.exists(path):
            raise FileNotFoundError(path)
        args += ["-i", path]
        f = [f"[{i}:a]aformat=sample_fmts=fltp:channel_layouts=mono", f"aresample={SR}",
             "silenceremove=start_periods=1:start_threshold=-42dB:start_silence=0.005"]
        if ly["pitch"] != 1.0:
            f += [f"asetrate={int(SR * ly['pitch'])}", f"aresample={SR}"]
        if ly["length"]:
            f.append(f"atrim=0:{ly['length']}")
        if ly["gain"]:
            f.append(f"volume={ly['gain']}dB")
        if ly["delay"]:
            f.append(f"adelay={int(ly['delay'] * 1000)}")
        chains.append(",".join(f) + f"[a{i}]")
        labels.append(f"[a{i}]")
    mix = "".join(labels) + (f"amix=inputs={len(labels)}:normalize=0" if len(labels) > 1 else "anull")
    # potong, lalu fade-out pendek di ujung supaya tidak ada klik
    mix += f",atrim=0:{max_len},areverse,afade=t=in:d=0.04,areverse[out]"
    tmp = tempfile.mktemp(suffix=".wav")
    r = run(args + ["-filter_complex", ";".join(chains + [mix]), "-map", "[out]", "-ar", str(SR), tmp])
    if r.returncode != 0:
        raise RuntimeError(r.stderr[-800:])
    peak = float(re.search(r"max_volume: ([-0-9.]+)", run(
        ["ffmpeg", "-hide_banner", "-i", tmp, "-af", "volumedetect", "-f", "null", "-"]).stderr).group(1))
    out = os.path.join(OUT, name + ".wav")
    r = run(["ffmpeg", "-y", "-hide_banner", "-i", tmp, "-af", f"volume={PEAK_DB - peak}dB",
             "-c:a", "pcm_s16le", out])
    os.unlink(tmp)
    if r.returncode != 0:
        raise RuntimeError(r.stderr[-800:])
    print("ok", name)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    os.makedirs(OUT, exist_ok=True)
    for n, (layers, max_len) in RECIPES.items():
        build(n, layers, max_len, sys.argv[1])

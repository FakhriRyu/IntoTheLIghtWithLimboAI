#!/usr/bin/env python3
"""Bangun ulang audio cutscene dari sampel rekaman CC0 (pengganti SFX sintetis).

Sumber (semua CC0, lihat Assets/audio/CREDITS.md) diekstrak ke satu folder:
  amb_rain_loop_1.ogg                      AMB Rain Loop 1 (OpenGameArt)
  atmosbasement.mp3_.flac                  Dripping water loop
  heartbeat.mp3_.flac                      Heartbeat (single sound)
  rumble.wav                               rumble fx
  dungeon002_0.ogg                         Dungeon Ambience
  cold_silence.ogg                         Cold Silence (musik)
  emotional_piano_solo_0.ogg               Emotional Piano (musik)
  horror/.../ambient_horror_track01.ogg    Ambient Horror Track 01 (musik)
  mw/*.ogg                                 100 CC0 Metal and Wood SFX
  brk/*.ogg                                75 CC0 breaking / falling / hit SFX
  kenney/*.ogg                             Kenney Interface/Impact Sounds (Assets/audio/sfx/kenney)

Pemakaian:  python3 tools/build_cutscene_audio.py <folder_sumber>
Keluaran:   Assets/audio/sfx/cutscene/*.wav  dan  Assets/audio/music/cutscene/*.mp3  (butuh ffmpeg)
"""
import os, re, subprocess, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SFX_OUT = os.path.join(ROOT, "Assets", "audio", "sfx", "cutscene")
MUSIC_OUT = os.path.join(ROOT, "Assets", "audio", "music", "cutscene")
KENNEY = os.path.join(ROOT, "Assets", "audio", "sfx", "kenney")
SR = 44100
REVERB = "aecho=0.8:0.6:60|140|260:0.35|0.25|0.15"


def ff(src, out, af, extra=()):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-af", af, *extra, out], check=True)


def pitch(p):
    """Geser nada (sekaligus durasi) dengan mengubah sample rate lalu kembalikan ke SR."""
    return f"asetrate={int(SR * p)},aresample={SR}"


def norm(db=-3):
    """Penanda puncak target (dB); gain dihitung di sfx()/render()."""
    return f"@peak={db}"


def render(src, out, af, ch=1):
    """Jalankan filter, ukur puncaknya, lalu naik/turunkan gain agar puncak = target dari norm()."""
    m = re.search(r",?@peak=(-?[0-9.]+)", af)
    target = float(m.group(1)) if m else -3.0
    af = re.sub(r",?@peak=-?[0-9.]+", "", af) + f",aformat=channel_layouts={'mono' if ch == 1 else 'stereo'}"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    probe = subprocess.run(["ffmpeg", "-v", "info", "-i", src, "-af", af + ",volume=-24dB,volumedetect", "-f", "null", "-"],
                           capture_output=True, text=True).stderr
    peak = float(re.search(r"max_volume: (-?[0-9.]+) dB", probe).group(1)) + 24.0  # diukur -24 dB agar tidak terpotong
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-af", f"{af},volume={target - peak}dB",
                    "-ar", str(SR), "-ac", str(ch), out], check=True)


def sfx(src, name, af, ch=1):
    render(src, os.path.join(SFX_OUT, name + ".wav"), af, ch)


def seamless_loop(src, name, start, length, xf=2.0, vol=0.0):
    """Potong [start, start+length], lalu silang-pudar ujung ke pangkal supaya loop tanpa klik."""
    fc = (f"[0]atrim={start + xf}:{start + length},asetpts=N/SR/TB[b];"
          f"[0]atrim={start}:{start + xf},asetpts=N/SR/TB[h];"
          f"[b][h]acrossfade=d={xf},volume={vol}dB")
    out = os.path.join(SFX_OUT, name + ".wav")
    subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-filter_complex", fc,
                    "-ar", "22050", "-ac", "1", out], check=True)


def main(d):
    p = lambda *a: os.path.join(d, *a)
    k = lambda n: os.path.join(KENNEY, n + ".ogg")

    # --- loop latar
    seamless_loop(p("amb_rain_loop_1.ogg"), "rain_loop", 5, 40, vol=13)
    seamless_loop(p("dungeon002_0.ogg"), "drone_loop", 20, 40, vol=17)

    # --- efek
    sfx(p("atmosbasement.mp3_.flac"), "drip", "atrim=4.55:5.3,asetpts=N/SR/TB,afade=t=in:d=0.01,afade=t=out:st=0.5:d=0.25," + norm(-4))
    sfx(p("brk", "bfh1_wood_hit_01.ogg"), "thump", f"{pitch(0.75)},lowpass=f=900," + norm(-3))
    sfx(p("mw", "keys_02.ogg"), "clink", f"{pitch(1.1)},afade=t=out:st=0.3:d=0.16," + norm(-6))
    sfx(p("mw", "wood_cracking_02.ogg"), "crack", f"{pitch(0.9)},afade=t=out:st=0.18:d=0.07," + norm(-3))
    sfx(p("rumble.wav"), "rumble", "atrim=0:4.5,afade=t=in:d=0.4,afade=t=out:st=3.3:d=1.2," + norm(-4), ch=2)
    sfx(os.path.join(ROOT, "Assets", "audio", "sfx", "real", "dash.wav"), "whoosh",
        f"{pitch(0.7)},{REVERB},afade=t=out:st=0.6:d=0.4," + norm(-5))
    # sting: benturan berat + dentang logam, ekor panjang
    render(k("impactPunch_heavy_001"), os.path.join(SFX_OUT, "sting.wav"),
           f"{pitch(0.7)},{REVERB},apad=pad_dur=1.0,atrim=0:2.2,afade=t=out:st=1.2:d=1.0," + norm(-3))
    # shimmer: dua dentingan kaca/konfirmasi dengan gema
    render(k("glass_002"), os.path.join(SFX_OUT, "shimmer.wav"),
           f"{pitch(1.0)},{REVERB},apad=pad_dur=1.6,atrim=0:2.0,afade=t=in:d=0.15,afade=t=out:st=1.0:d=1.0," + norm(-5))
    # beep monitor jantung: ketukan antarmuka bernada tinggi
    sfx(k("confirmation_001"), "beep", f"{pitch(1.0)},atrim=0:0.25,afade=t=out:st=0.15:d=0.1," + norm(-6))

    # --- blip dialog (tick lembut, nada beda per karakter)
    for name, pt in (("blip_fiora", 1.35), ("blip_elian", 0.95), ("blip_unknown", 0.7)):
        sfx(k("tick_002"), name, f"{pitch(pt)},atrim=0:0.09,afade=t=out:st=0.05:d=0.04," + norm(-8))

    # --- musik
    os.makedirs(MUSIC_OUT, exist_ok=True)
    for src, name, af in (
        (p("cold_silence.ogg"), "prolog_cold_silence", "atrim=0:150,afade=t=in:d=2,afade=t=out:st=145:d=5"),
        (p("horror", "Ambient Horror Track 01", "ambient_horror_track01.ogg"), "boss_ambient_horror", "volume=3dB,alimiter=limit=0.95,afade=t=in:d=2"),
        (p("emotional_piano_solo_0.ogg"), "ending_emotional_piano", "volume=8dB,alimiter=limit=0.95,afade=t=in:d=2,afade=t=out:st=70:d=6.8"),
    ):
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src, "-af", af, "-c:a", "libmp3lame", "-q:a", "4",
                        os.path.join(MUSIC_OUT, name + ".mp3")], check=True)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])

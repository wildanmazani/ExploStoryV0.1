"""Compose and render Explo-Story's Nusantara-flavoured music as WAV loops.

Gamelan-inspired: a slendro-like 5-tone scale, saron playing the core melody
(balungan), bonang elaborating at double speed, gong marking each cycle,
kendang drum patterns and a breathy suling flute. Pure Python (no numpy),
deterministic. Output: assets/audio/music/<area>_<stem>.ogg and stingers
(44.1 kHz Ogg Vorbis, mastered for phone speakers: see save()).

Each area has two stems that loop in sync:
  base   = gong, saron balungan, kendang, drone  (always playing)
  melody = bonang + suling                        (faded in while exploring)
Plus a shared "fokus" stem for puzzles, "debar" for chases and short one-shot
stingers.

Run: python tools/gen_music.py
"""
import math
import os
import random
import struct
import wave

import numpy as np
import soundfile as sf
from array import array

RATE = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "music")
SLENDRO = [1.0, 1.1487, 1.3195, 1.5157, 1.7411]  # ~240 cent steps

_cache = {}


def freq(degree, base):
    octave, step = divmod(degree, 5)
    return base * SLENDRO[step] * (2 ** octave)


# --- instruments (return float arrays) -------------------------------------
def metal(f, dur, partials, decay, amp, attack=0.003):
    key = ("m", round(f, 2), dur, tuple(partials), decay, amp)
    if key in _cache:
        return _cache[key]
    n = int(dur * RATE)
    out = array("f", bytes(4 * n))
    for ratio, pa, pd in partials:
        w = 2 * math.pi * f * ratio / RATE
        k = math.exp(-decay * pd / RATE)
        env = amp * pa
        for i in range(n):
            a = env * (min(1.0, i / (attack * RATE)))
            out[i] += a * math.sin(w * i)
            env *= k
    _cache[key] = out
    return out


def saron(f, amp=0.22):
    return metal(f, 1.6, [(1, 1.0, 1.0), (2.76, 0.35, 2.2), (5.4, 0.12, 3.5)], 2.6, amp)


def bonang(f, amp=0.16):
    return metal(f, 0.9, [(1, 1.0, 1.0), (1.51, 0.25, 1.6), (4.1, 0.1, 3.0)], 4.0, amp)


def gong(f=65.0, amp=0.5):
    # two close partials beat slowly (ombak), long decay
    return metal(f, 5.0, [(1, 1.0, 1.0), (1.012, 0.8, 1.0), (2.0, 0.25, 1.6), (2.9, 0.1, 2.5)], 0.8, amp, attack=0.02)


def kempul(f=110.0, amp=0.28):
    return metal(f, 2.2, [(1, 1.0, 1.0), (1.008, 0.7, 1.0), (2.1, 0.2, 2.0)], 1.6, amp, attack=0.01)


def musicbox(f, amp=0.18):
    return metal(f, 2.0, [(1, 1.0, 1.0), (3.0, 0.2, 2.5), (6.2, 0.08, 4.0)], 2.2, amp, attack=0.001)


def kendang(kind, amp=0.35):
    key = ("k", kind, amp)
    if key in _cache:
        return _cache[key]
    rnd = random.Random(kind)
    n = int(0.35 * RATE)
    out = array("f", bytes(4 * n))
    for i in range(n):
        t = i / RATE
        if kind == "dhung":   # deep open stroke
            v = math.sin(2 * math.pi * (90 + 70 * math.exp(-t * 25)) * t) * math.exp(-t * 9)
        elif kind == "tak":   # slap
            v = (rnd.uniform(-1, 1) * 0.6 + math.sin(2 * math.pi * 380 * t) * 0.4) * math.exp(-t * 45)
        else:                 # "tung" light
            v = math.sin(2 * math.pi * (210 + 60 * math.exp(-t * 30)) * t) * math.exp(-t * 16)
        out[i] = v * amp
    _cache[key] = out
    return out


def suling(f, dur, amp=0.12):
    n = int(dur * RATE)
    rnd = random.Random(int(f * 10))
    out = array("f", bytes(4 * n))
    ph = 0.0
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / 0.08) * min(1.0, (dur - t) / 0.15)
        vib = 1 + 0.006 * math.sin(2 * math.pi * 5.2 * t) * min(1.0, t / 0.4)
        ph += 2 * math.pi * f * vib / RATE
        v = math.sin(ph) + 0.18 * math.sin(2 * ph) + 0.05 * rnd.uniform(-1, 1)
        out[i] = v * env * amp
    return out


def drone(f, dur, amp=0.06):
    n = int(dur * RATE)
    out = array("f", bytes(4 * n))
    for i in range(n):
        t = i / RATE
        out[i] = amp * (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 1.5 * t + 1.0)) * (0.8 + 0.2 * math.sin(2 * math.pi * 0.1 * t))
    return out


# --- mixing ------------------------------------------------------------------
def place(buf, snd, at_sec, loop_len):
    """Add a sound; anything past the end wraps to the start so loops are seamless."""
    start = int(at_sec * RATE)
    n = len(buf)
    for i, v in enumerate(snd):
        buf[(start + i) % n] += v


def highpass(x, cutoff=120.0):
    """2nd-order high-pass (RBJ biquad): phone speakers cannot play the deep
    gong and drone, they only rattle and muddy everything else."""
    w0 = 2 * math.pi * cutoff / RATE
    alpha = math.sin(w0) / (2 * 0.707)
    c = math.cos(w0)
    a0 = 1 + alpha
    b0, b1, b2 = (1 + c) / 2 / a0, -(1 + c) / a0, (1 + c) / 2 / a0
    a1, a2 = -2 * c / a0, (1 - alpha) / a0
    out = np.empty_like(x)
    x1 = x2 = y1 = y2 = 0.0
    # run twice round the loop so the start continues from the end (seamless)
    for _ in range(2):
        for i in range(len(x)):
            v = x[i]
            y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, v, y1, y
            out[i] = y
    return out


def save(name, buf, peak=0.55):
    """Peaks leave room for the two stems and the sound effects to play
    together without clipping (the old 0.85 + 0.6 mix distorted)."""
    x = highpass(np.frombuffer(buf, dtype=np.float32).astype(np.float64))
    m = max(1e-6, float(np.max(np.abs(x))))
    x = x * (peak / m)
    os.makedirs(OUT, exist_ok=True)
    data = x.astype(np.float32)
    # in small blocks: libsndfile's Vorbis encoder overflows the stack on Windows
    # when handed a whole loop at once
    with sf.SoundFile(os.path.join(OUT, name + ".ogg"), "w", RATE, 1, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), 4096):
            f.write(data[i:i + 4096])
    print("wrote", name, "%.1fs" % (len(buf) / RATE))


# --- composition -------------------------------------------------------------
def balungan(rnd, length=16):
    """Core melody: stepwise with occasional leaps, each gatra ends on a stable tone."""
    notes, cur = [], rnd.choice([0, 2, 3])
    for i in range(length):
        if i % 4 == 3:
            cur = rnd.choice([0, 2, 4]) if i != length - 1 else 0
        else:
            cur = max(-2, min(6, cur + rnd.choice([-2, -1, -1, 1, 1, 2])))
        notes.append(cur)
    return notes


def area(name, bpm, base, seed, drums="calm", flute=True, mood="day"):
    rnd = random.Random(seed)
    beat = 60.0 / bpm
    beats = 32
    total = beats * beat
    n = int(total * RATE)
    base_buf = array("f", bytes(4 * n))
    mel_buf = array("f", bytes(4 * n))
    core = balungan(rnd) + balungan(rnd)

    for b in range(beats):
        t = b * beat
        place(base_buf, saron(freq(core[b], base)), t, n)
        if b % 16 == 0:
            place(base_buf, gong(base / 4.5), t, n)
        elif b % 8 == 4:
            place(base_buf, kempul(base / 2.2), t, n)
        # kendang
        if drums == "busy":
            pattern = ["dhung", "tak", "tung", "tak"]
            place(base_buf, kendang(pattern[b % 4]), t, n)
            if b % 2 == 1:
                place(base_buf, kendang("tung", 0.18), t + beat / 2, n)
        elif drums == "calm" and b % 4 in (0, 3):
            place(base_buf, kendang("dhung" if b % 4 == 0 else "tung", 0.22), t, n)
        # bonang: elaborate between this note and the next at double speed
        nxt = core[(b + 1) % beats]
        for k, deg in enumerate([core[b], nxt, core[b], nxt] if mood != "night" else [core[b] + 5, nxt + 5]):
            step = beat / (4 if mood != "night" else 2)
            snd = bonang(freq(deg + 5, base)) if mood != "night" else musicbox(freq(deg, base * 2))
            place(mel_buf, snd, t + k * step, n)
    place(base_buf, drone(base / 2, total), 0, n)
    if flute:
        t = 0.0
        while t < total - beat:
            deg = rnd.choice(core) + 5
            d = beat * rnd.choice([1, 2, 2, 3])
            place(mel_buf, suling(freq(deg, base), d * 0.95), t, n)
            t += d + beat * rnd.choice([0, 1, 2])
    save(name + "_base", base_buf)
    save(name + "_melody", mel_buf, peak=0.4)


def fokus(bpm=90, base=146.8):
    beat = 60.0 / bpm
    total = 16 * beat
    n = int(total * RATE)
    buf = array("f", bytes(4 * n))
    for b in range(16):
        place(buf, kendang("tung", 0.2), b * beat, n)
        if b % 4 == 0:
            place(buf, kempul(base / 1.5, 0.18), b * beat, n)
        place(buf, bonang(freq([0, 2, 1, 3][b % 4] + 5, base), 0.07), b * beat + beat / 2, n)
    save("fokus", buf, peak=0.35)


def debar(bpm=132, base=110.0):
    """Chases and fear (the fog in the dream, Aisyah running): a racing kendang
    and a low pulse that never settles, a semitone apart, under bonang
    tremolos that climb a little every bar. Same two stems as an area."""
    beat = 60.0 / bpm
    beats = 32
    total = beats * beat
    n = int(total * RATE)
    base_buf = array("f", bytes(4 * n))
    mel_buf = array("f", bytes(4 * n))
    semi = 2 ** (1 / 12)
    for b in range(beats):
        t = b * beat
        bar = b // 4
        # heartbeat kendang: dhung-dhung on the beat, slaps in between
        place(base_buf, kendang("dhung", 0.4), t, n)
        place(base_buf, kendang("dhung", 0.26), t + beat * 0.28, n)
        place(base_buf, kendang("tak", 0.2), t + beat * 0.5, n)
        place(base_buf, kendang("tung", 0.14), t + beat * 0.75, n)
        # the low pulse rocks between two notes a semitone apart
        f = base if bar % 2 == 0 else base * semi
        place(base_buf, kempul(f, 0.2), t, n)
        place(base_buf, kempul(f, 0.12), t + beat / 2, n)
        if b % 8 == 0:
            place(base_buf, gong(base / 2, 0.4), t, n)
        # tremolo: the tritone, rising a step every bar and back down
        lift = semi ** [0, 1, 2, 3, 2, 1, 3, 4][bar]
        for k in range(4):
            fk = base * 4 * lift * (1 if k % 2 == 0 else math.sqrt(2))
            place(mel_buf, bonang(fk, 0.07 + 0.01 * (bar % 4)), t + k * beat / 4, n)
    place(base_buf, drone(base / 2, total, 0.05), 0, n)
    save("debar_base", base_buf)
    save("debar_melody", mel_buf, peak=0.32)


def stinger(name, degrees, base, step, with_gong=True):
    total = step * len(degrees) + 3.0
    n = int(total * RATE)
    buf = array("f", bytes(4 * n))
    for i, d in enumerate(degrees):
        place(buf, saron(freq(d, base), 0.3), i * step, n)
        place(buf, bonang(freq(d + 5, base), 0.18), i * step, n)
    if with_gong:
        place(buf, gong(base / 4.5, 0.45), step * (len(degrees) - 1), n)
    save(name, buf, peak=0.7)


if __name__ == "__main__":
    import sys
    if "debar" in sys.argv[1:]:  # python tools/gen_music.py debar: only that one
        debar()
        sys.exit()
    area("tajuk", 76, 293.7, 11, drums="calm")
    area("bilik", 64, 220.0, 5, drums="none", flute=False, mood="night")
    area("permulaan", 84, 261.6, 21, drums="calm")
    area("kampung", 92, 293.7, 3, drums="calm")
    area("gerbang", 70, 246.9, 8, drums="none")
    area("pelabuhan", 108, 329.6, 13, drums="busy")
    area("melaka", 80, 277.2, 17, drums="calm")
    area("siguntang", 66, 233.1, 29, drums="none")
    fokus()
    debar()
    stinger("st_item", [0, 2, 4, 5, 7], 293.7, 0.13)
    stinger("st_zone", [0, 2, 3, 5, 7, 10], 261.6, 0.18)
    stinger("st_levelup", [0, 3, 5, 8], 329.6, 0.11, with_gong=False)
    stinger("st_correct", [5, 7], 293.7, 0.08, with_gong=False)

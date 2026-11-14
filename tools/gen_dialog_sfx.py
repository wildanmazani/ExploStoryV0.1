"""Dialogue sounds, rendered once to small WAV files so the game never has to
compute them (no lag on the web):

  assets/audio/sfx/babble_a/e/i/o/u.wav  cute fast "talking", one syllable per
                                          vowel; played at each speaker's pitch
  assets/audio/sfx/taip_1..4.wav          typewriter keys for the narrator
  assets/audio/sfx/taip_space.wav         the space bar (softer, lower)

    python tools/gen_dialog_sfx.py
"""
import math
import pathlib
import random
import struct
import wave

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets/audio/sfx"
RATE = 22050
FORMANTS = {"a": (800, 1250), "e": (500, 1900), "i": (320, 2400), "o": (520, 920), "u": (360, 780)}


def save(name: str, samples: list) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in samples))


def syllable(f1: float, f2: float) -> list:
    """a bright 300 Hz voice, rising a little, shaped by the vowel's formants"""
    w = [math.exp(-((300 * k - f1) / 160) ** 2) + 0.6 * math.exp(-((300 * k - f2) / 260) ** 2) + 0.08 / k for k in range(1, 15)]
    out = []
    for i in range(int(0.075 * RATE)):
        t = i / RATE
        f0 = 300 * (1 + 0.12 * min(t / 0.05, 1))
        ph = 2 * math.pi * f0 * t
        v = sum(math.sin(ph * (k + 1)) * w[k] for k in range(len(w)))
        env = min(t / 0.006, 1) * math.exp(-max(t - 0.02, 0) * 45)
        out.append(v * env * 0.22)
    return out


def key(seed: int, body: float, click: float, length: float = 0.06) -> list:
    """one typewriter key: a sharp metal click, then the key's wooden thock"""
    rnd = random.Random(seed)
    out = []
    lp = 0.0
    for i in range(int(length * RATE)):
        t = i / RATE
        n = rnd.uniform(-1, 1)
        lp += (n - lp) * 0.25  # duller noise for the thock
        c = n * math.exp(-t * 900) * 0.9                                   # click
        b = (lp * 1.6 + math.sin(2 * math.pi * body * t) * 0.6) * math.exp(-t * 110) * 0.55  # thock
        r = math.sin(2 * math.pi * click * t) * math.exp(-t * 260) * 0.25  # little metal ring
        out.append((c + b + r) * 0.7)
    return out


if __name__ == "__main__":
    for v, (f1, f2) in FORMANTS.items():
        save(f"babble_{v}", syllable(f1, f2))
    for i, (body, click) in enumerate([(180, 3100), (210, 2800), (165, 3400), (195, 2600)], 1):
        save(f"taip_{i}", key(i * 7, body, click))
    save("taip_space", [x * 0.8 for x in key(99, 120, 1800, 0.08)])
    print("written to", OUT)

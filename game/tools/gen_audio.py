"""Generates placeholder sound effects (no external assets needed).
Run: python3 tools/gen_audio.py   (writes into audio/)
Replace these files with real sounds later - keep the same file names."""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "audio")
random.seed(7)


def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.9 / peak
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples))


def n(sec):
    return int(sec * SR)


def lowpass(xs, a):
    y, out = 0.0, []
    for x in xs:
        y += a * (x - y)
        out.append(y)
    return out


def noise(sec):
    return [random.uniform(-1, 1) for _ in range(n(sec))]


def footstep():
    xs = lowpass(noise(0.14), 0.12)
    return [x * math.exp(-i / (SR * 0.03)) for i, x in enumerate(xs)]


def clank():
    out = []
    for i in range(n(0.7)):
        t = i / SR
        s = sum(math.sin(2 * math.pi * f * t) * math.exp(-t * d) for f, d in [(420, 6), (1130, 9), (1870, 12), (2650, 16)])
        s += random.uniform(-1, 1) * math.exp(-t * 60) * 0.8
        out.append(s)
    return out


def roar():
    xs = lowpass(noise(2.2), 0.05)
    out = []
    for i, x in enumerate(xs):
        t = i / SR
        env = min(1, t / 0.25) * math.exp(-max(0, t - 0.9) * 2.2)
        f = 110 - 50 * t / 2.2 + 6 * math.sin(2 * math.pi * 7 * t)
        s = math.sin(2 * math.pi * f * t) * 0.8 + x * 3.0
        out.append(math.tanh(s * 2.5) * env)
    return out


def sting():
    out = []
    for i in range(n(1.4)):
        t = i / SR
        env = math.exp(-t * 2.5)
        s = sum(math.sin(2 * math.pi * f * t) for f in [880, 932, 1245, 1318]) * 0.4
        s += math.sin(2 * math.pi * 55 * t) * 1.5 + random.uniform(-1, 1) * math.exp(-t * 8) * 1.5
        out.append(math.tanh(s) * env)
    return out


def chime():
    out = []
    for i in range(n(3.0)):
        t = i / SR
        out.append(sum(math.sin(2 * math.pi * 523 * r * t) * math.exp(-t * d) * a
                       for r, d, a in [(1, 1.2, 1), (2.76, 2.0, 0.5), (5.4, 3.5, 0.25)]))
    return out


def hum():
    xs = lowpass(noise(4.0), 0.02)
    out = []
    for i, x in enumerate(xs):
        t = i / SR
        out.append(math.sin(2 * math.pi * 50 * t) * 0.5 + math.sin(2 * math.pi * 100 * t) * 0.25 + x * 1.2)
    fade = n(0.05)  # smooth loop seam
    for i in range(fade):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return out


def click():
    return [random.uniform(-1, 1) * math.exp(-i / (SR * 0.004)) for i in range(n(0.04))]


def groan():
    out, ph = [], 0.0
    for i in range(n(1.8)):
        t = i / SR
        f = 80 + 10 * math.sin(2 * math.pi * 1.3 * t) - 15 * t
        ph += f / SR
        saw = 2 * (ph % 1) - 1
        env = math.sin(math.pi * t / 1.8)
        out.append(saw * env)
    return lowpass(out, 0.08)


def power_down():
    out, ph = [], 0.0
    for i in range(n(1.6)):
        t = i / SR
        f = 400 * math.exp(-t * 2.2) + 30
        ph += f / SR
        out.append(math.sin(2 * math.pi * ph) * math.exp(-t * 1.2) + random.uniform(-1, 1) * 0.1 * math.exp(-t * 3))
    return out


def pickup():
    out = []
    for f, dur in [(880, 0.07), (1320, 0.12)]:
        for i in range(n(dur)):
            t = i / SR
            out.append(math.sin(2 * math.pi * f * t) * math.exp(-t * 20))
    return out


def stamp():
    xs = lowpass(noise(0.25), 0.2)
    return [x * math.exp(-i / (SR * 0.04)) + math.sin(2 * math.pi * 90 * i / SR) * math.exp(-i / (SR * 0.06)) for i, x in enumerate(xs)]


def writeup():
    out = stamp()
    for i in range(n(0.45)):
        t = i / SR
        sq = 1 if math.sin(2 * math.pi * 150 * t) > 0 else -1
        out.append(sq * 0.4 * (1 - t / 0.45))
    return out


def quack():
    out, ph = [], 0.0
    for i in range(n(0.28)):
        t = i / SR
        f = 520 - 700 * t
        ph += f / SR
        saw = 2 * (ph % 1) - 1
        out.append(saw * math.sin(math.pi * t / 0.28))
    return lowpass(out, 0.3)


def radio():
    xs = noise(0.35)
    return [x * (0.5 + 0.5 * math.sin(2 * math.pi * 30 * i / SR)) * (1 - i / len(xs)) for i, x in enumerate(xs)]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, fn in [("footstep", footstep), ("clank", clank), ("roar", roar), ("sting", sting), ("chime", chime),
                     ("hum", hum), ("click", click), ("groan", groan), ("power_down", power_down), ("pickup", pickup),
                     ("stamp", stamp), ("writeup", writeup), ("quack", quack), ("radio", radio)]:
        save(name + ".wav", fn())
        print("wrote", name)

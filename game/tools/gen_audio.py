"""Procedural music + sound effects for Do Not Touch the Exhibits.

Everything is synthesized from scratch (no samples) so it is fully owned and commercial-safe.
Run from the game/ folder:   python3 tools/gen_audio.py        (takes ~1-2 minutes)
Writes audio/music/*.ogg (loops + stingers) and audio/*.wav / *.ogg (sound effects, ambience).
Replace any file with a real recording later - keep the same file name.

All music shares one leitmotif: the "Pemberton Waltz" (D minor, 3/4).
"""
import math
import os

import numpy as np
import soundfile as sf
from scipy import signal

SR = 32000
BASE = os.path.join(os.path.dirname(__file__), "..", "audio")
MUSIC = os.path.join(BASE, "music")
rng = np.random.default_rng(2026)


# =============================================================== basics ====

def n_of(sec):
    return int(round(sec * SR))


def t_of(n):
    return np.arange(n) / SR


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def note(name):
    """'D4' / 'C#5' / 'Bb3' -> midi number."""
    names = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    base = names[name[0]]
    rest = name[1:]
    if rest.startswith("#"):
        base += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        base -= 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + base


def write_ogg(path, data):
    """libsndfile can crash writing big Vorbis buffers at once - stream it in blocks."""
    data = np.ascontiguousarray(data, dtype=np.float32)
    channels = 1 if data.ndim == 1 else data.shape[1]
    with sf.SoundFile(path, "w", SR, channels, format="OGG", subtype="VORBIS") as f:
        for i in range(0, len(data), 8192):
            f.write(data[i:i + 8192])


def lowpass(x, cutoff, order=2):
    cutoff = min(cutoff, SR * 0.45)
    sos = signal.butter(order, cutoff, "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def highpass(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def bandpass(x, lo, hi, order=2):
    hi = min(hi, SR * 0.45)
    sos = signal.butter(order, [lo, hi], "band", fs=SR, output="sos")
    return signal.sosfilt(sos, x, axis=0)


def resonator(x, freq, q):
    b, a = signal.iirpeak(min(freq, SR * 0.45), q, fs=SR)
    return signal.lfilter(b, a, x)


def sweep_filter(x, cutoffs, kind="low", block=256):
    """Time-varying 2-pole filter. cutoffs: array per sample (or callable on time)."""
    out = np.zeros_like(x)
    zi = None
    for i in range(0, len(x), block):
        c = float(np.clip(cutoffs[min(i, len(cutoffs) - 1)], 30, SR * 0.45))
        sos = signal.butter(2, c, kind, fs=SR, output="sos")
        if zi is None:
            zi = signal.sosfilt_zi(sos) * 0.0
        out[i:i + block], zi = signal.sosfilt(sos, x[i:i + block], zi=zi)
    return out


def env_exp(n, decay):
    return np.exp(-t_of(n) / max(decay, 1e-4))


def adsr(n, a, d, s, r, hold=None):
    """hold = seconds before release (defaults to total - r)."""
    t = t_of(n)
    total = n / SR
    hold = total - r if hold is None else hold
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel = np.clip((t - hold) / max(r, 1e-4), 0, 1)
    return e * (1 - rel) ** 2


def saw_wave(freq_arr):
    ph = np.cumsum(freq_arr / SR)
    return 2 * (ph % 1.0) - 1


def sine_wave(freq_arr, phase=0.0):
    return np.sin(2 * np.pi * np.cumsum(freq_arr / SR) + phase)


def noise(n):
    return rng.standard_normal(n)


def brown(n):
    b = np.cumsum(rng.standard_normal(n))
    b = b - lowpass(b, 5)
    return b / (np.max(np.abs(b)) + 1e-9)


def pan(mono, p):
    """p in [-1,1] -> stereo (n,2) constant power."""
    a = (p + 1) * np.pi / 4
    return np.stack([mono * np.cos(a), mono * np.sin(a)], axis=1)


def place(buf, snd, t_sec):
    i = n_of(t_sec)
    if i >= len(buf):
        return
    j = min(len(buf), i + len(snd))
    buf[i:j] += snd[:j - i]


def normalize(x, peak=0.89):
    m = np.max(np.abs(x)) + 1e-9
    return x * (peak / m)


def soft_clip(x, drive=1.0):
    return np.tanh(x * drive) / np.tanh(drive)


# ---------------------------------------------------------------- reverb ---

_IR = {}


def reverb_ir(seconds, damping=4000.0, early=True, seed=1):
    key = (seconds, damping, early, seed)
    if key in _IR:
        return _IR[key]
    r = np.random.default_rng(seed)
    n = n_of(seconds)
    t = t_of(n)
    env = np.exp(-6.9 * t / seconds)
    ir = np.zeros((n, 2))
    for ch in range(2):
        bright = r.standard_normal(n)
        dark = lowpass(r.standard_normal(n), damping * 0.25)
        mix = np.clip(t / seconds * 2, 0, 1)
        ir[:, ch] = (lowpass(bright, damping) * (1 - mix) + dark * 3 * mix) * env
    if early:
        for k in range(8):
            d = n_of(0.008 + r.random() * 0.06)
            ir[d, :] += (0.6 - k * 0.05) * np.array([r.random(), r.random()])
    ir[: n_of(0.004), :] = 0
    ir /= np.sqrt(np.sum(ir ** 2) / 2)
    _IR[key] = ir
    return ir


def reverb(x, seconds=3.0, wet=0.35, damping=4000.0, predelay=0.02):
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    ir = reverb_ir(seconds, damping)
    pad = np.zeros((n_of(predelay), 2))
    out = np.zeros((len(x) + len(ir) - 1 + len(pad), 2))
    for ch in range(2):
        conv = signal.fftconvolve(x[:, ch], ir[:, ch])
        out[len(pad):len(pad) + len(conv), ch] = conv
    dry = np.zeros_like(out)
    dry[: len(x)] = x
    return dry * (1 - wet * 0.5) + out * wet * 0.25


def delay(x, sec, feedback=0.35, mix=0.3):
    d = n_of(sec)
    out = x.copy()
    tap = x.copy()
    for k in range(1, 6):
        tap = np.concatenate([np.zeros((d,) + x.shape[1:]), tap[:-d]]) * feedback
        out = out + tap * mix
    return out


def make_loop(stereo, loop_len):
    """Wraps everything past loop_len (reverb tails) back onto the start -> seamless loop."""
    L = n_of(loop_len)
    if len(stereo) < L:
        stereo = np.concatenate([stereo, np.zeros((L - len(stereo), stereo.shape[1]))])
    out = stereo[:L].copy()
    tail = stereo[L:]
    while len(tail) > 0:
        k = min(L, len(tail))
        out[:k] += tail[:k]
        tail = tail[k:]
    return out


# ============================================================ instruments ==

def piano(freq, dur, vel=0.7, bright=1.0):
    n = n_of(dur + 2.5)
    t = t_of(n)
    out = np.zeros(n)
    B = 0.00035
    for k in range(1, 14):
        fk = k * freq * math.sqrt(1 + B * k * k)
        if fk > SR * 0.45:
            break
        amp = vel * (1.0 / k ** (1.35 - 0.4 * vel * bright))
        decay = 3.2 / (1 + 0.35 * k) * (261.0 / freq) ** 0.45
        for det in (-0.0006, 0.0006):
            out += amp * 0.5 * np.sin(2 * np.pi * fk * (1 + det) * t + rng.random() * 6.28) * np.exp(-t / decay)
    hammer = lowpass(noise(n_of(0.012)), 2500) * 0.15 * vel
    out[: len(hammer)] += hammer
    rel = np.clip((t - dur) / 0.25, 0, 1)
    out *= (1 - rel) ** 2
    return lowpass(out, 1800 + 3500 * vel * bright)


def music_box(freq, dur=1.6, vel=0.8, detune=0.004):
    f = freq * (1 + rng.uniform(-detune, detune))
    n = n_of(dur + 1.0)
    t = t_of(n)
    out = (np.sin(2 * np.pi * f * t) * np.exp(-t / 1.4)
           + 0.28 * np.sin(2 * np.pi * f * 4.07 * t) * np.exp(-t / 0.25)
           + 0.12 * np.sin(2 * np.pi * f * 9.3 * t) * np.exp(-t / 0.06)
           + 0.05 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / 0.8))
    click = highpass(noise(n_of(0.004)), 3000) * 0.3
    out[: len(click)] += click
    return out * vel


def celesta(freq, dur=1.2, vel=0.7):
    n = n_of(dur + 1.5)
    t = t_of(n)
    return vel * (np.sin(2 * np.pi * freq * t) * np.exp(-t / 1.1) + 0.3 * np.sin(2 * np.pi * freq * 3 * t) * np.exp(-t / 0.2))


def ks_pluck(freq, dur, bright=0.5, decay=0.996, body=None):
    """Karplus-Strong plucked string, vectorized per period."""
    N = max(2, int(round(SR / freq)))
    n = n_of(dur)
    y = np.zeros(n + N + 2)
    burst = rng.uniform(-1, 1, N)
    if bright < 1.0:
        burst = lowpass(burst, 500 + bright * 8000, 1)
    y[1:N + 1] = burst
    i = N + 1
    while i < n + N + 1:
        j = min(i + N, n + N + 1)
        y[i:j] = 0.5 * (y[i - N:j - N] + y[i - N - 1:j - N - 1]) * decay
        i = j
    out = y[N + 1:N + 1 + n]
    return out


def harpsichord(freq, dur=1.4, vel=0.8):
    a = ks_pluck(freq, dur, 0.9, 0.997)
    b = ks_pluck(freq * 2.002, dur, 0.9, 0.995) * 0.35  # 4' stop
    out = (a + b) * vel
    click = highpass(noise(n_of(0.006)), 2000) * 0.2
    out[: len(click)] += click
    return highpass(out, 120)


def strings(midis, dur, vel=0.5, attack=0.7, release=1.4, vibrato=0.12, cutoff=2600, tremolo=0.0):
    n = n_of(dur + release)
    t = t_of(n)
    out = np.zeros(n)
    for m in midis:
        f0 = hz(m)
        for v in range(5):
            det = (v - 2) * 0.0045 + rng.uniform(-0.001, 0.001)
            vib = 1 + vibrato / 12 * np.log(2) * np.sin(2 * np.pi * (5.2 + v * 0.13) * t + v) * np.clip(t / 1.2, 0, 1)
            out += saw_wave(np.full(n, f0 * (1 + det)) * vib)
    out /= max(1, len(midis) * 5) ** 0.5
    out = lowpass(out, cutoff, 2)
    env = adsr(n, attack, 1.0, 0.85, release, hold=dur)
    if tremolo > 0:
        env *= 1 - 0.5 * (1 + np.sin(2 * np.pi * tremolo * t))
    return out * env * vel


def brass(freq, dur, vel=0.7, release=0.3):
    n = n_of(dur + release)
    t = t_of(n)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.4, 0, 1)
    raw = sum(saw_wave(np.full(n, freq * (1 + d)) * vib) for d in (-0.003, 0.0, 0.0035)) / 3
    dark = lowpass(raw, 450)
    bright = lowpass(raw, 2800 * (0.6 + vel * 0.5))
    fenv = np.clip(t / 0.06, 0, 1) * (0.6 + 0.4 * np.exp(-t / 0.3))
    out = dark * (1 - fenv) + bright * fenv
    return out * adsr(n, 0.04, 0.4, 0.8, release, hold=dur) * vel


def choir(midis, dur, vel=0.5, vowel="ah", attack=1.0, release=1.5):
    formants = {"ah": [(800, 1.0), (1150, 0.5), (2900, 0.25)], "oo": [(320, 1.0), (800, 0.4), (2300, 0.1)], "eh": [(600, 1.0), (1800, 0.5), (2600, 0.2)]}[vowel]
    n = n_of(dur + release)
    t = t_of(n)
    src = np.zeros(n)
    for m in midis:
        for v in range(4):
            vib = 1 + 0.006 * np.sin(2 * np.pi * (4.8 + v * 0.3) * t + v * 1.3)
            src += saw_wave(np.full(n, hz(m) * (1 + (v - 1.5) * 0.004)) * vib)
    out = np.zeros(n)
    for f, a in formants:
        out += resonator(src, f, 6) * a
    out += lowpass(noise(n), 4000) * 0.02
    return normalize(out, 1.0) * adsr(n, attack, 1, 0.9, release, hold=dur) * vel


def whistle(freqs_durs, vel=0.5):
    """freqs_durs: list of (freq, dur). Portamento between notes, breathy."""
    total = sum(d for _, d in freqs_durs) + 0.3
    n = n_of(total)
    f = np.zeros(n)
    amp = np.zeros(n)
    pos = 0
    for fr, d in freqs_durs:
        k = n_of(d)
        f[pos:pos + k] = fr
        a = np.ones(k)
        a[: n_of(0.02)] = np.linspace(0, 1, n_of(0.02))
        a[-n_of(0.04):] *= np.linspace(1, 0.3, n_of(0.04))
        amp[pos:pos + k] = a if fr > 0 else 0
        pos += k
    f[f == 0] = 800
    f = lowpass(f, 25, 1)
    t = t_of(n)
    f = f * (1 + 0.01 * np.sin(2 * np.pi * 5.5 * t))
    tone = sine_wave(f) + 0.08 * sine_wave(f * 2)
    breath = bandpass(noise(n), 1500, 5000) * 0.05
    return (tone + breath) * lowpass(amp, 40, 1) * vel


def taiko(vel=1.0, pitch=1.0):
    n = n_of(1.2)
    t = t_of(n)
    f = (48 + 75 * np.exp(-t * 18)) * pitch
    body = sine_wave(f) * np.exp(-t * 3.5)
    slap = lowpass(noise(n), 1200) * np.exp(-t * 35) * 0.5
    return (body + slap) * vel


def timpani(freq, vel=1.0):
    n = n_of(2.0)
    t = t_of(n)
    out = sum(a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t * (1.5 + r)) for r, a in [(1, 1), (1.5, 0.5), (1.98, 0.3), (2.44, 0.15)])
    out += lowpass(noise(n), 800) * np.exp(-t * 30) * 0.4
    return out * vel


def snare(vel=0.6):
    n = n_of(0.35)
    t = t_of(n)
    return (bandpass(noise(n), 1500, 7000) * np.exp(-t * 14) + 0.5 * np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30)) * vel


def tick(vel=0.3, f=6000):
    n = n_of(0.05)
    return highpass(noise(n), f) * env_exp(n, 0.008) * vel


def cymbal(vel=0.5, dur=2.5):
    n = n_of(dur)
    t = t_of(n)
    metal = sum(np.sin(2 * np.pi * f * t + rng.random() * 6) for f in (3120, 4370, 5180, 6730, 8210)) * 0.1
    return (highpass(noise(n), 4500) + metal) * np.exp(-t * (3.0 / dur)) * vel


def boom(vel=1.0, dur=3.0):
    n = n_of(dur)
    t = t_of(n)
    sub = np.sin(2 * np.pi * (32 + 30 * np.exp(-t * 6)) * t) * np.exp(-t * 1.4)
    rumble = lowpass(noise(n), 160) * np.exp(-t * 1.8) * 1.5
    return (sub + rumble) * vel


def heartbeat(vel=1.0):
    def thump(v):
        n = n_of(0.25)
        t = t_of(n)
        return lowpass(np.sin(2 * np.pi * (45 + 40 * np.exp(-t * 30)) * t) * np.exp(-t * 18), 200) * v
    out = np.zeros(n_of(0.6))
    place(out, thump(vel), 0.0)
    place(out, thump(vel * 0.7), 0.17)
    return out


def drone(midis, dur, cutoff=300, lfo=0.07, vel=0.5):
    n = n_of(dur)
    t = t_of(n)
    raw = np.zeros(n)
    for m in midis:
        for d in (-0.003, 0.0, 0.004):
            raw += saw_wave(np.full(n, hz(m) * (1 + d)))
            raw += 0.6 * np.sin(2 * np.pi * hz(m) * (1 + d) * t)
    cut = cutoff * (1 + 0.6 * np.sin(2 * np.pi * lfo * t))
    return normalize(sweep_filter(raw, cut), 1.0) * vel


def shepard_rise(dur, base=40.0, octaves=7, vel=0.4):
    """Endless rising tone. Loops seamlessly if `dur` = one octave of glide."""
    n = n_of(dur)
    t = t_of(n)
    out = np.zeros(n)
    for k in range(octaves):
        pos = (k + t / dur) % octaves
        f = base * 2 ** pos
        amp = np.exp(-((pos - octaves / 2) ** 2) / (2 * (octaves / 5) ** 2))
        ph = np.cumsum(f / SR)
        out += np.sin(2 * np.pi * ph) * amp
        out += 0.3 * saw_wave(f) * amp * 0.3
    return lowpass(out, 3000) * vel


def metal_resonance(freq, dur=4.0, vel=0.5):
    """Bowed / struck metal: noise exciting inharmonic resonators."""
    n = n_of(dur)
    t = t_of(n)
    exc = noise(n) * np.exp(-t * 0.8) * (0.3 + 0.7 * np.exp(-t * 6))
    out = sum(resonator(exc, freq * r, 120) * a for r, a in [(1.0, 1), (2.32, 0.6), (3.87, 0.4), (5.13, 0.25)])
    return normalize(out, 1.0) * np.clip(t / 0.05, 0, 1) * np.exp(-t * (2.0 / dur)) * vel


def formant_voice(pitch, vowel_seq, dur, vel=0.5, growl=0.0):
    n = n_of(dur)
    t = t_of(n)
    f = np.full(n, float(pitch)) * (1 + 0.02 * np.sin(2 * np.pi * 5 * t))
    if growl:
        f *= 1 + growl * lowpass(noise(n), 30)
    src = saw_wave(f)
    vowels = {"a": (800, 1200), "o": (450, 800), "u": (325, 700), "e": (500, 1800), "i": (300, 2300)}
    out = np.zeros(n)
    seg = n // len(vowel_seq)
    for i, v in enumerate(vowel_seq):
        a, b = vowels[v]
        s = src[i * seg:(i + 1) * seg + n_of(0.02)]
        o = resonator(s, a, 5) + 0.6 * resonator(s, b, 7)
        out[i * seg:i * seg + len(o)] += o[: max(0, min(len(o), n - i * seg))]
    return lowpass(out, 3500) * vel


# ============================================================== the theme ==
# (beat, midi, beats) for the Pemberton Waltz, 3/4. Two 8-bar phrases.
THEME = []
_m = [("A4", 1), ("D5", 1), ("F5", 1), ("E5", 2), ("D5", 1), ("C#5", 1), ("D5", 1), ("E5", 1), ("A4", 3),
      ("Bb4", 1), ("D5", 1), ("G5", 1), ("F5", 2), ("E5", 1), ("D5", 1), ("C#5", 1), ("E5", 1), ("D5", 3),
      ("F5", 1), ("A5", 1), ("D6", 1), ("C6", 2), ("Bb5", 1), ("A5", 1), ("G5", 1), ("F5", 1), ("E5", 3),
      ("D5", 1), ("F5", 1), ("Bb5", 1), ("A5", 2), ("G5", 1), ("F5", 1), ("E5", 1), ("C#5", 1), ("D5", 3)]
_b = 0
for nm, d in _m:
    THEME.append((_b, note(nm), d))
    _b += d
THEME_BEATS = _b  # 48 beats = 16 bars
# One chord per bar (root list in midi), D minor
CHORDS = [["D3", "F3", "A3"], ["A2", "D3", "F3"], ["A2", "C#3", "E3", "G3"], ["A2", "C#3", "E3"],
          ["G2", "Bb2", "D3"], ["D3", "F3", "A3"], ["A2", "C#3", "G3"], ["D3", "F3", "A3"],
          ["D3", "F3", "A3"], ["F2", "A2", "C3"], ["G2", "Bb2", "D3"], ["A2", "C#3", "E3"],
          ["Bb2", "D3", "F3"], ["G2", "Bb2", "D3"], ["A2", "C#3", "G3"], ["D3", "F3", "A3"]]
CHORDS = [[note(c) for c in ch] for ch in CHORDS]


def render(events, length_sec, stereo=True):
    buf = np.zeros(n_of(length_sec + 4))
    for t, snd in events:
        place(buf, snd, t)
    return buf


def mix_stereo(layers, length):
    """layers: list of (mono_or_stereo, pan, gain)."""
    out = np.zeros((n_of(length), 2))
    for x, p, g in layers:
        if x.ndim == 1:
            x = pan(x, p)
        k = min(len(out), len(x))
        out[:k] += x[:k] * g
    return out


def save_music(name, stereo, loop_len=None, peak=0.8):
    if loop_len:
        stereo = make_loop(stereo, loop_len)
    stereo = soft_clip(normalize(stereo, peak) * 1.05, 1.2) * 0.95
    fade = n_of(0.004)
    if not loop_len:
        stereo[-fade:] *= np.linspace(1, 0, fade)[:, None]
    write_ogg(os.path.join(MUSIC, name + ".ogg"), stereo)
    print("music", name, round(len(stereo) / SR, 1), "s")


def save_sfx(name, x, peak=0.9, ogg=False):
    x = normalize(x, peak)
    fade = min(n_of(0.004), len(x) // 4)
    if fade > 0:
        x[-fade:] *= np.linspace(1, 0, fade) if x.ndim == 1 else np.linspace(1, 0, fade)[:, None]
    path = os.path.join(BASE, name + (".ogg" if ogg else ".wav"))
    if ogg:
        write_ogg(path, x)
    else:
        sf.write(path, x.astype(np.float32), SR, subtype="PCM_16")


# ================================================================== music ==

def menu_theme():
    bpm = 80
    beat = 60 / bpm
    length = THEME_BEATS * beat * 2
    box, bass, pad, cel, pno = [], [], [], [], []
    for rep in range(2):
        off = rep * THEME_BEATS * beat
        for b, m, d in THEME:
            box.append((off + b * beat, music_box(hz(m + 12), 1.6, 0.8)))
            if rep == 1:
                pno.append((off + b * beat, piano(hz(m), d * beat, 0.35)))
        for bar, ch in enumerate(CHORDS):
            t0 = off + bar * 3 * beat
            bass.append((t0, ks_pluck(hz(ch[0] - 12), 1.5, 0.3, 0.993) * 0.9))
            for k in (1, 2):
                bass.append((t0 + k * beat, ks_pluck(hz(ch[1]), 0.8, 0.4, 0.99) * 0.35 + ks_pluck(hz(ch[2]), 0.8, 0.4, 0.99) * 0.35))
            pad.append((t0, strings(ch, 3 * beat, 0.35, attack=0.9, release=1.5, cutoff=1500)))
            if rep == 1 and bar % 2 == 1:
                cel.append((t0 + 1.5 * beat, celesta(hz(ch[-1] + 24), 1.0, 0.25)))
    crackle = (rng.random(n_of(length)) > 0.9993) * rng.uniform(-1, 1, n_of(length)) * 0.4
    crackle = highpass(crackle, 1500) + lowpass(noise(n_of(length)), 3000) * 0.004
    st = mix_stereo([(render(box, length), 0.25, 0.55), (render(bass, length), -0.2, 0.45), (render(pad, length), 0.0, 0.35),
                     (render(cel, length), 0.5, 0.3), (render(pno, length), -0.3, 0.45), (crackle, 0.0, 0.5)], length + 4)
    save_music("menu_theme", reverb(st, 3.5, 0.45), length)


def explore_calm():
    length = 96.0
    events_p, events_box = [], []
    phrase = [(0, "D4"), (2.2, "F4"), (4.0, "A4"), (7.5, "E4"), (12, "D4"), (14, "C#4"), (16.5, "D4"),
              (24, "Bb3"), (26, "D4"), (28, "G4"), (31.5, "F4"), (36, "E4"), (40, "A3")]
    for rep in range(2):
        for t, nm in phrase:
            events_p.append((rep * 48 + t + rng.uniform(0, 0.15), piano(hz(note(nm)), 2.5, 0.42, 0.7)))
            if rng.random() < 0.35:
                events_p.append((rep * 48 + t + 0.02, piano(hz(note(nm) - 12), 2.5, 0.25, 0.5)))
    # A broken music box tries the theme... and gives up
    for start in (20.0, 70.0):
        for i, (b, m, d) in enumerate(THEME[:5]):
            events_box.append((start + b * 0.8 * (1 + i * 0.08), music_box(hz(m + 12) * (1 - i * 0.006), 1.6, 0.5, 0.01)))
    dr = drone([note("D2"), note("A2")], length + 4, cutoff=260, lfo=0.05, vel=0.6)
    hi = strings([note("D5"), note("A5")], length, 0.12, attack=8, release=6, vibrato=0.05, cutoff=2200)
    air = lowpass(noise(n_of(length + 4)), 600) * 0.03
    st = mix_stereo([(render(events_p, length), -0.15, 0.55), (render(events_box, length), 0.45, 0.22), (dr, 0.0, 0.35),
                     (hi, 0.2, 0.25), (air, 0.0, 0.5)], length + 4)
    save_music("explore_calm", reverb(st, 5.0, 0.55, damping=3000), length)


def explore_tense():
    bpm = 92
    beat = 60 / bpm
    bars = 24
    length = bars * 4 * beat
    ost, ticks, swells, booms = [], [], [], []
    pattern = ["D2", "D2", "D2", "Eb2", "D2", "D2", "F2", "Eb2"]
    for bar in range(bars):
        for i in range(8):
            m = note(pattern[i]) + (5 if bar % 8 >= 6 else 0)
            ost.append((bar * 4 * beat + i * beat / 2, strings([m], beat / 2 * 0.9, 0.5, attack=0.01, release=0.15, vibrato=0, cutoff=1400)))
        for i in range(4):
            ticks.append((bar * 4 * beat + i * beat, tick(0.35 if i % 2 == 0 else 0.22, 5000 if i % 2 == 0 else 7000)))
        if bar % 8 == 4:
            swells.append((bar * 4 * beat, strings([note("D4"), note("Eb4"), note("Ab4")], 4 * beat * 3, 0.4, attack=4 * beat * 2, release=2, cutoff=3000)))
        if bar % 8 == 0:
            booms.append((bar * 4 * beat, boom(0.8)))
    st = mix_stereo([(render(ost, length), -0.1, 0.5), (render(ticks, length), 0.3, 0.35), (render(swells, length), 0.15, 0.4),
                     (render(booms, length), 0.0, 0.6), (drone([note("D1")], length + 4, 120, 0.1, 0.5), 0.0, 0.3)], length + 4)
    save_music("explore_tense", reverb(st, 3.0, 0.35), length)


def danger_near():
    length = 24.0  # one octave of Shepard glide
    beats = []
    t = 0.0
    while t < length:
        beats.append((t, heartbeat(1.0)))
        t += 60 / 82
    sh = shepard_rise(length, 55, 6, 1.0)
    dr = drone([note("D1"), note("Eb2")], length + 4, 180, 0.2, 0.6)
    scrapes = []
    for s in (3.0, 13.0, 19.5):
        scrapes.append((s, metal_resonance(rng.uniform(300, 700), 4.0, 0.5)))
    st = mix_stereo([(render(beats, length), 0.0, 0.75), (sh, 0.0, 0.3), (dr, 0.0, 0.4), (render(scrapes, length), 0.4, 0.3)], length + 4)
    save_music("danger_near", reverb(st, 2.5, 0.3), length)


def chase():
    bpm = 150
    beat = 60 / bpm
    bars = 24
    length = bars * 4 * beat
    drums, bass, stabs, shriek = [], [], [], []
    riff = ["D2", "D2", "F2", "D2", "G2", "F2", "E2", "C#2"]
    for bar in range(bars):
        t0 = bar * 4 * beat
        for i, hit in enumerate([1, 0, 0, 1, 0, 1, 1, 0]):
            if hit:
                drums.append((t0 + i * beat / 2, taiko(1.0 if i == 0 else 0.7, 1.0 if i % 4 == 0 else 1.3)))
        for i in range(4):
            drums.append((t0 + i * beat + beat / 2, snare(0.25 if i != 3 else 0.5)))
            drums.append((t0 + i * beat, tick(0.2)))
        for i in range(8):
            m = note(riff[i]) + (3 if bar % 8 >= 4 else 0)
            bass.append((t0 + i * beat / 2, brass(hz(m), beat / 2 * 0.8, 0.8, 0.08)))
        if bar % 4 == 0:
            for k, m in enumerate(["A4", "D5", "F5"]):
                stabs.append((t0 + k * beat * 0.75, brass(hz(note(m)), beat * 0.6, 0.9, 0.15) + brass(hz(note(m) - 12), beat * 0.6, 0.7, 0.15)))
        if bar % 8 == 7:
            shriek.append((t0, strings([note("D6"), note("Eb6"), note("A6")], 4 * beat, 0.5, attack=0.2, release=0.5, tremolo=14, cutoff=6000)))
            drums.append((t0 + 3.5 * beat, snare(0.6)))
            drums.append((t0 + 3.75 * beat, snare(0.7)))
        if bar % 8 == 0:
            drums.append((t0, cymbal(0.5)))
    st = mix_stereo([(render(drums, length), 0.0, 0.7), (render(bass, length), -0.15, 0.45), (render(stabs, length), 0.2, 0.5),
                     (render(shriek, length), 0.3, 0.3)], length + 4)
    save_music("chase", reverb(st, 2.2, 0.25), length)


def blackout():
    length = 64.0
    sub = drone([note("D1")], length + 4, 90, 0.03, 0.7)
    wind = sweep_filter(noise(n_of(length + 4)), 400 + 300 * np.sin(2 * np.pi * 0.05 * t_of(n_of(length + 4))), "low") * 0.5
    metals, groans = [], []
    for s in (5, 19, 33, 47, 58):
        metals.append((s, metal_resonance(rng.uniform(180, 420), 6.0, 0.5)))
    for s in (12, 40):
        groans.append((s, choir([note("D3"), note("F3"), note("A3")], 8, 0.4, "oo", attack=3, release=4)))
    st = mix_stereo([(sub, 0.0, 0.5), (wind, 0.0, 0.25), (render(metals, length), -0.4, 0.35), (render(groans, length), 0.3, 0.3)], length + 4)
    save_music("blackout", reverb(st, 6.0, 0.5, damping=2500), length)


def office_radio():
    """Diegetic easy-listening bossa on a tinny radio: the theme, in D MAJOR. Comic relief."""
    bpm = 108
    beat = 60 / bpm
    bars = 20
    length = bars * 4 * beat
    prog = [["D3", "F#3", "A3", "C#4"], ["B2", "D3", "F#3", "A3"], ["E3", "G3", "B3", "D4"], ["A2", "C#3", "E3", "G3"]]
    gtr, bassl, vib, brush = [], [], [], []
    for bar in range(bars):
        ch = [note(c) for c in prog[bar % 4]]
        t0 = bar * 4 * beat
        for pos in [0, 1.5, 2.5, 3.5]:
            for m in ch:
                gtr.append((t0 + pos * beat, ks_pluck(hz(m), 0.6, 0.35, 0.985) * 0.3))
        bassl.append((t0, ks_pluck(hz(ch[0] - 12), 1.0, 0.25, 0.992)))
        bassl.append((t0 + 2 * beat, ks_pluck(hz(ch[0] - 5), 0.8, 0.25, 0.992)))
        for i in range(8):
            brush.append((t0 + i * beat / 2, bandpass(noise(n_of(0.12)), 2000, 8000) * env_exp(n_of(0.12), 0.04) * (0.3 if i % 2 else 0.15)))
    major = {note("F5"): note("F#5"), note("C6"): note("C#6"), note("Bb4"): note("B4"), note("Bb5"): note("B5"), note("C5"): note("C#5")}
    off = 0.0
    for rep in range(2):
        for b, m, d in THEME:
            mm = major.get(m, m)
            tt = off + b * beat * 0.85 + 2 * beat
            if tt < length:
                n = n_of(d * beat + 1.0)
                tt_arr = t_of(n)
                tone = np.sin(2 * np.pi * hz(mm) * tt_arr) * np.exp(-tt_arr / 1.2) * (1 + 0.3 * np.sin(2 * np.pi * 5.5 * tt_arr))
                vib.append((tt, tone * 0.5))
        off += THEME_BEATS * beat * 0.85
    mono = render(gtr, length) * 0.5 + render(bassl, length) * 0.6 + render(vib, length) * 0.45 + render(brush, length) * 0.3
    mono = bandpass(mono, 300, 3500, 2) * 1.5
    mono += highpass((rng.random(len(mono)) > 0.9995) * rng.uniform(-1, 1, len(mono)), 2000) * 0.3 + lowpass(noise(len(mono)), 4000) * 0.01
    st = np.stack([mono, mono], axis=1)
    save_music("office_radio", st, length, peak=0.7)


def duchess_theme():
    bpm = 96
    beat = 60 / bpm
    length = THEME_BEATS * beat
    hp, bass = [], []
    for b, m, d in THEME:
        wob = 1 + 0.01 * math.sin(b * 0.7)
        hp.append((b * beat, harpsichord(hz(m) * wob, d * beat + 0.6, 0.6)))
        if d >= 2:
            hp.append((b * beat + beat * 0.5, harpsichord(hz(m + 3) * wob, beat, 0.25)))
    for bar, ch in enumerate(CHORDS):
        for k in range(3):
            bass.append((bar * 3 * beat + k * beat, harpsichord(hz(ch[0] if k == 0 else ch[k % len(ch)]), beat, 0.35)))
    whisper = whispers(length + 4) * 0.5
    st = mix_stereo([(render(hp, length), 0.2, 0.55), (render(bass, length), -0.25, 0.45), (whisper, 0.0, 0.25)], length + 4)
    # warped record: slow pitch wobble via resampling
    save_music("duchess_theme", reverb(st, 3.0, 0.4), length)


def automaton_tune():
    beat = 0.32
    length = 16 * 3 * beat
    ev = []
    for b, m, d in THEME:
        if b < 24:
            ev.append((b * beat, music_box(hz(m + 12), 1.2, 0.8, 0.002)))
    for b, m, d in THEME:
        if b < 24:
            ev.append((24 * beat + b * beat, music_box(hz(m + 12), 1.2, 0.8, 0.002)))
    st = mix_stereo([(render(ev, length), 0.0, 0.8)], length + 3)
    save_music("automaton_tune", reverb(st, 1.2, 0.2), length)


def gary_whistle():
    beat = 0.36
    seq = []
    for b, m, d in THEME[:18]:
        seq.append((hz(m) * 1.002, d * beat))
    seq.append((0, 1.2))
    x = whistle(seq, 0.6)
    st = np.stack([x, x], axis=1)
    save_music("gary_whistle", reverb(st, 1.0, 0.15), len(x) / SR)


def finale():
    bpm = 112
    beat = 60 / bpm
    length = THEME_BEATS * beat * 2
    br, drums, pad, ost, ch = [], [], [], [], []
    for rep in range(2):
        off = rep * THEME_BEATS * beat
        for b, m, d in THEME:
            br.append((off + b * beat, brass(hz(m), d * beat * 0.95, 0.85) + brass(hz(m - 12), d * beat * 0.95, 0.6)))
        for bar, chd in enumerate(CHORDS):
            t0 = off + bar * 3 * beat
            drums.append((t0, taiko(1.0)))
            drums.append((t0, timpani(hz(chd[0] - 12), 0.8)))
            drums.append((t0 + beat, taiko(0.5, 1.4)))
            drums.append((t0 + 2 * beat, taiko(0.6, 1.2)))
            drums.append((t0 + 2.5 * beat, snare(0.4)))
            if bar % 4 == 0:
                drums.append((t0, cymbal(0.45)))
            pad.append((t0, strings(chd, 3 * beat, 0.4, attack=0.3, release=0.8, cutoff=3000)))
            for k in range(6):
                ost.append((t0 + k * beat / 2, strings([chd[k % len(chd)] + 12], beat / 2 * 0.8, 0.35, attack=0.01, release=0.1, vibrato=0, cutoff=3500)))
            if rep == 1:
                ch.append((t0, choir([c + 12 for c in chd], 3 * beat, 0.35, "ah", attack=0.4, release=0.6)))
    st = mix_stereo([(render(br, length), 0.1, 0.5), (render(drums, length), 0.0, 0.6), (render(pad, length), -0.2, 0.35),
                     (render(ost, length), 0.25, 0.3), (render(ch, length), 0.0, 0.35)], length + 4)
    save_music("finale", reverb(st, 3.0, 0.35), length)


def dawn():
    length = 30.0
    pno, birds = [], []
    arps = [["D4", "F#4", "A4", "D5"], ["B3", "D4", "F#4", "B4"], ["G3", "B3", "D4", "G4"], ["A3", "C#4", "E4", "A4"]]
    t = 0.5
    for rep in range(3):
        for ch in arps:
            for k, nm in enumerate(ch):
                pno.append((t + k * 0.32, piano(hz(note(nm)), 2.0, 0.4)))
            t += 2.2
    for i in range(40):
        bt = rng.uniform(2, length - 2)
        n = n_of(0.12)
        tt = t_of(n)
        f = rng.uniform(2500, 4200) * (1 + 0.4 * np.sin(2 * np.pi * rng.uniform(15, 30) * tt))
        birds.append((bt, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.12) * 0.2))
    pad = strings([note("D3"), note("A3"), note("F#4")], length - 2, 0.3, attack=4, release=3, cutoff=2000)
    st = mix_stereo([(render(pno, length), -0.1, 0.55), (render(birds, length), 0.5, 0.35), (pad, 0.0, 0.35)], length + 4)
    save_music("dawn", reverb(st, 4.0, 0.45)[: n_of(length + 3)])


def credits():
    bpm = 66
    beat = 60 / bpm
    length = THEME_BEATS * beat + 6
    pno, pad = [], []
    for b, m, d in THEME:
        pno.append((b * beat + rng.uniform(0, 0.05), piano(hz(m), d * beat, 0.5)))
    for bar, ch in enumerate(CHORDS):
        for k, m in enumerate(ch):
            pno.append((bar * 3 * beat + k * beat * 0.33, piano(hz(m), 3 * beat, 0.25)))
        if bar >= 8:
            pad.append((bar * 3 * beat, strings(ch, 3 * beat, 0.3, attack=1.5, release=2, cutoff=2000)))
    st = mix_stereo([(render(pno, length), 0.0, 0.6), (render(pad, length), 0.0, 0.35)], length + 4)
    save_music("credits", reverb(st, 4.0, 0.45)[: n_of(length + 3)])


def gramophone():
    beat = 0.72
    length = THEME_BEATS * beat
    ev = []
    for b, m, d in THEME:
        ev.append((b * beat, piano(hz(m), d * beat, 0.5)))
        ev.append((b * beat, strings([m], d * beat, 0.25, attack=0.2, release=0.4)))
    for bar, ch in enumerate(CHORDS):
        ev.append((bar * 3 * beat, strings(ch, 3 * beat, 0.2, attack=0.3, release=0.5, cutoff=1200)))
    mono = render(ev, length)
    t = t_of(len(mono))
    mono = bandpass(mono, 250, 3000) * 2
    mono += highpass((rng.random(len(mono)) > 0.999) * rng.uniform(-1, 1, len(mono)), 1500) * 0.4
    mono += lowpass(noise(len(mono)), 5000) * 0.01
    st = np.stack([mono, mono], axis=1)
    save_music("gramophone", st, length, peak=0.6)


# ---------------------------------------------------------------- stingers -

def stingers():
    # Jumpscare: orchestral hit
    n = n_of(3.0)
    hit = np.zeros(n)
    for m, v in (("D3", 1.0), ("Eb3", 0.9), ("Ab3", 0.8)):
        place(hit, brass(hz(note(m)), 1.5, v), 0)
    place(hit, taiko(1.5), 0)
    place(hit, cymbal(0.7), 0)
    place(hit, strings([note("D6"), note("Eb6"), note("G#6")], 1.5, 0.8, attack=0.01, release=0.6, tremolo=16, cutoff=7000), 0)
    save_music("sting_scare", reverb(pan(hit, 0), 2.0, 0.3))
    # Knight moved: low piano cluster + scrape
    x = np.zeros(n_of(4))
    for m in ("D1", "Eb1", "A1", "D2"):
        place(x, piano(hz(note(m)), 2.5, 0.9), 0)
    place(x, metal_resonance(520, 3.0, 0.4), 0.1)
    save_music("sting_knight", reverb(pan(x, 0), 3.0, 0.4))
    # Reveal: swell + choir chord
    x = np.zeros(n_of(7))
    place(x, choir([note("D3"), note("F3"), note("A3"), note("D4")], 4.0, 0.7, "ah", attack=2.5, release=2.5), 0)
    place(x, strings([note("D2"), note("A2")], 4.0, 0.5, attack=2.5, release=2.5), 0)
    place(x, boom(0.6), 2.5)
    save_music("sting_reveal", reverb(pan(x, 0), 4.0, 0.45))
    # Night start: boom + music box phrase
    x = np.zeros(n_of(8))
    place(x, boom(0.9, 4.0), 0)
    for b, m, d in THEME[:9]:
        place(x, music_box(hz(m + 12), 1.4, 0.6), 1.0 + b * 0.55)
    save_music("sting_night", reverb(pan(x, 0), 4.0, 0.5))
    # Death: boom + descending strings
    x = np.zeros(n_of(6))
    place(x, boom(1.0, 4.0), 0)
    n = n_of(4.0)
    tt = t_of(n)
    gl = sum(saw_wave(hz(m) * 2 ** (-tt * 0.4)) for m in (note("D4"), note("Ab4"), note("D5"))) / 3
    place(x, lowpass(gl, 2500) * np.exp(-tt * 0.8) * 0.5, 0.1)
    save_music("sting_death", reverb(pan(x, 0), 4.0, 0.45))
    # Chase start: brass stab + taiko
    x = np.zeros(n_of(2.5))
    place(x, brass(hz(note("D3")), 0.5, 1.0) + brass(hz(note("A3")), 0.5, 0.9), 0)
    place(x, taiko(1.3), 0)
    save_music("sting_chase", reverb(pan(x, 0), 2.0, 0.3))
    # Safe: soft resolve
    x = strings([note("D3"), note("F#3"), note("A3")], 2.0, 0.5, attack=0.5, release=1.5, cutoff=1800)
    save_music("sting_safe", reverb(pan(x, 0), 3.0, 0.4))
    # Task complete: little music box arpeggio
    x = np.zeros(n_of(2.5))
    for k, m in enumerate(("D5", "F5", "A5", "D6")):
        place(x, music_box(hz(note(m)), 1.2, 0.6), k * 0.09)
    save_music("sting_task", reverb(pan(x, 0.1), 1.5, 0.3))
    # Write-up: sad trombone (wah-wah-wah-waaah)
    x = np.zeros(n_of(3.2))
    for k, (m, d) in enumerate([("A3", 0.32), ("Ab3", 0.32), ("G3", 0.32), ("F#3", 1.3)]):
        b = brass(hz(note(m)), d, 0.8, 0.15)
        tt = t_of(len(b))
        if k == 3:
            b *= 1 + 0.25 * np.sin(2 * np.pi * 6 * tt)
        place(x, lowpass(b, 1400), [0, 0.38, 0.76, 1.14][k])
    save_music("sting_writeup", reverb(pan(x, 0), 1.5, 0.25))
    # Hour bell: three tolls of a big clock
    x = np.zeros(n_of(7))
    for k in range(3):
        n = n_of(4)
        tt = t_of(n)
        bell = sum(a * np.sin(2 * np.pi * 196 * r * tt) * np.exp(-tt * dcy) for r, a, dcy in [(0.5, 0.6, 0.6), (1, 1, 0.9), (1.19, 0.5, 1.2), (1.5, 0.4, 1.5), (2.0, 0.35, 2), (2.74, 0.2, 3)])
        place(x, bell, k * 1.4)
    save_music("sting_hour", reverb(pan(x, 0), 4.0, 0.45))


# ================================================================== SFX ====

def whispers(length):
    n = n_of(length)
    out = np.zeros((n, 2))
    for k in range(12):
        dur = rng.uniform(0.6, 1.6)
        m = n_of(dur)
        src = noise(m)
        seq = rng.choice(list("aoeiu"), 5)
        w = np.zeros(m)
        seg = m // 5
        vowels = {"a": (800, 1200), "o": (450, 800), "u": (325, 700), "e": (500, 1800), "i": (300, 2300)}
        for i, v in enumerate(seq):
            a, b = vowels[v]
            s = src[i * seg:(i + 1) * seg]
            w[i * seg:i * seg + len(s)] = resonator(s, a, 4) + 0.7 * resonator(s, b, 6) + 0.3 * highpass(s, 4000)
        w *= np.sin(np.pi * t_of(m) / dur) ** 0.7 * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * rng.uniform(3, 6) * t_of(m))))
        st = pan(w, rng.uniform(-1, 1))
        i0 = n_of(rng.uniform(0, max(0.1, length - dur)))
        out[i0:i0 + m] += st[: n - i0]
    return out


def footsteps():
    for v in range(4):
        # marble: crisp heel click + soft body
        n = n_of(0.25)
        t = t_of(n)
        click = resonator(noise(n), rng.uniform(2200, 3200), 3) * np.exp(-t * 90)
        body = lowpass(noise(n), 300) * np.exp(-t * 35) * 2
        save_sfx(f"step_marble_{v + 1}", click * 0.6 + body)
        # wood: thump + slight creak on some
        thump = lowpass(noise(n), 250) * np.exp(-t * 28) * 2 + np.sin(2 * np.pi * rng.uniform(85, 110) * t) * np.exp(-t * 30)
        mid = resonator(noise(n), rng.uniform(600, 900), 4) * np.exp(-t * 50) * 0.5
        w = thump + mid
        if v % 2 == 1:
            w = np.concatenate([w, creak(0.35, 0.25)])
        save_sfx(f"step_wood_{v + 1}", w)
        # stone / sand: gritty
        grit = bandpass(noise(n), 800, 4500) * (rng.random(n) > 0.6) * np.exp(-t * 25)
        save_sfx(f"step_stone_{v + 1}", grit * 0.7 + body * 0.8)
        # carpet: soft muffled
        save_sfx(f"step_carpet_{v + 1}", lowpass(noise(n), 450) * np.exp(-t * 22))
        # concrete
        save_sfx(f"step_concrete_{v + 1}", bandpass(noise(n), 400, 2500) * np.exp(-t * 45) + body)


def creak(dur=0.7, vel=1.0):
    n = n_of(dur)
    t = t_of(n)
    rate = rng.uniform(25, 45) + rng.uniform(20, 60) * np.sin(np.pi * t / dur)
    rate *= 1 + 0.2 * lowpass(noise(n), 20)
    ph = np.cumsum(rate / SR)
    pulses = (np.diff(np.floor(ph), prepend=0) > 0).astype(float)
    res = resonator(pulses, rng.uniform(350, 800), 15) + 0.5 * resonator(pulses, rng.uniform(1200, 2000), 20)
    return res * np.sin(np.pi * t / dur) * vel


def sfx_all():
    footsteps()
    for v in range(3):
        n = n_of(0.6)
        t = t_of(n)
        metal = sum(np.sin(2 * np.pi * f * t + rng.random() * 6) * np.exp(-t * dcy) for f, dcy in
                    [(rng.uniform(380, 460), 6), (rng.uniform(1100, 1250), 9), (rng.uniform(1800, 2000), 12), (2650, 16), (3400, 20)])
        thud = lowpass(noise(n), 200) * np.exp(-t * 25) * 3
        save_sfx(f"knight_step_{v + 1}", metal * 0.4 + thud + highpass(noise(n), 3000) * np.exp(-t * 60) * 0.5)
    save_sfx("metal_scrape", metal_resonance(480, 1.6, 1.0) * 0.6 + bandpass(noise(n_of(1.6)), 1500, 5000) * 0.2 * np.sin(np.pi * t_of(n_of(1.6)) / 1.6))
    for v in range(3):
        save_sfx(f"mummy_groan_{v + 1}", formant_voice(rng.uniform(65, 85), list(rng.choice(list("aou"), 3)), 1.8, 1.0, growl=0.15) * np.sin(np.pi * t_of(n_of(1.8)) / 1.8))
    n = n_of(0.7)
    save_sfx("mummy_shuffle", lowpass(noise(n), 900) * np.sin(np.pi * t_of(n) / 0.7) ** 2 * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t_of(n))))
    # Dino roar: growl + formant + sub
    n = n_of(2.8)
    t = t_of(n)
    growl = saw_wave(110 * np.exp(-t * 0.3) * (1 + 0.08 * lowpass(noise(n), 40)))
    roar = resonator(growl, 500, 3) + resonator(growl, 1100, 4) * 0.6 + bandpass(noise(n), 300, 2500) * 0.6
    env = np.clip(t / 0.15, 0, 1) * np.exp(-np.clip(t - 1.2, 0, None) * 2.0)
    save_sfx("roar", soft_clip((roar * 0.7 + boom(0.8, 2.8)[:n]) * env, 2.0), ogg=True)
    # Automaton
    n = n_of(1.4)
    t = t_of(n)
    rate = 6 + 30 * (t / 1.4) ** 2
    clicks = (np.diff(np.floor(np.cumsum(rate / SR)), prepend=0) > 0).astype(float)
    save_sfx("wind_ratchet", resonator(clicks, 2500, 8) + resonator(clicks, 900, 6) * 0.5)
    x = np.zeros(n_of(3.5))
    for k, (b, m, d) in enumerate(THEME[:6]):
        place(x, music_box(hz(m + 12) * (1 - k * 0.05), 1.4, 0.7), k * (0.3 + k * 0.08))
    save_sfx("automaton_unwound", x)
    for v in range(2):
        n = n_of(0.15)
        t = t_of(n)
        save_sfx(f"automaton_step_{v + 1}", resonator(noise(n), rng.uniform(1500, 1900), 10) * np.exp(-t * 60) + lowpass(noise(n), 400) * np.exp(-t * 40))
    # Duchess
    save_sfx("whisper", whispers(6.0), ogg=True)
    n = n_of(1.6)
    t = t_of(n)
    shriek = formant_voice(1, ["a"], 1.6, 1.0)
    shriek = resonator(saw_wave(np.full(n, 600.0) * (1 + 0.6 * t) * (1 + 0.02 * np.sin(2 * np.pi * 7 * t))), 1200, 3) + bandpass(noise(n), 2000, 8000) * 0.5
    save_sfx("duchess_scream", soft_clip(shriek * np.clip(t / 0.05, 0, 1) * np.exp(-t * 1.2), 2.0))
    # Gary (wax guard)
    for v in range(3):
        n = n_of(0.3)
        t = t_of(n)
        save_sfx(f"boot_step_{v + 1}", lowpass(noise(n), 350) * np.exp(-t * 20) * 2 + resonator(noise(n), 1800, 6) * np.exp(-t * 70) * 0.4)
    for v in range(3):
        save_sfx(f"babble_gary_{v + 1}", babble(rng.uniform(95, 115), 1.0, radio=True))
    # Player
    for v in range(4):
        save_sfx(f"babble_{v + 1}", babble(rng.uniform(190, 230), rng.uniform(1.2, 1.8), radio=True))
    n = n_of(3.2)
    t = t_of(n)
    breath = bandpass(noise(n), 300, 2500) * (np.sin(2 * np.pi * t / 1.6) ** 2) * (0.6 + 0.4 * (np.sin(2 * np.pi * t / 1.6) > 0))
    save_sfx("breathing", breath, ogg=True)
    hb = np.zeros(n_of(0.86))
    place(hb, heartbeat(1.0), 0)
    save_sfx("heartbeat", hb)
    for name, f in (("flashlight_on", 5200), ("flashlight_off", 3800)):
        n = n_of(0.06)
        save_sfx(name, resonator(noise(n), f, 6) * env_exp(n, 0.006) + resonator(noise(n), f * 0.4, 5) * env_exp(n, 0.01) * 0.5)
    n = n_of(0.5)
    t = t_of(n)
    save_sfx("battery", np.concatenate([bandpass(noise(n_of(0.25)), 1500, 6000) * 0.2, resonator(noise(n_of(0.08)), 3000, 8) * env_exp(n_of(0.08), 0.01)]))
    n = n_of(0.7)
    t = t_of(n)
    save_sfx("paper", bandpass(noise(n), 1500, 9000) * (rng.random(n) > 0.7) * np.sin(np.pi * t / 0.7))
    lock = np.zeros(n_of(1.0))
    for k in range(5):
        place(lock, resonator(noise(n_of(0.08)), rng.uniform(900, 1400), 10) * env_exp(n_of(0.08), 0.02), k * 0.12)
    save_sfx("door_locked", lock)
    save_sfx("door_open", np.concatenate([creak(1.2, 1.0), lowpass(noise(n_of(0.2)), 300) * env_exp(n_of(0.2), 0.05)]))
    save_sfx("locker_open", np.concatenate([creak(0.4, 0.6), metal_resonance(700, 0.6, 0.8)]))
    save_sfx("locker_close", metal_resonance(560, 0.8, 1.0) + lowpass(noise(n_of(0.8)), 300) * env_exp(n_of(0.8), 0.05))
    n = n_of(0.4)
    t = t_of(n)
    save_sfx("stamp", lowpass(noise(n), 600) * np.exp(-t * 25) * 2 + resonator(noise(n), 1500, 5) * np.exp(-t * 40) + np.sin(2 * np.pi * 90 * t) * np.exp(-t * 20))
    n = n_of(1.5)
    t = t_of(n)
    save_sfx("coffee", bandpass(noise(n), 500, 3000) * (0.5 + 0.5 * np.sin(2 * np.pi * 13 * t)) * np.sin(np.pi * t / 1.5))
    n = n_of(0.35)
    t = t_of(n)
    save_sfx("radio_squelch", bandpass(noise(n), 800, 4000) * np.exp(-t * 8) + np.sin(2 * np.pi * 1400 * t) * np.exp(-t * 25) * 0.3)
    x = np.zeros(n_of(1.0))
    for k, f in enumerate((880, 1320)):
        place(x, np.sin(2 * np.pi * f * t_of(n_of(0.4))) * env_exp(n_of(0.4), 0.12), k * 0.08)
    save_sfx("pickup", x)
    n = n_of(1.6)
    t = t_of(n)
    pd_ph = np.cumsum((400 * np.exp(-t * 2.5) + 30) / SR)
    save_sfx("power_down", np.sin(2 * np.pi * pd_ph) * np.exp(-t * 1.0) + boom(0.5, 1.6)[:n] * 0.5)
    pu_ph = np.cumsum((40 + 360 * (1 - np.exp(-t * 2.0))) / SR)
    save_sfx("power_up", np.sin(2 * np.pi * pu_ph) * np.clip(t / 0.5, 0, 1) * np.exp(-np.clip(t - 1.0, 0, None) * 4) * 0.6 + resonator(noise(n), 120, 30) * 0.2)
    n = n_of(0.6)
    t = t_of(n)
    save_sfx("window_close", lowpass(noise(n), 400) * np.exp(-t * 18) * 2 + resonator(noise(n), 2200, 10) * np.exp(-t * 40) * 0.5 + resonator(noise(n), 3500, 30) * (t > 0.25) * np.exp(-(t - 0.25).clip(0) * 50) * 0.4)
    n = n_of(0.8)
    t = t_of(n)
    save_sfx("bulb", resonator(noise(n), 3000, 10) * np.exp(-t * 50) + np.sin(2 * np.pi * 120 * t) * 0.2 * (t > 0.1))
    n = n_of(0.3)
    t = t_of(n)
    ph = np.cumsum((520 - 700 * t) / SR)
    save_sfx("quack", lowpass(resonator(2 * (ph % 1) - 1, 900, 3), 3000) * np.sin(np.pi * t / 0.3))
    save_sfx("ui_click", resonator(noise(n_of(0.04)), 2500, 8) * env_exp(n_of(0.04), 0.006))
    save_sfx("ui_hover", resonator(noise(n_of(0.03)), 4000, 10) * env_exp(n_of(0.03), 0.004) * 0.5)
    # Ambience one-shots
    for v in range(4):
        save_sfx(f"creak_{v + 1}", creak(rng.uniform(0.6, 1.3), 1.0))
    for v in range(3):
        n = n_of(rng.uniform(5, 8))
        t = t_of(n)
        crack = highpass(noise(n), 1500) * np.exp(-t * 12) * (t > 0.0)
        roll = lowpass(brown(n), 200) * (0.3 + 0.7 * np.abs(lowpass(noise(n), 3))) * np.exp(-t * 0.5)
        save_sfx(f"thunder_{v + 1}", soft_clip(crack * 0.6 + roll * 2.0, 1.5), ogg=True)
    for v in range(2):
        steps = np.zeros(n_of(3.0))
        for k in range(5):
            n = n_of(0.25)
            t = t_of(n)
            place(steps, lowpass(noise(n), 300) * np.exp(-t * 25), 0.3 + k * 0.55)
        save_sfx(f"distant_steps_{v + 1}", lowpass(steps, 800))


def babble(pitch, dur, radio=True):
    n = n_of(dur)
    out = np.zeros(n)
    t = 0.0
    vowels = {"a": (800, 1200), "o": (450, 800), "u": (325, 700), "e": (500, 1800), "i": (300, 2300)}
    while t < dur - 0.15:
        sd = rng.uniform(0.07, 0.14)
        m = n_of(sd)
        tt = t_of(m)
        f = pitch * (1 + rng.uniform(-0.15, 0.25)) * (1 + 0.1 * np.sin(np.pi * tt / sd))
        src = saw_wave(np.full(m, 1.0) * f)
        a, b = vowels[rng.choice(list("aoeiu"))]
        syl = resonator(src, a, 5) + 0.6 * resonator(src, b, 7)
        syl *= np.sin(np.pi * tt / sd) ** 0.5
        if rng.random() < 0.4:
            syl[: n_of(0.02)] += highpass(noise(n_of(0.02)), 3000) * 0.4
        place(out, syl, t)
        t += sd + rng.uniform(0.0, 0.05)
        if rng.random() < 0.12:
            t += 0.12
    if radio:
        out = bandpass(out, 400, 3200) + bandpass(noise(n), 1000, 4000) * 0.02
    return out


def ambience():
    # Museum room tone (seamless)
    L = 20.0
    n = n_of(L + 2)
    t = t_of(n)
    tone = lowpass(brown(n), 180) * 0.6 + np.sin(2 * np.pi * 60 * t) * 0.02 + np.sin(2 * np.pi * 120 * t) * 0.01 + lowpass(noise(n), 1200) * 0.01
    save_music_amb("amb_museum", np.stack([tone, np.roll(tone, 3000)], axis=1), L)
    # Rain on windows
    L = 24.0
    n = n_of(L + 2)
    body = bandpass(noise(n), 600, 7000) * 0.25 + lowpass(noise(n), 500) * 0.2
    drops = np.zeros(n)
    for k in range(int(L * 120)):
        i = rng.integers(0, n - 400)
        m = 300
        tt = t_of(m)
        drops[i:i + m] += np.sin(2 * np.pi * rng.uniform(2000, 6000) * tt) * np.exp(-tt * 300) * rng.uniform(0.1, 0.5)
    st = np.stack([body + drops * 0.5, np.roll(body, 5000) + np.roll(drops, 2345) * 0.5], axis=1)
    save_music_amb("amb_rain", st, L)
    # Wind (for windows)
    L = 20.0
    n = n_of(L + 2)
    t = t_of(n)
    w = sweep_filter(noise(n), 350 + 250 * np.sin(2 * np.pi * 0.11 * t) + 150 * np.sin(2 * np.pi * 0.31 * t), "low") + resonator(noise(n), 900, 40) * 0.05 * (1 + np.sin(2 * np.pi * 0.07 * t))
    save_music_amb("wind", np.stack([w, w], axis=1), L, mono_wav=True)
    # Drip
    L = 12.0
    x = np.zeros(n_of(L + 1))
    for s in (0.5, 2.9, 4.1, 7.3, 9.8, 11.0):
        m = n_of(0.4)
        tt = t_of(m)
        f = rng.uniform(900, 1600) * (1 + 0.6 * np.exp(-tt * 40))
        place(x, np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 12), s)
    save_music_amb("drip", np.stack([x, x], axis=1), L, mono_wav=True)
    # Clock tick-tock (exact 2 s loop)
    x = np.zeros(n_of(2.0))
    for k, f in enumerate((2400, 1900)):
        m = n_of(0.05)
        place(x, resonator(noise(m), f, 12) * env_exp(m, 0.006) + resonator(noise(m), f * 0.5, 8) * env_exp(m, 0.01) * 0.5, k * 1.0)
    save_music_amb("clock_tick", np.stack([x, x], axis=1), 2.0, mono_wav=True)
    # Clockwork whirr
    L = 4.0
    n = n_of(L)
    t = t_of(n)
    clicks = (np.diff(np.floor(t * 8), prepend=0) > 0).astype(float)
    cw = resonator(clicks, 3200, 10) + resonator(clicks, 1400, 8) * 0.5 + bandpass(noise(n), 2000, 5000) * 0.03 * (1 + np.sin(2 * np.pi * 2 * t))
    save_music_amb("clockwork", np.stack([cw, cw], axis=1), L, mono_wav=True)


def save_music_amb(name, st, loop_len, mono_wav=False):
    st = make_loop(st, loop_len)
    st = normalize(st, 0.8)
    if mono_wav:
        sf.write(os.path.join(BASE, name + ".wav"), st[:, 0].astype(np.float32), SR, subtype="PCM_16")
    else:
        write_ogg(os.path.join(BASE, name + ".ogg"), st)
    print("ambience", name)


if __name__ == "__main__":
    import sys
    os.makedirs(MUSIC, exist_ok=True)
    only = set(sys.argv[1:])
    for f in [menu_theme, explore_calm, explore_tense, danger_near, chase, blackout, office_radio, duchess_theme,
              automaton_tune, gary_whistle, finale, dawn, credits, gramophone, stingers, sfx_all, ambience]:
        if not only or f.__name__ in only:
            f()

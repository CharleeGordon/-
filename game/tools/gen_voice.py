"""Voice lines + audio logs, synthesized with Piper TTS (neural, offline) and then aged with effects.

Voices: Piper "en-us-libritts-high" (LibriTTS dataset, CC BY 4.0 - credit it in the game credits).
These are placeholders - replace with voice actors later, keeping the same file names.

Run from the game/ folder:
    pip install piper-tts numpy scipy soundfile
    PIPER_MODEL=/path/to/en-us-libritts-high.onnx python3 tools/gen_voice.py

Writes:
    audio/voice/line_<md5 of text, 10 chars>.ogg   radio / spoken lines found in the scripts
    audio/voice/tape_<n>.ogg + tape_<n>.json        audio logs from scripts/data/tapes.gd (json = subtitle timings)
"""
import glob
import hashlib
import io
import json
import os
import re
import sys
import wave

import numpy as np
from scipy import signal

sys.path.insert(0, os.path.dirname(__file__))
import gen_audio as ga  # reuse filters + ogg writer

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "audio", "voice")
SR = 32000
MODEL = os.environ.get("PIPER_MODEL", "/tmp/claude-0/-home-user--/c945486d-29a0-5aa0-b223-d8a7293b8ca5/scratchpad/voices/en-us-libritts-high.onnx")

# Character -> (speaker id, speed (length scale), pitch factor via resampling)
VOICES = {
    "brenda": (77, 1.0, 1.0),
    "gary": (20, 0.95, 1.0),
    "pemberton": (400, 1.05, 0.93),
    "lucy": (0, 1.08, 0.98),
    "duchess": (250, 1.1, 1.0),
    "dolls": (12, 1.15, 1.32),
}
SPEAKER_TAGS = {"BRENDA (radio)": "brenda", "GARY": "gary", "SIR ARCHIBALD": "pemberton", "THE DUCHESS": "duchess", "THE DOLLS": "dolls"}

_voice = None


def piper():
    global _voice
    if _voice is None:
        from piper import PiperVoice
        _voice = PiperVoice.load(MODEL)
    return _voice


def tts(text, who):
    from piper import SynthesisConfig
    sid, speed, pitch = VOICES[who]
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        piper().synthesize_wav(text, w, syn_config=SynthesisConfig(speaker_id=sid, length_scale=speed, noise_scale=0.7, noise_w_scale=0.8))
    buf.seek(0)
    with wave.open(buf) as w:
        sr = w.getframerate()
        x = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768
    # resample to SR, applying the pitch factor (faster playback = higher pitch)
    n_out = int(len(x) * SR / sr / pitch)
    x = signal.resample(x, n_out)
    return x


def tremble(x, depth=0.018, rate=6.0):
    """Shaky, frightened voice: pitch vibrato via variable-rate resampling + amplitude tremor."""
    n = len(x)
    t = np.arange(n) / SR
    wobble = 1 + depth * np.sin(2 * np.pi * rate * t + np.sin(2 * np.pi * 0.7 * t)) + depth * 0.5 * ga.lowpass(np.random.standard_normal(n), 8)
    pos = np.cumsum(wobble)
    pos = pos / pos[-1] * (n - 1)
    y = np.interp(pos, np.arange(n), x)
    return y * (0.82 + 0.18 * np.sin(2 * np.pi * (rate * 0.9) * t + 1.0))


def radio(x):
    y = ga.bandpass(x, 320, 3300, 2)
    y = np.tanh(y * 2.5) / 2.0
    hiss = ga.bandpass(np.random.standard_normal(len(y)), 1000, 5000) * 0.012
    sq = ga.bandpass(np.random.standard_normal(ga.n_of(0.12)), 800, 4000) * np.exp(-np.arange(ga.n_of(0.12)) / ga.n_of(0.03)) * 0.25
    return np.concatenate([sq, y + hiss, sq * 0.6])


def tape(x, hiss=0.01):
    n = len(x)
    t = np.arange(n) / SR
    flutter = 1 + 0.004 * np.sin(2 * np.pi * 0.8 * t) + 0.0015 * np.sin(2 * np.pi * 9 * t)
    pos = np.cumsum(flutter)
    pos = pos / pos[-1] * (n - 1)
    y = np.interp(pos, np.arange(n), x)
    y = ga.lowpass(ga.highpass(y, 120), 5200)
    y = np.tanh(y * 1.6) / 1.4
    y += ga.bandpass(np.random.standard_normal(n), 2000, 9000) * hiss
    return y


def phonograph(x):
    n = len(x)
    y = ga.bandpass(x, 420, 2700, 2)
    t = np.arange(n) / SR
    warble = 1 + 0.008 * np.sin(2 * np.pi * 0.55 * t)
    pos = np.cumsum(warble)
    pos = pos / pos[-1] * (n - 1)
    y = np.interp(pos, np.arange(n), y)
    crackle = (np.random.random(n) > 0.9985) * np.random.uniform(-1, 1, n) * 0.5
    y = np.tanh(y * 2.0) / 1.8 + ga.highpass(crackle, 1500) + ga.lowpass(np.random.standard_normal(n), 3000) * 0.015
    return y


def voicemail(x):
    y = ga.bandpass(x, 300, 3400, 2)
    return y * 0.9 + ga.lowpass(np.random.standard_normal(len(y)), 2000) * 0.004


def beep(f=1000, d=0.25):
    t = np.arange(ga.n_of(d)) / SR
    return np.sin(2 * np.pi * f * t) * 0.3 * np.minimum(1, (d - t) * 40)


def clunk():
    n = ga.n_of(0.25)
    return ga.lowpass(np.random.standard_normal(n), 400) * np.exp(-np.arange(n) / ga.n_of(0.04)) * 0.6


def normalize(x, peak=0.85):
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def text_hash(text):
    return hashlib.md5(text.encode("utf-8")).hexdigest()[:10]


def unescape(s):
    return s.replace('\\"', '"').replace("\\n", "\n").replace("\\'", "'")


def collect_lines():
    lines = {}
    for path in glob.glob(os.path.join(ROOT, "scripts", "**", "*.gd"), recursive=True):
        src = open(path, encoding="utf-8").read()
        for m in re.finditer(r'brenda\("((?:[^"\\]|\\.)*)"', src):
            lines[unescape(m.group(1))] = "brenda"
        for m in re.finditer(r'Shift\.say\("((?:[^"\\]|\\.)*)",\s*(BOSS|"[^"]*")', src):
            tag = m.group(2).strip('"')
            who = "brenda" if tag == "BOSS" else SPEAKER_TAGS.get(tag)
            if who:
                lines[unescape(m.group(1))] = who
        for m in re.finditer(r'"voice": "((?:[^"\\]|\\.)*)"', src):
            t = unescape(m.group(1))
            lines[t] = "brenda_scared" if "Lucy" in t else "pemberton"
        for m in re.finditer(r'pemberton\(\)\.say\("((?:[^"\\]|\\.)*)"', src):
            lines[unescape(m.group(1))] = "pemberton"
        if path.endswith("pemberton.gd"):
            for m in re.finditer(r'(?:say\(|^\t)"((?:[^"\\]|\\.)*)"', src, re.M):
                lines[unescape(m.group(1))] = "pemberton"
        if path.endswith("wax_guard.gd"):
            for m in re.finditer(r'"([^"]*(?:closed|security|eyes)[^"]*)"', src, re.I):
                lines[unescape(m.group(1))] = "gary"
    return lines


def parse_tapes():
    src = open(os.path.join(ROOT, "scripts", "data", "tapes.gd"), encoding="utf-8").read()
    tapes = []
    for block in src.split('{"title": ')[1:]:
        fx = re.search(r'"fx": "(\w+)"', block).group(1)
        lines = [(w, unescape(t)) for w, t in re.findall(r'\["(\w+)", "((?:[^"\\]|\\.)*)"\]', block)]
        tapes.append((fx, lines))
    return tapes


def make_line(text, who):
    x = tts(text, "brenda" if who == "brenda_scared" else who)
    x = normalize(x)
    if who == "brenda":
        return normalize(radio(x))
    if who == "brenda_scared":
        return normalize(ga.reverb(radio(tremble(normalize(tts(text, "brenda")), 0.025, 6.5)), 3.0, 0.5)[:, 0])
    if who == "pemberton":
        return normalize(phonograph(ga.reverb(x, 2.5, 0.35)[:, 0]))
    if who == "dolls":
        return normalize(ga.reverb(tremble(x, 0.01, 4.0), 2.0, 0.4)[:, 0])
    return normalize(x)


def make_tape(fx, lines):
    parts = []
    timings = []
    t = 0.0
    lead = clunk() if fx != "voicemail" else beep(1000, 0.35)
    parts.append(lead)
    parts.append(np.zeros(ga.n_of(0.4)))
    t += len(lead) / SR + 0.4
    for who, text in lines:
        x = normalize(tts(text, who))
        if fx == "tape_tremble":
            x = tremble(x)
            breath = ga.bandpass(np.random.standard_normal(ga.n_of(0.45)), 400, 2500) * np.sin(np.linspace(0, np.pi, ga.n_of(0.45))) * 0.08
            parts.append(breath)
            t += len(breath) / SR
        timings.append([round(t, 2), text])
        parts.append(x)
        t += len(x) / SR
        gap = 0.55 if fx != "tape_tremble" else 0.9
        parts.append(np.zeros(ga.n_of(gap)))
        t += gap
    parts.append(clunk() if fx != "voicemail" else beep(800, 0.25))
    y = np.concatenate(parts)
    if fx in ("tape", "tape_tremble"):
        y = tape(y, 0.012 if fx == "tape" else 0.018)
    elif fx == "phonograph":
        y = phonograph(y)
    elif fx == "voicemail":
        y = voicemail(y)
    return normalize(y), timings


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    only = set(sys.argv[1:])
    if not only or "lines" in only:
        lines = collect_lines()
        print(len(lines), "spoken lines")
        for text, who in lines.items():
            path = os.path.join(OUT, "line_%s.ogg" % text_hash(text))
            if os.path.exists(path):
                continue
            ga.write_ogg(path, make_line(text, who))
        print("lines done")
    if not only or "tapes" in only:
        for i, (fx, lines) in enumerate(parse_tapes()):
            y, timings = make_tape(fx, lines)
            ga.write_ogg(os.path.join(OUT, "tape_%d.ogg" % (i + 1)), y)
            json.dump(timings, open(os.path.join(OUT, "tape_%d.json" % (i + 1)), "w"), indent=0)
            print("tape", i + 1, round(len(y) / SR, 1), "s")

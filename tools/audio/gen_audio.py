#!/usr/bin/env python3
"""Erzeugt Musik, Umgebungs-Loops und Soundeffekte für Cube City.

Nur Python-Standardbibliothek + ffmpeg (Hall per FIR-Faltung, Filter, MP3-Encoding).
Deterministisch über Seeds -> jederzeit reproduzierbar.

    python3 tools/audio/gen_audio.py            # alles
    python3 tools/audio/gen_audio.py music      # nur Musik
    python3 tools/audio/gen_audio.py ambient sfx
"""
import array
import math
import os
import random
import subprocess
import sys
import tempfile
import wave

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")
SR_MUSIC = 32000
SR_FX = 22050


# ---------------------------------------------------------------- Grundlagen

def zeros(n):
    return array.array("f", bytes(4 * n))


def write_wav(path, chans, sr):
    """chans: Liste von float-Arrays (-1..1), 16-bit PCM."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    n = len(chans[0])
    pcm = array.array("h", bytes(2 * n * len(chans)))
    k = 0
    for i in range(n):
        for c in chans:
            v = c[i]
            v = -1.0 if v < -1.0 else (1.0 if v > 1.0 else v)
            pcm[k] = int(v * 32767)
            k += 1
    with wave.open(path, "wb") as w:
        w.setnchannels(len(chans))
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def normalize(buf, peak=0.9):
    m = max(abs(x) for x in buf) or 1.0
    g = peak / m
    for i in range(len(buf)):
        buf[i] *= g
    return buf


def add(dst, src, offset=0, gain=1.0):
    n = min(len(src), len(dst) - offset)
    for i in range(max(0, -offset), n):
        dst[offset + i] += src[i] * gain


def add_wrapped(dst, src, offset, gain=1.0):
    """Wie add, aber über das Ende hinaus wieder vorne weiter (nahtlose Loops)."""
    L = len(dst)
    for i in range(len(src)):
        dst[(offset + i) % L] += src[i] * gain


def lowpass(buf, cutoff, sr):
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / sr)
    y = 0.0
    out = zeros(len(buf))
    for i in range(len(buf)):
        y += a * (buf[i] - y)
        out[i] = y
    return out


def highpass(buf, cutoff, sr):
    lp = lowpass(buf, cutoff, sr)
    return array.array("f", (buf[i] - lp[i] for i in range(len(buf))))


def white(n, rng, amp=1.0):
    return array.array("f", (rng.uniform(-amp, amp) for _ in range(n)))


def brown(n, rng, leak=0.995):
    out = zeros(n)
    y = 0.0
    for i in range(n):
        y = y * leak + rng.uniform(-1, 1) * 0.1
        out[i] = y
    return normalize(out, 1.0)


def osc(freq, n, sr, amp=1.0, decay=0.0, phase=0.0):
    """Sinus per Rekursion (schnell), optional exponentiell abklingend (decay in 1/s)."""
    out = zeros(n)
    w = 2.0 * math.pi * freq / sr
    c2 = 2.0 * math.cos(w)
    s1 = math.sin(phase)
    s0 = math.sin(phase - w)
    env = amp
    d = math.exp(-decay / sr)
    for i in range(n):
        out[i] = s1 * env
        s0, s1 = s1, c2 * s1 - s0
        env *= d
    return out


def env_ad(n, sr, attack, decay_rate):
    out = zeros(n)
    na = max(1, int(attack * sr))
    d = math.exp(-decay_rate / sr)
    e = 1.0
    for i in range(n):
        if i < na:
            out[i] = i / na
        else:
            out[i] = e
            e *= d
    return out


def mul(a, b):
    return array.array("f", (a[i] * b[i] for i in range(min(len(a), len(b)))))


def loopify(buf, xfade):
    """Letzte xfade Samples in den Anfang überblenden -> nahtloser Loop der Länge len-xfade."""
    L = len(buf) - xfade
    out = array.array("f", buf[:L])
    for i in range(xfade):
        t = i / xfade
        out[i] = buf[i] * t + buf[L + i] * (1.0 - t)
    return out


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


# ---------------------------------------------------------------- Instrumente

def midi_hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


_piano_cache = {}


def piano(midi, sr):
    """Gedämpftes Felt-Piano: inharmonische Teiltöne, 2 leicht verstimmte Saiten."""
    if midi in _piano_cache:
        return _piano_cache[midi]
    f = midi_hz(midi)
    base_decay = 0.55 + f / 700.0
    dur = min(7.0, math.log(3000) / base_decay)
    n = int(dur * sr)
    out = zeros(n)
    B = 0.00025
    for k in range(1, 8):
        fk = k * f * math.sqrt(1 + B * k * k)
        if fk > sr * 0.42:
            break
        amp = 1.0 / (k ** 1.8)
        dec = base_decay * (0.8 + 0.45 * k)
        for det in (-0.00035, 0.00035):
            add(out, osc(fk * (1 + det), n, sr, amp * 0.5, dec, phase=k * 0.7), 0)
    # weicher Filzanschlag
    att = int(0.012 * sr)
    for i in range(att):
        out[i] *= (i / att) ** 1.5
    _piano_cache[midi] = out
    return out


def pad_voice(midi, dur, sr, amp):
    """Weiche Fläche: Sinus + Oktave, langsames Ein-/Ausblenden, leichtes Schweben."""
    n = int(dur * sr)
    f = midi_hz(midi)
    a = osc(f * 1.0015, n, sr, 0.6)
    b = osc(f * 0.9985, n, sr, 0.6)
    c = osc(f * 2.0, n, sr, 0.12)
    out = zeros(n)
    att = 2.8 * sr
    rel = 3.2 * sr
    for i in range(n):
        e = min(1.0, i / att, (n - i) / rel)
        out[i] = (a[i] + b[i] + c[i]) * e * amp
    return out


# ---------------------------------------------------------------- Komposition

SCALES = {
    "major": [0, 2, 4, 5, 7, 9, 11],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
}

TRACKS = [
    # name, Grundton, Modus, BPM, Akkordstufen, Seed
    ("morgentau", 60, "lydian", 64, [0, 1, 5, 4], 11),
    ("schornsteine", 57, "dorian", 58, [0, 3, 6, 4], 23),
    ("gruenflaechen", 65, "major", 68, [0, 5, 3, 4], 37),
    ("abendrot", 62, "mixolydian", 56, [0, 6, 3, 0], 41),
]


def scale_note(root, scale, degree):
    octave, idx = divmod(degree, len(scale))
    return root + octave * 12 + scale[idx]


def compose(root, mode, bpm, prog, seed):
    rng = random.Random(seed)
    scale = SCALES[mode]
    beat = 60.0 / bpm
    chord_len = 8 * beat          # 2 Takte pro Akkord
    rounds = 4                    # Progression 4x -> 16 Akkorde
    notes = []                    # (zeit, midi, velocity)
    pads = []                     # (zeit, dauer, [midis])
    t = 1.5
    mel_deg = 7 + rng.randint(0, 4)
    total_chords = len(prog) * rounds
    for ci in range(total_chords):
        deg = prog[ci % len(prog)]
        intro = ci < 2
        outro = ci >= total_chords - 2
        chord = [deg, deg + 2, deg + 4] + ([deg + 6] if rng.random() < 0.5 else [])
        pads.append((t, chord_len + 2.5, [scale_note(root - 12, scale, d) for d in chord[:3]]))
        # Bass
        notes.append((t, scale_note(root - 24, scale, deg), 0.5))
        if not intro and rng.random() < 0.6:
            notes.append((t + 4 * beat, scale_note(root - 24, scale, deg + 4), 0.32))
        # gebrochener Akkord, linke Hand
        if not intro:
            for b in (0.0, 1.5, 3.0, 4.0, 5.5, 7.0):
                if rng.random() < 0.55:
                    d = rng.choice(chord)
                    notes.append((t + b * beat + rng.uniform(-0.02, 0.02), scale_note(root - 12, scale, d), rng.uniform(0.22, 0.34)))
        # Melodie: spärlich, schrittweise
        density = 0.15 if (intro or outro) else 0.42
        b = 0.0
        while b < 8.0:
            if rng.random() < density:
                step = rng.choice([-2, -1, -1, 0, 1, 1, 2, 3, -3])
                mel_deg = max(5, min(14, mel_deg + step))
                # auf schweren Zählzeiten Akkordtöne bevorzugen
                if b in (0.0, 4.0) and rng.random() < 0.6:
                    mel_deg = min(chord, key=lambda c: abs((c + 7) - mel_deg)) + 7
                vel = rng.uniform(0.32, 0.52)
                tn = t + b * beat + rng.uniform(-0.03, 0.03)
                notes.append((tn, scale_note(root, scale, mel_deg), vel))
                if rng.random() < 0.15:  # Terz dazu
                    notes.append((tn + 0.02, scale_note(root, scale, mel_deg - 2), vel * 0.6))
            b += rng.choice([1.0, 1.0, 1.5, 2.0, 0.5])
        t += chord_len * (1.08 if outro else 1.0)
    # Schlussakkord
    final = [prog[0], prog[0] + 2, prog[0] + 4]
    notes.append((t, scale_note(root - 24, scale, prog[0]), 0.45))
    for k, d in enumerate(final):
        notes.append((t + 0.15 * k, scale_note(root, scale, d), 0.35))
    pads.append((t, 9.0, [scale_note(root - 12, scale, d) for d in final]))
    return notes, pads, t + 10.0


def make_ir(sr, seconds=3.4, seed=5):
    """Stereo-Hall-Impulsantwort: frühe Reflexionen + abklingendes, dunkler werdendes Rauschen."""
    rng = random.Random(seed)
    n = int(seconds * sr)
    chans = []
    for ch in range(2):
        buf = zeros(n)
        buf[0] = 1.0
        for _ in range(14):
            buf[int(rng.uniform(0.008, 0.07) * sr)] += rng.uniform(-0.5, 0.5)
        y = 0.0
        for i in range(int(0.02 * sr), n):
            t = i / sr
            # Tiefpass wird mit der Zeit enger -> warmer Ausklang
            a = 0.5 * math.exp(-t * 1.2) + 0.05
            y += a * (rng.uniform(-1, 1) - y)
            buf[i] += y * 0.55 * math.exp(-t * 2.2)
        chans.append(buf)
    return chans


def render_music(only=None):
    tmp = tempfile.mkdtemp(prefix="cubecity_audio_")
    ir_path = os.path.join(tmp, "ir.wav")
    ir = make_ir(SR_MUSIC)
    peak = max(max(abs(x) for x in c) for c in ir)
    write_wav(ir_path, [array.array("f", (x / peak for x in c)) for c in ir], SR_MUSIC)
    for name, root, mode, bpm, prog, seed in TRACKS:
        if only and name not in only:
            continue
        print(f"Musik: {name} ...", flush=True)
        notes, pads, length = compose(root, mode, bpm, prog, seed)
        n = int(length * SR_MUSIC)
        mix = zeros(n)
        for t, m, v in notes:
            add(mix, piano(m, SR_MUSIC), int(t * SR_MUSIC), v)
        for t, dur, ms in pads:
            for m in ms:
                add(mix, pad_voice(m, dur, SR_MUSIC, 0.03), int(t * SR_MUSIC))
        normalize(mix, 0.7)
        dry = os.path.join(tmp, f"{name}_dry.wav")
        write_wav(dry, [mix], SR_MUSIC)
        out = os.path.join(OUT, "music", f"{name}.mp3")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        fade_start = max(0.0, length - 7.0)
        ffmpeg("-i", dry, "-i", ir_path, "-filter_complex",
               "[0:a]pan=stereo|c0=c0|c1=c0,asplit[a][b];"
               "[b][1:a]afir=irnorm=1[w];"
               "[a][w]amix=inputs=2:weights='1 0.55':normalize=0,"
               f"lowpass=f=5200,highpass=f=85,equalizer=f=160:t=q:w=1.2:g=-5,afade=t=in:d=1.5,afade=t=out:st={fade_start:.2f}:d=7,"
               "loudnorm=I=-23:TP=-2:LRA=14",
               "-ar", "44100", "-c:a", "libmp3lame", "-q:a", "3", out)
        print(f"  -> {os.path.relpath(out, ROOT)} ({length:.0f}s)")


# ---------------------------------------------------------------- Umgebung

def render_traffic(seconds=20.0, seed=3):
    sr = SR_FX
    rng = random.Random(seed)
    L = int(seconds * sr)
    mix = zeros(L)
    bed = lowpass(brown(L, rng), 260, sr)
    add(mix, bed, 0, 0.25)
    t = 0.0
    while t < seconds:
        dur = rng.uniform(2.4, 3.6)
        n = int(dur * sr)
        f0 = rng.uniform(42, 78)
        car = zeros(n)
        # Motor: sägezahnartig, Tonhöhe sinkt beim Vorbeifahren (Doppler)
        for k in range(1, 7):
            seg = zeros(n)
            ph = 0.0
            for i in range(n):
                x = i / n
                f = f0 * k * (1.06 - 0.12 * x)
                ph += 2 * math.pi * f / sr
                seg[i] = math.sin(ph) / k
            add(car, seg, 0, 1.0)
        tires = lowpass(highpass(white(n, rng), 250, sr), 1400, sr)
        add(car, tires, 0, 2.2)
        # Glockenkurve: nähern, vorbei, entfernen
        for i in range(n):
            x = (i / n - 0.5) * 3.2
            car[i] *= math.exp(-x * x)
        add_wrapped(mix, car, int(t * sr), rng.uniform(0.18, 0.32))
        t += rng.uniform(0.9, 2.6)
    return normalize(lowpass(mix, 2600, sr), 0.85)


def render_industry(seconds=16.0, seed=7):
    sr = SR_FX
    rng = random.Random(seed)
    L = int(seconds * sr)
    mix = zeros(L)
    add(mix, lowpass(brown(L, rng), 110, sr), 0, 0.5)
    for k, a in ((1, 0.10), (2, 0.06), (3, 0.03)):
        add(mix, osc(50.0 * k, L, sr, a), 0)
    # Stampfen
    beat = 0.8
    t = 0.0
    while t < seconds - 0.01:
        n = int(0.25 * sr)
        thud = osc(68, n, sr, 0.55, decay=18)
        add(thud, lowpass(white(n, rng), 300, sr), 0, 0.5)
        for i in range(n):
            thud[i] *= math.exp(-i / sr * 22)
        add_wrapped(mix, thud, int(t * sr))
        t += beat
    # Metall-Klonken
    t = 1.1
    while t < seconds:
        n = int(0.6 * sr)
        clank = zeros(n)
        for f, a in ((610, 0.5), (1437, 0.35), (2203, 0.22), (3170, 0.12)):
            add(clank, osc(f * rng.uniform(0.98, 1.02), n, sr, a, decay=9 + f / 400))
        add_wrapped(mix, clank, int(t * sr), rng.uniform(0.12, 0.2))
        t += rng.choice([2.4, 3.2, 4.0])
    # Dampfzischen
    t = 3.0
    while t < seconds:
        n = int(1.3 * sr)
        hiss = highpass(white(n, rng), 2500, sr)
        for i in range(n):
            x = i / n
            hiss[i] *= math.sin(math.pi * x) ** 2
        add_wrapped(mix, hiss, int(t * sr), 0.12)
        t += rng.uniform(4.5, 6.5)
    return normalize(lowpass(mix, 4000, sr), 0.85)


def render_wind(seconds=30.0, seed=9):
    sr = SR_FX
    rng = random.Random(seed)
    L = int(seconds * sr) + sr * 3
    noise = white(L, rng)
    out = zeros(L)
    y = 0.0
    for i in range(L):
        t = i / sr
        # Böen: langsam schwankende Grenzfrequenz und Lautstärke
        g = 0.5 + 0.3 * math.sin(t * 0.21) + 0.2 * math.sin(t * 0.077 + 1.3)
        cutoff = 220 + 520 * g
        a = 1.0 - math.exp(-2 * math.pi * cutoff / sr)
        y += a * (noise[i] - y)
        out[i] = y * (0.35 + 0.65 * g)
    return normalize(loopify(out, sr * 3), 0.8)


def chirp(sr, rng, f_start, f_end, dur, amp):
    n = int(dur * sr)
    out = zeros(n)
    ph = 0.0
    for i in range(n):
        x = i / n
        f = f_start + (f_end - f_start) * x
        ph += 2 * math.pi * f / sr
        out[i] = math.sin(ph) * math.sin(math.pi * x) * amp
    return out


def render_birds(seconds=30.0, seed=13):
    sr = SR_FX
    rng = random.Random(seed)
    L = int(seconds * sr)
    mix = zeros(L)
    t = 0.5
    while t < seconds:
        species = rng.randint(0, 2)
        dist = rng.uniform(0.25, 1.0)    # leiser = weiter weg
        count = rng.randint(2, 5)
        tt = t
        for _ in range(count):
            if species == 0:
                c = chirp(sr, rng, 3200, 4300, 0.07, 1.0)
            elif species == 1:
                c = chirp(sr, rng, 2600, 1900, 0.12, 1.0)
            else:
                c = chirp(sr, rng, 4200, 4600, 0.04, 1.0)
            add_wrapped(mix, c, int(tt * sr), 0.3 * dist)
            tt += rng.uniform(0.08, 0.22)
        t += rng.uniform(1.5, 4.5)
    return normalize(lowpass(mix, 6500, sr), 0.6)


def render_ambient():
    for name, fn in (("traffic", render_traffic), ("industry", render_industry),
                     ("wind", render_wind), ("birds", render_birds)):
        print(f"Umgebung: {name} ...", flush=True)
        buf = fn()
        path = os.path.join(OUT, "ambient", f"{name}.wav")
        write_wav(path, [buf], SR_FX)
        print(f"  -> {os.path.relpath(path, ROOT)} ({len(buf) / SR_FX:.0f}s)")


# ---------------------------------------------------------------- Effekte

def sfx_click(sr, rng):
    n = int(0.06 * sr)
    out = osc(720, n, sr, 0.6, decay=60)
    add(out, osc(1730, n, sr, 0.25, decay=90))
    add(out, lowpass(white(int(0.008 * sr), rng), 3000, sr), 0, 0.4)
    return out


def sfx_place(sr, rng):
    n = int(0.28 * sr)
    out = zeros(n)
    ph = 0.0
    for i in range(n):
        x = i / sr
        f = 95 + 85 * math.exp(-x * 30)
        ph += 2 * math.pi * f / sr
        out[i] = math.sin(ph) * math.exp(-x * 14)
    knock = lowpass(white(int(0.03 * sr), rng), 900, sr)
    add(out, knock, 0, 0.8)
    add(out, osc(880, int(0.08 * sr), sr, 0.12, decay=50))
    return out


def sfx_zone(sr, rng):
    n = int(0.12 * sr)
    out = zeros(n)
    ph = 0.0
    for i in range(n):
        x = i / n
        f = 520 + 300 * x
        ph += 2 * math.pi * f / sr
        out[i] = math.sin(ph) * math.sin(math.pi * x) * 0.7
    return out


def sfx_bulldoze(sr, rng):
    n = int(0.7 * sr)
    out = zeros(n)
    add(out, osc(70, n, sr, 0.6, decay=8))
    for _ in range(9):
        m = int(rng.uniform(0.04, 0.12) * sr)
        burst = lowpass(white(m, rng), rng.uniform(500, 1500), sr)
        for i in range(m):
            burst[i] *= math.exp(-i / sr * 35)
        add(out, burst, int(rng.uniform(0.0, 0.45) * sr), rng.uniform(0.4, 0.9))
    return out


def sfx_error(sr, rng):
    out = zeros(int(0.34 * sr))
    for k, f in enumerate((330.0, 247.0)):
        n = int(0.16 * sr)
        tone = osc(f, n, sr, 0.5, decay=12)
        add(tone, osc(f * 2, n, sr, 0.1, decay=20))
        add(out, tone, int(k * 0.15 * sr))
    return out


def sfx_notify(sr, rng):
    out = zeros(int(1.6 * sr))
    for k, m in enumerate((88, 95)):  # E6, B6 — Klavier passend zur Musik
        add(out, piano(m, sr), int(k * 0.11 * sr), 0.5)
    return out


def render_sfx():
    rng = random.Random(21)
    for name, fn in (("click", sfx_click), ("place", sfx_place), ("zone", sfx_zone),
                     ("bulldoze", sfx_bulldoze), ("error", sfx_error), ("notify", sfx_notify)):
        _piano_cache.clear()
        buf = normalize(fn(SR_FX, rng), 0.8)
        path = os.path.join(OUT, "sfx", f"{name}.wav")
        write_wav(path, [buf], SR_FX)
        print(f"SFX: {os.path.relpath(path, ROOT)}")
    _piano_cache.clear()


if __name__ == "__main__":
    what = set(sys.argv[1:]) or {"music", "ambient", "sfx"}
    if "sfx" in what:
        render_sfx()
    if "ambient" in what:
        render_ambient()
    if "music" in what:
        render_music()

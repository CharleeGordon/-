"""Procedural PBR texture generator (no external assets, fully owned / commercial-safe).

Run from the game/ folder:  python3 tools/gen_textures.py
Writes textures/<name>_albedo.jpg, _normal.jpg, _rough.jpg (+ a few extras).
All textures tile seamlessly. Requires: numpy, pillow.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
N = 1024
rng = np.random.default_rng(1234)


# ---------------------------------------------------------------- noise ----

def vnoise(size, cells, seed=None):
    """Tileable value noise in [0,1], shape (size,size)."""
    r = np.random.default_rng(seed) if seed is not None else rng
    grid = r.random((cells, cells))
    t = np.arange(size) * cells / size
    i0 = np.floor(t).astype(int) % cells
    i1 = (i0 + 1) % cells
    f = t - np.floor(t)
    f = f * f * (3 - 2 * f)
    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0, i1)]
    c = grid[np.ix_(i1, i0)]
    d = grid[np.ix_(i1, i1)]
    fx = f[None, :]
    fy = f[:, None]
    top = a + (b - a) * fx
    bot = c + (d - c) * fx
    return top + (bot - top) * fy


def fbm(size, cells=4, octaves=6, persistence=0.5, seed=None):
    total = np.zeros((size, size))
    amp, norm = 1.0, 0.0
    for o in range(octaves):
        c = cells * (2 ** o)
        if c > size:
            break
        total += vnoise(size, c, None if seed is None else seed + o) * amp
        norm += amp
        amp *= persistence
    return total / norm


def stretched_fbm(size, cx, cy, octaves=5, seed=None):
    """Anisotropic noise (cx cells across x, cy across y) for wood grain / brushed metal."""
    total = np.zeros((size, size))
    amp, norm = 1.0, 0.0
    r = np.random.default_rng(seed)
    for o in range(octaves):
        gx, gy = max(1, cx * 2 ** o), max(1, cy * 2 ** o)
        if gx > size or gy > size:
            break
        grid = r.random((gy, gx))
        ty = np.arange(size) * gy / size
        tx = np.arange(size) * gx / size
        y0 = np.floor(ty).astype(int) % gy
        x0 = np.floor(tx).astype(int) % gx
        fy = ty - np.floor(ty)
        fx = tx - np.floor(tx)
        fy = (fy * fy * (3 - 2 * fy))[:, None]
        fx = (fx * fx * (3 - 2 * fx))[None, :]
        a = grid[np.ix_(y0, x0)]
        b = grid[np.ix_(y0, (x0 + 1) % gx)]
        c = grid[np.ix_((y0 + 1) % gy, x0)]
        d = grid[np.ix_((y0 + 1) % gy, (x0 + 1) % gx)]
        total += ((a + (b - a) * fx) * (1 - fy) + (c + (d - c) * fx) * fy) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def coords(size=N):
    y, x = np.mgrid[0:size, 0:size] / size
    return x, y


def norm01(a):
    a = a - a.min()
    return a / max(a.max(), 1e-9)


def blur(a, radius):
    img = Image.fromarray((norm01(a) * 65535).astype(np.uint16).astype(np.int32), mode="I")
    # Pillow blur on 'I' is limited, use float trick via 'F'
    img = Image.fromarray(a.astype(np.float32), mode="F").filter(ImageFilter.GaussianBlur(radius))
    return np.array(img)


# ---------------------------------------------------------------- output ---

def height_to_normal(h, strength=4.0):
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5
    nx = -dx * strength * N / 256
    ny = dy * strength * N / 256  # OpenGL convention (Godot)
    nz = np.ones_like(h)
    l = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / l, ny / l, nz / l], axis=-1) * 0.5 + 0.5


def save_rgb(name, rgb, quality=90):
    arr = (np.clip(rgb, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(arr, "RGB").save(os.path.join(OUT, name), quality=quality, subsampling=0)


def save_gray(name, g, quality=90):
    g = np.broadcast_to(np.asarray(g, dtype=float), (N, N))
    arr = (np.clip(g, 0, 1) * 255).astype(np.uint8)
    Image.fromarray(arr, "L").save(os.path.join(OUT, name), quality=quality)


def save_set(name, albedo, height, rough, normal_strength=4.0):
    save_rgb(f"{name}_albedo.jpg", albedo)
    save_rgb(f"{name}_normal.jpg", height_to_normal(height, normal_strength), quality=95)
    save_gray(f"{name}_rough.jpg", rough)
    print("texture", name)


def colorize(t, c0, c1):
    t = t[..., None]
    return np.array(c0) * (1 - t) + np.array(c1) * t


def tile_grid(x, y, nx, ny, offset_rows=False):
    """Returns (u,v inside tile 0..1, tile ix, tile iy)."""
    gx = x * nx
    gy = y * ny
    iy = np.floor(gy)
    if offset_rows:
        gx = gx + (iy % 2) * 0.5
    ix = np.floor(gx)
    return gx - ix, gy - iy, ix % nx, iy % ny


def grout_mask(u, v, width):
    """1 on tile, 0 in grout, with soft bevel."""
    d = np.minimum(np.minimum(u, 1 - u), np.minimum(v, 1 - v))
    return np.clip(d / width, 0, 1)


def per_tile_random(ix, iy, seed):
    r = np.random.default_rng(seed).random((64, 64))
    return r[(iy.astype(int)) % 64, (ix.astype(int)) % 64]


# ------------------------------------------------------------- materials ---

def marble_floor():
    x, y = coords()
    u, v, ix, iy = tile_grid(x, y, 2, 2)
    checker = ((ix + iy) % 2)
    turb = fbm(N, 3, 7, 0.55, seed=10)
    veins = np.abs(np.sin((x * 3 + y * 2 + turb * 5.0) * math.pi))
    veins = 1 - np.power(veins, 0.18)
    fine = fbm(N, 16, 5, 0.5, seed=11)
    white = colorize(fine * 0.4 + 0.6, (0.72, 0.70, 0.66), (0.92, 0.91, 0.88))
    white = white * (1 - veins[..., None] * 0.55)
    black = colorize(fine, (0.05, 0.05, 0.06), (0.16, 0.15, 0.15))
    black = black + veins[..., None] * np.array([0.35, 0.33, 0.3])
    albedo = np.where(checker[..., None] == 0, white, black)
    g = grout_mask(u, v, 0.006)
    albedo = albedo * (0.45 + 0.55 * g[..., None])
    dirt = fbm(N, 6, 5, 0.6, seed=12)
    albedo *= (0.85 + 0.15 * dirt)[..., None]
    height = g * 0.6 + fine * 0.05
    rough = 0.12 + (1 - g) * 0.7 + dirt * 0.18 + veins * 0.05
    save_set("marble_floor", albedo, height, rough, 6.0)


def wood_floor():
    x, y = coords()
    planks_x, planks_y = 4, 16  # plank 1/4 wide, 1/16... rotated: long along x
    gy = y * planks_y
    iy = np.floor(gy)
    gx = x * planks_x + per_tile_random(np.zeros_like(iy), iy, 3) * 3
    ix = np.floor(gx)
    u, v = gx - ix, gy - iy
    rnd = per_tile_random(ix, iy, 4)
    grain = stretched_fbm(N, 2, 64, 6, seed=5)
    rings = np.sin((grain * 18 + rnd * 10 + v * 3) * math.pi) * 0.5 + 0.5
    base = colorize(rnd * 0.6 + rings * 0.4, (0.20, 0.11, 0.06), (0.42, 0.25, 0.13))
    knots = fbm(N, 8, 4, 0.5, seed=6)
    base *= (0.85 + 0.25 * knots)[..., None]
    gap = np.clip(np.minimum(v, 1 - v) / 0.04, 0, 1) * np.clip(np.minimum(u, 1 - u) / 0.008, 0, 1)
    albedo = base * (0.35 + 0.65 * gap[..., None])
    wear = fbm(N, 5, 5, 0.6, seed=7)
    height = gap * 0.7 + rings * 0.08 + grain * 0.1
    rough = 0.35 + rings * 0.15 + wear * 0.25 + (1 - gap) * 0.3
    save_set("wood_floor", albedo, height, rough, 5.0)


def dark_wood():
    x, y = coords()
    grain = stretched_fbm(N, 3, 48, 6, seed=20)
    rings = np.sin((grain * 22 + x * 2) * math.pi) * 0.5 + 0.5
    albedo = colorize(rings * 0.5 + grain * 0.5, (0.08, 0.04, 0.02), (0.24, 0.13, 0.07))
    height = rings * 0.2 + grain * 0.2
    rough = 0.35 + rings * 0.2
    save_set("dark_wood", albedo, height, rough, 3.0)


def plaster():
    x, y = coords()
    n = fbm(N, 4, 8, 0.55, seed=30)
    fine = fbm(N, 64, 3, 0.5, seed=31)
    stains = np.clip((fbm(N, 3, 5, 0.6, seed=32) - 0.55) * 3, 0, 1)
    albedo = colorize(n * 0.5 + fine * 0.5, (0.62, 0.58, 0.50), (0.78, 0.74, 0.66))
    albedo *= (1 - stains * 0.12)[..., None]
    height = n * 0.3 + fine * 0.25
    rough = 0.8 + fine * 0.15
    save_set("plaster", albedo, height, rough, 2.5)


def wallpaper():
    x, y = coords()
    # Damask-like motif: symmetric polar pattern repeated 4x4
    tu, tv, ix, iy = tile_grid(x, y, 4, 4, offset_rows=True)
    px, py = (tu - 0.5) * 2, (tv - 0.5) * 2
    r = np.sqrt(px * px + py * py)
    a = np.arctan2(py, np.abs(px))
    motif = np.sin(a * 6 + r * 9) * np.exp(-r * 1.8) + 0.6 * np.exp(-((np.abs(px) - 0.25) ** 2 + (py + 0.3) ** 2) * 30)
    motif += 0.5 * np.exp(-(px ** 2 + (py - 0.45) ** 2) * 40)
    m = np.clip(motif * 1.6, 0, 1)
    stripes = (np.sin(x * N * 0.5) * 0.5 + 0.5) * 0.04
    age = fbm(N, 4, 6, 0.55, seed=40)
    base = np.array([0.25, 0.04, 0.05]) * (0.8 + 0.3 * age[..., None])
    gold = np.array([0.55, 0.40, 0.16]) * (0.8 + 0.3 * age[..., None])
    albedo = base * (1 - m[..., None]) + gold * m[..., None] + stripes[..., None]
    height = m * 0.4 + age * 0.1
    rough = 0.75 - m * 0.35
    save_set("wallpaper", albedo, height, rough, 2.0)


def concrete():
    x, y = coords()
    n = fbm(N, 4, 8, 0.6, seed=50)
    pores = (vnoise(N, 256, 51) > 0.93).astype(float)
    cracks = np.abs(fbm(N, 3, 6, 0.6, seed=52) - 0.5)
    crack = np.clip(1 - cracks / 0.01, 0, 1) * (fbm(N, 2, 3, 0.5, seed=53) > 0.55)
    albedo = colorize(n, (0.25, 0.25, 0.24), (0.48, 0.47, 0.45))
    albedo *= (1 - pores * 0.4 - crack * 0.5)[..., None]
    height = n * 0.3 - pores * 0.3 - crack * 0.5
    rough = 0.85 + n * 0.1
    save_set("concrete", albedo, height, rough, 3.0)


def sandstone_blocks():
    """Egyptian wall: large sandstone blocks with carved glyphs."""
    x, y = coords()
    u, v, ix, iy = tile_grid(x, y, 2, 4, offset_rows=True)
    rnd = per_tile_random(ix, iy, 60)
    n = fbm(N, 8, 7, 0.55, seed=61)
    g = grout_mask(u, v, 0.012)
    # glyphs
    glyph = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(glyph)
    gr = np.random.default_rng(62)
    for row in range(16):
        for col in range(12):
            if gr.random() < 0.45:
                continue
            cx = int((col + 0.5) / 12 * N)
            cy = int((row + 0.5) / 16 * N)
            s = int(N / 40)
            kind = gr.integers(0, 7)
            w = 3
            if kind == 0:
                d.ellipse([cx - s, cy - s, cx + s, cy + s], outline=255, width=w)
                d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=255)  # sun / eye
            elif kind == 1:
                d.line([cx - s, cy + s, cx, cy - s, cx + s, cy + s], fill=255, width=w)  # pyramid
            elif kind == 2:
                d.line([cx, cy - s, cx, cy + s], fill=255, width=w)
                d.ellipse([cx - s // 2, cy - s, cx + s // 2, cy - s // 3], outline=255, width=w)  # ankh
                d.line([cx - s // 2, cy - s // 4, cx + s // 2, cy - s // 4], fill=255, width=w)
            elif kind == 3:
                for k in range(3):
                    d.line([cx - s, cy - s + k * s, cx + s, cy - s + k * s], fill=255, width=w)  # water
            elif kind == 4:
                d.arc([cx - s, cy - s, cx + s, cy + s], 200, 340, fill=255, width=w)
                d.line([cx - s, cy, cx + s, cy], fill=255, width=w)  # duck/bird-ish
                d.ellipse([cx + s // 2, cy - s, cx + s, cy - s // 2], outline=255, width=w)
            elif kind == 5:
                d.rectangle([cx - s // 2, cy - s, cx + s // 2, cy + s], outline=255, width=w)
            else:
                d.polygon([cx - s, cy, cx, cy - s, cx + s, cy, cx, cy + s], outline=255)
    glyph = glyph.filter(ImageFilter.GaussianBlur(1.2))
    gl = np.array(glyph) / 255.0
    albedo = colorize(n * 0.7 + rnd * 0.3, (0.55, 0.42, 0.26), (0.80, 0.68, 0.46))
    albedo *= (1 - gl * 0.35)[..., None]
    albedo *= (0.5 + 0.5 * g[..., None])
    height = g * 0.6 + n * 0.25 - gl * 0.35
    rough = 0.85 + n * 0.1
    save_set("sandstone", albedo, height, rough, 5.0)


def stone_tiles():
    x, y = coords()
    u, v, ix, iy = tile_grid(x, y, 4, 4)
    rnd = per_tile_random(ix, iy, 70)
    n = fbm(N, 8, 7, 0.55, seed=71)
    g = grout_mask(u, v, 0.02)
    tilt = (u - 0.5) * (rnd - 0.5) * 0.3
    albedo = colorize(n * 0.6 + rnd * 0.4, (0.14, 0.15, 0.15), (0.32, 0.33, 0.31))
    albedo *= (0.4 + 0.6 * g[..., None])
    height = g * 0.5 + n * 0.25 + tilt
    rough = 0.6 + n * 0.3 + (1 - g) * 0.1
    save_set("stone_tiles", albedo, height, rough, 5.0)


def ceiling():
    x, y = coords()
    u, v, ix, iy = tile_grid(x, y, 2, 2)
    n = fbm(N, 6, 6, 0.5, seed=80)
    g = grout_mask(u, v, 0.03)
    albedo = colorize(n, (0.42, 0.40, 0.37), (0.55, 0.53, 0.5)) * (0.55 + 0.45 * g[..., None])
    height = g * 0.5 + n * 0.1
    save_set("ceiling", albedo, height, 0.9 - n * 0.1, 3.0)


def metal():
    x, y = coords()
    brushed = stretched_fbm(N, 128, 2, 4, seed=90)
    scratches = np.zeros((N, N))
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    r = np.random.default_rng(91)
    for _ in range(400):
        x0, y0 = r.random() * N, r.random() * N
        ang = r.random() * math.pi
        ln = r.random() * 60 + 10
        d.line([x0, y0, x0 + math.cos(ang) * ln, y0 + math.sin(ang) * ln], fill=int(r.random() * 120 + 60), width=1)
    scratches = np.array(img) / 255.0
    rust = np.clip((fbm(N, 6, 6, 0.6, seed=92) - 0.62) * 4, 0, 1)
    base = colorize(brushed, (0.50, 0.51, 0.53), (0.70, 0.71, 0.73))
    albedo = base * (1 - rust[..., None]) + np.array([0.28, 0.13, 0.06]) * rust[..., None]
    albedo += scratches[..., None] * 0.15
    height = brushed * 0.1 - scratches * 0.2 + rust * 0.2
    rough = 0.3 + brushed * 0.1 + rust * 0.55 - scratches * 0.1
    save_set("metal", albedo, height, rough, 2.0)
    save_gray("metal_metallic.jpg", 1.0 - rust * 0.9)


def gold():
    x, y = coords()
    hammer = fbm(N, 32, 3, 0.5, seed=100)
    tarnish = np.clip((fbm(N, 5, 6, 0.6, seed=101) - 0.5) * 2, 0, 1)
    albedo = colorize(hammer, (0.75, 0.55, 0.18), (1.0, 0.78, 0.34)) * (1 - tarnish[..., None] * 0.45)
    save_set("gold", albedo, hammer * 0.5, 0.25 + tarnish * 0.35 + hammer * 0.1, 3.0)


def velvet():
    x, y = coords()
    n = fbm(N, 8, 6, 0.6, seed=110)
    fibers = vnoise(N, 512, 111)
    albedo = colorize(n * 0.7 + fibers * 0.3, (0.25, 0.02, 0.03), (0.55, 0.06, 0.07))
    save_set("velvet", albedo, fibers * 0.3, 0.9 + fibers * 0.1, 1.5)


def linen():
    """Mummy bandages: woven linen with grime."""
    x, y = coords()
    weave = (np.sin(x * N * 0.9) * np.sin(y * N * 0.9)) * 0.5 + 0.5
    n = fbm(N, 6, 6, 0.6, seed=120)
    grime = np.clip((fbm(N, 4, 6, 0.6, seed=121) - 0.4) * 2, 0, 1)
    stripes = (np.sin(y * 24 * math.pi + n * 4) * 0.5 + 0.5) ** 8
    albedo = colorize(n * 0.5 + weave * 0.2, (0.52, 0.46, 0.34), (0.78, 0.72, 0.58))
    albedo *= (1 - grime * 0.5 - stripes * 0.25)[..., None]
    save_set("linen", albedo, weave * 0.3 + stripes * 0.4, 0.95, 3.0)


def bone():
    x, y = coords()
    n = fbm(N, 6, 7, 0.55, seed=130)
    pores = (vnoise(N, 200, 131) > 0.9).astype(float)
    cracks = np.clip(1 - np.abs(fbm(N, 4, 6, 0.6, seed=132) - 0.5) / 0.012, 0, 1)
    albedo = colorize(n, (0.48, 0.40, 0.28), (0.82, 0.76, 0.60)) * (1 - pores * 0.3 - cracks * 0.5)[..., None]
    save_set("bone", albedo, n * 0.3 - pores * 0.2 - cracks * 0.4, 0.7 + n * 0.2, 3.0)


def wax():
    x, y = coords()
    n = fbm(N, 4, 6, 0.5, seed=140)
    albedo = colorize(n, (0.72, 0.55, 0.45), (0.86, 0.70, 0.60))
    save_set("wax", albedo, n * 0.1, 0.35 + n * 0.1, 1.0)


def porcelain():
    x, y = coords()
    n = fbm(N, 4, 5, 0.5, seed=150)
    craq = np.clip(1 - np.abs(fbm(N, 12, 4, 0.6, seed=151) - 0.5) / 0.01, 0, 1)
    albedo = colorize(n, (0.82, 0.80, 0.76), (0.95, 0.94, 0.91)) * (1 - craq * 0.25)[..., None]
    save_set("porcelain", albedo, -craq * 0.3, 0.12 + craq * 0.3, 2.0)


def uniform_fabric():
    x, y = coords()
    twill = (np.sin((x + y) * N * 0.6) * 0.5 + 0.5)
    n = fbm(N, 8, 5, 0.5, seed=160)
    albedo = colorize(n * 0.6 + twill * 0.2, (0.06, 0.08, 0.14), (0.14, 0.17, 0.26))
    save_set("uniform", albedo, twill * 0.2, 0.9, 1.5)


def crate_wood():
    x, y = coords()
    gy = y * 6
    iy = np.floor(gy)
    v = gy - iy
    rnd = per_tile_random(np.zeros_like(iy), iy, 170)
    grain = stretched_fbm(N, 3, 40, 5, seed=171)
    albedo = colorize(grain * 0.6 + rnd * 0.4, (0.35, 0.24, 0.13), (0.62, 0.47, 0.29))
    gap = np.clip(np.minimum(v, 1 - v) / 0.05, 0, 1)
    albedo *= (0.3 + 0.7 * gap[..., None])
    save_set("crate", albedo, gap * 0.6 + grain * 0.1, 0.85, 4.0)


# ------------------------------------------------------------ extras ------

def flashlight_cookie():
    """Light projector texture: hot center, soft ring, subtle lens imperfections."""
    S = 256
    y, x = np.mgrid[0:S, 0:S] / (S - 1) * 2 - 1
    r = np.sqrt(x * x + y * y)
    center = np.exp(-r * r * 6)
    ring = np.exp(-((r - 0.62) ** 2) * 120) * 0.35
    falloff = np.clip(1 - r, 0, 1) ** 0.6
    n = fbm(S, 8, 4, 0.5, seed=180)
    img = np.clip((center * 0.8 + ring + falloff * 0.35) * (0.85 + 0.3 * n), 0, 1)
    img[r > 1] = 0
    Image.fromarray((img * 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(OUT, "flashlight_cookie.png"))


def oil_canvas(seed, kind, w=512, h=640):
    """A procedural 'old master' style painting with craquelure and yellowed varnish."""
    r = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w]
    xn, yn = x / w, y / h
    n = fbm(max(w, h), 4, 6, 0.55, seed=seed)[:h, :w]
    if kind == "portrait":
        # Chiaroscuro: dark background with a soft light pool behind the sitter.
        glow = np.exp(-(((xn - 0.38) / 0.45) ** 2 + ((yn - 0.35) / 0.5) ** 2))
        img = colorize(n * 0.4 + glow * 0.6, (0.015, 0.012, 0.01), (0.20, 0.15, 0.09))
        L = np.array([-0.55, -0.45, 0.70])
        L = L / np.linalg.norm(L)

        def sphere_shade(cx, cy, rx, ry):
            ex, ey = (xn - cx) / rx, (yn - cy) / ry
            inside = ex ** 2 + ey ** 2 < 1
            nz = np.sqrt(np.clip(1 - ex ** 2 - ey ** 2, 0, 1))
            d = np.clip(ex * L[0] + ey * L[1] + nz * L[2], 0, 1)
            return inside, 0.18 + 0.95 * d ** 1.3

        dress_c = np.array([r.random() * 0.25 + 0.08, r.random() * 0.12 + 0.04, r.random() * 0.22 + 0.08])
        body, bshade = sphere_shade(0.5, 1.08, 0.46, 0.42)
        img[body] = dress_c * bshade[body, None] * (0.7 + 0.5 * n[body, None])
        if r.random() < 0.6:  # white ruff collar, very old-master
            ruff, rshade = sphere_shade(0.5, 0.66, 0.2, 0.06)
            img[ruff] = np.array([0.85, 0.82, 0.74]) * rshade[ruff, None]
        skin = np.array([0.80, 0.62, 0.50])
        neck, nshade = sphere_shade(0.5, 0.6, 0.075, 0.14)
        img[neck] = skin * nshade[neck, None] * 0.75
        hair_c = np.array([0.10, 0.06, 0.035]) * (0.5 + r.random())
        hair, hshade = sphere_shade(0.5, 0.33, 0.2, 0.25)
        img[hair] = hair_c * hshade[hair, None] * (0.6 + 0.8 * n[hair, None])
        face, fshade = sphere_shade(0.5, 0.39, 0.155, 0.215)
        img[face] = skin[None, :] * fshade[face, None] * (0.92 + 0.16 * n[face, None])
        fx, fy = (xn - 0.5) / 0.155, (yn - 0.39) / 0.215
        for ex in (-0.38, 0.38):
            socket = ((fx - ex) / 0.3) ** 2 + ((fy + 0.12) / 0.16) ** 2 < 1
            img[socket] *= 0.78
            eye = ((fx - ex) / 0.17) ** 2 + ((fy + 0.12) / 0.065) ** 2 < 1
            img[eye] = [0.75, 0.72, 0.66]
            pupil = ((fx - ex - 0.02) / 0.07) ** 2 + ((fy + 0.12) / 0.065) ** 2 < 1
            img[pupil] = [0.06, 0.04, 0.03]
            brow = ((fx - ex) / 0.25) ** 2 + ((fy + 0.3) / 0.04) ** 2 < 1
            img[brow] = img[brow] * 0.45
        nose = ((fx + 0.08) / 0.07) ** 2 + ((fy - 0.18) / 0.22) ** 2 < 1
        img[nose] *= 0.85
        lip = (fx / 0.28) ** 2 + ((fy - 0.5) / 0.045) ** 2 < 1
        img[lip] = img[lip] * np.array([0.85, 0.55, 0.5])
        cheek = ((np.abs(fx) - 0.45) / 0.2) ** 2 + ((fy - 0.2) / 0.15) ** 2 < 1
        img[cheek & face] *= np.array([1.05, 0.93, 0.9])
        img = np.array(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2.2))) / 255.0
    elif kind == "landscape":
        sky = colorize(yn, (0.25, 0.30, 0.38), (0.75, 0.62, 0.42))
        img = sky * (0.85 + 0.2 * n[..., None])
        hills = 0.55 + fbm(w, 3, 5, 0.5, seed=seed + 1)[0, :w] * 0.25
        land = yn > hills[None, :]
        img[land] = (np.array([0.12, 0.16, 0.08]) * (0.6 + 0.8 * n[land, None]))
        moon = ((xn - 0.75) ** 2 + (yn - 0.2) ** 2) < 0.004
        img[moon] = [0.95, 0.92, 0.8]
        hills2 = 0.68 + fbm(w, 5, 5, 0.5, seed=seed + 2)[0, :w] * 0.2
        land2 = yn > hills2[None, :]
        img[land2] = np.array([0.05, 0.07, 0.04]) * (0.6 + 0.8 * n[land2, None])
        mist = np.exp(-((yn - hills[None, :]) / 0.04) ** 2) * 0.25
        img = img + mist[..., None] * np.array([0.7, 0.7, 0.65])
        img = np.array(Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))) / 255.0
    elif kind == "still_life":
        img = colorize(n, (0.05, 0.04, 0.03), (0.16, 0.12, 0.08))
        table = yn > 0.68
        img[table] = np.array([0.30, 0.18, 0.09]) * (0.6 + 0.6 * n[table, None])
        for (cx, cy, rad, col) in [(0.42, 0.58, 0.12, (0.55, 0.65, 0.15)), (0.62, 0.62, 0.09, (0.7, 0.2, 0.1)),
                                   (0.3, 0.64, 0.07, (0.6, 0.5, 0.1))]:
            dist = ((xn - cx) ** 2 + (yn - cy) ** 2) / rad ** 2
            m = dist < 1
            lit = np.clip(1.2 - (xn - cx + 0.5 * rad) / rad * 0.6, 0.3, 1.2)
            img[m] = np.array(col) * lit[m, None]
        # the angry pear's eyebrows
        img[(np.abs(yn - 0.52) < 0.008) & (np.abs(xn - 0.39) < 0.03)] = [0.05, 0.05, 0.02]
        img[(np.abs(yn - 0.52) < 0.008) & (np.abs(xn - 0.46) < 0.03)] = [0.05, 0.05, 0.02]
    else:  # night
        img = colorize(n, (0.01, 0.01, 0.015), (0.04, 0.04, 0.06))
    # brush strokes
    strokes = stretched_fbm(max(w, h), 64, 8, 3, seed=seed + 9)[:h, :w]
    img = img * (0.88 + 0.24 * strokes[..., None])
    # craquelure + varnish
    craq = np.clip(1 - np.abs(fbm(max(w, h), 16, 4, 0.6, seed=seed + 7)[:h, :w] - 0.5) / 0.008, 0, 1)
    img = img * (1 - craq[..., None] * 0.35)
    img = img * np.array([1.0, 0.92, 0.72])  # yellowed varnish
    vign = 1 - ((xn - 0.5) ** 2 + (yn - 0.5) ** 2) * 0.9
    img = img * vign[..., None]
    return np.clip(img, 0, 1)


def paintings():
    specs = [("painting_man", "portrait", 201), ("painting_duchess", "portrait", 202),
             ("painting_pear", "still_life", 203), ("painting_landscape", "landscape", 204),
             ("painting_night", "night", 205), ("painting_founder", "portrait", 206),
             ("painting_lady", "portrait", 207), ("painting_hills", "landscape", 208)]
    for name, kind, seed in specs:
        img = oil_canvas(seed, kind)
        Image.fromarray((img * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, name + ".jpg"), quality=90)
        print("painting", name)


def night_sky():
    """Equirectangular night sky: gradient, stars, clouds and a moon toward +X (where the moonlight comes from)."""
    W, Hh = 2048, 1024
    v = (np.arange(Hh) / (Hh - 1))[:, None] * np.ones((1, W))
    u = (np.arange(W) / (W - 1))[None, :] * np.ones((Hh, 1))
    elev = (0.5 - v) * math.pi  # +pi/2 top
    az = (u - 0.5) * 2 * math.pi
    sky = colorize(np.clip(1 - np.abs(elev) / (math.pi / 2), 0, 1) ** 3, (0.004, 0.006, 0.014), (0.05, 0.065, 0.10))
    r = np.random.default_rng(300)
    stars = r.random((Hh, W))
    mask = (stars > 0.9992) & (elev > 0.05)
    bright = r.random((Hh, W)) ** 3
    sky[mask] += (bright[mask] * 0.9 + 0.1)[:, None] * np.array([0.9, 0.92, 1.0])
    big = fbm(1024, 4, 6, 0.55, seed=301)
    clouds = np.clip((np.tile(big, (1, 2))[:Hh, :W] - 0.5) * 2.2, 0, 1) * np.clip(elev * 3, 0, 1)
    # moon direction (x=1, y=0.75, z=-0.35): Godot panorama u=0.5 looks toward -Z, u increases toward +X... use az = atan2(x, -z)
    m_az = math.atan2(1.0, 0.35)
    m_el = math.asin(0.75 / math.sqrt(1 + 0.75 ** 2 + 0.35 ** 2))
    d = np.arccos(np.clip(np.sin(elev) * math.sin(m_el) + np.cos(elev) * math.cos(m_el) * np.cos(az - m_az), -1, 1))
    glow = np.exp(-d * 9) * 0.35 + np.exp(-d * 30) * 0.5
    disc = (d < 0.035).astype(float)
    sky += glow[..., None] * np.array([0.55, 0.62, 0.8])
    sky = sky * (1 - clouds[..., None] * 0.85) + clouds[..., None] * (np.array([0.03, 0.035, 0.05]) + glow[..., None] * 0.5)
    sky = sky * (1 - disc[..., None]) + disc[..., None] * np.array([0.95, 0.95, 0.88])
    Image.fromarray((np.clip(sky, 0, 1) * 255).astype(np.uint8), "RGB").save(os.path.join(OUT, "night_sky.jpg"), quality=92)
    print("sky")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for fn in [marble_floor, wood_floor, dark_wood, plaster, wallpaper, concrete, sandstone_blocks, stone_tiles,
               ceiling, metal, gold, velvet, linen, bone, wax, porcelain, uniform_fabric, crate_wood]:
        fn()
    flashlight_cookie()
    paintings()
    night_sky()

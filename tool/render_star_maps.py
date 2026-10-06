"""Star maps for the alignment stars, drawn from the Hipparcos catalogue.

Each map is a gnomonic projection centred on the star, north up and east to
the left (as seen in the sky), with every star to magnitude 9 drawn with a
size from its brightness and a colour from its B-V index. The maps are our
own drawing of public catalogue data, so they carry no image licence.

Run from the repository root (needs numpy and Pillow):

    python3 tool/render_star_maps.py assets/catalog_images [star_id ...]

The catalogue (~4 MB) is downloaded from VizieR to tool/hip.tsv on first use.
"""
import json, math, os, re, sys, urllib.request
import numpy as np
from PIL import Image

W, H, SS = 800, 600, 2          # output size and supersampling
FOV = 18.0                      # degrees across the width
OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

def slug(s):
    s = re.sub(r'[^a-z0-9]+', '_', s.lower())
    return re.sub(r'^_+|_+$', '', s)

HIP = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'hip.tsv')
if not os.path.exists(HIP):
    urllib.request.urlretrieve(
        'https://vizier.cds.unistra.fr/viz-bin/asu-tsv?-source=I/239/hip_main'
        '&-out=HIP,_RAJ2000,_DEJ2000,Vmag,B-V&Vmag=%3C9.0&-out.max=200000', HIP)

rows = []
for line in open(HIP):
    p = line.rstrip('\n').split('\t')
    if len(p) < 5: continue
    try:
        ra, dec, v = float(p[1]), float(p[2]), float(p[3])
    except ValueError:
        continue
    try: bv = float(p[4])
    except ValueError: bv = 0.6
    rows.append((ra, dec, v, bv))
cat = np.array(rows)
RA, DEC, V, BV = (cat[:, i] for i in range(4))

def colour(bv):
    """B-V to RGB via an approximate black-body temperature."""
    bv = np.clip(bv, -0.35, 1.9)
    t = 4600 * (1 / (0.92 * bv + 1.7) + 1 / (0.92 * bv + 0.62))
    t = t / 100.0
    r = np.where(t <= 66, 255.0, 329.7 * np.power(np.maximum(t - 60, 1e-6), -0.1332))
    g = np.where(t <= 66, 99.47 * np.log(t) - 161.12, 288.12 * np.power(np.maximum(t - 60, 1e-6), -0.0755))
    b = np.where(t >= 66, 255.0, np.where(t <= 19, 0.0, 138.52 * np.log(np.maximum(t - 10, 1e-6)) - 305.04))
    rgb = np.clip(np.stack([r, g, b], -1), 0, 255) / 255.0
    # Saturate a little so red giants and blue stars read as such.
    mean = rgb.mean(-1, keepdims=True)
    return np.clip(mean + (rgb - mean) * 1.6, 0, 1)

def render(ra0, dec0):
    w, h = W * SS, H * SS
    scale = w / math.radians(FOV)            # pixels per radian at the centre
    a0, d0 = math.radians(ra0), math.radians(dec0)
    a, d = np.radians(RA), np.radians(DEC)
    cosc = math.sin(d0) * np.sin(d) + math.cos(d0) * np.cos(d) * np.cos(a - a0)
    ok = cosc > 0.5
    xi = np.cos(d) * np.sin(a - a0) / cosc
    eta = (math.cos(d0) * np.sin(d) - math.sin(d0) * np.cos(d) * np.cos(a - a0)) / cosc
    x = w / 2 - xi * scale                   # east to the left
    y = h / 2 - eta * scale                  # north up
    ok &= (x > -60) & (x < w + 60) & (y > -60) & (y < h + 60)

    img = np.zeros((h, w, 3))
    yy, xx = np.mgrid[0:h, 0:w]
    # Sky: deep blue, slightly lighter in the middle.
    r2 = ((xx - w / 2) / w) ** 2 + ((yy - h / 2) / h) ** 2
    sky = np.exp(-r2 * 3.0)[..., None]
    img += np.array([0.012, 0.018, 0.040]) + sky * np.array([0.018, 0.028, 0.060])

    cols = colour(BV)
    order = np.argsort(-V)                   # faint first
    for i in order:
        if not ok[i]: continue
        flux = 10 ** (-0.4 * (V[i] - 6.0))   # 1 at magnitude 6
        sigma = SS * (0.75 + 0.55 * flux ** 0.30)
        amp = min(2.2, 0.55 * flux ** 0.45 + 0.25)
        rad = int(sigma * 5) + 2
        x0, y0 = x[i], y[i]
        xa, xb = max(0, int(x0) - rad), min(w, int(x0) + rad + 1)
        ya, yb = max(0, int(y0) - rad), min(h, int(y0) + rad + 1)
        if xa >= xb or ya >= yb: continue
        dx = xx[ya:yb, xa:xb] - x0; dy = yy[ya:yb, xa:xb] - y0
        rr = dx * dx + dy * dy
        core = amp * np.exp(-rr / (2 * sigma * sigma))
        img[ya:yb, xa:xb] += core[..., None] * (0.35 + 0.65 * cols[i])
        if V[i] < 3.2:                       # soft halo for the bright ones
            hs = sigma * 3.2
            hr = int(hs * 4)
            xa, xb = max(0, int(x0) - hr), min(w, int(x0) + hr + 1)
            ya, yb = max(0, int(y0) - hr), min(h, int(y0) + hr + 1)
            dx = xx[ya:yb, xa:xb] - x0; dy = yy[ya:yb, xa:xb] - y0
            halo = 0.16 * amp * np.exp(-(dx * dx + dy * dy) / (2 * hs * hs))
            img[ya:yb, xa:xb] += halo[..., None] * cols[i]

    # The target star: the brightest one within 0.2 degrees of the centre.
    near = np.where(ok & (np.hypot(x - w / 2, y - h / 2) < 0.2 * scale * math.pi / 180))[0]
    if len(near):
        t = near[np.argmin(V[near])]
        c = cols[t]
        dx = xx - w / 2; dy = yy - h / 2
        rr = dx * dx + dy * dy
        glow = 0.55 * np.exp(-rr / (2 * (26 * SS) ** 2)) + 1.6 * np.exp(-rr / (2 * (7 * SS) ** 2))
        img += glow[..., None] * (0.25 + 0.75 * c)
        length, width = 95 * SS, 1.1 * SS
        for u, v in ((dx, dy), (dy, dx)):
            spike = 0.9 * np.exp(-np.abs(u) / (length / 3)) * np.exp(-(v * v) / (2 * width * width))
            img += spike[..., None] * (0.5 + 0.5 * c)

    img = 1 - np.exp(-img * 1.35)            # soft tone mapping
    img = np.clip(img, 0, 1) ** (1 / 1.15)
    out = Image.fromarray((img * 255).astype(np.uint8)).resize((W, H), Image.LANCZOS)
    return out

d = json.load(open('assets/celestial_catalog.json'))
only = set(sys.argv[2:])
for o in d['calibration_targets']:
    oid = 'star_' + slug(o['name'])
    if only and oid not in only: continue
    im = render(o['right_ascension_hours'] * 15, o['declination_degrees'])
    im.save(f'{OUT}/{oid}.jpg', quality=86, optimize=True, progressive=True)
    print('ok', oid)

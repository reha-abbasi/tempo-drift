"""Download CC0 assets from Poly Haven's public API into assets/polyhaven/ (the textures the
streets and buildings use).
Usage: python3 fetch_polyhaven.py  (re-running skips files that already exist)"""
import json, os, sys, urllib.request

ROOT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'polyhaven')
API = 'https://api.polyhaven.com/files/'
# Poly Haven asks API clients to identify themselves
UA = {'User-Agent': 'TempoDrift-asset-fetch/1.0 (personal game project; github.com/reha-abbasi/tempo-drift)'}

MODELS = []
TEXTURES = ['cobblestone_floor_04', 'asphalt_02', 'brick_wall_07', 'red_brick_plaster_patch_02', 'white_sandstone_bricks',
            'grey_roof_tiles', 'roof_slates_02', 'concrete_pavement', 'painted_plaster_wall', 'concrete_tile_facade',
            'rectangular_facade_tiles_02', 'metal_plate', 'pavement_02', 'large_sandstone_blocks', 'worn_asphalt',
            'granite_tile', 'clay_roof_tiles']
HDRIS = []
MAPS = {'Diffuse': 'albedo', 'nor_gl': 'normal', 'arm': 'arm'}

def get(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r, open(dest + '.part', 'wb') as f:
        f.write(r.read())
    os.replace(dest + '.part', dest)

def files(asset):
    with urllib.request.urlopen(urllib.request.Request(API + asset, headers=UA)) as r:
        return json.load(r)

for a in MODELS:
    g = files(a)['gltf']['1k']['gltf']
    d = os.path.join(ROOT, 'models', a)
    get(g['url'], os.path.join(d, os.path.basename(g['url'])))
    for rel, inc in g.get('include', {}).items():
        get(inc['url'], os.path.join(d, rel))
    print('model', a, flush=True)
for a in TEXTURES:
    f = files(a)
    for key, short in MAPS.items():
        if key in f:
            get(f[key]['1k']['jpg']['url'], os.path.join(ROOT, 'textures', a, f'{a}_{short}.jpg'))
    print('texture', a, flush=True)
for a in HDRIS:
    get(files(a)['hdri']['2k']['hdr']['url'], os.path.join(ROOT, 'hdri', a + '_2k.hdr'))
    print('hdri', a, flush=True)
with open(os.path.join(ROOT, 'LICENSE.txt'), 'w') as f:
    f.write('All files in this folder are from Poly Haven (https://polyhaven.com) and are CC0 (public domain).\n')

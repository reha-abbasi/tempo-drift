#!/usr/bin/env python3
"""Exports the world map from the web game (coastlines and city positions) for the Godot map screen.
usage: python3 godot/tools/export_map.py"""
import json, os, re
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
s = open(os.path.join(ROOT, 'web/game.html')).read()
i = s.find('LAND_RINGS=`') + len('LAND_RINGS=`')
raw = s[i:s.find('`', i)]
rings = []
for r in raw.split('|'):
    P = [[float(v) / 4 for v in p.split(',')] for p in r.split(' ') if p]
    # keep each coastline continuous across the date line (a ring that wraps the globe keeps its own longitudes)
    U = [list(q) for q in P]
    for k in range(1, len(U)):
        while U[k][0] - U[k - 1][0] > 180: U[k][0] -= 360
        while U[k][0] - U[k - 1][0] < -180: U[k][0] += 360
    rings.append(P if abs(U[-1][0] - U[0][0]) > 180 else U)
g = s[s.find('const GEO={') + len('const GEO='):]
g = g[:g.find('};') + 1]
geo = {m.group(1): [float(m.group(2)), float(m.group(3))] for m in re.finditer(r"'([^']+)':\[(-?[\d.]+),(-?[\d.]+)\]", g)}
out = os.path.join(ROOT, 'godot/game/data/world.json')
json.dump({'rings': rings, 'cities': geo}, open(out, 'w'), separators=(',', ':'))
print(len(rings), 'coastlines,', len(geo), 'cities ->', out)

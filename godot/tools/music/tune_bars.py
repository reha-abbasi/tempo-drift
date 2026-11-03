"""write a carnival tune as the web game's bar melodies (same rings and ghosts as carnival.course):
tune_bars.py NAME OUT.json   (reads courses/sunset_1.json)"""
import json, sys
import carnival
name, out = sys.argv[1:3]
c = json.load(open('courses/sunset_1.json'))
cc, dem = carnival.course(c, name)
bar, e8 = cc['bar'], cc['bar'] / 8
bars = {}
for g, lst in ((0, cc['notes']), (1, cc['ghosts'])):
    for n in lst:
        b = int(n['t'] // bar + 1e-6)
        on = round((n['t'] - b * bar) / e8, 3)
        bars.setdefault(b, []).append([on, n['note'], n['len']] + ([None, 1] if g else []))
for v in bars.values():
    v.sort(key=lambda m: m[0])
json.dump(bars, open(out, 'w'))
print(len(bars), 'bars', len(cc['notes']), 'rings', len(cc['ghosts']), 'ghosts', dem, 'demoted')

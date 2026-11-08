"""Option A: the Astronaut, sculpted. A real EVA suit: soft fabric limbs with bellows at the joints, a hard upper torso, a
big helmet with a gold mirror visor, a life-support pack that is also the jetpack."""
import sys

from parts import *
from sdf import *

r = Rig(arm_out=40.0, leg_out=8.0, shoulder_x=0.27, leg_x=0.1)
S, E, W, L, K, A = r.S, r.E, r.W, r.L, r.K, r.A
da, dl = r.arm_dir, r.leg_dir

WHITE = (0.72, 0.71, 0.67)
SHELL = (0.78, 0.77, 0.74)
ORANGE = (0.95, 0.27, 0.05)
DARK = (0.03, 0.035, 0.05)
GREY = (0.32, 0.34, 0.38)
GOLD = (1.0, 0.72, 0.26)
TEAL = (0.08, 0.85, 0.75)

# ---- the soft suit
arm = U(cone(S, E, 0.08, 0.066), cone(E, W, 0.066, 0.054), k=0.02)
arm = disp(arm, ribs(E, da, 0.062, 0.03, 0.01))
arm = disp(arm, ribs(S + da * 0.075, da, 0.05, 0.028, 0.009))
leg = U(cone(L, K, 0.1, 0.08), cone(K, A, 0.08, 0.064), k=0.02)
leg = disp(leg, ribs(K, dl, 0.075, 0.034, 0.012))
leg = disp(leg, ribs(L + dl * 0.05, dl, 0.05, 0.03, 0.008))
core = U(cone((0, 0.8, 0), (0, 0.6, 0), 0.155, 0.15), ell((0, 0.5, 0.0), (0.175, 0.125, 0.14)), k=0.06)
core = disp(core, ribs((0, 0.66, 0), (0, 1, 0), 0.075, 0.032, 0.009))
suit_f = U(core, mx(arm), mx(leg), k=0.018)
# seams on the legs
suit_f = disp(suit_f, mx(groove(plane(L + dl * 0.17, dl), 0.0035, 0.004)))

# ---- the hard upper torso
hut = ell((0, 0.845, -0.002), (0.195, 0.17, 0.158))
hut = U(hut, mx(sphere(S + V(-0.02, 0.0, 0), 0.094)), k=0.06)
hut = I(hut, plane((0, 0.725, 0), (0, -1, 0)), k=0.012)
hut = D(hut, mx(cyl(S - da * 0.03, S + da * 0.2, 0.085, 0.012)), k=0.01)
hut = disp(hut, groove(plane((0, 0.87, 0), (0, 1, 0.5)), 0.0034, 0.0045))
hut = disp(hut, mx(groove(plane((0.095, 0.8, 0), (1, 0, 0.1)), 0.0034, 0.0045)))
hut = disp(hut, groove(plane((0, 0.76, 0), (0, 1, 0)), 0.003, 0.003))

# ---- rings, bands
rings = U(tor((0, 0.975, 0), (0, 1, 0), 0.118, 0.018), tor((0, 0.728, 0), (0, 1, 0), 0.157, 0.012),
	mx(tor(S + da * 0.1, da, 0.082, 0.0095)), mx(tor(W - da * 0.01, da, 0.066, 0.011)), mx(tor(A + dl * 0.0 - dl * 0.06, dl, 0.074, 0.01)))
band_arm = I(off(arm, 0.008), band(plane(S + da * 0.15, da), 0.026), k=0.004)
band_thigh = I(off(leg, 0.008), band(plane(L + dl * 0.17 + V(0, -0.04, 0), dl), 0.03), k=0.004)
bands = mx(U(band_arm, band_thigh))

# ---- the chest control unit
tilt = rot_x(0.42)
dcu = box((0, 0.8, -0.168), (0.09, 0.056, 0.026), r=0.012, rot=tilt)
dials = []
btn = []
for i, x in enumerate((-0.058, -0.02, 0.02, 0.058)):
	p = np.array((x, 0.8 + 0.018, -0.168)) + tilt @ V(0, 0, -0.028)
	(dials if i % 2 == 0 else btn).append(cyl(p + tilt @ V(0, 0, 0.01), p + tilt @ V(0, 0, -0.01), 0.011, 0.0028))
for x in np.linspace(-0.05, 0.05, 6):
	p = np.array((x, 0.8 - 0.02, -0.168)) + tilt @ V(0, 0, -0.028)
	dials.append(cyl(p + tilt @ V(0, 0, 0.01), p + tilt @ V(0, 0, -0.008), 0.005, 0.0016))

# ---- the helmet (rigid on the head)
c = V(0, 1.1, 0)
dome = ell(c, (0.168, 0.178, 0.178))
neck = cyl((0, 0.98, 0), (0, 1.03, 0), 0.118, 0.008)
helm = U(dome, neck, k=0.02)
window = ell(c + V(0, -0.012, -0.12), (0.136, 0.104, 0.13))
shell = D(helm, window, k=0.012)
visor = I(ell(c, (0.163, 0.173, 0.173)), off(window, 0.012))
rim = I(off(helm, 0.006), skin(window, 0.0075), k=0.003)
# the crest over the visor, ear pods, a head lamp
crest = I(off(dome, 0.012), I(band(plane(c, (1, 0, 0)), 0.02), plane(c + V(0, 0.1, -0.02), (0, -0.5, -1)), k=0.006), k=0.006)
ears = mx(U(cyl((0.158, 1.09, 0.03), (0.186, 1.09, 0.03), 0.046, 0.009), cyl((0.178, 1.09, 0.03), (0.195, 1.09, 0.03), 0.024, 0.006), k=0.003))
lamp_body = mx(I(off(dome, 0.012), ell((0.098, 1.215, -0.098), (0.03, 0.02, 0.03)), k=0.004))
lamp = mx(I(off(dome, 0.0145), ell((0.098, 1.215, -0.1), (0.021, 0.012, 0.03))))

# ---- the pack (rigid on the torso)
JP = V(0, 0.76, 0.17)
pk = box((0, 0.83, 0.262), (0.158, 0.21, 0.094), r=0.045)
pk = D(pk, box((0, 0.84, 0.36), (0.1, 0.13, 0.025), r=0.012), k=0.008)
pk = disp(pk, groove(plane((0, 0.73, 0), (0, 1, 0)), 0.0034, 0.0045))
pk = disp(pk, groove(plane((0, 0.95, 0), (0, 1, 0)), 0.0034, 0.0045))
strip = I(off(box((0, 0.83, 0.262), (0.158, 0.21, 0.094), r=0.045), 0.004), band(plane((0, 0.665, 0), (0, 1, 0)), 0.012))
tanks = mx(cap((0.178, 0.72, 0.25), (0.178, 0.96, 0.25), 0.044))
tank_bands = mx(U(*[I(off(cap((0.178, 0.72, 0.25), (0.178, 0.96, 0.25), 0.044), 0.003), band(plane((0, y, 0), (0, 1, 0)), 0.008)) for y in (0.76, 0.92)]))
core_pk = box((0, 0.84, 0.335), (0.094, 0.124, 0.012), r=0.006)
vents = mx(U(*[box((0.05, y, 0.343), (0.03, 0.0065, 0.01), r=0.003) for y in np.linspace(0.76, 0.92, 7)]))
led = box((0, 0.68, 0.357), (0.05, 0.006, 0.004), r=0.002)
bell = mx(U(nozzle((0.085, 0.645, 0.27), (0.085, 0.545, 0.27), 0.05, 0.072), cyl((0.085, 0.66, 0.27), (0.085, 0.62, 0.27), 0.05, 0.006)))
fuel = mx(tor((0.085, 0.6, 0.27), (0, 1, 0), 0.058, 0.0055))

# ---- gloves and boots
HR, HL = hand_frame(r, "R"), hand_frame(r, "L")
g_local = glove(palm=1.08, cuff=(0.07, 0.058))
glove_R = xf(g_local, HR)
glove_L = flip(glove_R)
b_up, b_sole = boot(height=0.15, r=(0.086, 0.078), toe=(0.082, 0.06, 0.12), sole_y=-0.335)
bu_R = xf(b_up, r.M["KneeR"])
bs_R = xf(b_sole, r.M["KneeR"])
bu_L, bs_L = flip(bu_R), flip(bs_R)

BODY = ((-0.72, -0.2, -0.26), (0.72, 1.02, 0.26))
TORSO = ((-0.42, 0.6, -0.26), (0.42, 1.05, 0.24))
HEAD = ((-0.24, 0.94, -0.26), (0.24, 1.32, 0.26))
PACK = ((-0.3, 0.5, 0.12), (0.3, 1.1, 0.42))
def hand_box(f):
	return ((0.4, 0.3, -0.2), (0.9, 0.7, 0.2))

layers = [
	Layer("suit", suit_f, "fabric", *BODY, 10500, color=WHITE, h=0.0035, wear=0.1, hidden_by=("bands",)),
	Layer("hut", hut, "shell", *TORSO, 2600, color=SHELL, wear=0.05, bone="Torso"),
	Layer("rings", rings, "metal", *BODY, 1500, color=GREY, h=0.0035),
	Layer("bands", bands, "accent", *BODY, 1200, color=ORANGE, h=0.0035),
	Layer("dcu", dcu, "dark", (-0.14, 0.72, -0.23), (0.14, 0.9, -0.12), 300, color=GREY, bone="Torso", h=0.0025),
	Layer("dials", U(*dials), "accent", (-0.14, 0.72, -0.23), (0.14, 0.9, -0.12), 300, color=ORANGE, bone="Torso", h=0.002),
	Layer("btn", U(*btn), "glow", (-0.14, 0.72, -0.23), (0.14, 0.9, -0.12), 150, color=TEAL, bone="Torso", h=0.002),
	Layer("helmet", U(shell, ears, lamp_body, k=0.004), "shell", *HEAD, 3200, color=SHELL, bone="Head", h=0.003, wear=0.05),
	Layer("visor", visor, "visor", *HEAD, 900, color=GOLD, bone="Head", h=0.003),
	Layer("rim", U(rim, crest), "metal", *HEAD, 1300, color=GREY, bone="Head", h=0.003),
	Layer("lamp", lamp, "glow", *HEAD, 80, color=(1.0, 0.95, 0.75), bone="Head", h=0.002),
	Layer("pack", U(pk, k=0.01), "shell", *PACK, 1400, color=SHELL, bone="Jetpack", h=0.0035, wear=0.05),
	Layer("packdark", U(tanks, core_pk, k=0.002), "dark", *PACK, 700, color=(0.085, 0.09, 0.11), bone="Jetpack", h=0.0035),
	Layer("packacc", U(strip, tank_bands), "accent", *PACK, 300, color=ORANGE, bone="Jetpack", h=0.003),
	Layer("vents", vents, "metal", *PACK, 300, color=GREY, bone="Jetpack", h=0.0034),
	Layer("packled", led, "glow", *PACK, 40, color=TEAL, bone="Jetpack", h=0.0025),
	Layer("bell", U(bell, fuel), "metal", *PACK, 900, color=(0.2, 0.2, 0.23), bone="Jetpack", h=0.0048),
	Layer("gloveR", glove_R, "rubber", *hand_box(glove_R), 1000, color=WHITE, bone="HandR", h=0.003, wear=0.1),
	Layer("gloveL", glove_L, "rubber", *[tuple(V(*x) * V(-1, 1, 1)) if False else x for x in ((-0.9, 0.3, -0.2), (-0.4, 0.7, 0.2))], 1000, color=WHITE, bone="HandL", h=0.003, wear=0.1),
	Layer("bootR", bu_R, "fabric", (0.02, -0.25, -0.26), (0.34, 0.2, 0.16), 900, color=WHITE, bone="KneeR", h=0.0035, wear=0.1),
	Layer("bootL", bu_L, "fabric", (-0.34, -0.25, -0.26), (-0.02, 0.2, 0.16), 900, color=WHITE, bone="KneeL", h=0.0035, wear=0.1),
	Layer("soleR", bs_R, "rubber", (0.02, -0.25, -0.26), (0.34, 0.02, 0.16), 300, color=(0.1, 0.1, 0.12), bone="KneeR", h=0.003),
	Layer("soleL", bs_L, "rubber", (-0.34, -0.25, -0.26), (-0.02, 0.02, 0.16), 300, color=(0.1, 0.1, 0.12), bone="KneeL", h=0.003),
]

M = dict()
pm = np.eye(4)
pm[:3, 3] = JP
frames = {"Jetpack": pm, "HandR": HR, "HandL": HL}
caps = r.capsules(torso_r=0.16, hip_r=0.15, arm=(0.08, 0.062), leg=(0.105, 0.08))
materials = {
	"fabric": {"rough": 0.86, "rim": 0.35, "rim_tint": 0.25},
	"shell": {"rough": 0.34, "coat": 0.5, "coat_rough": 0.2, "spec": 0.5},
	"metal": {"rough": 0.3, "metal": 0.95},
	"accent": {"rough": 0.5},
	"dark": {"rough": 0.42, "metal": 0.25},
	"visor": {"rough": 0.06, "metal": 1.0},
	"rubber": {"rough": 0.78, "rim": 0.2, "rim_tint": 0.2},
	"glow": {"rough": 0.4, "emit": (0.5, 1.0, 0.9), "energy": 3.0},
}
char = {"rig": r, "layers": layers, "frames": frames, "caps": caps, "materials": materials, "jetpack": list(JP - V(0, 0.5, 0)),
	"flames": [[0.085, 0.545 - 0.76, 0.27 - 0.17], [-0.085, 0.545 - 0.76, 0.27 - 0.17]]}

# (the layers carry their boxes; rigid ones export in their bone's space)
bake(char, sys.argv[1] if len(sys.argv) > 1 else "out/astro")

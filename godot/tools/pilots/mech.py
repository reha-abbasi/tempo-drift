"""The Mech Suit: a heavy, square-cut exosuit in crimson over a dark frame: faceted chest with a slot of light, big shoulder
blocks, gauntlets, a blocky helmet with a T visor, twin rockets on the back and a small thruster on each boot."""
import sys

from bodies import *

r = Rig(arm_out=34.0, leg_out=9.0, shoulder_x=0.31, leg_x=0.125)
S, E, W, L, K, A = r.S, r.E, r.W, r.L, r.K, r.A
da, dl = r.arm_dir, r.leg_dir
RED, GOLD, GUN, DARK, ICE = (0.46, 0.04, 0.055), (0.85, 0.58, 0.16), (0.14, 0.145, 0.165), (0.045, 0.048, 0.058), (0.2, 0.68, 1.0)

def limb(a, b, hw, hd, inset=0.05, rr=0.022):
	a, b = V(a), V(b)
	return box((a + b) * 0.5, (hw, np.linalg.norm(b - a) * 0.5 - inset, hd), r=rr, rot=frame(norm(b - a)))

# the crimson armour
chest = box((0, 0.82, -0.008), (0.222, 0.165, 0.152), r=0.036)
chest = I(chest, mx(plane((0.165, 0.665, 0), (1, -0.42, 0))), k=0.012)
chest = I(chest, mx(plane((0.0, 0.83, -0.172), (0.3, 0.0, -1))), k=0.012)
chest = D(chest, cyl((0, 0.93, 0.0), (0, 1.1, 0.0), 0.094, 0.01), k=0.008)
chest = disp(chest, groove(plane((0, 0.758, 0), (0, 1, 0)), 0.0034, 0.005))
chest = disp(chest, mx(groove(plane((0.12, 0, 0), (1, 0, 0)), 0.0034, 0.005)))
hips = box((0, 0.505, -0.004), (0.165, 0.074, 0.118), r=0.03)
hips = I(hips, mx(plane((0.11, 0.455, 0), (1, -0.55, 0))), k=0.01)
tasset = mx(box((L[0] + 0.1, 0.46, 0.0), (0.026, 0.1, 0.1), r=0.018, rot=rot_z(0.14)))
pauld = mx(U(box(S + V(0.04, 0.046, 0), (0.106, 0.066, 0.118), r=0.03, rot=rot_z(-0.2)), box(S + V(0.086, -0.04, 0), (0.046, 0.06, 0.1), r=0.022, rot=rot_z(-0.2)), k=0.008))
pauld = disp(pauld, mx(groove(plane(S + V(0.04, 0.046, 0), (0, 0, 1)), 0.003, 0.004)))
gaunt = limb(E, W, 0.076, 0.084, inset=0.03)
gaunt = disp(gaunt, groove(plane(E + da * 0.135, da), 0.003, 0.0042))
up_a = limb(S + da * 0.05, E, 0.058, 0.064, inset=0.012)
thigh = limb(L, K, 0.098, 0.108, inset=0.05)
thigh = disp(thigh, groove(plane(L + dl * 0.15, dl), 0.003, 0.0042))
shin = limb(K, A + dl * 0.02, 0.094, 0.112, inset=0.05)
shin = disp(shin, groove(plane(K + dl * 0.16, dl), 0.003, 0.0042))
armor = U(chest, hips, mx(gaunt), mx(thigh), mx(shin), mx(up_a), tasset, pauld)

# gold trim
trim_p = mx(I(off(pauld, 0.0045), band(plane(S + V(0.04, 0.1, 0), (0.2, 1, 0)), 0.012), k=0.003))
trim_g = mx(I(off(gaunt, 0.0045), band(plane(W - da * 0.03, da), 0.012), k=0.003))
trim_s = mx(I(off(shin, 0.0045), band(plane(A - dl * 0.03, dl), 0.012), k=0.003))
kneec = mx(I(off(U(thigh, shin), 0.0), ell(K + V(0, 0, -0.095), (0.062, 0.075, 0.04)), k=0.0)) if False else mx(box(K + V(0, 0, -0.098), (0.056, 0.06, 0.03), r=0.022, rot=frame(dl)))
collar_g = tor((0, 0.965, -0.004), (0, 1, 0), 0.103, 0.0125)
gold = U(trim_p, trim_g, trim_s, kneec, collar_g)

# the dark frame between the plates
waist = cyl((0, 0.57, 0), (0, 0.68, 0), 0.118, 0.006)
waist = disp(waist, ribs((0, 0.625, 0), (0, 1, 0), 0.062, 0.024, 0.01))
frame_b = mx(U(sphere(S, 0.084), sphere(E, 0.066), sphere(L + dl * 0.01, 0.09), sphere(K, 0.082), sphere(W + da * 0.004, 0.052)))
neck = cyl((0, 0.95, 0), (0, 1.03, 0), 0.07, 0.006)
under = U(waist, frame_b, neck)

# the light slot in the chest
slot_c = V(0, 0.855, -0.178)
tilt = rot_x(0.0)
slot_f = box(slot_c, (0.092, 0.03, 0.012), r=0.008)
slot = box(slot_c + V(0, 0, -0.008), (0.078, 0.019, 0.006), r=0.004)
bars = U(*[box(slot_c + V(x, 0, -0.0125), (0.0036, 0.021, 0.0035), r=0.0015) for x in np.linspace(-0.06, 0.06, 7)])

# the helmet
c = V(0, 1.115, 0)
hbox = box(c, (0.122, 0.118, 0.13), r=0.03)
hbox = I(hbox, mx(plane(c + V(0.075, -0.09, 0), (1, -0.65, 0))), k=0.01)
hbox = I(hbox, plane(c + V(0, 0, -0.15), (0, -0.25, -1)), k=0.012)
tv = U(box(c + V(0, 0.024, -0.13), (0.082, 0.0105, 0.016), r=0.004), box(c + V(0, -0.024, -0.13), (0.0095, 0.042, 0.016), r=0.004), k=0.003)
hshell = D(hbox, off(tv, 0.003), k=0.002)
tv_g = I(off(hbox, -0.003), tv)
crest = box(c + V(0, 0.135, 0.01), (0.017, 0.03, 0.115), r=0.012)
cheek = mx(box(c + V(0.117, -0.02, 0.02), (0.016, 0.052, 0.06), r=0.012))

# the rockets on the back and the small ones on the boots
JP = V(0, 0.76, 0.16)
blk = mx(box((0.098, 0.82, 0.26), (0.078, 0.175, 0.082), r=0.03))
blk = disp(blk, groove(plane((0, 0.74, 0), (0, 1, 0)), 0.004, 0.0045))
blk_t = mx(I(off(box((0.098, 0.82, 0.26), (0.078, 0.175, 0.082), r=0.03), 0.004), band(plane((0, 0.925, 0), (0, 1, 0)), 0.012), k=0.003))
vents = mx(U(*[box((0.098, 0.72 + i * 0.03, 0.344), (0.05, 0.0058, 0.006), r=0.0025) for i in range(4)]))
bell = mx(U(nozzle((0.098, 0.655, 0.26), (0.098, 0.545, 0.26), 0.052, 0.082), cyl((0.098, 0.665, 0.26), (0.098, 0.62, 0.26), 0.06, 0.006)))
glow = mx(box((0.098, 0.88, 0.343), (0.03, 0.0065, 0.004), r=0.002))

foot = U(box((0, -0.298, -0.04), (0.094, 0.04, 0.13), r=0.03), box((0, -0.25, 0.012), (0.084, 0.044, 0.075), r=0.028), k=0.012)
sole = box((0, -0.327, -0.04), (0.1, 0.0095, 0.136), r=0.008)
b_noz = U(nozzle((0, -0.2, 0.128), (0, -0.262, 0.128), 0.024, 0.04, wall=0.0055))
foot_R, sole_R, noz_R = xf(foot, r.M["KneeR"]), xf(sole, r.M["KneeR"]), xf(b_noz, r.M["KneeR"])

HR, HL = hand_frame(r, "R"), hand_frame(r, "L")
glove_R = xf(glove(palm=1.16, curl=0.5, cuff=(0.056, 0.05), cuff_len=0.05), HR)

BODY = ((-0.86, -0.28, -0.3), (0.86, 1.08, 0.28))
TORSO = ((-0.34, 0.62, -0.26), (0.34, 1.0, 0.2))
HEAD = ((-0.2, 0.92, -0.22), (0.2, 1.34, 0.22))
PACK = ((-0.3, 0.44, 0.12), (0.3, 1.1, 0.44))
HANDS, HANDL = ((0.4, 0.24, -0.16), (0.96, 0.78, 0.16)), ((-0.96, 0.24, -0.16), (-0.4, 0.78, 0.16))
FR, FL = ((0.0, -0.3, -0.3), (0.36, 0.2, 0.22)), ((-0.36, -0.3, -0.3), (0.0, 0.2, 0.22))
layers = [
	Layer("armor", armor, "paint", *BODY, 7000, color=RED, h=0.0036, wear=0.5, ao_k=1.2),
	Layer("gold", gold, "gold", *BODY, 2600, color=GOLD, h=0.0032),
	Layer("under", under, "dark", *BODY, 3400, color=DARK, h=0.0036),
	Layer("slotf", slot_f, "gun", *TORSO, 300, color=GUN, bone="Torso", h=0.0026),
	Layer("slot", slot, "glow", *TORSO, 100, color=ICE, bone="Torso", h=0.0024),
	Layer("bars", bars, "gun", *TORSO, 300, color=DARK, bone="Torso", h=0.002),
	Layer("helmet", U(hshell, cheek, k=0.004), "paint", *HEAD, 2600, color=RED, bone="Head", h=0.0026, wear=0.5),
	Layer("tv", tv_g, "glow", *HEAD, 200, color=ICE, bone="Head", h=0.0024),
	Layer("crest", crest, "gold", *HEAD, 400, color=GOLD, bone="Head", h=0.0026),
	Layer("packb", blk, "paint", *PACK, 2200, color=RED, bone="Jetpack", h=0.0052, wear=0.5),
	Layer("packt", blk_t, "gold", *PACK, 300, color=GOLD, bone="Jetpack", h=0.003),
	Layer("vents", vents, "dark", *PACK, 300, color=DARK, bone="Jetpack", h=0.0026),
	Layer("packg", glow, "glow", *PACK, 60, color=ICE, bone="Jetpack", h=0.0026),
	Layer("bell", bell, "metal", *PACK, 900, color=(0.18, 0.18, 0.21), bone="Jetpack", h=0.0048),
	Layer("gloveR", glove_R, "gun", *HANDS, 1000, color=GUN, bone="HandR", h=0.0028, wear=0.5),
	Layer("gloveL", flip(glove_R), "gun", *HANDL, 1000, color=GUN, bone="HandL", h=0.0028, wear=0.5),
	Layer("footR", foot_R, "paint", *FR, 500, color=RED, bone="KneeR", h=0.0034, wear=0.5),
	Layer("footL", flip(foot_R), "paint", *FL, 500, color=RED, bone="KneeL", h=0.0034, wear=0.5),
	Layer("soleR", sole_R, "dark", *FR, 150, color=DARK, bone="KneeR", h=0.0034),
	Layer("soleL", flip(sole_R), "dark", *FL, 150, color=DARK, bone="KneeL", h=0.0034),
	Layer("nozR", noz_R, "metal", *FR, 400, color=(0.18, 0.18, 0.21), bone="KneeR", h=0.004),
	Layer("nozL", flip(noz_R), "metal", *FL, 400, color=(0.18, 0.18, 0.21), bone="KneeL", h=0.004),
]
pm = np.eye(4)
pm[:3, 3] = JP
materials = {
	"paint": {"rough": 0.28, "metal": 0.4, "coat": 0.7, "coat_rough": 0.12},
	"gold": {"rough": 0.3, "metal": 1.0},
	"gun": {"rough": 0.4, "metal": 0.6},
	"dark": {"rough": 0.55, "metal": 0.4},
	"metal": {"rough": 0.3, "metal": 0.95},
	"glow": {"rough": 0.4, "emit": (0.2, 0.68, 1.0), "energy": 1.7},
}
caps = [("Hip", V(0, 0.44, 0), V(0, 0.585, 0), 0.15), ("Torso", V(0, 0.67, 0), V(0, 0.93, 0), 0.19), ("Head", V(0, 1.02, 0), V(0, 1.2, 0), 0.1)]
for s, nm in ((-1.0, "L"), (1.0, "R")):
	m = V(s, 1, 1)
	caps += [("Shoulder" + nm, S * m, E * m, 0.085), ("Elbow" + nm, E * m, r.Hd * m, 0.07), ("Leg" + nm, L * m, K * m, 0.095), ("Knee" + nm, K * m, A * m, 0.09)]
char = {"rig": r, "layers": layers, "frames": {"Jetpack": pm, "HandR": HR, "HandL": HL}, "caps": caps, "tau": 0.0028, "materials": materials,
	"jetpack": list(JP - V(0, 0.5, 0)), "flames": [[0.098, 0.545 - 0.76, 0.26 - 0.16], [-0.098, 0.545 - 0.76, 0.26 - 0.16]],
	"bone_flames": [["KneeR", 0.0, -0.262, 0.128], ["KneeL", 0.0, -0.262, 0.128]]}
bake(char, sys.argv[1] if len(sys.argv) > 1 else "out/mech")

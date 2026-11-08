"""The Fox Pilot: a fox in a bomber jacket, goggles up on the head, a big white-tipped tail, and a riveted copper rocket."""
import sys

from bodies import *

r = Rig(arm_out=36.0, leg_out=8.0, shoulder_x=0.235, leg_x=0.095)
S, E, W, L, K, A = r.S, r.E, r.W, r.L, r.K, r.A
da, dl = r.arm_dir, r.leg_dir
FUR, CREAM, LEATHER, KHAKI, BRASS, COPPER, DARK, LENS, BOOT = (0.85, 0.36, 0.09), (0.93, 0.87, 0.75), (0.26, 0.14, 0.075), (0.2, 0.26, 0.17), (0.85, 0.6, 0.22), (0.8, 0.36, 0.17), (0.03, 0.025, 0.02), (0.3, 0.72, 0.95), (0.15, 0.08, 0.04)

jacket, tor_j, arm_j, trousers = bomber(r)
front = keep((0, 0, 0), (0, 0, -1))
zipper = I(I(off(tor_j, 0.0034), band(plane((0, 0, 0), (1, 0, 0)), 0.0058)), front)
hem = I(off(tor_j, 0.012), band(plane((0, 0.598, 0), (0, 1, 0)), 0.026), k=0.004)
cuffs = mx(I(off(arm_j, 0.0085), band(plane(W - da * 0.017, da), 0.026), k=0.004))
def tuft(P):
	return 0.0035 * (np.sin(P[..., 0] * 110.0) * np.sin(P[..., 1] * 120.0 + 1.0) * np.sin(P[..., 2] * 100.0 + 2.0))
fleece = disp(tor((0, 0.968, 0.005), (0, 1, 0.14), 0.118, 0.043), tuft)
straps = mx(I(I(off(tor_j, 0.009), band(plane((0.098, 0, 0), (1, 0, 0.05)), 0.019)), keep((0, 0.67, 0), (0, 1, 0))))

# the head
c = V(0, 1.11, 0)
skull = ell(c, (0.13, 0.118, 0.128))
muzzle = cone(c + V(0, -0.034, -0.075), c + V(0, -0.05, -0.215), 0.07, 0.024)
tufts = mx(U(cone(c + V(0.085, -0.05, 0.0), c + V(0.178, -0.083, 0.028), 0.052, 0.008), cone(c + V(0.085, -0.02, 0.0), c + V(0.164, -0.024, 0.04), 0.044, 0.007), k=0.02))
head = U(skull, muzzle, tufts, k=0.03)
ear_shape = lambda grow: mx(I(cone(c + V(0.075, 0.075, 0.01), c + V(0.118, 0.255, 0.028), 0.062 + grow, 0.01), band(plane(c + V(0, 0, 0.024), (0, 0.15, 1)), 0.028 + grow), k=0.006))
head = U(head, ear_shape(0.0), k=0.012)
ears_in = mx(I(cone(c + V(0.08, 0.1, 0.0), c + V(0.116, 0.238, 0.02), 0.04, 0.006), keep(c + V(0, 0, 0.0), (0, -0.15, -1)), k=0.003))
ears_in = I(ears_in, off(ear_shape(0.0), 0.0025))
face_w = U(cone(c + V(0, -0.052, -0.07), c + V(0, -0.062, -0.21), 0.078, 0.03), mx(ell(c + V(0.09, -0.078, -0.05), (0.085, 0.052, 0.075))), k=0.01)
white = I(off(head, 0.0024), face_w, k=0.004)
nose = ell(c + V(0, -0.038, -0.232), (0.027, 0.02, 0.022))
mouth = mx(I(off(head, 0.0032), I(band(plane(c + V(0, -0.078, -0.19), (-0.42, 1, 0.1)), 0.0026), I(keep(c, (1, 0, 0)), keep(c + V(0.034, 0, 0), (-1, 0, 0)))), k=0.001))
eyes = mx(ell(c + V(0.066, 0.016, -0.106), (0.024, 0.027, 0.014)))
glint = mx(sphere(c + V(0.058, 0.03, -0.1187), 0.0066))
brows = mx(cap(c + V(0.05, 0.052, -0.112), c + V(0.082, 0.056, -0.097), 0.0046))

# the goggles
n1 = norm(V(0, 0.82, -0.57))
gc = c + V(0.058, 0.118, -0.058)
gframe = mx(U(tor(gc, n1, 0.04, 0.0092), cyl(gc - n1 * 0.008, gc + n1 * 0.002, 0.048, 0.005), k=0.003))
glens = mx(cyl(gc - n1 * 0.002, gc + n1 * 0.0073, 0.0362, 0.003))
strap = I(off(head, 0.0035), I(band(plane(c + V(0, 0.095, 0), (0, 1, 0.95)), 0.0125), keep(c + V(0.0, 0.0, -0.06), (0, 0, 1))), k=0.002)

# the tail, a big soft curve behind the hips
tp = [V(0.02, 0.48, 0.09), V(0.15, 0.42, 0.15), V(0.27, 0.46, 0.22), V(0.34, 0.58, 0.27), V(0.35, 0.73, 0.3)]
rad = [0.03, 0.06, 0.082, 0.07, 0.02]
tail_s = U(*[cone(tp[i], tp[i + 1], rad[i], rad[i + 1]) for i in range(len(tp) - 1)], k=0.03)
tail_s = disp(tail_s, tuft)
tip_cut = keep(tp[3] + (tp[2] - tp[3]) * 0.25, tp[3] - tp[2])
tail_o = D(tail_s, I(off(tail_s, 0.02), tip_cut), k=0.003)
tail_w = I(tail_s, tip_cut, k=0.003)

# the copper rocket
JP = V(0, 0.76, 0.16)
tank = cap((0, 0.7, 0.285), (0, 0.97, 0.285), 0.128)
ring_ys = (0.68, 0.81, 0.94)
tank_rings = U(*[I(off(tank, 0.0045), band(plane((0, y, 0), (0, 1, 0)), 0.0095)) for y in ring_ys])
rivets = [sphere((0.135 * math.cos(i / 14 * math.tau), y, 0.285 + 0.135 * math.sin(i / 14 * math.tau)), 0.0066) for y in ring_ys for i in range(14)]
gauge = U(cyl((0.0, 1.03, 0.285), (0.0, 1.13, 0.285), 0.022, 0.006), sphere((0, 1.14, 0.285), 0.03), tor((0.0, 1.075, 0.285), (0, 1, 0), 0.03, 0.0068), k=0.002)
bell = mx(U(nozzle((0.066, 0.62, 0.285), (0.066, 0.53, 0.285), 0.05, 0.08), cyl((0.066, 0.66, 0.285), (0.066, 0.6, 0.285), 0.052, 0.006)))

HR, HL = hand_frame(r, "R"), hand_frame(r, "L")
glove_R = xf(glove(palm=1.05, curl=0.5, cuff=(0.066, 0.058), cuff_len=0.06), HR)
b_up, b_sole = boot(height=0.1, r=(0.08, 0.075), toe=(0.086, 0.066, 0.124), sole_y=-0.335)
bu_R, bs_R = xf(b_up, r.M["KneeR"]), xf(b_sole, r.M["KneeR"])

BODY = ((-0.75, -0.22, -0.26), (0.75, 1.05, 0.24))
TORSO = ((-0.34, 0.54, -0.26), (0.34, 1.05, 0.26))
HEAD = ((-0.26, 0.9, -0.38), (0.26, 1.44, 0.22))
TAIL = ((-0.08, 0.28, 0.0), (0.5, 0.86, 0.46))
PACK = ((-0.3, 0.44, 0.12), (0.3, 1.2, 0.46))
HANDS, HANDL = ((0.34, 0.26, -0.18), (0.86, 0.74, 0.18)), ((-0.86, 0.26, -0.18), (-0.34, 0.74, 0.18))
FR, FL = ((0.0, -0.26, -0.28), (0.34, 0.22, 0.16)), ((-0.34, -0.26, -0.28), (0.0, 0.22, 0.16))
layers = [
	Layer("fur", head, "fur", *HEAD, 3600, color=FUR, bone="Head", h=0.0028, ao_k=0.85, hidden_by=("whitefur",)),
	Layer("whitefur", white, "fur", *HEAD, 1600, color=CREAM, bone="Head", h=0.0025, ao_k=0.8),
	Layer("earin", ears_in, "web", *HEAD, 300, color=(0.17, 0.08, 0.05), bone="Head", h=0.0024),
	Layer("nose", nose, "eye", *HEAD, 200, color=(0.012, 0.012, 0.014), bone="Head", h=0.002),
	Layer("mouth", mouth, "web", *HEAD, 300, color=(0.12, 0.05, 0.04), bone="Head", h=0.0018),
	Layer("eyes", eyes, "eye", *HEAD, 300, color=(0.012, 0.012, 0.016), bone="Head", h=0.002),
	Layer("glint", glint, "glint", *HEAD, 80, color=(1, 1, 1), bone="Head", h=0.0016),
	Layer("brows", brows, "web", *HEAD, 200, color=(0.07, 0.03, 0.015), bone="Head", h=0.002),
	Layer("gframe", gframe, "brass", *HEAD, 700, color=BRASS, bone="Head", h=0.0022),
	Layer("glens", glens, "lens", *HEAD, 200, color=LENS, bone="Head", h=0.0022),
	Layer("jacket", jacket, "leather", *BODY, 6000, color=LEATHER, h=0.0038, wear=0.55, ao_k=1.1),
	Layer("zipper", zipper, "brass", *TORSO, 250, color=BRASS, bone="Torso", h=0.0028),
	Layer("hem", U(hem, cuffs), "cloth", *BODY, 1400, color=(0.5, 0.42, 0.3), h=0.003),
	Layer("fleece", fleece, "cloth", *TORSO, 1500, color=CREAM, bone="Torso", h=0.0034, ao_k=1.3),
	Layer("trousers", trousers, "cloth", *BODY, 3500, color=KHAKI, h=0.004, wear=0.2, hidden_by=("jacket",)),
	Layer("packstrap", straps, "web", *TORSO, 500, color=(0.06, 0.04, 0.03), bone="Torso", h=0.003),
	Layer("tail", tail_o, "fur", *TAIL, 1500, color=FUR, bone="Hip", h=0.0036, ao_k=0.8),
	Layer("tailw", tail_w, "fur", *TAIL, 500, color=CREAM, bone="Hip", h=0.0036, ao_k=0.8),
	Layer("tank", tank, "copper", *PACK, 800, color=COPPER, bone="Jetpack", h=0.0036),
	Layer("brassy", U(tank_rings, gauge, *rivets), "brass", *PACK, 2400, color=BRASS, bone="Jetpack", h=0.0028),
	Layer("bell", bell, "metal", *PACK, 900, color=(0.14, 0.12, 0.11), bone="Jetpack", h=0.0048),
	Layer("gloveR", glove_R, "fur", *HANDS, 1000, color=(0.07, 0.05, 0.04), bone="HandR", h=0.003),
	Layer("gloveL", flip(glove_R), "fur", *HANDL, 1000, color=(0.07, 0.05, 0.04), bone="HandL", h=0.003),
	Layer("bootR", bu_R, "leather", *FR, 800, color=BOOT, bone="KneeR", h=0.0034, wear=0.6),
	Layer("bootL", flip(bu_R), "leather", *FL, 800, color=BOOT, bone="KneeL", h=0.0034, wear=0.6),
	Layer("soleR", bs_R, "rubber", *FR, 300, color=(0.05, 0.04, 0.035), bone="KneeR", h=0.0032),
	Layer("soleL", flip(bs_R), "rubber", *FL, 300, color=(0.05, 0.04, 0.035), bone="KneeL", h=0.0032),
]
pm = np.eye(4)
pm[:3, 3] = JP
materials = {
	"fur": {"rough": 0.82, "rim": 0.75, "rim_tint": 0.85, "spec": 0.25},
	"eye": {"rough": 0.08, "spec": 0.9, "coat": 1.0, "coat_rough": 0.05},
	"glint": {"rough": 0.5, "emit": (1, 1, 1), "energy": 1.6},
	"web": {"rough": 0.75},
	"leather": {"rough": 0.46, "rim": 0.22, "rim_tint": 0.4},
	"cloth": {"rough": 0.9, "rim": 0.3, "rim_tint": 0.7},
	"rubber": {"rough": 0.8},
	"brass": {"rough": 0.3, "metal": 1.0},
	"copper": {"rough": 0.34, "metal": 1.0},
	"metal": {"rough": 0.32, "metal": 0.95},
	"lens": {"rough": 0.06, "metal": 0.6, "coat": 1.0, "coat_rough": 0.05},
}
char = {"rig": r, "layers": layers, "frames": {"Jetpack": pm, "HandR": HR, "HandL": HL},
	"caps": r.capsules(torso_r=0.16, hip_r=0.145, arm=(0.075, 0.065), leg=(0.095, 0.074)), "materials": materials, "jetpack": list(JP - V(0, 0.5, 0)),
	"flames": [[0.066, 0.53 - 0.76, 0.285 - 0.16], [-0.066, 0.53 - 0.76, 0.285 - 0.16]]}
bake(char, sys.argv[1] if len(sys.argv) > 1 else "out/fox")

"""Option B: the Test Pilot. Slim and sharp: a blaze orange flight suit with creases and seams, a black harness, a white
fighter helmet with a smoked visor and breathing hose, and a slim twin-tank rocket pack."""
import sys

from parts import *
from sdf import *

r = Rig(arm_out=38.0, leg_out=7.0, shoulder_x=0.215, leg_x=0.085)
S, E, W, L, K, A = r.S, r.E, r.W, r.L, r.K, r.A
da, dl = r.arm_dir, r.leg_dir

ORANGE = (0.83, 0.24, 0.045)
BLACK = (0.022, 0.024, 0.03)
WEB = (0.05, 0.055, 0.06)
WHITE = (0.8, 0.8, 0.78)
STEEL = (0.5, 0.52, 0.56)
SMOKE = (0.1, 0.13, 0.2)
BLUE = (0.05, 0.16, 0.5)
YELLOW = (0.95, 0.7, 0.08)

chest = ell((0, 0.835, 0), (0.168, 0.15, 0.114))
pec = mx(ell((0.072, 0.862, -0.072), (0.078, 0.056, 0.048)))
delt = mx(ell(S + V(-0.02, 0.005, 0), (0.078, 0.072, 0.072)))
torso = U(chest, pec, delt, cone((0, 0.78, 0), (0, 0.6, 0), 0.122, 0.116), ell((0, 0.5, 0), (0.15, 0.11, 0.112)),
	cone((0, 0.95, 0), (0, 1.03, 0), 0.06, 0.054), k=0.05)
arm = U(cone(S, E, 0.057, 0.047), ell(S + da * 0.13, (0.054, 0.088, 0.054), rot=frame(da)), cone(E, W, 0.047, 0.036),
	ell(E + da * 0.07, (0.046, 0.075, 0.046), rot=frame(da)), k=0.025)
leg = U(cone(L, K, 0.084, 0.057), ell(L + dl * 0.15 + V(0, 0, -0.012), (0.086, 0.13, 0.082), rot=frame(dl)), cone(K, A, 0.056, 0.04),
	ell(K + dl * 0.1 + V(0, 0, 0.017), (0.057, 0.095, 0.058), rot=frame(dl)), k=0.03)
torso = disp(torso, folds((0, 0.67, 0), (0, 1, 0), 0.085, 0.036, 0.0065))
arm = disp(disp(arm, folds(E, da, 0.075, 0.03, 0.0065)), folds(S + da * 0.05, da, 0.05, 0.034, 0.004))
leg = disp(disp(leg, folds(K, dl, 0.09, 0.034, 0.0075)), folds(A - dl * 0.06, dl, 0.07, 0.03, 0.005))
leg = disp(leg, groove(plane((L[0] + 0.082, 0, 0), (1, 0, -0.1)), 0.003, 0.0035))
arm = disp(arm, groove(plane(S + V(0, 0, 0), (0, 0, 1)), 0.003, 0.003))
torso = disp(torso, mx(groove(plane((0.115, 0.85, 0), (1, 0.15, 0)), 0.003, 0.0035)))
body = U(torso, mx(arm), mx(leg), k=0.015)

front = keep((0, 0, 0), (0, 0, -1))
zip_l = I(I(off(torso, 0.0035), band(plane((0, 0, 0), (1, 0, 0)), 0.005)), I(I(front, keep((0, 0.56, 0), (0, 1, 0))), keep((0, 0.95, 0), (0, -1, 0))))
collar = I(I(off(torso, 0.013), band(plane((0, 0.985, 0), (0, 1, 0.1)), 0.026), k=0.004), cyl((0, 0.9, 0), (0, 1.05, 0), 0.095, 0.01), k=0.006)
pocket_sh = I(off(mx(leg), 0.006), I(band(plane(L + dl * 0.2, dl), 0.036), I(band(plane((L[0] + 0.07, 0, 0), (1, 0, 0)), 0.042), keep((0, 0, -0.01), (0, 0, -1)))), k=0.004)

# the harness
chest_str = band(plane((0, 0.815, 0), (0, 1, 0)), 0.015)
belt = band(plane((0, 0.625, 0), (0, 1, 0)), 0.02)
vert = mx(band(plane((0.088, 0, 0), (1, 0, 0.05)), 0.017))
upper = keep((0, 0.59, 0), (0, 1, 0))
web = I(off(torso, 0.0105), U(chest_str, I(belt, upper), I(vert, upper)), k=0.003)
loops = mx(I(off(leg, 0.009), band(plane(L + dl * 0.105, dl + V(0, 0.34, 0)), 0.017), k=0.003))
harness = U(web, loops)
buckle = U(box((0, 0.815, -0.128), (0.034, 0.024, 0.012), r=0.006), box((0, 0.625, -0.128), (0.036, 0.026, 0.012), r=0.006))
knee = mx(I(off(leg, 0.012), ell(K + V(0, 0, -0.058), (0.072, 0.075, 0.075)), k=0.005))

patch_a = I(off(chest, 0.0035), cyl((-0.095, 0.875, -0.22), (-0.095, 0.875, 0.0), 0.03, 0.003))
patch_b = I(off(pec, 0.0035), box((0.092, 0.875, -0.12), (0.042, 0.016, 0.1), r=0.003))

# the helmet
c = V(0, 1.1, 0.008)
dome = ell(c, (0.133, 0.15, 0.158))
chin = ell(c + V(0, -0.074, -0.055), (0.094, 0.072, 0.104))
helm = U(dome, chin, cone(c + V(0, -0.06, 0.03), V(0, 0.985, 0.012), 0.104, 0.082), k=0.05)
window = I(ell(c + V(0, 0.012, -0.11), (0.122, 0.068, 0.12)), keep(c + V(0, -0.058, 0), (0, 1, 0.05)), k=0.012)
shell = D(helm, window, k=0.006)
visor = I(off(helm, -0.008), off(window, 0.014))
stripe = I(off(helm, 0.0028), I(band(plane(c, (1, 0, 0)), 0.018), keep(c + V(0, 0.055, -0.02), (0, 0.9, 0.3))), k=0.002)
stripe_s = mx(I(off(helm, 0.0028), I(band(plane(c + V(0.04, 0, 0), (1, 0, 0)), 0.0065), keep(c + V(0, 0.055, -0.02), (0, 0.9, 0.3))), k=0.0015))
vents = mx(U(*[box((0.03 + i * 0.022, 1.02 - i * 0.007, -0.1 + i * 0.016), (0.0055, 0.011, 0.04), r=0.003, rot=rot_y(0.55)) for i in range(3)]))
shell = D(shell, vents, k=0.002)
rim = I(off(helm, 0.0045), skin(window, 0.0055), k=0.002)
ears = mx(ell(c + V(0.13, -0.01, 0.02), (0.018, 0.05, 0.055)))
P0, P1, P2, P3 = V(0.055, 1.0, -0.115), V(0.1, 0.93, -0.13), V(0.105, 0.86, -0.135), V(0.085, 0.8, -0.135)
hose = U(cap(P0, P1, 0.0165), cap(P1, P2, 0.0165), cap(P2, P3, 0.0165), k=0.008)
hose = disp(hose, lambda P: 0.0024 * (0.5 + 0.5 * np.sin(P[..., 1] * 250.0)))
hose = mx(hose) if False else hose

# the pack
JP = V(0, 0.76, 0.125)
tank = lambda x: U(cone((x, 0.66, 0.19), (x, 0.92, 0.19), 0.062, 0.056), ell((x, 0.955, 0.19), (0.056, 0.095, 0.056)), k=0.012)
tanks = mx(tank(0.078))
spine = box((0, 0.8, 0.14), (0.062, 0.14, 0.02), r=0.012)
bands_p = mx(U(*[I(off(tank(0.078), 0.003), band(plane((0, y, 0), (0, 1, 0)), 0.0085)) for y in (0.7, 0.87)]))
fin = mx(U(box((0.148, 0.655, 0.19), (0.022, 0.05, 0.0055), r=0.0035, rot=rot_z(-0.6))))
bell = mx(U(nozzle((0.078, 0.66, 0.19), (0.078, 0.555, 0.19), 0.046, 0.066), cyl((0.078, 0.675, 0.19), (0.078, 0.625, 0.19), 0.05, 0.005)))
led = mx(box((0.078, 0.8, 0.252), (0.0065, 0.04, 0.004), r=0.0025))

HR, HL = hand_frame(r, "R"), hand_frame(r, "L")
glove_R = xf(glove(palm=0.86, cuff=(0.048, 0.04), cuff_len=0.085), HR)
glove_L = flip(glove_R)
b_up, b_sole = boot(height=0.165, r=(0.08, 0.056), toe=(0.06, 0.05, 0.112), sole_y=-0.335)
bu_R, bs_R = xf(b_up, r.M["KneeR"]), xf(b_sole, r.M["KneeR"])
bu_L, bs_L = flip(bu_R), flip(bs_R)

BODY = ((-0.72, -0.2, -0.26), (0.72, 1.05, 0.24))
TORSO = ((-0.3, 0.55, -0.24), (0.3, 1.05, 0.24))
HEAD = ((-0.2, 0.93, -0.25), (0.2, 1.3, 0.22))
PACK = ((-0.3, 0.5, 0.08), (0.3, 1.1, 0.34))
HANDS = ((0.34, 0.3, -0.16), (0.8, 0.72, 0.16))
HANDL = ((-0.8, 0.3, -0.16), (-0.34, 0.72, 0.16))
FR, FL = ((0.0, -0.25, -0.24), (0.32, 0.25, 0.14)), ((-0.32, -0.25, -0.24), (0.0, 0.25, 0.14))

layers = [
	Layer("suit", body, "fabric", *BODY, 10000, color=ORANGE, h=0.0035, wear=0.22, ao_k=1.15),
	Layer("harness", harness, "web", *BODY, 2200, color=WEB, h=0.0035),
	Layer("buckle", buckle, "metal", *TORSO, 300, color=STEEL, h=0.0025),
	Layer("zip", zip_l, "metal", *TORSO, 400, color=STEEL, h=0.0025),
	Layer("collar", collar, "web", *TORSO, 900, color=BLACK, h=0.003),
	Layer("pocket", pocket_sh, "fabric", *BODY, 500, color=(0.68, 0.18, 0.03), h=0.003, wear=0.2),
	Layer("knee", knee, "plastic", *BODY, 700, color=BLACK, h=0.003, wear=0.5),
	Layer("patchA", patch_a, "plastic", *TORSO, 200, color=BLUE, bone="Torso", h=0.0022),
	Layer("patchB", patch_b, "plastic", *TORSO, 200, color=YELLOW, bone="Torso", h=0.0022),
	Layer("helmet", U(shell, ears, k=0.004), "shell", *HEAD, 3600, color=WHITE, bone="Head", h=0.0028, wear=0.05),
	Layer("visor", visor, "visor", *HEAD, 1300, color=SMOKE, bone="Head", h=0.0028),
	Layer("stripe", U(stripe, stripe_s), "paint", *HEAD, 500, color=ORANGE, bone="Head", h=0.0024),
	Layer("rim", rim, "web", *HEAD, 800, color=BLACK, bone="Head", h=0.0024),
	Layer("hose", hose, "rubber", *TORSO, 700, color=BLACK, bone="Torso", h=0.0025),
	Layer("tanks", tanks, "shell", *PACK, 1800, color=WHITE, bone="Jetpack", h=0.003, wear=0.05),
	Layer("packacc", U(bands_p, fin), "paint", *PACK, 600, color=ORANGE, bone="Jetpack", h=0.003),
	Layer("spine", spine, "web", *PACK, 300, color=BLACK, bone="Jetpack", h=0.003),
	Layer("bell", bell, "metal", *PACK, 900, color=(0.22, 0.22, 0.25), bone="Jetpack", h=0.0048),
	Layer("packled", led, "glow", *PACK, 60, color=(1.0, 0.35, 0.1), bone="Jetpack", h=0.0025),
	Layer("gloveR", glove_R, "rubber", *HANDS, 1000, color=BLACK, bone="HandR", h=0.0026, wear=0.5),
	Layer("gloveL", glove_L, "rubber", *HANDL, 1000, color=BLACK, bone="HandL", h=0.0026, wear=0.5),
	Layer("bootR", bu_R, "leather", *FR, 800, color=(0.05, 0.05, 0.06), bone="KneeR", h=0.0032, wear=0.6),
	Layer("bootL", bu_L, "leather", *FL, 800, color=(0.05, 0.05, 0.06), bone="KneeL", h=0.0032, wear=0.6),
	Layer("soleR", bs_R, "rubber", *FR, 300, color=(0.02, 0.02, 0.022), bone="KneeR", h=0.003),
	Layer("soleL", bs_L, "rubber", *FL, 300, color=(0.02, 0.02, 0.022), bone="KneeL", h=0.003),
]
pm = np.eye(4)
pm[:3, 3] = JP
materials = {
	"fabric": {"rough": 0.8, "rim": 0.3, "rim_tint": 0.6},
	"web": {"rough": 0.72},
	"plastic": {"rough": 0.38, "coat": 0.3},
	"paint": {"rough": 0.3, "coat": 0.6},
	"shell": {"rough": 0.22, "coat": 0.8, "coat_rough": 0.08},
	"metal": {"rough": 0.28, "metal": 0.95},
	"visor": {"rough": 0.05, "metal": 1.0},
	"rubber": {"rough": 0.72},
	"leather": {"rough": 0.45, "rim": 0.2, "rim_tint": 0.3},
	"glow": {"rough": 0.4, "emit": (1.0, 0.4, 0.12), "energy": 3.0},
}
char = {"rig": r, "layers": layers, "frames": {"Jetpack": pm, "HandR": HR, "HandL": HL},
	"caps": r.capsules(torso_r=0.125, hip_r=0.12, arm=(0.057, 0.045), leg=(0.084, 0.056)), "materials": materials, "jetpack": list(JP - V(0, 0.5, 0)),
	"flames": [[0.078, 0.555 - 0.76, 0.19 - 0.125], [-0.078, 0.555 - 0.76, 0.19 - 0.125]]}
bake(char, sys.argv[1] if len(sys.argv) > 1 else "out/testpilot")

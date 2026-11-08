"""The Racer: a red and white race suit, knee sliders, a long aero helmet with a tail, twin tanks."""
import sys

from bodies import *

r = Rig(arm_out=38.0, leg_out=7.0, shoulder_x=0.215, leg_x=0.085)
S, E, W, L, K, A = r.S, r.E, r.W, r.L, r.K, r.A
da, dl = r.arm_dir, r.leg_dir
RED, WHITE, BLACK, DARK, STEEL = (0.68, 0.035, 0.05), (0.8, 0.8, 0.78), (0.02, 0.022, 0.028), (0.06, 0.065, 0.075), (0.5, 0.52, 0.56)

torso, arm, leg = slim(r, 0.55)
hump = ell((0, 0.9, 0.11), (0.075, 0.13, 0.06))
torso = U(torso, hump, k=0.05)
body = U(torso, mx(arm), mx(leg), k=0.015)

# white panels: down the side of the arm and leg, across the shoulders
arm_stripe = I(off(arm, 0.008), I(I(band(plane(S, (0, 0, 1)), 0.019), keep(S - V(0.03, 0, 0), (1, 0.2, 0))), plane(W - da * 0.02, da)), k=0.004)
leg_stripe = I(off(leg, 0.008), I(I(band(plane(L, (0, 0, 1)), 0.022), keep(L, (1, 0, 0))), plane(K + dl * 0.08, dl)), k=0.004)
yoke = I(off(torso, 0.006), I(keep((0, 0.905, 0), (0, 1, 0.1)), keep((0, 1.0, 0), (0, -1, 0))), k=0.005)
yoke = D(yoke, cyl((0, 0.8, 0), (0, 1.1, 0), 0.066, 0.006), k=0.004)
side = mx(I(off(torso, 0.008), I(band(plane((0.098, 0, 0), (1, 0.05, 0)), 0.015), keep((0, 0.0, 0.0), (0, 0, -1))), k=0.004))
white = U(mx(arm_stripe), mx(leg_stripe), yoke, side)
belt_line = I(off(torso, 0.0062), band(plane((0, 0.615, 0), (0, 1, 0)), 0.012), k=0.002)
slider = mx(I(off(leg, 0.013), ell(K + V(0.004, 0.0, -0.058), (0.05, 0.062, 0.05)), k=0.004))
cup = mx(I(off(arm, 0.012), ell(S + da * 0.05 + V(0.03, 0.02, 0), (0.07, 0.066, 0.07)), k=0.006))
elbow = mx(I(off(arm, 0.009), ell(E + V(0, 0, 0.05), (0.042, 0.05, 0.04)), k=0.004))
collar = I(I(off(torso, 0.012), band(plane((0, 0.985, 0), (0, 1, 0.1)), 0.024), k=0.004), cyl((0, 0.9, 0), (0, 1.05, 0), 0.09, 0.01), k=0.006)
zip_l = I(I(off(torso, 0.0035), band(plane((0, 0, 0), (1, 0, 0)), 0.0046)), I(I(keep((0, 0, 0), (0, 0, -1)), keep((0, 0.58, 0), (0, 1, 0))), keep((0, 0.97, 0), (0, -1, 0))))

# the long aero helmet
c = V(0, 1.1, 0.0)
dome = ell(c, (0.128, 0.138, 0.15))
tail = cone(c + V(0, 0.015, 0.04), c + V(0, 0.03, 0.3), 0.116, 0.022)
chin = ell(c + V(0, -0.075, -0.05), (0.094, 0.07, 0.102))
helm = U(dome, tail, chin, cone(c + V(0, -0.06, 0.03), V(0, 0.985, 0.012), 0.102, 0.08), k=0.05)
window = I(ell(c + V(0, 0.012, -0.105), (0.118, 0.062, 0.12)), keep(c + V(0, -0.05, 0), (0, 1, 0.05)), k=0.012)
shell = D(helm, window, k=0.006)
visor = I(off(helm, -0.011), off(window, 0.016))
rim = I(off(helm, 0.004), skin(window, 0.005), k=0.002)
stripe = I(off(helm, 0.0028), I(band(plane(c, (1, 0, 0)), 0.021), keep(c + V(0, 0.06, -0.04), (0, 0.9, 0.2))), k=0.002)
fin = I(off(helm, 0.002), ell(c + V(0, 0.04, 0.26), (0.05, 0.05, 0.08)))

JP = V(0, 0.76, 0.125)
tanks, bands, fins, bell, spine, led, flames = twin_tanks(JP)
HR, HL = hand_frame(r, "R"), hand_frame(r, "L")
glove_R = xf(glove(palm=0.86, cuff=(0.048, 0.04), cuff_len=0.085), HR)
b_up, b_sole = boot(height=0.17, r=(0.08, 0.056), toe=(0.06, 0.05, 0.112), sole_y=-0.335)
bu_R, bs_R = xf(b_up, r.M["KneeR"]), xf(b_sole, r.M["KneeR"])

BODY = ((-0.72, -0.2, -0.26), (0.72, 1.05, 0.24))
TORSO = ((-0.3, 0.55, -0.24), (0.3, 1.05, 0.24))
HEAD = ((-0.2, 0.93, -0.25), (0.2, 1.3, 0.46))
PACK = ((-0.3, 0.5, 0.08), (0.3, 1.1, 0.34))
HANDS, HANDL = ((0.34, 0.3, -0.16), (0.8, 0.72, 0.16)), ((-0.8, 0.3, -0.16), (-0.34, 0.72, 0.16))
FR, FL = ((0.0, -0.25, -0.24), (0.32, 0.25, 0.14)), ((-0.32, -0.25, -0.24), (0.0, 0.25, 0.14))
layers = [
	Layer("suit", body, "leather", *BODY, 9000, color=RED, h=0.0035, wear=0.35, ao_k=1.1, hidden_by=("white",)),
	Layer("white", white, "leather", *BODY, 4200, color=WHITE, h=0.003, wear=0.1),
	Layer("armor", U(slider, cup, elbow), "plastic", *BODY, 1300, color=DARK, h=0.003, wear=0.5),
	Layer("belt", belt_line, "plastic", *TORSO, 500, color=BLACK, h=0.003),
	Layer("zip", zip_l, "metal", *TORSO, 300, color=STEEL, h=0.0026),
	Layer("collar", collar, "plastic", *TORSO, 700, color=BLACK, h=0.003),
	Layer("helmet", shell, "shell", *HEAD, 3200, color=RED, bone="Head", h=0.0028, wear=0.05),
	Layer("visor", visor, "visor", *HEAD, 1000, color=(0.08, 0.1, 0.16), bone="Head", h=0.0028),
	Layer("stripe", U(stripe, fin), "shell", *HEAD, 500, color=WHITE, bone="Head", h=0.0024),
	Layer("rim", rim, "plastic", *HEAD, 700, color=BLACK, bone="Head", h=0.0024),
	Layer("tanks", tanks, "shell", *PACK, 1600, color=WHITE, bone="Jetpack", h=0.003),
	Layer("packacc", U(bands, fins), "shell", *PACK, 600, color=RED, bone="Jetpack", h=0.003),
	Layer("spine", spine, "plastic", *PACK, 300, color=BLACK, bone="Jetpack", h=0.003),
	Layer("bell", bell, "metal", *PACK, 900, color=(0.22, 0.22, 0.25), bone="Jetpack", h=0.0048),
	Layer("packled", led, "glow", *PACK, 60, color=(1.0, 0.25, 0.2), bone="Jetpack", h=0.0025),
	Layer("gloveR", glove_R, "leather", *HANDS, 1000, color=DARK, bone="HandR", h=0.0026, wear=0.5),
	Layer("gloveL", flip(glove_R), "leather", *HANDL, 1000, color=DARK, bone="HandL", h=0.0026, wear=0.5),
	Layer("bootR", bu_R, "leather", *FR, 800, color=WHITE, bone="KneeR", h=0.0032, wear=0.3),
	Layer("bootL", flip(bu_R), "leather", *FL, 800, color=WHITE, bone="KneeL", h=0.0032, wear=0.3),
	Layer("soleR", bs_R, "rubber", *FR, 300, color=BLACK, bone="KneeR", h=0.003),
	Layer("soleL", flip(bs_R), "rubber", *FL, 300, color=BLACK, bone="KneeL", h=0.003),
]
pm = np.eye(4)
pm[:3, 3] = JP
materials = {
	"leather": {"rough": 0.42, "rim": 0.25, "rim_tint": 0.5},
	"plastic": {"rough": 0.36, "coat": 0.3},
	"shell": {"rough": 0.2, "coat": 0.9, "coat_rough": 0.08},
	"metal": {"rough": 0.28, "metal": 0.95},
	"visor": {"rough": 0.05, "metal": 1.0},
	"rubber": {"rough": 0.75},
	"glow": {"rough": 0.4, "emit": (1.0, 0.25, 0.2), "energy": 3.0},
}
char = {"rig": r, "layers": layers, "frames": {"Jetpack": pm, "HandR": HR, "HandL": HL},
	"caps": r.capsules(torso_r=0.125, hip_r=0.12, arm=(0.057, 0.045), leg=(0.084, 0.056)), "materials": materials, "jetpack": list(JP - V(0, 0.5, 0)), "flames": flames}
bake(char, sys.argv[1] if len(sys.argv) > 1 else "out/racer")

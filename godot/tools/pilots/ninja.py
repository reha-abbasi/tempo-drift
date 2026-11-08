"""The Cyber Ninja: a matte black suit under layered armour plates, cyan light along the plates' edges, a glowing slit visor."""
import sys

from bodies import *

r = Rig(arm_out=38.0, leg_out=7.0, shoulder_x=0.215, leg_x=0.085)
S, E, W, L, K, A = r.S, r.E, r.W, r.L, r.K, r.A
da, dl = r.arm_dir, r.leg_dir
BLACK, PLATE, GUN, CYAN = (0.02, 0.021, 0.026), (0.055, 0.058, 0.07), (0.05, 0.052, 0.062), (0.2, 0.95, 1.0)

torso, arm, leg = slim(r, 0.8)
body = U(torso, mx(arm), mx(leg), k=0.015)
front, back = keep((0, 0, 0), (0, 0, -1)), keep((0, 0, 0), (0, 0, 1))

# plates: a shell over the body inside a shape, with a rounded edge
breast = I(off(torso, 0.012), I(keep((0, 0.735, 0), (0, 1, 0)), keep((0, 0.965, 0), (0, -1, 0))), k=0.006)
breast = I(breast, mx(keep((0.168, 0, 0), (-1, 0, 0))), k=0.012)
breast = D(breast, cyl((0, 0.8, 0), (0, 1.1, 0), 0.075, 0.008), k=0.005)
breast = disp(breast, groove(plane((0, 0, 0), (1, 0, 0)), 0.0035, 0.005))
breast = disp(breast, groove(plane((0, 0.835, 0), (0, 1, 0.06)), 0.0032, 0.0045))
faulds = U(*[I(off(torso, 0.0115 - i * 0.0012), band(plane((0, 0.71 - i * 0.042, 0), (0, 1, 0)), 0.018), k=0.004) for i in range(3)])
faulds = I(faulds, front, k=0.01)
pauld = mx(I(off(arm, 0.017), I(ell(S + da * 0.05, (0.095, 0.095, 0.09)), keep(S + da * 0.1, -da), k=0.006), k=0.005))
fore = mx(I(off(arm, 0.011), I(band(plane(E + da * 0.125, da), 0.072), keep(E, V(0.2, 0.3, 1.0)) if False else keep(W, -da)), k=0.005))
thigh = mx(I(off(leg, 0.011), I(band(plane(L + dl * 0.17, dl), 0.085), front), k=0.006))
shin = mx(I(off(leg, 0.011), I(band(plane(K + dl * 0.15, dl), 0.105), front), k=0.006))
knee = mx(I(off(leg, 0.017), ell(K + V(0, 0, -0.058), (0.056, 0.06, 0.056)), k=0.005))
plates = U(breast, faulds, pauld, fore, thigh, shin, knee)

# lines of light along the plates
n1 = I(off(torso, 0.0145), I(band(plane((0, 0.742, 0), (0, 1, 0)), 0.0034), front), k=0.0015)
n2 = mx(I(off(torso, 0.0145), I(band(plane((0.075, 0.87, 0), (1, -0.42, 0)), 0.0034), I(front, I(keep((0, 0.78, 0), (0, 1, 0)), keep((0, 0.955, 0), (0, -1, 0))))), k=0.0015))
n3 = mx(I(off(arm, 0.0135), I(band(plane(E + da * 0.065, da), 0.0032), keep((0, 0, 0.0), (0, 0, -1))), k=0.0015))
n4 = mx(I(off(leg, 0.0135), I(band(plane((L[0] + 0.0, 0, 0), (1, 0, 0)), 0.0034), I(front, I(plane(K + dl * 0.26, dl), keep(K + dl * 0.05, dl)))), k=0.0015))
n5 = mx(I(off(leg, 0.0135), I(band(plane(L + dl * 0.255, dl), 0.0032), front), k=0.0015))
neon = U(n1, n2, n3, n4, n5)

# the helmet
c = V(0, 1.1, 0.005)
helm = U(ell(c, (0.122, 0.135, 0.145)), ell(c + V(0, -0.08, -0.04), (0.086, 0.07, 0.1)), cone(c + V(0, -0.06, 0.03), V(0, 0.985, 0.012), 0.098, 0.078), k=0.04)
slit = mx(I(band(plane(c + V(0, 0.002, 0), (-0.33, 1, 0)), 0.0115), ell(c + V(0, 0.015, -0.12), (0.112, 0.06, 0.08)), k=0.003))
shell = D(helm, slit, k=0.003)
visor = I(off(helm, -0.004), off(slit, 0.005))
crest = I(band(plane(c, (1, 0, 0)), 0.0075), U(I(off(helm, 0.026), I(keep(c + V(0, 0.05, -0.08), (0, 1, 0.3)), keep(c + V(0, 0.18, 0.15), (0, -1, -1))))), k=0.002)
shell = disp(shell, mx(groove(plane(c + V(0.06, -0.09, -0.08), (0.8, 0.0, -0.6)), 0.0032, 0.004)))
cheek = mx(I(off(helm, 0.0028), I(band(plane(c + V(0, -0.062, 0), (-0.2, 1, 0.3)), 0.0034), I(keep(c + V(0.038, 0, 0), (1, 0, 0)), keep(c + V(0.108, 0, 0), (-1, 0, 0)))), k=0.0012))

JP = V(0, 0.76, 0.125)
tanks, bands, fins, bell, spine, led, flames = twin_tanks(JP, x=0.07)
HR, HL = hand_frame(r, "R"), hand_frame(r, "L")
glove_R = xf(glove(palm=0.86, cuff=(0.05, 0.042), cuff_len=0.07), HR)
b_up, b_sole = boot(height=0.15, r=(0.077, 0.054), toe=(0.056, 0.046, 0.108), sole_y=-0.335)
bu_R, bs_R = xf(b_up, r.M["KneeR"]), xf(b_sole, r.M["KneeR"])

BODY = ((-0.72, -0.2, -0.26), (0.72, 1.05, 0.24))
TORSO = ((-0.3, 0.55, -0.24), (0.3, 1.05, 0.24))
HEAD = ((-0.2, 0.93, -0.25), (0.2, 1.42, 0.34))
PACK = ((-0.3, 0.5, 0.08), (0.3, 1.1, 0.34))
HANDS, HANDL = ((0.34, 0.3, -0.16), (0.8, 0.72, 0.16)), ((-0.8, 0.3, -0.16), (-0.34, 0.72, 0.16))
FR, FL = ((0.0, -0.25, -0.24), (0.32, 0.25, 0.14)), ((-0.32, -0.25, -0.24), (0.0, 0.25, 0.14))
layers = [
	Layer("suit", body, "fabric", *BODY, 7000, color=BLACK, h=0.0037, wear=0.8, ao_k=1.0, hidden_by=("plates",)),
	Layer("plates", plates, "plate", *BODY, 7000, color=PLATE, h=0.003, wear=0.9),
	Layer("neon", neon, "neon", *BODY, 1600, color=CYAN, h=0.0024),
	Layer("helmet", U(shell, crest, k=0.004), "plate", *HEAD, 3200, color=PLATE, bone="Head", h=0.0026, wear=0.9),
	Layer("visor", visor, "neon", *HEAD, 500, color=CYAN, bone="Head", h=0.0024),
	Layer("hline", cheek, "neon", *HEAD, 300, color=CYAN, bone="Head", h=0.0022),
	Layer("tanks", tanks, "plate", *PACK, 1400, color=PLATE, bone="Jetpack", h=0.003, wear=0.9),
	Layer("packacc", U(bands, led), "neon", *PACK, 500, color=CYAN, bone="Jetpack", h=0.0028),
	Layer("packdark", U(fins, spine), "fabric", *PACK, 400, color=GUN, bone="Jetpack", h=0.003),
	Layer("bell", bell, "metal", *PACK, 900, color=(0.14, 0.14, 0.17), bone="Jetpack", h=0.0048),
	Layer("gloveR", glove_R, "fabric", *HANDS, 1000, color=GUN, bone="HandR", h=0.0026, wear=0.9),
	Layer("gloveL", flip(glove_R), "fabric", *HANDL, 1000, color=GUN, bone="HandL", h=0.0026, wear=0.9),
	Layer("bootR", bu_R, "plate", *FR, 800, color=PLATE, bone="KneeR", h=0.0032, wear=0.9),
	Layer("bootL", flip(bu_R), "plate", *FL, 800, color=PLATE, bone="KneeL", h=0.0032, wear=0.9),
	Layer("soleR", bs_R, "fabric", *FR, 300, color=BLACK, bone="KneeR", h=0.003),
	Layer("soleL", flip(bs_R), "fabric", *FL, 300, color=BLACK, bone="KneeL", h=0.003),
]
pm = np.eye(4)
pm[:3, 3] = JP
materials = {
	"fabric": {"rough": 0.85, "rim": 0.45, "rim_tint": 0.2},
	"plate": {"rough": 0.32, "metal": 0.35, "rim": 0.35, "rim_tint": 0.2},
	"metal": {"rough": 0.3, "metal": 0.95},
	"neon": {"rough": 0.4, "emit": (0.2, 0.95, 1.0), "energy": 3.2},
}
char = {"rig": r, "layers": layers, "frames": {"Jetpack": pm, "HandR": HR, "HandL": HL},
	"caps": r.capsules(torso_r=0.125, hip_r=0.12, arm=(0.057, 0.045), leg=(0.084, 0.056)), "materials": materials, "jetpack": list(JP - V(0, 0.5, 0)), "flames": flames}
bake(char, sys.argv[1] if len(sys.argv) > 1 else "out/ninja")

"""The Robot: boxy steel panels on dark ball joints, LED eyes, a mint core, one big thruster on the back."""
import sys

from bodies import *

r = Rig(arm_out=30.0, leg_out=6.0, shoulder_x=0.262, leg_x=0.105)
S, E, W, L, K, A = r.S, r.E, r.W, r.L, r.K, r.A
da, dl = r.arm_dir, r.leg_dir
STEEL, LIGHT, DARK, MINT, YEL = (0.36, 0.5, 0.62), (0.68, 0.74, 0.8), (0.07, 0.085, 0.11), (0.3, 1.0, 0.82), (0.95, 0.68, 0.1)
fa, fl = frame(da), frame(dl)

# the shell: chest, waist, hips, head; arms and legs are boxes along their bones
chest = box((0, 0.815, 0), (0.185, 0.158, 0.128), r=0.038)
chest = U(chest, box((0, 0.93, 0.0), (0.13, 0.05, 0.1), r=0.03), k=0.02)
chest = disp(chest, groove(plane((0, 0.75, 0), (0, 1, 0)), 0.0034, 0.0045))
chest = disp(chest, mx(groove(plane((0.11, 0, 0), (1, 0, 0)), 0.0034, 0.0045)))
hips = box((0, 0.505, 0), (0.15, 0.072, 0.105), r=0.03)
hips = disp(hips, groove(plane((0, 0, 0), (1, 0, 0)), 0.0034, 0.0045))
def limb(a, b, hw, hd, inset=0.052, rr=0.02):
	a, b = V(a), V(b)
	m = (a + b) * 0.5
	ax = norm(b - a)
	return box(m, (hw, np.linalg.norm(b - a) * 0.5 - inset, hd), r=rr, rot=frame(ax))
up_a = limb(S, E, 0.056, 0.058)
lo_a = limb(E, W, 0.052, 0.054, inset=0.036)
thigh = limb(L, K, 0.072, 0.08)
shin = limb(K, A + dl * 0.01, 0.066, 0.074, inset=0.04)
panel_a = disp(U(up_a, lo_a), groove(plane(S + da * 0.13, da), 0.003, 0.004))
panel_l = disp(U(thigh, shin), groove(plane(K + dl * 0.16, dl), 0.003, 0.004))
shell = U(chest, hips, mx(panel_a), mx(panel_l))
cap_s = mx(I(off(sphere(S + V(0.006, 0.0, 0), 0.082), 0.0), keep(S + V(0.0, -0.02, 0), (0.45, 1, 0)), k=0.012))
shell = U(shell, cap_s)

# what shows between the panels
waist = cyl((0, 0.57, 0), (0, 0.67, 0), 0.098, 0.006)
waist = disp(waist, ribs((0, 0.62, 0), (0, 1, 0), 0.06, 0.022, 0.009))
balls = mx(U(sphere(S, 0.07), sphere(E, 0.056), sphere(L + dl * 0.01, 0.075), sphere(K, 0.066), sphere(W + da * 0.004, 0.044)))
neck = cyl((0, 0.97, 0), (0, 1.03, 0), 0.056, 0.006)
neck = disp(neck, ribs((0, 1.0, 0), (0, 1, 0), 0.03, 0.016, 0.006))
vent = mx(U(*[box((0.135, 0.885 - i * 0.022, -0.125), (0.022, 0.0056, 0.008), r=0.0025) for i in range(4)]))
inner = U(waist, balls, neck)

# the core, and hazard marks on the chest
core_ring = tor((0, 0.815, -0.13), (0, 0, 1), 0.052, 0.0085)
core = cyl((0, 0.815, -0.128), (0, 0.815, -0.136), 0.043, 0.004)
mark = mx(U(box((0.14, 0.72, -0.128), (0.024, 0.008, 0.004), r=0.002), box((0.14, 0.738, -0.128), (0.024, 0.0045, 0.004), r=0.002)))

# the head
c = V(0, 1.115, 0)
head = box(c, (0.128, 0.1, 0.115), r=0.034)
brow = box(c + V(0, 0.058, -0.103), (0.106, 0.017, 0.018), r=0.008)
head = U(head, brow, k=0.008)
head = disp(head, groove(plane(c + V(0, -0.042, 0), (0, 1, 0)), 0.0028, 0.0038))
eyes = mx(box(c + V(0.054, 0.006, -0.1175), (0.032, 0.018, 0.004), r=0.0035))
sock = mx(box(c + V(0.054, 0.006, -0.112), (0.039, 0.025, 0.007), r=0.006))
grill = U(*[box(c + V(0, -0.066 - i * 0.0, -0.115), (0.058, 0.002, 0.003), r=0.001) for i in range(1)])
grill = U(*[box(c + V(x, -0.068, -0.1155), (0.0043, 0.016, 0.0034), r=0.0018) for x in np.linspace(-0.055, 0.055, 9)])
ears = mx(U(cyl(c + V(0.12, 0.004, 0), c + V(0.145, 0.004, 0), 0.042, 0.007), cyl(c + V(0.14, 0.004, 0), c + V(0.154, 0.004, 0), 0.024, 0.005), k=0.002))
ant = U(cyl(c + V(0.0, 0.09, 0.01), c + V(0.0, 0.2, 0.01), 0.008, 0.003), cyl(c + V(0.0, 0.09, 0.01), c + V(0.0, 0.122, 0.01), 0.022, 0.006))
ant_tip = sphere(c + V(0.0, 0.21, 0.01), 0.018)
head = D(head, sock, k=0.002)

# the feet: a block with a heel
foot = U(box((0, -0.3, -0.04), (0.074, 0.036, 0.122), r=0.03), box((0, -0.255, 0.012), (0.066, 0.042, 0.068), r=0.028), k=0.012)
sole = box((0, -0.327, -0.04), (0.08, 0.009, 0.128), r=0.008)
foot_R, sole_R = xf(foot, r.M["KneeR"]), xf(sole, r.M["KneeR"])

# the one big thruster
JP = V(0, 0.76, 0.14)
housing = box((0, 0.83, 0.235), (0.145, 0.175, 0.085), r=0.045)
housing = disp(housing, groove(plane((0, 0.74, 0), (0, 1, 0)), 0.0034, 0.0045))
housing = disp(housing, mx(groove(plane((0.09, 0, 0), (1, 0, 0)), 0.0034, 0.0045)))
fan = D(cyl((0, 0.85, 0.3), (0, 0.85, 0.33), 0.092, 0.012), cyl((0, 0.85, 0.325), (0, 0.85, 0.36), 0.074, 0.006), k=0.003)
fan_core = cyl((0, 0.85, 0.3), (0, 0.85, 0.33), 0.03, 0.006)
big = U(nozzle((0, 0.66, 0.235), (0, 0.52, 0.235), 0.075, 0.118, wall=0.008), cyl((0, 0.69, 0.235), (0, 0.63, 0.235), 0.085, 0.008))
pipe = mx(U(cap((0.15, 0.72, 0.2), (0.11, 0.66, 0.235), 0.015), k=0.0))
strip = mx(box((0.12, 0.92, 0.32), (0.018, 0.04, 0.004), r=0.002))

HR, HL = hand_frame(r, "R"), hand_frame(r, "L")
g_local = glove(palm=0.98, curl=0.4, cuff=(0.052, 0.046), cuff_len=0.055)
glove_R = xf(g_local, HR)

BODY = ((-0.78, -0.24, -0.28), (0.78, 1.04, 0.26))
TORSO = ((-0.34, 0.6, -0.26), (0.34, 1.05, 0.24))
HEAD = ((-0.24, 0.92, -0.2), (0.24, 1.38, 0.2))
PACK = ((-0.3, 0.42, 0.1), (0.3, 1.1, 0.4))
HANDS, HANDL = ((0.34, 0.26, -0.16), (0.84, 0.76, 0.16)), ((-0.84, 0.26, -0.16), (-0.34, 0.76, 0.16))
FR, FL = ((0.0, -0.3, -0.26), (0.34, 0.2, 0.18)), ((-0.34, -0.3, -0.26), (0.0, 0.2, 0.18))
layers = [
	Layer("shell", shell, "steel", *BODY, 5200, color=STEEL, h=0.0034, wear=0.45, ao_k=1.2),
	Layer("inner", inner, "dark", *BODY, 3600, color=DARK, h=0.0034),
	Layer("vent", vent, "dark", *TORSO, 200, color=DARK, h=0.0024),
	Layer("corer", core_ring, "metal", *TORSO, 500, color=LIGHT, bone="Torso", h=0.0024),
	Layer("core", core, "glow", *TORSO, 150, color=MINT, bone="Torso", h=0.0024),
	Layer("mark", mark, "paint", *TORSO, 200, color=YEL, bone="Torso", h=0.0022),
	Layer("head", U(head, ears, k=0.003), "steel", *HEAD, 2400, color=LIGHT, bone="Head", h=0.0026, wear=0.45),
	Layer("eyes", eyes, "glow", *HEAD, 120, color=MINT, bone="Head", h=0.002),
	Layer("grill", U(grill, sock), "dark", *HEAD, 400, color=DARK, bone="Head", h=0.002),
	Layer("ant", ant, "dark", *HEAD, 300, color=DARK, bone="Head", h=0.0024),
	Layer("anttip", ant_tip, "glow", *HEAD, 120, color=MINT, bone="Head", h=0.0024),
	Layer("housing", housing, "steel", *PACK, 1300, color=LIGHT, bone="Jetpack", h=0.0032, wear=0.45),
	Layer("fan", U(fan, pipe), "dark", *PACK, 900, color=DARK, bone="Jetpack", h=0.0034),
	Layer("fancore", U(fan_core, strip), "glow", *PACK, 160, color=MINT, bone="Jetpack", h=0.003),
	Layer("big", big, "metal", *PACK, 1000, color=(0.2, 0.21, 0.24), bone="Jetpack", h=0.0048),
	Layer("gloveR", glove_R, "steel", *HANDS, 1000, color=LIGHT, bone="HandR", h=0.0028, wear=0.45),
	Layer("gloveL", flip(glove_R), "steel", *HANDL, 1000, color=LIGHT, bone="HandL", h=0.0028, wear=0.45),
	Layer("footR", foot_R, "steel", *FR, 500, color=STEEL, bone="KneeR", h=0.0034, wear=0.45),
	Layer("footL", flip(foot_R), "steel", *FL, 500, color=STEEL, bone="KneeL", h=0.0034, wear=0.45),
	Layer("soleR", sole_R, "dark", *FR, 150, color=DARK, bone="KneeR", h=0.0034),
	Layer("soleL", flip(sole_R), "dark", *FL, 150, color=DARK, bone="KneeL", h=0.0034),
]
pm = np.eye(4)
pm[:3, 3] = JP
materials = {
	"steel": {"rough": 0.34, "metal": 0.55, "rim": 0.25, "rim_tint": 0.3},
	"dark": {"rough": 0.5, "metal": 0.4},
	"metal": {"rough": 0.3, "metal": 0.95},
	"paint": {"rough": 0.45},
	"glow": {"rough": 0.4, "emit": (0.3, 1.0, 0.82), "energy": 3.0},
}
caps = [("Hip", V(0, 0.46, 0), V(0, 0.585, 0), 0.13), ("Torso", V(0, 0.66, 0), V(0, 0.93, 0), 0.17), ("Head", V(0, 1.02, 0), V(0, 1.2, 0), 0.1)]
for s, nm in ((-1.0, "L"), (1.0, "R")):
	m = V(s, 1, 1)
	caps += [("Shoulder" + nm, S * m, E * m, 0.06), ("Elbow" + nm, E * m, r.Hd * m, 0.05), ("Leg" + nm, L * m, K * m, 0.075), ("Knee" + nm, K * m, A * m, 0.07)]
char = {"rig": r, "layers": layers, "frames": {"Jetpack": pm, "HandR": HR, "HandL": HL}, "caps": caps, "tau": 0.0028, "materials": materials,
	"jetpack": list(JP - V(0, 0.5, 0)), "flames": [[0.0, 0.52 - 0.76, 0.235 - 0.14]]}
bake(char, sys.argv[1] if len(sys.argv) > 1 else "out/robot")

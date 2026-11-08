"""Bodies and kit several pilots share."""
from parts import *
from sdf import *


def slim(r, creases=1.0):
	"""An athletic body in a fitted suit: (torso, right arm, right leg)"""
	S, E, W, L, K, A = r.S, r.E, r.W, r.L, r.K, r.A
	da, dl = r.arm_dir, r.leg_dir
	chest = ell((0, 0.835, 0), (0.168, 0.15, 0.114))
	pec = mx(ell((0.072, 0.862, -0.072), (0.078, 0.056, 0.048)))
	delt = mx(ell(S + V(-0.02, 0.005, 0), (0.078, 0.072, 0.072)))
	torso = U(chest, pec, delt, cone((0, 0.78, 0), (0, 0.6, 0), 0.122, 0.116), ell((0, 0.5, 0), (0.15, 0.11, 0.112)),
		cone((0, 0.95, 0), (0, 1.03, 0), 0.06, 0.054), k=0.05)
	arm = U(cone(S, E, 0.057, 0.047), ell(S + da * 0.13, (0.054, 0.088, 0.054), rot=frame(da)), cone(E, W, 0.047, 0.036),
		ell(E + da * 0.07, (0.046, 0.075, 0.046), rot=frame(da)), k=0.025)
	leg = U(cone(L, K, 0.084, 0.057), ell(L + dl * 0.15 + V(0, 0, -0.012), (0.086, 0.13, 0.082), rot=frame(dl)), cone(K, A, 0.056, 0.04),
		ell(K + dl * 0.1 + V(0, 0, 0.017), (0.057, 0.095, 0.058), rot=frame(dl)), k=0.03)
	if creases > 0.0:
		torso = disp(torso, folds((0, 0.67, 0), (0, 1, 0), 0.085, 0.036, 0.0065 * creases))
		arm = disp(arm, folds(E, da, 0.075, 0.03, 0.0065 * creases))
		leg = disp(leg, folds(K, dl, 0.09, 0.034, 0.0075 * creases))
	return torso, arm, leg


def twin_tanks(JP, x=0.078, z=0.19):
	"""Two slim rocket tanks: (tanks, bands, fins, bells, spine, flames relative to JP)"""
	tank = lambda: U(cone((x, 0.66, z), (x, 0.92, z), 0.062, 0.056), ell((x, 0.955, z), (0.056, 0.095, 0.056)), k=0.012)
	tanks = mx(tank())
	bands = mx(U(*[I(off(tank(), 0.003), band(plane((0, y, 0), (0, 1, 0)), 0.0085)) for y in (0.7, 0.87)]))
	fin = mx(box((x + 0.07, 0.655, z), (0.022, 0.05, 0.0055), r=0.0035, rot=rot_z(-0.6)))
	bell = mx(U(nozzle((x, 0.66, z), (x, 0.555, z), 0.046, 0.066), cyl((x, 0.675, z), (x, 0.625, z), 0.05, 0.005)))
	spine = box((0, 0.8, z - 0.05), (0.062, 0.14, 0.02), r=0.012)
	led = mx(box((x, 0.8, z + 0.062), (0.0065, 0.04, 0.004), r=0.0025))
	flames = [[x, 0.555 - JP[1], z - JP[2]], [-x, 0.555 - JP[1], z - JP[2]]]
	return tanks, bands, fin, bell, spine, led, flames


def bomber(r):
	"""A leather bomber jacket and trousers: (jacket, torso of it, right sleeve, trousers)"""
	S, E, W, L, K, A = r.S, r.E, r.W, r.L, r.K, r.A
	da, dl = r.arm_dir, r.leg_dir
	tor_j = U(ell((0, 0.815, 0), (0.192, 0.165, 0.142)), cone((0, 0.78, 0), (0, 0.61, 0), 0.158, 0.155), mx(sphere(S + V(-0.03, 0, 0), 0.09)), k=0.06)
	tor_j = I(tor_j, keep((0, 0.585, 0), (0, 1, 0)), k=0.012)
	tor_j = disp(tor_j, folds((0, 0.68, 0), (0, 1, 0), 0.09, 0.05, 0.0075))
	arm_j = U(cone(S, E, 0.08, 0.07), cone(E, W, 0.07, 0.064), k=0.02)
	arm_j = disp(arm_j, folds(E, da, 0.08, 0.036, 0.0085))
	jacket = U(tor_j, mx(arm_j), k=0.03)
	jacket = disp(jacket, mx(groove(plane(S + da * 0.045, da), 0.0034, 0.004)))
	jacket = disp(jacket, groove(plane((0, 0.885, 0), (0, 1, 0.1)), 0.003, 0.0034))
	pel = ell((0, 0.5, 0), (0.17, 0.125, 0.13))
	leg_p = U(cone(L, K, 0.094, 0.074), cone(K, A, 0.074, 0.062), k=0.02)
	leg_p = disp(leg_p, folds(K, dl, 0.085, 0.04, 0.008))
	trousers = U(pel, mx(leg_p), k=0.03)
	trousers = disp(trousers, mx(groove(plane((L[0] + 0.09, 0, 0), (1, 0, -0.1)), 0.003, 0.0034)))
	return jacket, tor_j, arm_j, trousers

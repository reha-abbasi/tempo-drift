"""Pieces every sculpted pilot shares: a glove, a boot and jetpack bits, each sculpted once in its bone's own space."""
import numpy as np

from sdf import *


def xf(f, M):
	"""f, sculpted in the frame M (a 4x4 from that frame to the model), as a shape in model space"""
	inv = np.linalg.inv(M)
	R, t = inv[:3, :3], inv[:3, 3]
	return lambda P: f((R @ P[..., None])[..., 0] + t)


def flip(f):
	"""The same shape on the other side"""
	def g(P):
		q = P.copy()
		q[..., 0] = -q[..., 0]
		return f(q)
	return g


def hand_frame(rig, side):
	m = rig.M["Elbow" + side].copy()
	m[:3, 3] += m[:3, :3] @ V(0, -0.25, 0)
	return m


def glove(palm=1.0, curl=0.55, cuff=(0.066, 0.056), cuff_len=0.1):
	"""A gloved right hand, in its own space: the wrist up (+y), the fingers down, the palm facing the body (-x), the
	thumb forward (-z). Fingers are a little curled, as if holding something."""
	s = palm
	palm_box = box((0.0, -0.005 * s, 0.0), (0.024 * s, 0.043 * s, 0.043 * s), r=0.02 * s)
	fingers = []
	for i, (z, ln) in enumerate(((-0.031, 1.0), (-0.0105, 1.1), (0.0105, 1.04), (0.031, 0.84))):
		z *= s
		l1 = 0.03 * ln * s
		l2 = 0.026 * ln * s
		a = (-0.002, -0.042 * s, z)
		b = (a[0] - l1 * math.sin(curl * 0.6), a[1] - l1 * math.cos(curl * 0.6), z)
		c = (b[0] - l2 * math.sin(curl * 1.5), b[1] - l2 * math.cos(curl * 1.5), z)
		fingers.append(U(cap(a, b, 0.0128 * s), cap(b, c, 0.0118 * s), k=0.006))
	th_a = (-0.006, 0.005 * s, -0.036 * s)
	th_b = (-0.024 * s, -0.022 * s, -0.056 * s)
	th_c = (-0.038 * s, -0.048 * s, -0.056 * s)
	thumb = U(cone(th_a, th_b, 0.02 * s, 0.015 * s), cap(th_b, th_c, 0.0138 * s), k=0.008)
	hand = U(palm_box, *fingers, thumb, k=0.009)
	cuffs = cone((0, 0.03, 0), (0, cuff_len, 0), cuff[1], cuff[0])
	return U(hand, cuffs, k=0.03)


def boot(height=0.13, r=(0.074, 0.07), toe=(0.07, 0.052, 0.112), sole_y=-0.335):
	"""A right boot in the shin's own space (the knee at the origin, the foot forward, -z). Returns (upper, sole)"""
	ank = -0.27
	shaft = cone((0, ank + height, 0), (0, ank, 0.004), r[0], r[1])
	foot = ell((0, sole_y + toe[1] * 0.92, -0.04), toe)
	heel = ell((0, sole_y + 0.05, 0.03), (0.066, 0.052, 0.06))
	upper = U(shaft, foot, heel, k=0.05)
	upper = U(upper, tor((0, ank + height, 0), (0, 1, 0), r[0] - 0.002, 0.0125), k=0.008)
	upper = I(upper, plane((0, sole_y + 0.016, 0), (0, -1, 0)), k=0.006)
	sole = box((0, sole_y + 0.016, -0.036), (toe[0] + 0.004, 0.017, toe[2] + 0.046), r=0.0125)
	sole = I(sole, ell((0, sole_y + 0.02, -0.036), (toe[0] + 0.006, 0.06, toe[2] + 0.048)))
	def treads(P):
		return 0.0028 * smooth(sole_y + 0.008, sole_y, P[..., 1]) * (0.5 + 0.5 * np.sin(P[..., 2] * 280.0))
	return upper, disp(sole, treads)


def nozzle(top, bottom, r_top, r_bottom, wall=0.007):
	"""A rocket bell, open at the bottom"""
	top, bottom = V(top), V(bottom)
	outer = cone(top, bottom, r_top, r_bottom)
	cut = cone(top + V(0, -0.012, 0), bottom + V(0, -0.02, 0), r_top - wall, r_bottom - wall)
	body = I(outer, plane(bottom, (0, -1, 0)), k=0.003)
	return D(body, cut, k=0.002)

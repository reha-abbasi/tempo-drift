"""Sculpting pilots in code: shapes are signed-distance functions, joined smoothly into one surface, turned into a mesh
(marching cubes, then simplified), and baked with smooth normals, ambient occlusion and bone weights.
Every shape is a function f(P) -> distance, P an (N, 3) array, negative inside."""
import json
import math
import multiprocessing as mp
import os
import struct

import fast_simplification
import numpy as np
from scipy.ndimage import zoom
from skimage.measure import marching_cubes


def V(*a):
	return np.array(a[0] if len(a) == 1 else a, dtype=np.float64)


def norm(v):
	return v / np.linalg.norm(v)


# ------------------------------------------------------------------ shapes

def sphere(c, r):
	c = V(c)
	return lambda P: np.linalg.norm(P - c, axis=-1) - r


def ell(c, r, rot=None):
	"""An ellipsoid (rot: a 3x3 matrix from world to the ellipsoid's axes)"""
	c, r = V(c), V(r)
	def f(P):
		q = P - c
		if rot is not None:
			q = q @ rot
		k0 = np.linalg.norm(q / r, axis=-1)
		k1 = np.linalg.norm(q / (r * r), axis=-1) + 1e-9
		return k0 * (k0 - 1.0) / k1
	return f


def cap(a, b, r):
	return cone(a, b, r, r)


def cone(a, b, r1, r2):
	"""A round cone: a capsule from a (radius r1) to b (radius r2)"""
	a, b = V(a), V(b)
	ba = b - a
	l2 = ba.dot(ba)
	rr = r1 - r2
	a2 = l2 - rr * rr
	il2 = 1.0 / l2
	def f(P):
		pa = P - a
		y = (pa * ba).sum(-1)
		z = y - l2
		w = pa * l2 - ba[None, :] * y[..., None]
		x2 = (w * w).sum(-1)
		y2 = y * y * l2
		z2 = z * z * l2
		k = np.sign(rr) * rr * rr * x2
		out = (np.sqrt(x2 * a2 * il2) + y * rr) * il2 - r1
		m1 = np.sign(z) * a2 * z2 > k
		out = np.where(m1, np.sqrt(x2 + z2) * il2 - r2, out)
		m2 = (~m1) & (np.sign(y) * a2 * y2 < k)
		return np.where(m2, np.sqrt(x2 + y2) * il2 - r1, out)
	return f


def box(c, b, r=0.0, rot=None):
	"""A box of half sizes b with its edges rounded by r (rot: 3x3, world to the box's axes)"""
	c, b = V(c), V(b) - r
	def f(P):
		q = P - c
		if rot is not None:
			q = q @ rot
		q = np.abs(q) - b
		return np.linalg.norm(np.maximum(q, 0.0), axis=-1) + np.minimum(q.max(-1), 0.0) - r
	return f


def cyl(a, b, ra, r=0.0):
	"""A capped cylinder from a to b, radius ra, edges rounded by r"""
	a, b = V(a), V(b)
	ax = norm(b - a)
	half = np.linalg.norm(b - a) * 0.5
	m = (a + b) * 0.5
	def f(P):
		q = P - m
		y = (q * ax).sum(-1)
		x = np.linalg.norm(q - ax[None, :] * y[..., None], axis=-1)
		dx = x - (ra - r)
		dy = np.abs(y) - (half - r)
		return np.minimum(np.maximum(dx, dy), 0.0) + np.sqrt(np.maximum(dx, 0.0) ** 2 + np.maximum(dy, 0.0) ** 2) - r
	return f


def tor(c, n, R, r):
	"""A torus round c, its plane's normal n, ring radius R, tube radius r"""
	c, n = V(c), norm(V(n))
	def f(P):
		q = P - c
		y = (q * n).sum(-1)
		x = np.linalg.norm(q - n[None, :] * y[..., None], axis=-1) - R
		return np.sqrt(x * x + y * y) - r
	return f


def keep(c, n):
	"""For intersecting: the half of space that n points to"""
	c, n = V(c), norm(V(n))
	return lambda P: -((P - c) * n).sum(-1)


def plane(c, n):
	"""Distance to a plane: positive on the side n points to"""
	c, n = V(c), norm(V(n))
	return lambda P: ((P - c) * n).sum(-1)


# ------------------------------------------------------------------ joining

def _smin(a, b, k):
	if k <= 0.0:
		return np.minimum(a, b)
	h = np.maximum(k - np.abs(a - b), 0.0) / k
	return np.minimum(a, b) - h * h * k * 0.25


def U(*fs, k=0.0):
	"""Union; k: how wide the smooth blend between the shapes is"""
	def f(P):
		d = fs[0](P)
		for g in fs[1:]:
			d = _smin(d, g(P), k)
		return d
	return f


def I(f, g, k=0.0):
	"""Intersection, smoothed"""
	return lambda P: -_smin(-f(P), -g(P), k)


def D(f, g, k=0.0):
	"""f with g cut out, smoothed"""
	return lambda P: -_smin(-f(P), g(P), k)


def off(f, t):
	"""Grown by t (thicker), or shrunk if t is negative"""
	return lambda P: f(P) - t


def skin(f, t):
	"""A thin layer of thickness t on the surface of f"""
	return lambda P: np.abs(f(P)) - t


def band(p, w):
	"""Between two parallel planes, around p (a plane function), w to each side"""
	return lambda P: np.abs(p(P)) - w


def mx(f):
	"""Mirrored in x (model the +x side only)"""
	def g(P):
		q = P.copy()
		q[..., 0] = np.abs(q[..., 0])
		return f(q)
	return g


def disp(f, g):
	"""f with g(P) added to the distance: positive pushes the surface in"""
	return lambda P: f(P) + g(P)


def smooth(a, b, x):
	t = np.clip((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def ribs(c, ax, half, period, amp):
	"""Bellows round a joint: rings along ax over +- half around c"""
	c, ax = V(c), norm(V(ax))
	def g(P):
		s = ((P - c) * ax).sum(-1)
		win = 1.0 - smooth(half * 0.7, half, np.abs(s))
		return amp * (0.5 + 0.5 * np.cos(s / period * math.tau)) * win
	return g


def groove(p, w, depth):
	"""A seam: a narrow dent along a plane function p"""
	def g(P):
		x = p(P) / w
		return depth * np.exp(-x * x)
	return g


def folds(c, ax, half, period, amp, twist=0.03):
	"""Creases in cloth round a joint: rings that wander as they go round the limb"""
	c, ax = V(c), norm(V(ax))
	e1 = norm(np.cross(ax, V(0.3, 0.2, 1.0)))
	e2 = np.cross(ax, e1)
	def g(P):
		q = P - c
		s = (q * ax).sum(-1)
		a = np.arctan2(q @ e1, q @ e2)
		win = 1.0 - smooth(half * 0.55, half, np.abs(s))
		w = np.sin((s + twist * np.sin(a * 2.0 + s * 20.0)) / period * math.pi)
		return amp * win * w * w
	return g


def ring2d(c, R, w):
	"""A ring drawn on the xy plane and pushed through in z"""
	c = V(c)
	def f(P):
		x = np.hypot(P[..., 0] - c[0], P[..., 1] - c[1]) - R
		return np.abs(x) - w
	return f


def ribbon(pts, wave, t, w):
	"""A strip of cloth along a smooth line in the xz plane (pts: x, y, z), hanging y-wise: t half thick, w half wide"""
	p = np.array(pts, float)
	xz = p[:, [0, 2]]
	# (a Catmull-Rom through the points)
	q = [xz[0]]
	ys = [p[0, 1]]
	n = len(xz)
	for i in range(n - 1):
		p0, p1, p2, p3 = xz[max(i - 1, 0)], xz[i], xz[i + 1], xz[min(i + 2, n - 1)]
		y0, y1, y2, y3 = p[max(i - 1, 0), 1], p[i, 1], p[i + 1, 1], p[min(i + 2, n - 1), 1]
		for u in np.linspace(0.0, 1.0, 9)[1:]:
			q.append(0.5 * (2 * p1 + (p2 - p0) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (3 * p1 - p0 - 3 * p2 + p3) * u ** 3))
			ys.append(0.5 * (2 * y1 + (y2 - y0) * u + (2 * y0 - 5 * y1 + 4 * y2 - y3) * u * u + (3 * y1 - y0 - 3 * y2 + y3) * u ** 3))
	q = np.array(q)
	ys = np.array(ys)
	a = q[:-1]
	ba = q[1:] - a
	l2 = (ba * ba).sum(-1)
	def f(P):
		xzp = P[..., [0, 2]]
		best = np.full(P.shape[:-1], 1e9)
		y_at = np.zeros(P.shape[:-1])
		arc = np.zeros(P.shape[:-1])
		acc = 0.0
		for i in range(a.shape[0]):
			pa = xzp - a[i]
			h = np.clip((pa @ ba[i]) / l2[i], 0.0, 1.0)
			d = np.linalg.norm(pa - h[..., None] * ba[i], axis=-1)
			m = d < best
			best = np.where(m, d, best)
			y_at = np.where(m, ys[i] + (ys[i + 1] - ys[i]) * h, y_at)
			arc = np.where(m, acc + h * math.sqrt(l2[i]), arc)
			acc += math.sqrt(l2[i])
		dy = np.abs(P[..., 1] - y_at - wave(arc)) - w
		dx = best - t
		return np.minimum(np.maximum(dx, dy), 0.0) + np.sqrt(np.maximum(dx, 0.0) ** 2 + np.maximum(dy, 0.0) ** 2) - 0.003
	return f


def quilt(ax1, ax2, period, depth):
	"""Puffy quilted squares"""
	ax1, ax2 = norm(V(ax1)), norm(V(ax2))
	def g(P):
		u = np.sin((P @ ax1) / period * math.pi)
		v = np.sin((P @ ax2) / period * math.pi)
		return depth * (1.0 - np.minimum(np.abs(u), np.abs(v)) ** 0.5)
	return g


def rot_z(a):
	c, s = math.cos(a), math.sin(a)
	return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def rot_x(a):
	c, s = math.cos(a), math.sin(a)
	return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_y(a):
	c, s = math.cos(a), math.sin(a)
	return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def frame(y_dir, z_hint=(0, 0, 1)):
	"""A 3x3 whose columns are the x, y and z axes of a frame with its y along y_dir"""
	y = norm(V(y_dir))
	x = norm(np.cross(y, V(z_hint)))
	z = np.cross(x, y)
	return np.stack([x, y, z], axis=1)


# ------------------------------------------------------------------ the skeleton (the same joints as the old pilots)

class Rig:
	"""The joints where the game's poses expect them (pilot_pose.gd, rooftop.gd, rescue_plane.gd). The body is modelled
	with the arms and legs held away from it, so shapes don't melt together; bones[...] are in that pose."""
	HIP = V(0, 0.5, 0)
	NECK = V(0, 1.08, 0)
	SHOULDER = V(0.22, 0.92, 0)
	LEG = V(0.09, 0.48, 0)

	def __init__(self, arm_out=38.0, leg_out=7.0, shoulder_x=0.22, leg_x=0.09):
		a, b = math.radians(arm_out), math.radians(leg_out)
		self.SHOULDER = V(shoulder_x, 0.92, 0)
		self.LEG = V(leg_x, 0.48, 0)
		self.arm_dir = V(math.sin(a), -math.cos(a), 0)
		self.leg_dir = V(math.sin(b), -math.cos(b), 0)
		self.S = self.SHOULDER
		self.E = self.S + self.arm_dir * 0.25
		self.W = self.S + self.arm_dir * 0.47
		self.Hd = self.S + self.arm_dir * 0.50
		self.L = self.LEG
		self.K = self.L + self.leg_dir * 0.30
		self.A = self.K + self.leg_dir * 0.27
		self.arm_rot = rot_z(a)
		self.leg_rot = rot_z(b)
		M = {}
		def m(b3, o):
			x = np.eye(4)
			x[:3, :3] = b3
			x[:3, 3] = o
			return x
		M["Hip"] = m(np.eye(3), self.HIP)
		M["Torso"] = m(np.eye(3), self.HIP)
		M["Head"] = m(np.eye(3), self.NECK)
		for s, nm in ((-1.0, "L"), (1.0, "R")):
			mirror = V(s, 1, 1)
			ang = a * s
			leg_ang = b * s
			sh = self.S * mirror
			M["Shoulder" + nm] = m(rot_z(ang), sh)
			M["Elbow" + nm] = m(rot_z(ang), sh + (rot_z(ang) @ V(0, -0.25, 0)))
			lg = self.L * mirror
			M["Leg" + nm] = m(rot_z(leg_ang), lg)
			M["Knee" + nm] = m(rot_z(leg_ang), lg + (rot_z(leg_ang) @ V(0, -0.3, 0)))
		self.M = M

	BONES = ["Hip", "Torso", "Head", "ShoulderL", "ElbowL", "ShoulderR", "ElbowR", "LegL", "KneeL", "LegR", "KneeR"]
	PARENT = {"Torso": "Hip", "Head": "Torso", "ShoulderL": "Torso", "ElbowL": "ShoulderL", "ShoulderR": "Torso",
		"ElbowR": "ShoulderR", "LegL": "Hip", "KneeL": "LegL", "LegR": "Hip", "KneeR": "LegR"}
	PATH = {"Hip": "Hip", "Torso": "Hip/Torso", "Head": "Hip/Torso/Head", "ShoulderL": "Hip/Torso/ShoulderL",
		"ElbowL": "Hip/Torso/ShoulderL/Elbow", "ShoulderR": "Hip/Torso/ShoulderR", "ElbowR": "Hip/Torso/ShoulderR/Elbow",
		"LegL": "Hip/LegL", "KneeL": "Hip/LegL/Knee", "LegR": "Hip/LegR", "KneeR": "Hip/LegR/Knee"}

	def capsules(self, torso_r=0.15, hip_r=0.13, arm=(0.07, 0.055), leg=(0.095, 0.07)):
		"""What each bone moves, as capsules: (bone, a, b, radius)"""
		out = [("Hip", V(0, 0.46, 0), V(0, 0.56, 0), hip_r), ("Torso", V(0, 0.72, 0), V(0, 0.92, 0), torso_r),
			("Head", V(0, 1.05, 0), V(0, 1.2, 0), 0.12)]
		for s, nm in ((-1.0, "L"), (1.0, "R")):
			m = V(s, 1, 1)
			out.append(("Shoulder" + nm, self.S * m, self.E * m, arm[0]))
			out.append(("Elbow" + nm, self.E * m, self.Hd * m, arm[1]))
			out.append(("Leg" + nm, self.L * m, self.K * m, leg[0]))
			out.append(("Knee" + nm, self.K * m, (self.A + V(0, -0.1, -0.06)) * m, leg[1]))
		return out


# ------------------------------------------------------------------ meshing

def _sample(f, lo, hi, h, coarse=4):
	H = h * coarse
	nc = np.ceil((hi - lo) / H).astype(int) + 1
	axes = [np.linspace(lo[i], lo[i] + H * (nc[i] - 1), nc[i], dtype=np.float32) for i in range(3)]
	g = np.stack(np.meshgrid(*axes, indexing="ij"), -1).reshape(-1, 3)
	dc = np.empty(g.shape[0], np.float32)
	for i in range(0, g.shape[0], 400000):
		dc[i:i + 400000] = f(g[i:i + 400000].astype(np.float64))
	dc = dc.reshape(nc)
	nf = (nc - 1) * coarse + 1
	d = zoom(dc, [nf[i] / nc[i] for i in range(3)], order=1, grid_mode=False, mode="nearest").astype(np.float32)
	ix = np.argwhere(np.abs(d) < H * 1.1)
	pts = lo + ix.astype(np.float64) * h
	for i in range(0, pts.shape[0], 400000):
		j = ix[i:i + 400000]
		d[j[:, 0], j[:, 1], j[:, 2]] = f(pts[i:i + 400000])
	return d


def gradient(f, P, e=0.0015):
	g = np.empty_like(P)
	for a in range(3):
		o = np.zeros(3)
		o[a] = e
		g[:, a] = f(P + o) - f(P - o)
	return g / (2.0 * e)


def mesh(f, lo, hi, h, target):
	"""The surface of f inside the box lo..hi: vertices, triangles"""
	lo, hi = V(lo), V(hi)
	d = _sample(f, lo, hi, h)
	if d.min() > 0.0 or d.max() < 0.0:
		return np.zeros((0, 3)), np.zeros((0, 3), int)
	v, t, _n, _s = marching_cubes(d, level=0.0, spacing=(h, h, h))
	v = v + lo
	# marching cubes winds triangles outward along the gradient only one way round; set it right by hand below
	if t.shape[0] > target:
		v, t = v.astype(np.float32), t.astype(np.int32)
		for agg in (2.5, 3.5, 4.5):
			v, t = fast_simplification.simplify(v, t, target_count=target, agg=agg, lossless=False)
			if t.shape[0] <= target * 1.15:
				break
		v = v.astype(np.float64)
	for _i in range(3):
		g = gradient(f, v)
		v -= g * (f(v) / np.maximum((g * g).sum(-1), 1e-6))[:, None]
	return v, t


def fix_winding(v, t, n):
	"""Triangles wound so their face normal agrees with the vertex normals (Godot's front faces are clockwise)"""
	a, b, c = v[t[:, 0]], v[t[:, 1]], v[t[:, 2]]
	fn = np.cross(b - a, c - a)
	vn = n[t[:, 0]] + n[t[:, 1]] + n[t[:, 2]]
	flip = (fn * vn).sum(-1) > 0.0     # (counter-clockwise when seen from outside: flip)
	t = t.copy()
	t[flip] = t[flip][:, [0, 2, 1]]
	return t


def ao(scene, v, n, strength=1.0):
	"""How much of the sky a point sees, from the distance field: 0 dark .. 1 open"""
	occ = np.zeros(v.shape[0])
	w = 1.0
	total = 0.0
	for h in (0.008, 0.018, 0.035, 0.06, 0.1):
		d = scene(v + n * h)
		occ += w * np.maximum(h - d, 0.0) / h
		total += w
		w *= 0.75
	return np.clip(1.0 - occ / total * 1.6 * strength, 0.12, 1.0)


def curvature(f, v, e=0.006):
	"""Rounded edges positive, creases negative (for worn edges and dirt in the seams)"""
	lap = -6.0 * f(v)
	for a in range(3):
		o = np.zeros(3)
		o[a] = e
		lap += f(v + o) + f(v - o)
	return lap / (e * e)


def bone_weights(v, caps, names, tau=0.011):
	ds = []
	for bone, a, b, r in caps:
		ds.append(cap(a, b, r)(v))
	ds = np.stack(ds, -1)
	w = np.exp(-np.maximum(ds - ds.min(-1, keepdims=True), 0.0) / tau)
	idx = np.argsort(-w, axis=-1)[:, :4]
	wt = np.take_along_axis(w, idx, -1)
	wt[wt < 0.01] = 0.0
	wt /= wt.sum(-1, keepdims=True)
	bi = np.array([names.index(c[0]) for c in caps])[idx]
	return bi, wt


# ------------------------------------------------------------------ a character

class Layer:
	def __init__(self, name, f, mat, lo, hi, tris, bone=None, color=(1, 1, 1), h=0.004, paint=None, wear=0.0, ao_k=1.0, hidden_by=()):
		"""bone: a bone's name for a rigid part (it moves with that one bone); None: skinned to the whole skeleton"""
		self.__dict__.update(locals())
		del self.__dict__["self"]


_C = None


def _do_layer(i):
	return _build_layer(_C, i)


def _build_layer(c, i):
	l = c["layers"][i]
	v, t = mesh(l.f, l.lo, l.hi, l.h, l.tris)
	if v.shape[0] == 0:
		return None
	n = gradient(l.f, v)
	n /= np.linalg.norm(n, axis=-1, keepdims=True) + 1e-9
	# (drop what another layer covers completely)
	for other in l.hidden_by:
		o = next(x for x in c["layers"] if x.name == other)
		inside = o.f(v) < -0.004
		keep = ~(inside[t[:, 0]] & inside[t[:, 1]] & inside[t[:, 2]])
		t = t[keep]
	used, inv = np.unique(t, return_inverse=True)
	t = inv.reshape(t.shape)
	v, n = v[used], n[used]
	t = fix_winding(v, t, n)
	scene = c["scene"]
	occ = ao(scene, v, n, l.ao_k)
	col = np.tile(V(l.color), (v.shape[0], 1))
	if l.paint is not None:
		col = l.paint(v, col)
	if l.wear:
		k = np.clip(curvature(l.f, v), -60.0, 60.0) / 60.0
		col = col * (1.0 + l.wear * k[:, None])
	col = np.clip(col * occ[:, None], 0.0, 4.0)
	bones, wts = None, None
	if l.bone is None:
		bones, wts = bone_weights(v, c["caps"], c["rig"].BONES, c.get("tau", 0.011))
		v_out, n_out = v, n
	else:
		m = np.linalg.inv(c["rig"].M[l.bone] if l.bone in c["rig"].M else c["frames"][l.bone])
		v_out = (m[:3, :3] @ v.T).T + m[:3, 3]
		n_out = (m[:3, :3] @ n.T).T
	return i, v_out, n_out, col, bones, wts, t


def write(out_dir, c, results):
	os.makedirs(out_dir, exist_ok=True)
	rig = c["rig"]
	meta = {"bones": [], "layers": [], "materials": c["materials"], "flames": c["flames"], "jetpack": c.get("jetpack"),
		"shoulder_x": float(rig.SHOULDER[0]), "leg_x": float(rig.LEG[0]), "bone_flames": c.get("bone_flames", [])}
	for b in rig.BONES:
		m = rig.M[b]
		meta["bones"].append({"name": b, "parent": rig.PARENT.get(b, ""), "path": rig.PATH[b],
			"model": [float(x) for x in np.concatenate([m[:3, 0], m[:3, 1], m[:3, 2], m[:3, 3]])]})
	tot = 0
	for r in results:
		if r is None:
			continue
		li, v, n, col, bones, wts, t = r
		l = c["layers"][li]
		nv, nt = v.shape[0], t.shape[0]
		tot += nt
		with open(os.path.join(out_dir, l.name + ".bin"), "wb") as fp:
			fp.write(struct.pack("<ii", nv, nt))
			fp.write(v.astype(np.float32).tobytes())
			fp.write(n.astype(np.float32).tobytes())
			fp.write(np.concatenate([col, np.ones((nv, 1))], axis=1).astype(np.float32).tobytes())
			if bones is not None:
				fp.write(bones.astype(np.int32).tobytes())
				fp.write(wts.astype(np.float32).tobytes())
			fp.write(t.astype(np.int32).tobytes())
		meta["layers"].append({"name": l.name, "mat": l.mat, "bone": l.bone or "", "skinned": bones is not None, "verts": nv, "tris": nt})
		print("  %-14s %6d tris  %s" % (l.name, nt, l.mat))
	with open(os.path.join(out_dir, "meta.json"), "w") as fp:
		json.dump(meta, fp)
	print("  total %d triangles" % tot)


def bake(c, out_dir, jobs=8):
	"""Mesh every layer and write it out for tools/editor/build_pilots.gd"""
	global _C
	_C = c
	layers = c["layers"]
	def scene(P):
		d = layers[0].f(P)
		for l in layers[1:]:
			d = np.minimum(d, l.f(P))
		return d
	c["scene"] = scene
	ctx = mp.get_context("fork")
	with ctx.Pool(jobs) as pool:
		results = pool.map(_do_layer, range(len(layers)))
	write(out_dir, c, results)

class_name KatanaClips
extends RefCounted
## Fábrica dos clipes de golpe da katana a partir do clipe `Sword_Attack` do pacote
## Universal Animation Library (Quaternius, CC0).
##
## O pacote tem UM clipe de espada. Cada golpe é derivado dele por recorte de trecho e,
## opcionalmente, espelhamento esquerda/direita; velocidade e janelas ficam em StrikeData.
## Os clipes derivados são amostrados a 60 Hz em novos recursos Animation.

const SOURCE_CLIP := "Sword_Attack"
const SAMPLE_STEP := 1.0 / 60.0

## Fórmula de espelhamento do quaternion local (x, y, z, w) para ossos de eixos simétricos.
enum Mirror { NONE, YZ_FLIP, XZ_FLIP, XY_FLIP }


## Recorta [t0, t1] de `src` (tempo da origem) e devolve um clipe começando em 0.
static func derive(src: Animation, t0: float, t1: float, mirror := Mirror.NONE) -> Animation:
	var out := Animation.new()
	out.length = t1 - t0
	out.loop_mode = Animation.LOOP_NONE
	var steps := maxi(int(ceil((t1 - t0) / SAMPLE_STEP)), 1)
	for i in src.get_track_count():
		var type := src.track_get_type(i)
		if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_SCALE_3D:
			continue
		var path := src.track_get_path(i)
		var out_path := NodePath(_mirror_bone_path(String(path))) if mirror != Mirror.NONE else path
		var ti := out.add_track(type)
		out.track_set_path(ti, out_path)
		for s in steps + 1:
			var t := minf(s * SAMPLE_STEP, t1 - t0)
			var st := t0 + t
			match type:
				Animation.TYPE_POSITION_3D:
					var p := src.position_track_interpolate(i, st)
					if mirror != Mirror.NONE:
						p.x = -p.x
					out.position_track_insert_key(ti, t, p)
				Animation.TYPE_ROTATION_3D:
					var q := src.rotation_track_interpolate(i, st)
					if mirror != Mirror.NONE:
						q = _mirror_quat(q, mirror)
					out.rotation_track_insert_key(ti, t, q)
				_:
					out.scale_track_insert_key(ti, t, src.scale_track_interpolate(i, st))
	return out


static func _mirror_quat(q: Quaternion, mode: Mirror) -> Quaternion:
	match mode:
		Mirror.YZ_FLIP:
			return Quaternion(q.x, -q.y, -q.z, q.w)
		Mirror.XZ_FLIP:
			return Quaternion(-q.x, q.y, -q.z, q.w)
		Mirror.XY_FLIP:
			return Quaternion(-q.x, -q.y, q.z, q.w)
	return q


## "Armature/Skeleton3D:hand_r" -> "Armature/Skeleton3D:hand_l" (e vice-versa).
static func _mirror_bone_path(path: String) -> String:
	var parts := path.rsplit(":", true, 1)
	if parts.size() < 2:
		return path
	var bone := parts[1]
	if bone.ends_with("_r"):
		bone = bone.trim_suffix("_r") + "_l"
	elif bone.ends_with("_l"):
		bone = bone.trim_suffix("_l") + "_r"
	return parts[0] + ":" + bone

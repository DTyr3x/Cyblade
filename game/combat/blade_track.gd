class_name BladeTrack
extends RefCounted
## Trajetória da lâmina de um golpe, calculada do CLIPE e guardada em passos de 120 Hz, no espaço do corpo.
## A pose do esqueleto na tela só existe por quadro de render; se o acerto dependesse dela, o alcance mudaria
## com o FPS. Com esta tabela o acerto depende só do tempo do golpe e da posição da cápsula, na física.

const STEP := 1.0 / 120.0

var origins := PackedVector3Array()
var axes := PackedVector3Array()


## `to_body`: do esqueleto ao corpo. `grip`: da mão à katana. `hand`: osso da mão.
static func bake(anim: Animation, skeleton: Skeleton3D, hand: int, to_body: Transform3D, grip: Transform3D) -> BladeTrack:
	var pos_tracks := {}
	var rot_tracks := {}
	for i in anim.get_track_count():
		var bone := skeleton.find_bone(String(anim.track_get_path(i).get_subname(0)))
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D:
			pos_tracks[bone] = i
		elif anim.track_get_type(i) == Animation.TYPE_ROTATION_3D:
			rot_tracks[bone] = i
	var chain: Array[int] = []
	var b := hand
	while b >= 0:
		chain.push_front(b)
		b = skeleton.get_bone_parent(b)
	var out := BladeTrack.new()
	for s in int(ceil(anim.length / STEP)) + 1:
		var t := minf(s * STEP, anim.length)
		var g := to_body
		for bone in chain:
			var rest := skeleton.get_bone_rest(bone)
			var p := anim.position_track_interpolate(pos_tracks[bone], t) if pos_tracks.has(bone) else rest.origin
			var q := anim.rotation_track_interpolate(rot_tracks[bone], t) if rot_tracks.has(bone) else rest.basis.get_rotation_quaternion()
			g = g * Transform3D(Basis(q).scaled(rest.basis.get_scale()), p)
		var blade := g * grip
		out.origins.append(blade.origin)
		out.axes.append(blade.basis.y)
	return out


## [base, ponta] no mundo, a `from` e `to` metros do punho, no tempo de clipe `t`.
func segment(t: float, from: float, to: float, body: Transform3D) -> Array[Vector3]:
	var x := clampf(t / STEP, 0.0, origins.size() - 1.0)
	var i := mini(int(x), origins.size() - 2)
	var f := x - i
	var o := body * origins[i].lerp(origins[i + 1], f)
	var axis := body.basis * axes[i].lerp(axes[i + 1], f).normalized()
	return [o + axis * from * axes[i].length(), o + axis * to * axes[i].length()]

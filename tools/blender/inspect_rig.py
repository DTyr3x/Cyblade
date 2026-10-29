# Inspeciona o rig do UAL no Blender (sem interface):
#   blender -b --python tools/blender/inspect_rig.py -- <caminho do .glb>
import sys
import bpy

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path, bone_heuristic="FORTUNE")
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
print("ARM", arm.name, "loc", tuple(round(v, 4) for v in arm.location), "rot", tuple(round(v, 4) for v in arm.rotation_euler), "scale", tuple(round(v, 4) for v in arm.scale))
print("parent", arm.parent.name if arm.parent else None)
for o in bpy.data.objects:
    print("OBJ", o.name, o.type, tuple(round(v, 3) for v in o.matrix_world.to_translation()), tuple(round(v, 3) for v in o.matrix_world.to_scale()))
names = ["root", "pelvis", "spine_01", "spine_03", "neck_01", "Head", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l", "thigh_r", "calf_r", "foot_r", "ball_r", "thigh_l", "calf_l", "foot_l"]
for n in names:
    b = arm.data.bones.get(n)
    if b is None:
        print("MISSING", n)
        continue
    m = arm.matrix_world @ b.matrix_local
    print("BONE", n, "parent", b.parent.name if b.parent else None, "head", tuple(round(v, 3) for v in m.to_translation()), "Yaxis", tuple(round(v, 3) for v in m.to_3x3().col[1]), "len", round(b.length, 3))
print("ACTIONS", len(bpy.data.actions), [a.name for a in bpy.data.actions][:5])
for n in ["hand_r", "hand_l", "foot_r", "pelvis"]:
    b = arm.data.bones[n]
    m = (arm.matrix_world @ b.matrix_local).to_3x3()
    print("AXES", n, "X", tuple(round(v, 3) for v in m.col[0]), "Y", tuple(round(v, 3) for v in m.col[1]), "Z", tuple(round(v, 3) for v in m.col[2]))
print("FINGERS", [b.name for b in arm.data.bones if b.parent and b.parent.name == "hand_r"])

# Converts the Rigify raccoon rig into a single-root, deform-only skeleton
# with baked animation, then exports FBX files for Roblox.
# Run on a COPY of the file: it deletes the Rigify rig from the open scene.
#   blender --background RakunFBX.blend --python rakun_to_roblox.py
# or open RakunFBX.blend, Scripting tab -> open this file -> Run Script.
#   Optional env vars: RIG_NAME=Squirrel RIG_ACTIONS="Idle:Idle,Walking:Walk:1:60"
#   (source:export name[:first frame:last frame], defaults to the action's key range)
#   RIG_FBX=Deer.fbx starts from an FBX exported from a Rigify rig instead of a .blend.
import bpy, bmesh, os
from mathutils import Matrix

SRC_RIG = 'rig'
ACTIONS = [p.split(':') for p in os.environ.get('RIG_ACTIONS', 'Idlee:Idle,Walking:Walk').split(',')]
NEW_NAME = os.environ.get('RIG_NAME', 'Rakun')
OUT_DIR = os.environ.get('RAKUN_OUT') or bpy.path.abspath('//roblox_export')

if os.environ.get('RIG_FBX'):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.environ['RIG_FBX'])

scene = bpy.context.scene
view_layer = bpy.context.view_layer
rig = bpy.data.objects[SRC_RIG]
bones = rig.data.bones
meta = bpy.data.objects.get('metarig')
meshes = [o for o in bpy.data.objects if o.type == 'MESH'
          and any(m.type == 'ARMATURE' and m.object == rig for m in o.modifiers)]


def clean(n):
    return 'Root' if n == 'root' else (n[4:] if n.startswith('DEF-') else n)


# FBX import marks every bone as deform, so prefer Rigify's DEF- naming when present.
HAS_DEF_PREFIX = any(b.name.startswith('DEF-') for b in bones)


def is_def(b):
    return b.name.startswith('DEF-') if HAS_DEF_PREFIX else b.use_deform


export = ['root'] + [b.name for b in bones if is_def(b)]


def deform_subtree(name):
    out, stack = set(), [bones[name]]
    while stack:
        b = stack.pop()
        out.add(b.name)
        stack.extend(c for c in b.children if is_def(c))
    return out


def find_parent(name):
    b = bones[name]
    if name == 'root':
        return None
    if b.parent and is_def(b.parent):
        return b.parent.name
    sub = deform_subtree(name)
    # Rigify parents each DEF bone under ORG bones; the ORG bone's DEF twin is the anatomical parent.
    p = b.parent
    while p:
        if p.name.startswith('ORG-'):
            cand = 'DEF-' + p.name[4:]
            if cand in bones and is_def(bones[cand]) and cand not in sub:
                return cand
        p = p.parent
    if meta:
        mb = meta.data.bones.get(name[4:])
        p = mb.parent if mb else None
        while p:
            cand = 'DEF-' + p.name
            if cand in bones and cand not in sub:
                return cand
            p = p.parent
    return 'root'


parent_of = {n: find_parent(n) for n in export}
for n in export:
    seen, p = {n}, parent_of[n]
    while p:
        assert p not in seen, f"cycle at {n}"
        seen.add(p)
        p = parent_of[p]
roots = [n for n in export if parent_of[n] is None]
assert roots == ['root'], roots
print("REPORT reparented:", {clean(n): clean(parent_of[n]) for n in export
                             if n != 'root' and (bones[n].parent is None or bones[n].parent.name != parent_of[n])})

# --- capture evaluated pose of every exported bone (and mesh verts) for each frame ---
dg = bpy.context.evaluated_depsgraph_get()
if rig.animation_data is None:
    rig.animation_data_create()
rig.animation_data.use_nla = False  # bake only the chosen action, nothing blended in from NLA
caps, mesh_caps, max_scale_dev = {}, {}, 0.0


def mesh_world_verts(o):
    ev = o.evaluated_get(dg)
    me = ev.to_mesh()
    vs = [ev.matrix_world @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    return vs


for src, dst, *rng in ACTIONS:
    act = bpy.data.actions[src]
    rig.animation_data.action = act
    f0, f1 = (int(x) for x in rng) if rng else (int(round(x)) for x in act.frame_range)
    frames, mframes = {}, {}
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        ev = rig.evaluated_get(dg)
        mats = {}
        for n in export:
            loc, rot, sca = ev.pose.bones[n].matrix.decompose()
            max_scale_dev = max(max_scale_dev, *(abs(s - 1) for s in sca))
            mats[n] = Matrix.LocRotScale(loc, rot, None)  # Roblox bones carry no scale
        frames[f] = mats
        mframes[f] = {o.name: mesh_world_verts(o) for o in meshes}
    caps[dst] = (f0, f1, frames)
    mesh_caps[dst] = mframes
print(f"REPORT max bone scale deviation dropped (stretch): {max_scale_dev:.4f}")

# --- build clean armature ---
arm_data = bpy.data.armatures.new(NEW_NAME)
new = bpy.data.objects.new(NEW_NAME, arm_data)
scene.collection.objects.link(new)
new.matrix_world = rig.matrix_world.copy()
new.show_in_front = True
for o in view_layer.objects:
    o.select_set(False)
view_layer.objects.active = new
new.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
ebs = arm_data.edit_bones
for n in export:
    b = bones[n]
    eb = ebs.new(clean(n))
    eb.head, eb.tail = b.head_local, b.tail_local
    eb.matrix = b.matrix_local
    eb.use_deform = True
for n in export:
    p = parent_of[n]
    if p:
        eb = ebs[clean(n)]
        eb.parent = ebs[clean(p)]
        eb.use_connect = False  # connected bones ignore location keys, which the bake needs
bpy.ops.object.mode_set(mode='OBJECT')
rest_err = max(abs(x) for n in export
               for row in (arm_data.bones[clean(n)].matrix_local - bones[n].matrix_local) for x in row)
print(f"REPORT rest pose max matrix error: {rest_err:.2e}")

# --- bake animation onto the clean armature ---
rest = {n: bones[n].matrix_local for n in export}
new.animation_data_create()
for pb in new.pose.bones:
    pb.rotation_mode = 'QUATERNION'
new_actions = {}
for dst, (f0, f1, frames) in caps.items():
    act = bpy.data.actions.new(dst)
    act.use_fake_user = True
    new.animation_data.action = act
    prevq = {}
    for f in range(f0, f1 + 1):
        M = frames[f]
        for n in export:
            p = parent_of[n]
            if p is None:
                basis = rest[n].inverted() @ M[n]
            else:
                basis = (rest[p].inverted() @ rest[n]).inverted() @ M[p].inverted() @ M[n]
            loc, q, _ = basis.decompose()
            if n in prevq and q.dot(prevq[n]) < 0:
                q.negate()
            prevq[n] = q
            pb = new.pose.bones[clean(n)]
            pb.location, pb.rotation_quaternion, pb.scale = loc, q, (1, 1, 1)
            for path in ('location', 'rotation_quaternion'):
                pb.keyframe_insert(path, frame=f, group=pb.name)
    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'LINEAR'
    new_actions[dst] = (act, f0, f1)

# --- move meshes onto the clean armature (bake their object scale into vertices) ---
for o in meshes:
    if o.data.users > 1:
        o.data = o.data.copy()
    mw = o.matrix_world.copy()
    o.parent = None
    o.data.transform(mw)
    if mw.determinant() < 0:  # mirrored object: baking the negative scale turns faces inside out
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
        bm.to_mesh(o.data)
        bm.free()
    o.matrix_world = Matrix()
    o.parent = new
    o.matrix_parent_inverse = new.matrix_world.inverted()
    for m in o.modifiers:
        if m.type == 'ARMATURE' and m.object == rig:
            m.object = new
    for vg in list(o.vertex_groups):
        if vg.name.startswith('DEF-'):
            vg.name = vg.name[4:]
        elif vg.name not in arm_data.bones:
            o.vertex_groups.remove(vg)

# Roblox builds the skeleton from one skinned mesh; a separate mesh using only head bones
# (the eyes) gave a rig with just the spine. Merge into one mesh so every bone is used.
body = max(meshes, key=lambda o: len(o.data.vertices))
others = [o for o in meshes if o != body]
ref_order = [body.name] + [o.name for o in others]
for o in view_layer.objects:
    o.select_set(o in meshes)
view_layer.objects.active = body
if others:
    bpy.ops.object.join()
body.name = body.data.name = NEW_NAME + 'Mesh'
meshes = [body]
# Roblox keeps at most 4 bone influences per vertex
bpy.ops.object.vertex_group_limit_total(group_select_mode='BONE_DEFORM', limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode='BONE_DEFORM', lock_active=False)

# --- remove the Rigify rig, metarig, widgets and old actions ---
for o in list(bpy.data.objects):
    if o in (rig, meta) or o.name.startswith('WGT-'):
        bpy.data.objects.remove(o, do_unlink=True)
keep = {a for a, _, _ in new_actions.values()}
for a in list(bpy.data.actions):
    if a not in keep:
        bpy.data.actions.remove(a)
for dst, (act, _, _) in new_actions.items():
    act.name = dst  # drop the .001 suffix from clashing with the removed source action
for c in list(bpy.data.collections):
    if c.name.startswith('WGTS') and not c.all_objects:
        bpy.data.collections.remove(c)
if 'rig_ui.py' in bpy.data.texts:
    bpy.data.texts.remove(bpy.data.texts['rig_ui.py'])
bpy.data.orphans_purge(do_recursive=True)

# --- verify: bone poses and mesh deformation vs the original Rigify result ---
dg = bpy.context.evaluated_depsgraph_get()
for dst, (act, f0, f1) in new_actions.items():
    new.animation_data.action = act
    bone_err = mesh_err = 0.0
    for f in range(f0, f1 + 1):
        scene.frame_set(f)
        ev = new.evaluated_get(dg)
        for n in export:
            d = ev.pose.bones[clean(n)].matrix - caps[dst][2][f][n]
            bone_err = max(bone_err, max(abs(x) for row in d for x in row))
        ref = [v for name in ref_order for v in mesh_caps[dst][f][name]]
        cur = mesh_world_verts(body)
        assert len(cur) == len(ref), (len(cur), len(ref))
        mesh_err = max(mesh_err, max((a - b).length for a, b in zip(cur, ref)))
    print(f"REPORT {dst}: frames {f0}-{f1}, max bone matrix error {bone_err:.2e}, "
          f"max mesh vertex drift vs Rigify {mesh_err * 100:.2f} cm")

# --- export ---
os.makedirs(OUT_DIR, exist_ok=True)


def export_fbx(path, act=None, f0=None, f1=None):
    for o in view_layer.objects:
        o.select_set(o == new or o in meshes)
    view_layer.objects.active = new
    new.animation_data.action = act
    if act is None:
        for pb in new.pose.bones:
            pb.matrix_basis = Matrix()
    else:
        scene.frame_start, scene.frame_end = f0, f1
    scene_name = scene.name
    scene.name = act.name if act else scene_name  # FBX take name comes from the scene
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, object_types={'ARMATURE', 'MESH'},
        use_mesh_modifiers=True, mesh_smooth_type='FACE', add_leaf_bones=False,
        use_armature_deform_only=True, armature_nodetype='NULL',
        primary_bone_axis='Y', secondary_bone_axis='X',
        bake_anim=act is not None, bake_anim_use_all_actions=False,
        bake_anim_use_nla_strips=False, bake_anim_force_startend_keying=True,
        bake_anim_step=1.0, bake_anim_simplify_factor=0.0,
        apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE', path_mode='STRIP')
    scene.name = scene_name
    print("REPORT exported", path)


export_fbx(os.path.join(OUT_DIR, f'{NEW_NAME}_Roblox.fbx'))
for dst, (act, f0, f1) in new_actions.items():
    export_fbx(os.path.join(OUT_DIR, f'{NEW_NAME}_{dst}.fbx'), act, f0, f1)
new.animation_data.action = new_actions['Idle'][0]
scene.frame_start, scene.frame_end = new_actions['Idle'][1], new_actions['Idle'][2]

if bpy.app.background:
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR, f'{NEW_NAME}_Roblox.blend'),
                                relative_remap=False)
    print("REPORT saved blend")

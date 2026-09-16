/// Load an .obj model from a filepath. Currently reads vertices (`v` components) and faces (`f` components).
/// There is no support for vertex normals or materials.
model_load :: (path: string) -> Model, bool
{
    file, ok := read_entire_file(path,, temp);
    if !ok {
        log_error("Couldn't load model from '%'", path);
        return .{}, false;
    }

    verts: [..]Vector3;  verts.allocator = temp;
    faces: [..]Face;  faces.allocator = temp;

    for line: split(file, "\n",, temp) {
        s := line;
        if starts_with(s, "v ") {
            // Parse vertex (v v1 v2 v3)
            advance(*s, 2);
            x := parse_float(*s);
            y := parse_float(*s);
            z := parse_float(*s);

            v := Vector3.{ x, -y, -z }; // In OBJ, positive y/z is our negative y/z, so negate it
            array_add(*verts, v);
        } else if starts_with(s, "f ") {
            // Parse face (f v1[vt1][vn2] v2[vt2][vn2] v3[vt3][vn3])
            advance(*s, 2);
            idx: [3]s32;
            for 0..2 {
                v := parse_int(*s, s32);
                idx[it] = v - 1;

                // Skip vt and vn for now
                while s.count && s[0] != #char " "  advance(*s, 1);
                while s.count && s[0] == #char " "  advance(*s, 1);
            }

            f := Face.{ idx[0], idx[1], idx[2] };
            array_add(*faces, f);
        }
    }

    m: Model;
    m.vertices = array_copy(verts);
    m.faces = array_copy(faces);
    return m, true;
}

/// Rotate all vertices of the model in the desired axis
model_transform :: (m: Model, rotation: Vector3) -> []Vector3
{
    // @FIXME: This quaternion thing is not correct, use rotate_x etc. funcs.
    out := NewArray(m.vertices.count, Vector3, initialized = false,, temp);
    for m.vertices {
        rot: Quaternion;
        rot.xyz = rotation;
        out[it_index] = rotate(it, rot);
    }
    return out;
}

// @TODO: Use arenas for models, this should not be used
model_drop :: (m: *Model)
{
    array_free(m.faces);
    array_free(m.vertices);
}

/// Helper for grabbing the offsite of a member in a struct
offset_of :: ($T: Type, $member: string) -> int #compile_time
#modify {
    ti := cast(*Type_Info) T;
    if ti.type != .STRUCT return false;

    return true;
} {
    for type_info(T).members {
        if it.name == member  return it.offset_in_bytes;
    }

    assert(false, "Type '%' does not have member '%'", T, member);
    return -1;
}

field_count :: ($T: Type) -> u8 #compile_time
#modify {
    ti := cast(*Type_Info) T;
    if ti.type != .STRUCT return false;

    return true;
} {
    ti := cast(*Type_Info_Struct) T;
    n := 0;

    for ti.members {
        if !(it.flags & .CONSTANT)  n += 1;
    }

    return n;
}

Handle :: struct($T: Type) {
    index: u32;
    generation: u32;
}

Texture :: struct {} // @Opaque
Mesh    :: struct {} // @Opaque

Mesh_Handle    :: #type,distinct Handle(Mesh);
Texture_Handle :: #type,distinct Handle(Texture);

Mesh_Data :: struct {
    vertices: []Vertex;
    indices:  []u32;
    // @FIXME: Not even sure we need this one right now
    // textures: []Texture_Handle; // @TODO: Replace with handle-based container
}

Vertex :: struct {
    position: Vector3;
    texture_coords: Vector2;
}

Face :: struct {
    a, b, c: s32;
}

Model :: struct {
    vertices: []Vector3;
    faces:    []Face;
}

#import "Basic";
#import "Math";
#import "File";
#import "String";
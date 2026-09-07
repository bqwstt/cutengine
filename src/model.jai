Face :: struct {
    a, b, c: s32;
}

Model :: struct {
    vertices: []Vector3;
    faces:    []Face;
}

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
            // Vertices
            advance(*s, 2);
            x := parse_float(*s);
            y := parse_float(*s);
            z := parse_float(*s);

            v := Vector3.{ x, -y, -z };
            array_add(*verts, v);
        } else if starts_with(s, "f ") {
            // Faces
            advance(*s, 2);
            idx: [3]s32;
            for 0..2 {
                v := parse_int(*s, s32);
                idx[it] = v - 1;
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

model_transform :: (m: Model, rotation: Vector3) -> []Vector3
{
    out := NewArray(m.vertices.count, Vector3, initialized = false,, temp);
    for m.vertices {
        rot: Quaternion;
        rot.xyz = rotation;
        out[it_index] = rotate(it, rot);
    }
    return out;
}

// @TODO: Use arenas for models, this should be used
model_drop :: (m: *Model)
{
    array_free(m.faces);
    array_free(m.vertices);
}

#import "Basic";
#import "Math";
#import "File";
#import "String";
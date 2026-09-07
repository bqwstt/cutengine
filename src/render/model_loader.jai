Model :: struct {
    vertices: []Vector3;
    faces:    []Vector3;
}

model_load :: (path: string) -> Model, bool
{
    file, ok := read_entire_file(path,, temp);
    if !ok {
        log_error("Couldn't load model from '%'", path);
        return .{}, false;
    }

    verts: [..]Vector3;  verts.allocator = temp;
    faces: [..]Vector3;  faces.allocator = temp;

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

            f := Vector3.{ xx idx[0], xx idx[1], xx idx[2] };
            array_add(*faces, f);
        }
    }

    model: Model;
    model.vertices = array_copy(verts);
    model.faces = array_copy(faces);
    return model, true;
}

model_transform :: (model: Model, rotation: Vector3) -> []Vector3 {
    out := NewArray(model.vertices.count, Vector3, initialized = false,, temp);
    for model.vertices {
        rot: Quaternion;
        rot.xyz = rotation;
        out[it_index] = rotate(it, rot);
    }
    return out;
}

#import "Basic";
#import "Math";
#import "Flat_Pool";
#import "File";
#import "String";
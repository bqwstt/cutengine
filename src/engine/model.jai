/// Load an .obj model from a filepath. Currently reads vertices (`v` components) and faces (`f` components).
/// There is no support for vertex normals or materials.
load_obj :: (path: string) -> []Mesh, bool
{
    original_allocator := context.allocator;
    context.allocator = context.per_frame_allocator;
    defer context.allocator = original_allocator;

    file, ok := read_entire_file(path);
    if !ok {
        log_error("Couldn't load model from '%'", path);
        return .{}, false;
    }

    meshes: [..]Mesh;

    positions: [..]Vector3;
    normals:   [..]Vector3;
    texture_coords: [..]Vector2;

    vertices: [..]Vertex;
    faces:    [..]Face;

    // @TODO: Profile
    // @TODO: Parse different meshes
    for line: split(file, "\n") {
        s := line;

        if starts_with(s, "v ") {
            // Vertex coordinatees (v v1 v2 v3)
            advance(*s, 2);
            x := parse_float(*s);
            y := parse_float(*s);
            z := parse_float(*s);
            array_add(*positions, .{ x, y, z });
        } else if starts_with(s, "vt ") {
            // Texture coordinates (vt vt1 vt2)
            advance(*s, 3);
            u := parse_float(*s);
            v := parse_float(*s);
            array_add(*texture_coords, .{ u, v });
        } else if starts_with(s, "vn ") {
            // Normal coordinates (vn vn1 vn2 vn3)
            advance(*s, 3);
            x := parse_float(*s);
            y := parse_float(*s);
            z := parse_float(*s);
            array_add(*normals, .{ x, y, z });
        } else if starts_with(s, "f ") {
            // Face (f v1/[vt1]/[vn2] v2/[vt2]/[vn2] v3/[vt3]/[vn3])
            advance(*s, 2);

            face: Face;
            for i: 0..2 {
                v := parse_int(*s, u32, delimiters="/");
                while s.count && s[0] == #char "/"  advance(*s, 1);

                // vt and vn are optional, mark them with -1 if not found
                vt := ifx s.count && s[0] != #char " "  parse_int(*s, s32, delimiters="/") else  -1;
                while s.count && s[0] == #char "/"  advance(*s, 1);

                vn := ifx s.count && s[0] != #char " "  parse_int(*s, s32, delimiters="/") else  -1;
                while s.count && s[0] == #char "/"  advance(*s, 1);

                face.indices[i]  = v;
                face.normals[i]  = vn;
                face.textures[i] = vt;
            }

            array_add(*faces, face);
        }
    }

    m: Mesh;
    for face: faces {
        // f 2/1/1 3/2/1 4/3/1
        for i: 0..2 {
            normals_index := face.normals[i] - 1;
            texture_coord_index := face.textures[i] - 1;

            v: Vertex;
            v.position = positions[face.indices[i]-1];
            v.normal = ifx normals_index >= 0 normals[normals_index] else .{};
            v.texture_coords = ifx texture_coord_index >= 0 texture_coords[texture_coord_index] else .{};

            // Reuse an identical vertex if we already added one
            // @FIXME: This probably is slow.
            found := -1;
            for existing, idx: m.vertices {
                if existing.position == v.position
                    && existing.normal == v.normal
                    && existing.texture_coords == v.texture_coords
                {
                    found = idx;
                    break;
                }
            }

            if found >= 0 {
                array_add(*m.indices, cast(u32) found);
            } else {
                array_add(*m.indices, cast(u32) m.vertices.count);  // index of the vertex we're about to add
                array_add(*m.vertices, v);
            }
        }
    }

    // Copy temporary data to transient memory
    array_add(*meshes, m,, context.transient_allocator);
    return meshes, true;
}

Texture :: struct {}

Handle :: struct($T: Type) {
    index: u32;
    generation: u32;
}

Mesh_Handle    :: #type,distinct Handle(Mesh);
Texture_Handle :: #type,distinct Handle(Texture);

Mesh :: struct {
    vertices: [..]Vertex;
    indices:  [..]u32;
    // @FIXME: Not even sure we need this one right now
    // textures: []Texture_Handle; // @TODO: Replace with handle-based container
}

Vertex :: struct {
    position: Vector3;
    normal: Vector3;
    texture_coords: Vector2;
}

Model :: struct {
    meshes: [..]Mesh_Handle;
}

#scope_file

Face :: struct {
    indices:  [3]u32;
    textures: [3]s32; // s32 as it can be -1
    normals:  [3]s32; // s32 as it can be -1
}

#import "Basic";
#import "Math";
#import "File";
#import "String";
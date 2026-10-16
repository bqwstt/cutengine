// @TODO: This should really be parsing a packed array of bytes, not a human-readable string.
load_asset :: (asset: string, render_config: Render_Config) -> Cpu_Model, bool
{
    original_allocator := context.allocator;
    context.allocator = context.per_frame_allocator;
    defer context.allocator = original_allocator;

    // @TODO: Remove SDL from here.
    assets_path := path_join(to_string(SDL_GetBasePath()), "../assets/") ;
    full_path := path_join(assets_path, asset);
    file, ok := read_entire_file(full_path);
    if !ok {
        log_error("Couldn't load model from '%'", asset);
        return .{}, false;
    }

    albedo_path: string;
    model_path:  string;

    for line: split(file, "\n") {
        trimmed := trim(line);

        if      starts_with(trimmed, "albedo") albedo_path = path_join(assets_path, quoted_value(trimmed));
        else if starts_with(trimmed, "path")   model_path  = path_join(assets_path, quoted_value(trimmed));
    }

    albedo_surface := SDL_LoadPNG(to_c_string(albedo_path));
    albedo: Cpu_Texture;
    albedo.width  = xx albedo_surface.w;
    albedo.height = xx albedo_surface.h;
    albedo.pixels = albedo_surface.pixels;
    albedo.pitch  = xx albedo_surface.pitch;

    model: Cpu_Model;
    model.meshes = load_obj(model_path, render_config);
    model.material = Material.{ albedo = albedo }; // @TODO: Remove and actually read the pixels.
    return model, true;
}

#scope_file

/// Load an .obj model from a filepath. Currently reads vertices (`v` components) and faces (`f` components).
/// There is no support for vertex normals or materials.
load_obj :: (path: string, render_config: Render_Config) -> []Cpu_Mesh, bool
{
    original_allocator := context.allocator;
    context.allocator = context.per_frame_allocator;
    defer context.allocator = original_allocator;

    file, ok := read_entire_file(path);
    if !ok {
        log_error("Couldn't load model from '%'", path);
        return .{}, false;
    }

    positions: [..]Vector3;
    normals:   [..]Vector3;
    texture_coords: [..]Vector2;

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
            array_add(*texture_coords, .{ u, ifx render_config & .FLIP_V then 1-v else v });
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

    vertices: [..]Vertex;
    indices:  [..]u32;

    m: Cpu_Mesh;
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
            for existing, idx: vertices {
                if existing.position == v.position
                    && existing.normal == v.normal
                    && existing.texture_coords == v.texture_coords
                {
                    found = idx;
                    break;
                }
            }

            if found >= 0 {
                array_add(*indices, cast(u32) found);
            } else {
                array_add(*indices, cast(u32) vertices.count);  // index of the vertex we're about to add
                array_add(*vertices, v);
            }
        }
    }

    meshes: [..]Cpu_Mesh;
    m.vertices = vertices;
    m.indices  = indices;

    // Copy temporary data to transient memory
    array_add(*meshes, m,, context.transient_allocator);
    return meshes, true;
}

// @TODO: Remove
quoted_value :: (line: string) -> string {
    first := find_index_from_left (line, #char "\"");
    last  := find_index_from_right(line, #char "\"");
    if first < 0 || last <= first return "";
    return slice(line, first + 1, last - first - 1);
}

Face :: struct {
    indices:  [3]u32;
    textures: [3]s32; // s32 as it can be -1
    normals:  [3]s32; // s32 as it can be -1
}

#load "asset_format.jai";
parse_asset_type :: (filename: string, data: string) -> Asset_Type #compile_time
{
    type: Asset_Type = .NOT_SUPPORTED;
    is_img := stbi_info_from_memory(data.data, cast(s32) data.count, null, null, null);
    if is_img  type = .TEXTURE;
    if path_extension(filename) == "obj"  type = .MODEL; // There is no magic number in obj.
    if path_extension(filename) == "hlsl" type = .SHADER;

    return type;
}

// Take hero.jpg, stone.png, tree.ase -> hero.ca, stone.ca, tree.ca
write_asset :: (source_filepath: string) #compile_time
{
    _, has_extension := path_extension(source_filepath);
    if !has_extension  return;

    source_contents, source_ok := read_entire_file(source_filepath);
    if !source_ok  return;

    target_filename := tprint("%.ca", path_filename(path_strip_extension(source_filepath)));
    target := path_join(ASSETS_DIR, target_filename); // ASSETS_DIR is defined in first.jai

    // Check the type before opening the target: opening truncates it, so unsupported files
    // (cube.mtl next to cube.obj) would otherwise leave an empty .ca behind.
    asset_type := parse_asset_type(source_filepath, source_contents);
    if asset_type == .NOT_SUPPORTED  return;

    f, ok := file_open(target, for_writing = true);
    if !ok  return;
    defer file_close(*f);

    print("Writing asset: %\n", target);

    // NOTE: The casts are not needed, they are here mainly for readability.
    header: Asset_Header;
    header.magic   = cast(u32) MAGIC;
    header.version = cast(u32) VERSION;
    header.type    = cast(Asset_Type) asset_type;
    header.entry_count  = cast(u32) 0; // @FIXME: We should get a count of how many elements and put it here
    header.entry_offset = cast(u32) size_of(Asset_Header);

    // Write header
    // NOTE: We construct each field manually (as opposed to the whole struct)
    // in order to avoid padding. See note in asset_format.jai.
    file_write(*f, *header.magic, size_of(u32));
    file_write(*f, *header.version, size_of(u32));
    file_write(*f, *header.type, size_of(u8));
    file_write(*f, *header.entry_count, size_of(u32));
    file_write(*f, *header.entry_offset, size_of(u32));

    // Write asset data
    if asset_type == {
    case .TEXTURE; write_texture(*f, source_contents);
    case .MODEL;   write_model(*f, source_contents);
    case .SHADER;  write_shader(*f, source_filepath);
    }
}

#scope_file

write_texture :: (f: *File, file_data: string) #compile_time
{
    width: s32;
    height: s32;
    channels: s32;

    // Load uncompressed bytes from texture
    // @TODO: We always construct a RGBA8 image (desired_channels = 4), which can
    // take a couple more bytes for other kinds of images. Then format in the header is always RGBA8.
    // We will also add BC7 format support later, so watch out for it.
    pixels := stbi_load_from_memory(file_data.data, cast(s32) file_data.count, *width, *height, null, 4);
    if !pixels {
        print("Texture decode failed: %\n", to_string(stbi_failure_reason()));
        return;
    }
    defer stbi_image_free(pixels);

    byte_count := cast(s64) width * height * 4;

    header: Asset_Texture_Header;
    header.width  = cast(u32) width;
    header.height = cast(u32) height;
    header.format = cast(Asset_Texture_Format) .RGBA8;
    header.compressed = cast(u8) 0x00; // @TODO: Add compression?
    header.stored_size = cast(u32) byte_count;
    header.raw_size = cast(u32) byte_count; // @TODO: Change when compressed

    // Write header
    file_write(f, *header.width,  size_of(u32));
    file_write(f, *header.height, size_of(u32));
    file_write(f, *header.format, size_of(u8));
    file_write(f, *header.compressed, size_of(u8));
    file_write(f, *header.stored_size, size_of(u32));
    file_write(f, *header.raw_size, size_of(u32));

    // Write data
    file_write(f, pixels, byte_count);
}

write_shader :: (f: *File, source_filepath: string) #compile_time
{
    name := path_filename(path_strip_extension(source_filepath)); // texture.frag.hlsl -> texture.frag

    header: Asset_Shader_Header;
    if path_extension(name) == {
    case "vert"; header.stage = .VERTEX;
    case "frag"; header.stage = .FRAGMENT;
    case "comp"; header.stage = .COMPUTE;
    case;
        compiler_report(tprint("Couldn't deduce shader stage from filename: %", source_filepath));
        return;
    }

    // We only bake the backend for the platform we're building on.
    // @TODO: Should we always produce SPIRV and embed it?
    #if OS == .WINDOWS     header.backend = .DXIL;
    else #if OS == .LINUX  header.backend = .SPIRV;
    else                   header.backend = .MSL;
    dest := tprint("%", header.backend); // Enum names match shadercross' destination formats

    // Reflection tells us how many resources the shader declares, so nobody has to type them by hand.
    reflection, reflection_ok := run_shadercross(source_filepath, "JSON");
    if !reflection_ok  return;

    code, code_ok := run_shadercross(source_filepath, dest);
    if !code_ok  return;

    header.num_samplers         = reflected_count(reflection, "samplers");
    header.num_storage_textures = reflected_count(reflection, "storage_textures");
    header.num_storage_buffers  = reflected_count(reflection, "storage_buffers");
    header.num_uniforms         = reflected_count(reflection, "uniform_buffers");
    header.code_len             = cast(u32) code.count;

    // Write header
    file_write(f, *header.stage, size_of(u8));
    file_write(f, *header.backend, size_of(u8));
    file_write(f, *header.num_samplers, size_of(u8));
    file_write(f, *header.num_storage_textures, size_of(u8));
    file_write(f, *header.num_storage_buffers, size_of(u8));
    file_write(f, *header.num_uniforms, size_of(u8));
    file_write(f, *header.code_len, size_of(u32));

    // Write data
    file_write(f, code.data, code.count);
}

write_model :: (f: *File, file_data: string) #compile_time
{
    // Read source data
    // @TODO: Check format instead of assuming it's obj
    obj_data := read_obj(file_data);
    vertices := obj_data.vertices;
    indices  := obj_data.indices;
    material := obj_data.material;

    header: Asset_Model_Header;
    header.vertices_count = cast(u32) vertices.count;
    header.indices_count = cast(u32) indices.count;
    header.material_name_len = cast(u32) material.count; // @TODO: Write material size and name

    // Write header
    file_write(f, *header.vertices_count, size_of(u32));
    file_write(f, *header.indices_count, size_of(u32));
    file_write(f, *header.material_name_len, size_of(u32));

    // Write data
    // @TODO: Probably size_of(Vertex) is not what we want. What about vertices without normals?
    //        I think that's fine though, they will be 0, but double check.
    // @TODO: Store x, y, z in separate columns?
    file_write(f, vertices.data, vertices.count * size_of(Vertex)); // Vertices
    file_write(f, indices.data, indices.count * size_of(u32));      // Indices
    file_write(f, material.data, material.count * size_of(u8));     // Material name (if any)
}

/// Load an .obj model from a filepath. Currently reads vertices (`v` components) and faces (`f` components).
/// There is no support for materials.
/// @FIXME: This is too slow.
read_obj :: (file_contents: string) -> Obj_Data #compile_time
{
    context.allocator = temp;

    positions: [..]Vector3;
    normals:   [..]Vector3;
    texture_coords: [..]Vector2;

    faces:    [..]Face;
    material_name: string;

    // @TODO: Profile
    // @TODO: Parse different meshes
    for line: split(file_contents, "\n") {
        s := line;

        if starts_with(s, "v ") {
            // Vertex coordinates (v v1 v2 v3)
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
            array_add(*texture_coords, .{ u, 1-v }); // OBJ uv's are bottom-left origin, we are top-left, so flip
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
        } else if starts_with(s, "usemtl ") {
            advance(*s, 7);
            name := trim(s);
            material_name = copy_string(name);
        }
    }

    vertices: [..]Vertex;
    indices:  [..]u32;

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

    data: Obj_Data;
    data.vertices = vertices;
    data.indices = indices;
    data.material = material_name;
    return data;
}

/// Runs shadercross and returns what it outputs. It requires an output path, so we point it to
/// stdout and capture that instead of going through a file. Its logs go to stderr, so they don't mix in.
/// @TODO: Windows has no /dev/stdout. Use a temporary file there when we bake DXIL.
run_shadercross :: (source: string, dest: string) -> string, bool #compile_time
{
    result, output, error := run_command("shadercross", source, "-d", dest, "-o", "/dev/stdout",
        capture_and_return_output = true, print_captured_output = false);

    if result.exit_code != 0 {
        compiler_report(tprint("Couldn't compile shader '%' to %:\n%", source, dest, error));
        return "", false;
    }
    return output, true;
}

// Reads `"key": N` from shadercross' reflection JSON.
reflected_count :: (json: string, key: string) -> u8 #compile_time
{
    pattern := tprint("\"%\":", key);
    index := find_index_from_left(json, pattern);
    if index < 0  return 0;

    rest := json;
    advance(*rest, index + pattern.count);
    count := parse_int(*rest, u8, delimiters=",}");
    return count;
}

Obj_Data :: struct {
    vertices: []Vertex;
    indices:  []u32;
    material: string;
}

Face :: struct {
    indices:  [3]u32;
    textures: [3]s32; // s32 as it can be -1
    normals:  [3]s32; // s32 as it can be -1
}

#load "asset_format.jai";
#load "model.jai"; // For Vertex

#import "Hash";
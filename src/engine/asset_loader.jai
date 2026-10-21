load_texture_asset :: (asset: string) -> Cpu_Texture, bool
{
    reader, ok := load_asset_begin(asset);
    if !ok  return .{}, false;

    width := read(*reader, u32);
    height := read(*reader, u32);
    format := cast(Asset_Texture_Format) read(*reader, u8);
    is_compressed := read(*reader, u8);
    stored_bytes := read(*reader, u32);
    raw_bytes := read(*reader, u32);
    bytes := read_bytes(*reader, cast(s64) raw_bytes);

    texture: Cpu_Texture;
    texture.height = height;
    texture.width  = width;
    texture.pixels = bytes;

    if format == {
    case .RGBA8; texture.pitch = width * 4;
    case;
        log_error("Unsupported texture format % in '%'", format, asset);
        return .{}, false;
    }

    return texture, true;
}

load_model_asset :: (asset: string) -> Cpu_Model, bool
{
    reader, ok := load_asset_begin(asset);
    if !ok  return .{}, false;

    vertices_count := read(*reader, u32);
    indices_count  := read(*reader, u32);
    material_name_len := read(*reader, u32);

    meshes: [..]Cpu_Mesh;
    meshes.allocator = context.transient_allocator;

    mesh: Cpu_Mesh;
    mesh.vertices = .{ data = cast(*Vertex) read_bytes(*reader, vertices_count * size_of(Vertex)), count = vertices_count };
    mesh.indices  = .{ data = cast(*u32) read_bytes(*reader, indices_count * size_of(u32)), count = indices_count };
    array_add(*meshes, mesh);

    material: Cpu_Material;
    material_name := to_string(read_bytes(*reader, material_name_len), material_name_len);
    albedo_ok := false;
    if material_name != "" {
        // @TODO: This loads each file separately. Add a check for #if DEBUG once we have a packed asset path.
        // @TODO: Change this for a `load_material_asset` call, which parses all texture types.
        material.albedo, albedo_ok = load_texture_asset(material_name);

        // No material, or its texture couldn't be loaded: use the missing texture so it stands out.
        if !albedo_ok {
            material.albedo, albedo_ok = load_texture_asset(DEFAULT_TEXTURE_ASSET_NAME);
            assert(albedo_ok, "Couldn't load fallback texture '%'", DEFAULT_TEXTURE_ASSET_NAME);
        }
    } else {
        // Load default material
        material = DEFAULT_MATERIAL_DATA;
    }


    model: Cpu_Model;
    model.meshes = meshes;
    model.material = material;
    return model, true;
}

load_shader_asset :: (asset: string) -> Cpu_Shader, bool
{
    reader, ok := load_asset_begin(asset);
    if !ok  return .{}, false;

    shader: Cpu_Shader;
    shader.stage   = cast(Asset_Shader_Stage)   read(*reader, u8);
    shader.backend = cast(Asset_Shader_Backend) read(*reader, u8);
    shader.num_samplers         = read(*reader, u8);
    shader.num_storage_textures = read(*reader, u8);
    shader.num_storage_buffers  = read(*reader, u8);
    shader.num_uniforms         = read(*reader, u8);

    code_len := read(*reader, u32);
    shader.code = to_string(read_bytes(*reader, code_len), code_len);

    return shader, true;
}

#scope_file

load_asset_begin :: (asset: string) -> Asset_Reader, bool
{
    // Add the extension ourselves. Only strip `.ca`, as shader names have dots in them (texture.frag).
    name := ifx path_extension(asset) == ASSETS_EXT  asset else tprint("%.%", asset, ASSETS_EXT);
    full_path := path_join(ASSETS_PATH, name);
    file, ok := read_entire_file(full_path,, context.transient_allocator);
    if !ok {
        log_error("Couldn't read asset from '%'", asset);
        return .{}, false;
    }

    reader: Asset_Reader;
    reader.data = file;
    reader.pos  = 0;

    // Read header
    magic := read(*reader, u32); // Magic number
    if magic != MAGIC {
        log_error("File % is not an asset.", asset);
        return .{}, false;
    }

    // For now, version does nothing until we bump up the version number.
    version := read(*reader, u32);
    type := cast(Asset_Type) read(*reader, u8);
    entry_count := read(*reader, u32);
    entry_offset := read(*reader, u32);

    return reader, true;
}

read :: (reader: *Asset_Reader, $T: Type) -> T, bool
{
    value: T;
    if reader.pos + size_of(T) > reader.data.count  return value, false;
    memcpy(*value, reader.data.data + reader.pos, size_of(T));
    reader.pos += size_of(T);
    return value, true;
}

read_bytes :: (reader: *Asset_Reader, count: s64) -> *u8, bool
{
    data: *u8;
    if reader.pos + count > reader.data.count  return null, false;

    data = reader.data.data + reader.pos;
    reader.pos += count;
    return data, true;
}

Asset_Reader :: struct {
    data: string;
    pos:  s64;
}

ASSETS_EXT  :: "ca";
ASSETS_PATH :: #run path_join(#filepath, "../../assets/") ;

// #region Asset defaults

WHITE_PIXELS  :: u8.[255, 255, 255, 255];
WHITE_TEXTURE :: Cpu_Texture.{ width = 1, height = 1, pixels = WHITE_PIXELS.data, pitch = 4 };

DEFAULT_TEXTURE_ASSET_NAME :: "missing_texture";  // Used when a model can't load its texture
DEFAULT_MATERIAL_DATA :: Cpu_Material.{ albedo = WHITE_TEXTURE }; // Used when a model has no material

#load "asset_format.jai";
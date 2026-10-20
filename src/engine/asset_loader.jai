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
    texture.pitch  = width * cast(u8) format;
    texture.pixels = bytes;
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
    material_name := to_string(read_bytes(*reader, material_name_len * size_of(u8)), material_name_len);
    if material_name != "" {
        // @TODO: This loads each file separately. Add a check for #if DEBUG once we have a packed asset path.
        // @TODO: Change this for a `load_material_asset` call, which parses all texture types.
        material.albedo = load_texture_asset(material_name);
    }

    model: Cpu_Model;
    model.meshes = meshes;
    model.material = material;
    return model, true;
}

#scope_file

load_asset_begin :: (asset: string) -> Asset_Reader, bool
{
    // Add the extension ourselves.
    name := tprint("%.%", path_strip_extension(asset), ASSETS_EXT);
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

#load "asset_format.jai";
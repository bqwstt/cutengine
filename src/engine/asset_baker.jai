parse_asset_type :: (data: string) -> Asset_Type #compile_time
{
    type: Asset_Type = .NOT_SUPPORTED;
    is_img := stbi_info_from_memory(data.data, cast(s32) data.count, null, null, null);
    if is_img  type = .TEXTURE;

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

    f, ok := file_open(target, for_writing = true);
    if !ok  return;
    defer file_close(*f);

    asset_type := parse_asset_type(source_contents);
    if asset_type == .NOT_SUPPORTED  return;

    print("Writing asset: %\n", target);

    // NOTE: The casts are not needed, they are here mainly for readability.
    header: Asset_Header;
    header.magic   = cast(u32) MAGIC;
    header.version = cast(u32) 1;
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
    }
}

write_texture :: (f: *File, file_data: string) #compile_time
{
    width: s32;
    height: s32;
    channels: s32;

    // Load uncompressed bytes from texture
    pixels := stbi_load_from_memory(file_data.data, cast(s32) file_data.count, *width, *height, *channels, 0);
    if !pixels {
        print("Texture decode failed: %\n", to_string(stbi_failure_reason()));
        return;
    }
    defer stbi_image_free(pixels);

    byte_count := cast(s64) width * height * channels;

    header: Asset_Texture_Header;
    header.width  = cast(u32) width;
    header.height = cast(u32) height;
    header.format = cast(Asset_Texture_Format)  channels;
    header.compressed = cast(u8) 0x00; // @TODO: Add compression?

    // Compute hash for texture.
    // We have to hash the header itself as two textures may have the same pixels
    // but different metadata, e.g. a 2x8 vs 4x4 image.
    hash := fnv1a_hash(*header, size_of(Asset_Texture_Header)); // Header
    hash  = fnv1a_hash(pixels, byte_count, hash);               // Data
    header.checksum = hash;

    // Write header
    file_write(f, *header.width,  size_of(u32));
    file_write(f, *header.height, size_of(u32));
    file_write(f, *header.format, size_of(u8));
    file_write(f, *header.compressed, size_of(u8));
    file_write(f, *header.checksum, size_of(u64));

    // Write data
    file_write(f, pixels, byte_count);
}

#load "asset_format.jai";

#import "Hash";
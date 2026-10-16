parse_asset_type :: (file: File) -> Asset_Type #compile_time
{
    type: Asset_Type;
    is_img := stbi_info_from_file(file.handle, null, null, null);
    if is_img  type = .TEXTURE;

    return type;
}

// Take hero.jpg, stone.png, tree.ase -> hero.ca, stone.ca, tree.ca
write_asset :: (source_filepath: string) #compile_time
{
    _, has_extension := path_extension(source_filepath);
    if !has_extension  return;

    target_filename := tprint("%.ca", path_filename(path_strip_extension(source_filepath)));
    target := path_join(ASSETS_DIR, target_filename); // ASSETS_DIR is defined in first.jai

    f, ok := file_open(target, for_writing = true);
    if !ok return;
    defer file_close(*f);

    header: Asset_Header;
    header.magic = MAGIC;
    header.version = 1;
    header.type = parse_asset_type(f);
    header.entry_count = 0;
    header.entry_offset = cast(u32) size_of(Asset_Header);

    file_write(*f, *header, size_of(Asset_Header)); // Write the header
}

#load "asset_format.jai";
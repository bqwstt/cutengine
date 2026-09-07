#scope_file

Color :: enum u32 {
    BLACK :: 0xFF_00_00_00;
    WHITE :: 0xFF_FF_FF_FF;

    RED   :: 0xFF_FF_00_00;
    GREEN :: 0xFF_00_FF_00;
    BLUE  :: 0xFF_00_00_FF;
}

put_pixel :: (fb: Framebuffer, x: s32, y: s32, color: Color)
{
    tx := x /* - cast(s32) camera.position.x */;
    ty := y /* - cast(s32) camera.position.y */;

    if tx < 0 || tx >= fb.width || ty < 0 || ty >= fb.height  return; 
    fb.pixels[(fb.width * ty) + tx] = xx color;
}

#scope_export

Framebuffer :: struct {
    pixels: []u32;
    width: s32;
    height: s32;
}

framebuffer_make :: (width: s32, height: s32) -> Framebuffer
{
    fb: Framebuffer;
    fb.width = width;
    fb.height = height;
    fb.pixels = NewArray(width * height, u32);
    return fb;
}

framebuffer_drop :: (fb: *Framebuffer)
{
    array_free(fb.pixels);
    fb.* = .{};
}

framebuffer_clear :: (fb: *Framebuffer, color: Color)
{
    for * fb.pixels  it.* = xx color;
}
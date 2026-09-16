engine_memory_make :: (permanent_size: u64, transient_size: u64) -> Engine_Memory, bool
{
    return .{}, false;
}

Native_Window :: struct {} // Opaque on purpose

Window :: struct {
    native: *Native_Window;
    width:  s32;
    height: s32;
}

// @TODO: Check if this is needed? May only be used by Renderer. In that case, move it there. (If Framebuffer doesn't make sense.)
Framebuffer_View :: struct {
    pixels: []u32;
    width:  s32;
    height: s32;
    pitch:  s32; // In pixels
}

Input :: struct {
    mouse_x: float;
    mouse_y: float;
    mouse_dx: float;
    mouse_dy: float;

    dt: float;

    quit_requested: bool;
}

Engine_Memory :: struct {
    permanent: []u8;
    transient: []u8;
}
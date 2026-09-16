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

Input :: struct {
    mouse_x: float;
    mouse_y: float;
    mouse_dx: float;
    mouse_dy: float;

    dt: float64;

    quit_requested: bool;
}

Engine_Memory :: struct {
    permanent: []u8;
    transient: []u8;
}

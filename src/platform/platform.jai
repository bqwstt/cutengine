memory_make :: (permanent_size: s64, transient_size: s64) -> Memory
{
    m: Memory;
    init(*m.permanent, permanent_size);
    init(*m.transient, transient_size);
    return m;
}

permanent_allocator :: inline (m: *Memory) -> Allocator
{
    return .{ proc = flat_pool_allocator_proc, data = *m.permanent };
}

transient_allocator :: inline (m: *Memory) -> Allocator
{
    return .{ proc = flat_pool_allocator_proc, data = *m.transient };
}

trap_allocator_proc :: (mode: Allocator_Mode, size: s64, old_size: s64, old: *void, data: *void) -> *void
{
    if mode == .ALLOCATE || mode == .RESIZE  assert(false, "Heap allocation after startup. Use `permanent` or `transient` allocators");
    return null;
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

/// How memory works
/// ================
///
/// We have three types of memory allocation in the game.
/// 1. Permanent: we want to store stuff that will live *for the whole duration* of the game, starting from when it's launched until it's closed.
///    This is anything that the game _requires_ in order to run. For example, a framebuffer.
///    This is likely a small amount of memory.
/// 2. Transient: we want to store stuff that will live *for a shorter period of time* during the game.
///    This is anything that the game _constructs_ and _uses_ in-between frames, but may not be needed later. For example, a model, a particle effect.
/// 3. Temporary: we want to store stuff that will live *for the duration of a single frame*.
///    This is anything that the game _temporarily constructs_ and immediately _discards_ after some work is done. For example, populating a vertex array.
///
///         Lifetime of the game          L = Launch
/// |=================================|   C = Close
/// L                                 C
///  |-------------------------------|    P  = Permanent
///                 P                     TR = Transient
///  |-------------| |---| |--| |----|    T  = Temporary
///         TR        TR    TR    TR
///                 -     -    -
///                 T     T    T
///
/// When memory is deallocated, *the whole thing* is deallocated. There is no way to deallocate single objects.
/// When the game closes, all memory is freed by the OS.
/// When a level is unloaded, or moving into a new zone, transient storage is reset.
/// When a frame ends, temporary memory is reset.
///
/// Code is forced to use these allocators and any call to New or similar stuff will just use either the permanent or transient allocators.
/// Otherwise, the game will crash (on purpose)!
Memory :: struct {
    permanent: Flat_Pool;
    transient: Flat_Pool;
}

#import "Flat_Pool";
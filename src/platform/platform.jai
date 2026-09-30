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

/// Shared between all platforms.
/// This could be implemented by each platform separately, but for now, using Jai's clock is fine.
platform_time_ns :: () -> u64
{
    return cast(u64) to_nanoseconds(current_time_monotonic());
}

key_is_down :: (input: *Input, key: Keyboard_Key) -> bool
{
    return input.keyboard_buttons[key].ended_down;
}

key_was_pressed :: (input: *Input, key: Keyboard_Key) -> bool
{
    b := input.keyboard_buttons[key];
    return b.half_transitions > 1 || (b.half_transitions == 1 && b.ended_down);
}

key_was_released :: (input: *Input, key: Keyboard_Key) -> bool
{
    b := input.keyboard_buttons[key];
    return b.half_transitions > 1 || (b.half_transitions == 1 && !b.ended_down);
}

reset_keyboard_input :: inline (input: *Input)
{
    for *input.keyboard_buttons  it.half_transitions = 0;
}

Native_Window :: struct {} // Opaque on purpose

Window :: struct {
    native: *Native_Window;
    width:  s32;
    height: s32;
}

Input :: struct {
    mouse_pos: Vector2;
    quit_requested: bool;
    keyboard_buttons: [KEYBOARD_BUTTONS_AMOUNT]Button_State;
}

// We follow a US-QWERTY keyboard.
Keyboard_Key :: enum u8 {
    UNKNOWN;

    Q; W; E; R; T; Y; U; I; O; P;
    A; S; D; F; G; H; J; K; L;
    Z; X; C; V; B; N; M;

    NUM_1; NUM_2; NUM_3; NUM_4; NUM_5;
    NUM_6; NUM_7; NUM_8; NUM_9; NUM_0;

    LEFT_ARROW; RIGHT_ARROW;
    UP_ARROW; DOWN_ARROW;

    MINUS; EQUALS;
    LEFT_BRACKET; RIGHT_BRACKET; BACKSLASH;
    SEMICOLON; TICK;
    COMMA; DOT; SLASH;
    BACKTICK;

    // Modifiers
    LEFT_SHIFT; RIGHT_SHIFT;
    LEFT_CTRL;  RIGHT_CTRL;
    LEFT_ALT;   RIGHT_ALT;
    LEFT_CMD;   RIGHT_CMD;

    RETURN;
    DELETE;
    ESCAPE;
}

KEYBOARD_BUTTONS_AMOUNT :: #run enum_highest_value(Keyboard_Key) + 1;

/// Handmade-Hero style input
/// - https://www.youtube.com/watch?v=Lt9DfMzZ9sI
Button_State :: struct {
    ended_down:       bool;
    half_transitions: u8;
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
///    NOTE: Temporary is provided by the runtime in Temporary_Storage, so no need to add it to this struct.
///          However, it is added to the context in `context.per_frame_allocator` for completeness.
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
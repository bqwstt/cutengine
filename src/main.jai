engine_logger :: (message: string, data: *void, info: Log_Info)
{
    if !message  return;

    prefix := ifx info.common_flags & .ERROR then "ERRO: "
    else ifx info.common_flags & .WARNING then "WARN: "
    else "INFO: ";

    newline := ifx message[message.count-1] == #char "\n" then "" else "\n";
    write_strings(prefix, message, newline, to_standard_error = (info.common_flags & .ERROR) != 0);
}

// Add allocators to the context to use globally.
#add_context permanent_allocator: Allocator;
#add_context transient_allocator: Allocator;

FPS :: 60.0;
DELTA_WANTED :: 1.0 / FPS;

main :: ()
{
    // #region Initialization
    // Create static memory for the whole program.
    memory := memory_make(PERMANENT_MEMORY_SIZE, TRANSIENT_MEMORY_SIZE);

    context.logger = engine_logger;
    context.permanent_allocator = permanent_allocator(*memory);
    context.transient_allocator = transient_allocator(*memory);
    context.allocator = context.permanent_allocator; // Use permanent allocation for initialization

    window, window_ok := platform_init("cutty", WINDOW_WIDTH, WINDOW_HEIGHT);
    if !window_ok  return;
    defer platform_shutdown(*window);

    renderer, renderer_ok := renderer_init(*window, .GPU, WINDOW_WIDTH, WINDOW_HEIGHT);
    if !renderer_ok  return;
    defer renderer_drop(*renderer);

    // Store current game state and previous game state for later interpolation.
    // NOTE: These use the permanent allocator, so they live for the whole program.
    game_state := New(Game_State);
    game_init(game_state, *renderer);

    prev_game_state := New(Game_State);
    prev_game_state.* = game_state.*;

    // #region 0-allocs
    // Use trap allocator from now on, no more accidental allocations after this!
    // (Any alloc will now need to pass in either `,,permament_allocator` or `,,transient_allocator`.)
    context.allocator = .{ trap_allocator_proc, null };
    defer context.allocator = context.permanent_allocator; // If, for some reason, some shutdown code allocates, revert it before they run.

    ts := cast(*Temporary_Storage_Paged_Alloc) context.temporary_storage;
    oa := ts.overflow_allocator;
    ts.overflow_allocator = .{ trap_allocator_proc, null };
    defer ts.overflow_allocator = oa;

    input: Input;
    input.dt = DELTA_WANTED;

    prev_time := platform_time_ns();
    frame_acc: float64;

    render_list: Render_List;

    // Main loop
    while !input.quit_requested {
        new_time := platform_time_ns();
        frame_time := cast(float64) (new_time - prev_time) / 1_000_000_000.0;
        frame_time = min(frame_time, 0.25);
        prev_time = new_time;

        platform_poll_events(*window, *input);

        frame_acc += frame_time;
        ticks := cast(int) floor(frame_acc / DELTA_WANTED);
        frame_acc -= cast(float64) ticks * DELTA_WANTED;

        for i: 1 .. ticks {
            // Copy state and update game
            // Note that the game runs on a fixed delta
            prev_game_state.* = game_state.*;
            game_update(game_state, *input, DELTA_WANTED);
        }

        alpha := frame_acc / DELTA_WANTED;

        // Build render commands list and execute using the current renderer
        game_construct_render_list(*render_list, prev_game_state, game_state, alpha);
        renderer_execute_commands(*renderer, *render_list);

        reset_temporary_storage();
    }

    // @TODO: Not sure if this makes sense, as we're only using arenas, but just in case.
    #if DEBUG report_memory_leaks();
}

KiB :: 1024;
MiB :: 1024 * KiB;
GiB :: 1024 * MiB;

PERMANENT_MEMORY_SIZE :: 64 * MiB;
TRANSIENT_MEMORY_SIZE ::  4 * GiB;

#load "platform/platform.jai";
#load "platform/platform_sdl.jai"; // @FIXME: Load depending on platform wanted
#load "engine/scene.jai";
#load "engine/model.jai";
#load "render/renderer.jai";
#load "game/game.jai";

#import "Basic"()(MEMORY_DEBUGGER = DEBUG); // Enable memory debugger on debug buids.
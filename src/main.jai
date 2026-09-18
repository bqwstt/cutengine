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

main :: ()
{
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

    // Use trap allocator from now on, no more accidental allocations after this!
    // (Any alloc will now need to pass in either `,,permament_allocator` or `,,transient_allocator`.)
    context.allocator = .{ trap_allocator_proc, null };
    defer context.allocator = context.permanent_allocator; // If, for some reason, some shutdown code allocates, revert it before they run.

    ts := cast(*Temporary_Storage_Paged_Alloc) context.temporary_storage;
    oa := ts.overflow_allocator;
    ts.overflow_allocator = .{ trap_allocator_proc, null };
    defer ts.overflow_allocator = oa;

    input: Input;
    last_time := platform_time_ns();

    camera := camera_make();

    while !input.quit_requested {
        now := platform_time_ns();
        input.dt = (now - last_time) / 1_000_000_000.0;
        last_time = now;

        platform_poll_events(*window, *input);
        renderer_draw(*renderer, *camera);
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

#import "Basic"()(MEMORY_DEBUGGER = DEBUG); // Enable memory debugger on debug buids.
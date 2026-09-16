engine_logger :: (message: string, data: *void, info: Log_Info)
{
    if !message  return;

    prefix := ifx info.common_flags & .ERROR then "ERRO: "
    else ifx info.common_flags & .WARNING then "WARN: "
    else "INFO: ";

    newline := ifx message[message.count-1] == #char "\n" then "" else "\n";
    write_strings(prefix, message, newline, to_standard_error = (info.common_flags & .ERROR) != 0);
}

main :: ()
{
    context.logger = engine_logger;

    window, window_ok := platform_init("cutty", WINDOW_WIDTH, WINDOW_HEIGHT);
    if !window_ok  return;
    defer platform_shutdown(*window);

    memory, memory_ok := engine_memory_make(PERMANENT_MEMORY_SIZE, TRANSIENT_MEMORY_SIZE);
    // @FIXME: Skip check for now
    // if !memory_ok  return;

    renderer, renderer_ok := renderer_init(*window, .GPU, WINDOW_WIDTH, WINDOW_HEIGHT);
    if !renderer_ok  return;
    defer renderer_drop(*renderer);

    input: Input;
    last_time := platform_time_ns();

    while !input.quit_requested {
        now := platform_time_ns();
        input.dt = (now - last_time) / 1_000_000_000.0;
        last_time = now;

        platform_poll_events(*window, *input);
        renderer_draw(*renderer);
        reset_temporary_storage();
    }
}

// @TODO: Change these, make them modifiable and query during runtime.
WINDOW_WIDTH  :: 1920;
WINDOW_HEIGHT :: 1080;

PERMANENT_MEMORY_SIZE :: 256 * 1024 * 1024;
TRANSIENT_MEMORY_SIZE :: 512 * 1024 * 1024;

#load "platform/platform.jai";
#load "platform/platform_sdl.jai"; // @FIXME: Load depending on platform wanted
#load "engine/scene.jai";
#load "engine/model.jai";
#load "render/renderer.jai";

#import "Basic";
#import "SDL3";
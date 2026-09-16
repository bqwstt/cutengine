engine_logger :: (message: string, data: *void, info: Log_Info)
{
    if !message  return;

    prefix := ifx info.common_flags & .ERROR then "ERRO: "
    else ifx info.common_flags & .WARNING then "WARN: "
    else "INFO: ";

    newline := ifx message[message.count-1] == #char "\n" then "" else "\n";
    write_strings(prefix, message, newline, to_standard_error = (info.common_flags & .ERROR) != 0);
}

Engine_State :: struct
{
    window: *SDL_Window;
    renderer: Renderer;
}

state: Engine_State; /* static */

// @TODO: Change these, make them modifiable and query during runtime.
WINDOW_WIDTH  :: 1920;
WINDOW_HEIGHT :: 1080;

PERMANENT_MEMORY_SIZE :: 256 * 1024 * 1024;
TRANSIENT_MEMORY_SIZE :: 512 * 1024 * 1024;

app_init :: (_: **void, argc: s32, argv: **u8) -> SDL_AppResult
{
    SDL_SetAppMetadata("cutengine", "v0.0.1", "com.engine.cutengine");

    ok := SDL_InitSubSystem(.VIDEO);
    if !ok {
        log_error("Couldn't initialize SDL: %", SDL_GetErrorString());
        return .FAILURE;
    }

    // Use high pixel density, otherwise we have blurry edges on MacOS
    window_flags: SDL_WindowFlags = .HIGH_PIXEL_DENSITY | .RESIZABLE;
    window := SDL_CreateWindow("cutengine", WINDOW_WIDTH, WINDOW_HEIGHT, window_flags);
    if !window {
        log_error("Couldn't create window: %", SDL_GetErrorString());
        return .FAILURE;
    }

    state.window = window;
    state.renderer, ok = renderer_make(window, .GPU, WINDOW_WIDTH, WINDOW_HEIGHT);
    if !ok  return .FAILURE;

    log("Initialized SDL using GPU acceleration");
    return .CONTINUE;
}

app_event :: (_: *void, event: *SDL_Event) -> SDL_AppResult
{
    if event.type == {
    case .QUIT;
        return .SUCCESS;
    case .KEY_DOWN;
        if event.key.key == SDLK_ESCAPE {
            return .SUCCESS;
        }
    }

    return .CONTINUE;
}

app_iterate :: (_: *void) -> SDL_AppResult
{
    renderer_draw(*state.renderer);
    reset_temporary_storage();
    return .CONTINUE;
}

app_quit :: (_: *void, result: SDL_AppResult)
{
    renderer_drop(*state.renderer);
    if state.window  SDL_DestroyWindow(state.window);

    SDL_Quit();
}

main :: ()
{
    context.logger = engine_logger;
    // SDL_EnterAppMainCallbacks(app_init, app_iterate, app_event, app_quit);

    // SDL_SetAppMetadata("cutengine", "v0.0.1", "com.engine.cutengine");

    // ok := SDL_InitSubSystem(.VIDEO);
    // assert(ok, "Couldn't initialize SDL: %", SDL_GetErrorString());
    // defer SDL_Quit();

    // // Use high pixel density, otherwise we have blurry edges on MacOS
    // window_flags: SDL_WindowFlags = .HIGH_PIXEL_DENSITY | .RESIZABLE;
    // window := SDL_CreateWindow("cutengine", WINDOW_WIDTH, WINDOW_HEIGHT, window_flags);
    // assert(window != null, "Couldn't create window: %", SDL_GetErrorString());
    // defer SDL_DestroyWindow(state.window);

    // state.window = window;
    // state.renderer, ok = renderer_make(window, .GPU, WINDOW_WIDTH, WINDOW_HEIGHT);
    // assert(ok, "Couldn't create renderer");
    // defer renderer_drop(state.renderer);

    // log("Initialized SDL using GPU acceleration");
    // return .CONTINUE;

    window, window_ok := platform_init("cutty", WINDOW_WIDTH, WINDOW_HEIGHT);
    if !window_ok  return;
    defer platform_shutdown(*window);

    memory, memory_ok := engine_memory_make(PERMANENT_MEMORY_SIZE, TRANSIENT_MEMORY_SIZE);
    if !memory_ok  return;

    renderer, renderer_ok := renderer_make(*window, .GPU, WINDOW_WIDTH, WINDOW_HEIGHT);
    if !renderer_ok  return;
    defer renderer_drop(*renderer);

    input: Input;
    last_time := platform_time_ns();

    while !input.quit_requested {
        now := platform_time_ns();
        input.dt = cast(float) (now - last_time) / 1_000_000_000.0;
        last_time = now;

        platform_poll_events(*window, *input);
        renderer_draw(*renderer, *window);
        reset_temporary_storage();
    }
}

#load "platform/platform_sdl.jai"; // @FIXME: Load depending on platform wanted
#load "engine/scene.jai";
#load "engine/model.jai";
#load "render/renderer.jai";
#load "render/software.jai";
#load "render/gpu.jai";

#import "Basic";
#import "SDL3";
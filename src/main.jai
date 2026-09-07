#load "scene.jai";
#load "model.jai";
#load "render/renderer.jai";
#load "render/software.jai";
#load "render/gpu.jai";

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
WINDOW_WIDTH :: 1920;
WINDOW_HEIGHT :: 1080;

app_init :: (_: **void, argc: s32, argv: **u8) -> SDL_AppResult
{
    SDL_SetAppMetadata("cutengine", "v0.0.1", "com.engine.cutengine");

    ok := SDL_InitSubSystem(.VIDEO);
    if !ok {
        log_error("Couldn't initialize SDL: %", SDL_GetErrorString());
        return .FAILURE;
    }

    window := SDL_CreateWindow("cutengine", WINDOW_WIDTH, WINDOW_HEIGHT, 0);
    if !window {
        log_error("Couldn't create window: %", SDL_GetErrorString());
        return .FAILURE;
    }

    state.window = window;
    state.renderer, ok = renderer_make(window, .SOFTWARE, WINDOW_WIDTH, WINDOW_HEIGHT);
    if !ok  return .FAILURE;

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
    SDL_EnterAppMainCallbacks(app_init, app_iterate, app_event, app_quit);
}

#import "Basic";
#import "SDL3";
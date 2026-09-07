#import "Basic";
#import "SDL3";

#load "render/renderer.jai";

engine_logger :: (message: string, data: *void, info: Log_Info)
{
    if !message  return;

    prefix := "";
    if info.common_flags & .ERROR then prefix = "ERRO: ";
    else if info.common_flags & .WARNING then prefix = "WARN: ";
    else prefix = "INFO: ";

    newline := ifx message[message.count-1] == #char "\n" then "" else "\n";
    write_strings(prefix, message, newline, to_standard_error = (info.common_flags & .ERROR) != 0);
}

Game_State :: struct
{
    window: *SDL_Window;
    renderer: Renderer;
}

game_state: Game_State; /* static */

app_init :: (app_state: **void, argc: s32, argv: **u8) -> SDL_AppResult
{
    app_state.* = *game_state;
    SDL_SetAppMetadata("cutengine", "v0.0.1", "com.engine.cutengine");

    ok := SDL_InitSubSystem(.VIDEO);
    if !ok {
        log_error("Couldn't initialize SDL: %", SDL_GetErrorString());
        return .FAILURE;
    }

    window := SDL_CreateWindow("cutengine", 1920, 1080, 0);
    if !ok {
        log_error("Couldn't create window: %", SDL_GetErrorString());
        return .FAILURE;
    }

    game_state.window = window;
    game_state.renderer, ok = renderer_make(window, .SOFTWARE, 1920, 1080);
    if !ok  return .FAILURE;

    return .CONTINUE;
}

app_event :: (app_state: *void, event: *SDL_Event) -> SDL_AppResult
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

app_iterate :: (app_state: *void) -> SDL_AppResult
{
    state := cast(*Game_State) app_state;
    renderer_draw(*state.renderer);
    reset_temporary_storage();
    return .CONTINUE;
}

app_quit :: (app_state: *void, result: SDL_AppResult)
{
    state := cast(*Game_State) app_state;

    renderer_drop(*state.renderer);
    if state.window  SDL_DestroyWindow(state.window);

    SDL_Quit();
}

main :: ()
{
    context.logger = engine_logger;
    SDL_EnterAppMainCallbacks(app_init, app_iterate, app_event, app_quit);
}
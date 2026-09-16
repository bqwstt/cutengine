platform_init :: (title: string, width: s32, height: s32) -> Window, bool
{
    SDL_SetAppMetadata("cutengine", "v0.0.1", "com.engine.cutengine");

    log("ok opened window bich");
    ok := SDL_InitSubSystem(.VIDEO);
    if !ok {
        log_error("Couldn't initialize SDL: %", SDL_GetErrorString());
        return .{}, false;
    }

    // Use high pixel density, otherwise we have blurry edges on MacOS
    window_flags: SDL_WindowFlags = .HIGH_PIXEL_DENSITY | .RESIZABLE;
    sdl_window := SDL_CreateWindow(to_c_string(title,,temp), WINDOW_WIDTH, WINDOW_HEIGHT, window_flags);
    if !sdl_window {
        log_error("Couldn't create SDL window: %", SDL_GetErrorString());
        return .{}, false;
    }

    window: Window;
    window.native = cast(*Native_Window) sdl_window;
    window.width = width;
    window.height = height;
    return window, true;
}

platform_shutdown :: (window: *Window)
{
    sdl_win := convert_to_sdl_window(window);
    SDL_DestroyWindow(sdl_win);
    SDL_Quit();
}

platform_poll_events :: (window: *Window, input: *Input)
{
    event: SDL_Event;
    while SDL_PollEvent(*event) {
        // @FIXME: Return input instead of doing actual things.
        // That way we can check for key presses outside the platform layer.
	    if event.type == {
		case .QUIT;
		    input.quit_requested = true;
		case .KEY_DOWN;
		    if event.key.key == SDLK_ESCAPE {
                input.quit_requested = true;
            }
	    }
	}
}

platform_time_ns :: () -> u64
{
    return SDL_GetTicksNS();
}

#scope_file

convert_to_sdl_window :: (w: *Window) -> *SDL_Window
{
    return cast(*SDL_Window) w.native;
}

#load "platform.jai";

#import "SDL3";
platform_init :: (title: string, width: s32, height: s32) -> Window, bool
{
    SDL_SetAppMetadata("cutengine", "v0.0.1", "com.engine.cutengine");

    ok := SDL_InitSubSystem(.VIDEO);
    if !ok {
        log_error("Couldn't initialize SDL: %", SDL_GetErrorString());
        return .{}, false;
    }

    // Use high pixel density, otherwise we have blurry edges on MacOS
    window_flags: SDL_WindowFlags = .HIGH_PIXEL_DENSITY | .RESIZABLE;
    sdl_window := SDL_CreateWindow(to_c_string(title,,temp), width, height, window_flags);
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
	    if event.type == {
		case .QUIT;
		    input.quit_requested = true;

        // Keyboard-related events
		case .KEY_DOWN; #through;
        case .KEY_UP;
            if event.key.repeat  continue;
            key := translate_sdl_key(event.key.scancode);
            if key == .UNKNOWN  continue;

            b := *input.keyboard_buttons[key];
            b.ended_down = event.type == .KEY_DOWN;
            b.half_transitions += 1;

        // Mouse-related events
        case .MOUSE_BUTTON_DOWN; #through;
        case .MOUSE_BUTTON_UP;
            button := translate_sdl_mouse_button(event.button.button);
            b := *input.mouse_buttons[button];
            b.ended_down = event.type == .MOUSE_BUTTON_DOWN;
            b.half_transitions += 1;
        case .MOUSE_WHEEL;
            input.mouse_scroll_wheel += event.wheel.y;
        case .MOUSE_MOTION;
            input.mouse_pos.x = event.motion.x;
            input.mouse_pos.y = event.motion.y;
            input.mouse_delta.x = event.motion.xrel;
            input.mouse_delta.y = event.motion.yrel;
	    }
	}
}

platform_get_window_width :: (window: *Window) -> (u32, u32)
{
    window_width, window_height: s32;
    SDL_GetWindowSizeInPixels(convert_to_sdl_window(window), *window_width, *window_height);
    return cast(u32) window_width, cast(u32) window_height;
}

#scope_file

convert_to_sdl_window :: inline (w: *Window) -> *SDL_Window
{
    return cast(*SDL_Window) w.native;
}

translate_sdl_mouse_button :: (sdl_button: u8) -> Mouse_Button
{
    if sdl_button == {
        case SDL_BUTTON_LEFT;   return .LEFT_CLICK;
        case SDL_BUTTON_RIGHT;  return .RIGHT_CLICK;
        case SDL_BUTTON_MIDDLE; return .SCROLL_WHEEL_CLICK;
    }

    return .UNKNOWN;
}

translate_sdl_key :: (sdl_key: SDL_Scancode) -> Keyboard_Key
{
    SDL :: SDL_Scancode; MY :: Keyboard_Key;

    if sdl_key == {
        case SDL.Q; return MY.Q;
        case SDL.W; return MY.W;
        case SDL.E; return MY.E;
        case SDL.R; return MY.R;
        case SDL.T; return MY.T;
        case SDL.Y; return MY.Y;
        case SDL.U; return MY.U;
        case SDL.I; return MY.I;
        case SDL.O; return MY.O;
        case SDL.P; return MY.P;

        case SDL.A; return MY.A;
        case SDL.S; return MY.S;
        case SDL.D; return MY.D;
        case SDL.F; return MY.F;
        case SDL.G; return MY.G;
        case SDL.H; return MY.H;
        case SDL.J; return MY.J;
        case SDL.K; return MY.K;
        case SDL.L; return MY.L;

        case SDL.Z; return MY.Z;
        case SDL.X; return MY.X;
        case SDL.C; return MY.C;
        case SDL.V; return MY.V;
        case SDL.B; return MY.B;
        case SDL.N; return MY.N;
        case SDL.M; return MY.M;

        case SDL._1; return MY.NUM_1;
        case SDL._2; return MY.NUM_2;
        case SDL._3; return MY.NUM_3;
        case SDL._4; return MY.NUM_4;
        case SDL._5; return MY.NUM_5;
        case SDL._6; return MY.NUM_6;
        case SDL._7; return MY.NUM_7;
        case SDL._8; return MY.NUM_8;
        case SDL._9; return MY.NUM_9;
        case SDL._0; return MY.NUM_0;

        case SDL.LEFT;  return MY.LEFT_ARROW;
        case SDL.RIGHT; return MY.RIGHT_ARROW;
        case SDL.UP;    return MY.UP_ARROW;
        case SDL.DOWN;  return MY.DOWN_ARROW;

        case SDL.MINUS;        return MY.MINUS;
        case SDL.EQUALS;       return MY.EQUALS;
        case SDL.LEFTBRACKET;  return MY.LEFT_BRACKET;
        case SDL.RIGHTBRACKET; return MY.RIGHT_BRACKET;
        case SDL.BACKSLASH;    return MY.BACKSLASH;
        case SDL.SEMICOLON;    return MY.SEMICOLON;
        case SDL.APOSTROPHE;   return MY.TICK;
        case SDL.COMMA;        return MY.COMMA;
        case SDL.PERIOD;       return MY.DOT;
        case SDL.SLASH;        return MY.SLASH;
        case SDL.GRAVE;        return MY.BACKTICK;

        case SDL.LSHIFT; return MY.LEFT_SHIFT;
        case SDL.RSHIFT; return MY.RIGHT_SHIFT;
        case SDL.LCTRL;  return MY.LEFT_CTRL;
        case SDL.RCTRL;  return MY.RIGHT_CTRL;
        case SDL.LALT;   return MY.LEFT_ALT;    // Option on Mac
        case SDL.RALT;   return MY.RIGHT_ALT;
        case SDL.LGUI;   return MY.LEFT_CMD;    // Cmd on Mac, Windows key on PC
        case SDL.RGUI;   return MY.RIGHT_CMD;   // Mac only

        case SDL.RETURN; return MY.RETURN;
        case SDL.DELETE; return MY.DELETE;
        case SDL.ESCAPE; return MY.ESCAPE;
    }

    return .UNKNOWN;
}

#import "SDL3";
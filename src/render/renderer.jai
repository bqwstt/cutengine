#scope_export

Backend_Kind :: enum u32 {
    GPU :: 0;
    SOFTWARE :: 1;
}

Renderer :: struct {
    window: *SDL_Window;
    sdl_renderer: *SDL_Renderer;
    width: s32;
    height: s32;

    using data: Backend_Data;
    Backend_Data :: union backend: Backend_Kind {
        .SOFTWARE ,, software_data: Software_Renderer_Data;
        .GPU      ,, gpu_data: Gpu_Renderer_Data;
    }
}

renderer_make :: (window: *SDL_Window, backend: Backend_Kind, width: s32, height: s32) -> Renderer, bool
{
    ren: Renderer;
    ren.backend = backend;
    ren.window = window;
    ren.width = width;
    ren.height = height;

    ren.sdl_renderer = SDL_CreateRenderer(window, null);
    if !ren.sdl_renderer {
        log_error("Couldn't create SDL renderer: %", SDL_GetErrorString());
        return .{}, false;
    }

    ok := SDL_SetRenderVSync(ren.sdl_renderer, 1);
    if !ok {
        log_error("Couldn't set renderer VSync: %", SDL_GetErrorString());
        return .{}, false;
    }

    if #complete backend == {
    case .SOFTWARE;
        data, ok := software_renderer_make(ren.sdl_renderer, width, height);
        if !ok  return .{}, false;
        ren.software_data = data;
    case .GPU;
        /* gpu data creation */
    }

    return ren, true;
}

renderer_drop :: (using ren: *Renderer)
{
    if #complete backend == {
    case .SOFTWARE;
        software_renderer_drop(*software_data);
    case .GPU;
        /* gpu data drop */
    }

    if sdl_renderer  SDL_DestroyRenderer(sdl_renderer);
    ren.* = .{};
}

renderer_draw :: (using ren: *Renderer)
{
    if #complete backend == {
    case .SOFTWARE;
        software_renderer_draw(sdl_renderer, *software_data);
    case .GPU;
        gpu_renderer_draw(sdl_renderer);
    }

    SDL_RenderPresent(sdl_renderer);
}

#import "Basic";
#import "SDL3";
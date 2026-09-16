renderer_init :: (window: *Window, backend: Backend_Kind, width: s32, height: s32) -> Renderer, bool
{
    ren: Renderer;
    ren.backend = backend;
    ren.window = window;

    if #complete backend == {
    case .SOFTWARE;
    /* @FIXME: Removed until this works.
        data, ok := software_renderer_make(window, width, height);
        if !ok  return .{}, false;

        ren.software_data = data;
    */
    case .GPU;
        data, ok := sdl_gpu_renderer_make(window);
        if !ok  return .{}, false;

        ren.gpu_data = data;
    }

    return ren, true;
}

renderer_drop :: (using ren: *Renderer)
{
    if #complete backend == {
    case .SOFTWARE;
    /* @FIXME: Removed until this works.
        software_renderer_drop(*software_data);
    */
    case .GPU;
        sdl_gpu_renderer_drop(window, *gpu_data);
    }

    ren.* = .{};
}

renderer_draw :: (using ren: *Renderer)
{
    if #complete backend == {
    case .SOFTWARE;
    /* @FIXME: Removed until this works.
        software_renderer_draw(*software_data);
    */
    case .GPU;
        sdl_gpu_renderer_draw(window, *gpu_data);
    }
}

Backend_Kind :: enum u32 {
    GPU :: 0;
    SOFTWARE :: 1;
}

Renderer :: struct {
    window: *Window;

    using data: Backend_Data;
    Backend_Data :: union backend: Backend_Kind {
        .SOFTWARE ,, software_data: Software_Renderer_Data;
        .GPU      ,, gpu_data: Gpu_Renderer_Data;
    }
}

#load "renderer_software.jai";
#load "renderer_sdl_gpu.jai";

#import "Basic";
#load "software.jai";
#load "model_loader.jai";

#scope_file

Backend_Kind :: enum u32 {
    GPU :: 0;
    SOFTWARE :: 1;
}

Software_Renderer_Data :: struct {
    framebuffer: Framebuffer;
    texture: *SDL_Texture;
}

Gpu_Renderer_Data :: struct {}

model: Model;

#scope_export

Renderer :: struct {
    window: *SDL_Window;
    renderer: *SDL_Renderer;
    width: s32;
    height: s32;

    camera: Camera;

    using data: Backend_Data;
    Backend_Data :: union backend: Backend_Kind {
        .SOFTWARE ,, software: Software_Renderer_Data;
        .GPU      ,, gpu: Gpu_Renderer_Data;
    }
}

renderer_make :: (window: *SDL_Window, backend: Backend_Kind, width: s32, height: s32) -> Renderer, bool
{
    ren: Renderer;
    ren.backend = backend;
    ren.window = window;
    ren.width = width;
    ren.height = height;

    ren.camera = Camera.{ position = .{ 0, -2, -30 } };
    ren.camera.fov = 400;

    // @FIXME: Remove
    model = model_load("assets/teddybear.obj");

    ren.renderer = SDL_CreateRenderer(window, null);
    if !ren.renderer {
        log_error("Couldn't create SDL renderer: %", SDL_GetErrorString());
        return .{}, false;
    }

    ok := SDL_SetRenderVSync(ren.renderer, 1);
    if !ok {
        log_error("Couldn't set renderer VSync: %", SDL_GetErrorString());
        return .{}, false;
    }

    if #complete backend == {
    case .SOFTWARE;
        soft := *ren.software;
        soft.texture = SDL_CreateTexture(ren.renderer, .ARGB8888, .STREAMING, width, height);
        if !ren.software.texture {
            log_error("Couldn't create texture for software renderer: %", SDL_GetErrorString());
            return .{}, false;
        }

        soft.framebuffer = framebuffer_make(width, height);
    case .GPU;
    }

    return ren, true;
}

renderer_drop :: (using ren: *Renderer)
{
    if #complete backend == {
    case .SOFTWARE;
        if software.texture  SDL_DestroyTexture(software.texture);
        framebuffer_drop(*software.framebuffer);
    case .GPU;
    }

    if renderer  SDL_DestroyRenderer(renderer);
    ren.* = .{};
}

renderer_draw :: (using ren: *Renderer)
{
    if #complete backend == {
    case .SOFTWARE;
        fb := *software.framebuffer;
        framebuffer_clear(fb, .BLACK);
        framebuffer_draw_model(fb, camera, model, .GREEN);
        SDL_UpdateTexture(software.texture, null, fb.pixels.data, fb.width * size_of(u32));
        SDL_RenderTexture(renderer, software.texture, null, null);
    case .GPU;
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        SDL_RenderClear(renderer);
    }

    SDL_RenderPresent(renderer);
}

#import "Basic";
#import "SDL3";
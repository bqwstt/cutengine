renderer_init :: (window: *Window, backend: Backend_Kind, width: s32, height: s32) -> Renderer, bool
{
    ren: Renderer;
    ren.backend = backend;
    ren.window = window;

    if #complete backend == {
    case .SOFTWARE;
        data, ok := software_renderer_make(window, width, height);
        if !ok  return .{}, false;

        ren.software_data = data;
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
        software_renderer_drop(*software_data);
    case .GPU;
        sdl_gpu_renderer_drop(window, *gpu_data);
    }

    ren.* = .{};
}

renderer_draw :: (using ren: *Renderer, camera: *Camera)
{
    if #complete backend == {
    case .SOFTWARE;
        software_renderer_draw(*software_data);
    case .GPU;
        sdl_gpu_renderer_draw(window, *gpu_data, camera);
    }
}

renderer_execute_commands :: (using ren: *Renderer, list: *Render_List)
{
    if #complete backend == {
    case .SOFTWARE;
        /* ... */
    case .GPU;
        sdl_gpu_renderer_execute_commands(window, *gpu_data, list);
    }
}

render_list_init :: (list: *Render_List, clear_color: Vector4)
{
    list.clear_color = clear_color;
    array_free(list.commands);
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

Render_Command_Kind :: enum u32 {
    DRAW_INDEXED;
}

Render_Command :: struct {
    using data: Command_Data;
    Command_Data :: union kind: Render_Command_Kind {
        .DRAW_INDEXED ,, draw_indexed: Draw_Indexed_Render_Command;
    }
}

Render_List :: struct {
    clear_color: Vector4;

    // @TODO: Convert to small array or similar?
    commands: [..]Render_Command;
}

Draw_Indexed_Render_Command :: struct {
    mesh: Mesh_Handle;
    texture: Texture_Handle;
}

#load "renderer_software.jai";
#load "renderer_sdl_gpu.jai";

#import "Basic";
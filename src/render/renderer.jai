// #region API-specific renderers

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

renderer_execute_commands :: (using ren: *Renderer, list: *Render_List)
{
    if #complete backend == {
    case .SOFTWARE;
        // TODO: Implement software execution of render list
    case .GPU;
        sdl_gpu_renderer_execute_commands(window, *gpu_data, list);
    }
}

render_list_begin :: (list: *Render_List, clear_color: Vector4)
{
    list.clear_color = clear_color;
    list.commands_count = 0;
}

render_list_commands :: (list: *Render_List) -> []Render_Command { return array_view(list.commands, 0, list.commands_count); }

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

// #region Render commands

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

    commands:       [1024]Render_Command;
    commands_count: s64;
}

Draw_Indexed_Render_Command :: struct {
    mesh: Mesh_Handle;
    texture: Texture_Handle;
}

#scope_file

// @TODO:
// push_command :: (list: *Render_List, kind: Render_Command_Kind) -> *Render_Command;

#load "backend/renderer_software.jai";
#load "backend/renderer_sdl_gpu.jai";

#import "Basic";
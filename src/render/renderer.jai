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
    case .SOFTWARE; software_renderer_drop(*software_data);
    case .GPU; sdl_gpu_renderer_drop(window, *gpu_data);
    }

    ren.* = .{};
}

renderer_execute_commands :: (using ren: *Renderer, list: *Render_List)
{
    if #complete backend == {
    case .SOFTWARE;
        // TODO: Implement software execution of render list
    case .GPU; sdl_gpu_renderer_execute_commands(window, *gpu_data, list);
    }
}

render_list_begin :: (list: *Render_List, view_projection: Matrix4, clear_color: Vector4 = .{ 0.0, 0.0, 0.0, 1.0 })
{
    list.clear_color = clear_color;
    list.view_projection = view_projection;
    list.commands_count = 0;
}

renderer_upload_mesh :: (using ren: *Renderer, mesh: Mesh) -> Mesh_Handle
{
    if #complete backend == {
    case .SOFTWARE; return .{}; // Nothing?
    case .GPU; return sdl_gpu_upload_mesh(*gpu_data, mesh);
    }
}

render_draw_mesh :: (list: *Render_List, mesh: Mesh_Handle, transform: Matrix4)
{
    cmd := push_command(list, .DRAW_INDEXED);
    if !cmd  return;

    cmd.draw_indexed = Draw_Indexed_Render_Command.{ mesh = mesh, transform = transform };
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
    view_projection: Matrix4; // @TODO: Should this belong here?

    commands:       [1024]Render_Command;
    commands_count: s64;
}

Draw_Indexed_Render_Command :: struct {
    mesh: Mesh_Handle;
    transform: Matrix4; // @TODO: Should this belong here?
}

#scope_file

push_command :: (list: *Render_List, kind: Render_Command_Kind) -> *Render_Command
{
    if list.commands_count >= list.commands.count  return null;

    cmd := *list.commands[list.commands_count];
    cmd.kind = kind;

    list.commands_count += 1;
    return cmd;
}

#load "backend/renderer_software.jai";
#load "backend/renderer_sdl_gpu.jai";

#import "Basic";
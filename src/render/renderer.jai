// #region API-specific renderers

renderer_init :: (window: *Window, backend: Backend_Kind, width: s32, height: s32) -> Renderer, bool
{
    ren: Renderer;
    ren.backend = backend;
    ren.window = window;

    if #complete backend == {
    case .SDL_GPU;
        data, ok := sdl_gpu_renderer_make(window);
        if !ok  return .{}, false;

        ren.gpu_data = data;
        ren.config = Render_Config.FLIP_V;
    }

    return ren, true;
}

renderer_drop :: (using ren: *Renderer)
{
    if #complete backend == {
    case .SDL_GPU; sdl_gpu_renderer_drop(window, *gpu_data);
    }

    ren.* = .{};
}

renderer_execute_commands :: (using ren: *Renderer, list: *Render_List)
{
    if #complete backend == {
    case .SDL_GPU; sdl_gpu_renderer_execute_commands(window, *gpu_data, list);
    }
}

render_list_begin :: (list: *Render_List, uniforms: Render_Uniforms)
{
    list.uniforms = uniforms;
    reset(*list.commands);
    reset(*list.instances);
}

renderer_load_texture :: (using ren: *Renderer, texture: Cpu_Texture) -> Texture_Handle
{
    if #complete backend == {
    case .SDL_GPU; return sdl_gpu_upload_texture(*gpu_data, texture);
    }
}

renderer_load_mesh :: (using ren: *Renderer, mesh: Cpu_Mesh) -> Mesh_Handle
{
    if #complete backend == {
    case .SDL_GPU; return sdl_gpu_upload_mesh(*gpu_data, mesh);
    }
}

render_draw_mesh :: (list: *Render_List, mesh: Mesh_Handle, transform: Matrix4)
{
    cmd := push_command(list, .DRAW_INDEXED);
    if !cmd  return;

    uniforms: Draw_Indexed_Render_Command.Uniforms;
    uniforms.transform = transform;
    cmd.draw_indexed = Draw_Indexed_Render_Command.{ mesh = mesh, uniforms = uniforms }; 
}

render_draw_mesh_instances :: (list: *Render_List, mesh: Mesh_Handle, transform: Matrix4, instances: []Render_Instance)
{
    // Copy render instances to list
    instance := push(*list.instances, instances);
    if !instance  return;

    cmd := push_command(list, .DRAW_INDEXED_INSTANCES);
    if !cmd  return;

    uniforms: Draw_Indexed_Instanced_Render_Command.Uniforms;
    uniforms.transform = transform;
    cmd.draw_indexed_instances = Draw_Indexed_Instanced_Render_Command.{
        mesh = mesh,
        uniforms = uniforms,
        instances = instances.count
    };
}

render_list_commands  :: (list: *Render_List) -> []Render_Command  { return view(list.commands); }
render_list_instances :: (list: *Render_List) -> []Render_Instance { return view(list.instances); }

Backend_Kind :: enum u32 {
    SDL_GPU :: 0;
}

Renderer :: struct {
    window: *Window;
    config: Render_Config;

    using data: Backend_Data;
    Backend_Data :: union backend: Backend_Kind {
        .SDL_GPU ,, gpu_data: Gpu_Renderer_Data;
    }
}

// #region Render commands

Render_Command_Kind :: enum u32 {
    DRAW_INDEXED;
    DRAW_INDEXED_INSTANCES;
}

Render_Command :: struct {
    using data: Command_Data;
    Command_Data :: union kind: Render_Command_Kind {
        .DRAW_INDEXED ,, draw_indexed: Draw_Indexed_Render_Command;
        .DRAW_INDEXED_INSTANCES ,, draw_indexed_instances: Draw_Indexed_Instanced_Render_Command;
    }
}

// @TODO: Not sure if I like to have this here.
Render_Instance :: struct {
    position: Vector3;
    _padding: [1]u8;
}
// For instanced drawing, shaders use 16-bit aligned float4s, so we need to make sure our struct is 16 bytes as well.
#assert size_of(Render_Instance) % 16 == 0;

Render_List :: struct {
    clear_color: Vector4;

    uniforms:  Render_Uniforms;
    commands:  Fixed_Array(Render_Command, MAX_RENDER_COMMANDS);
    instances: Fixed_Array(Render_Instance, MAX_RENDER_INSTANCES);
}

// #region Render uniforms

// All of the fields inside this struct will be accessible by the GPU,
// so they must be 16-bit aligned.
Render_Uniforms :: struct {
    camera:   Render_Camera_Uniforms;
    light:    Render_Light_Uniforms;
    _padding: [1]u8;
}
#assert size_of(Render_Uniforms) % 16 == 0;

Render_Camera_Uniforms :: struct {
    view_projection: Matrix4;
}

Render_Light_Uniforms :: struct {
    global_light: Light_Source;
}

Render_Config :: enum_flags u8 {
    FLIP_Y;
    FLIP_Z;
    FLIP_V;
}

Draw_Indexed_Render_Command :: struct {
    mesh: Mesh_Handle;
    uniforms: Uniforms;

    #assert size_of(Uniforms) % 16 == 0;
    Uniforms :: struct {
        transform: Matrix4;
    }
}

Draw_Indexed_Instanced_Render_Command :: struct {
    using base: Draw_Indexed_Render_Command;
    instances: s64;
}

MAX_RENDER_COMMANDS :: 1024;
MAX_RENDER_INSTANCES :: 16384;

#scope_file

push_command :: (list: *Render_List, kind: Render_Command_Kind) -> *Render_Command
{
    cmd: Render_Command;
    cmd.kind = kind;
    return push(*list.commands, cmd);
}

// @TODO: Make this a module and only export backend functions to this file.
#load "backend/renderer_sdl_gpu.jai";

#import "Basic";
game_init :: (state: *Game_State, renderer: *Renderer)
{
    state.camera = camera_make(renderer.window);
    state.light.position = Vector3.{ 10, 10, 10 };

    tent_asset, ok := load_model_asset("tent.ca");
    assert(ok, "Failed to load asset");

    tent_model := load_model(renderer, tent_asset);
    state.light.model = tent_model;
    state.obj.model   = tent_model;

    camera_move(*state.camera, .{ 0, 0, 1 }); // Move the camera a bit back
}

/// Constructs the game render list with commands to be executed by the renderer.
/// These commands are graphics API-agnostic, which means each individual API will implement
/// code that will execute these commands in their own layer.
game_construct_render_list :: (list: *Render_List, prev_state: *Game_State, curr_state: *Game_State, alpha: float64)
{
    uniforms: Render_Uniforms;
    uniforms.camera.view_projection = curr_state.camera.projection_matrix * curr_state.camera.view_matrix;
    uniforms.light.global_light.color = Vector4.{ 1.0, 1.0, 1.0, 1.0 };
    uniforms.light.global_light.position = curr_state.light.position;

    render_list_begin(list, uniforms);

    obj: Object;
    light: Object;

    // Lerp values
    // @TODO: If this grows to lots of lerps, it might be useful to have a utility that automatically adds lerp calls for us.
    t := cast(float) alpha;
    obj.model = curr_state.obj.model;
    obj.position =  lerp(prev_state.obj.position, curr_state.obj.position, t);
    obj.rotation = nlerp(prev_state.obj.rotation, curr_state.obj.rotation, t);
    obj.scale    =  lerp(prev_state.obj.scale, curr_state.obj.scale, t);

    light.model = curr_state.light.model;
    light.position = lerp(prev_state.light.position, curr_state.light.position, t);
    light.rotation = nlerp(prev_state.light.rotation, curr_state.light.rotation, t);
    light.scale = lerp(prev_state.light.scale, curr_state.light.scale, t);

    render_draw_object(list, *light); // Draw light source (a cube)
    render_draw_object(list, *obj);
}

game_update :: (state: *Game_State, input: *Input, dt: float64)
{
    if key_is_down(input, .A)  camera_move(*state.camera, .{ cast(float) -dt, 0, 0 });
    if key_is_down(input, .D)  camera_move(*state.camera, .{ cast(float)  dt, 0, 0 });
    if key_is_down(input, .W)  camera_move(*state.camera, .{ 0, cast(float)  dt, 0 });
    if key_is_down(input, .S)  camera_move(*state.camera, .{ 0, cast(float) -dt, 0 });

    state.light_angle += cast(float) dt;
    state.light.position.x = state.obj.position.x + 8.0 * cos(state.light_angle);
    state.light.position.y = state.obj.position.y + 5.0;
    state.light.position.z = state.obj.position.z + 8.0 * sin(state.light_angle);

    ROTATION_SPEED :: 0.6;

    if mouse_was_pressed(input, .RIGHT_CLICK)   state.dragging = true;
    if mouse_was_released(input, .RIGHT_CLICK)  state.dragging = false;

    if state.dragging {
        fdt := cast(float) dt;
        dx := input.mouse_delta.x;
        dy := input.mouse_delta.y;
        if abs(dx) < 0.7  dx = 0.0;
        if abs(dy) < 0.7  dy = 0.0;

        x := ROTATION_SPEED * dx * fdt;
        y := ROTATION_SPEED * dy * fdt;
        camera_rotate(*state.camera, .{ x, y });
    }

    camera_move(*state.camera, .{ 0, 0, input.mouse_scroll_wheel * cast(float) dt });
}

Game_State :: struct {
    camera: Camera;
    obj: Object;
    dragging: bool;

    light: Object;
    light_angle: float;
}

#scope_file

render_draw_object :: (list: *Render_List, using obj: *Object)
{
    transform := make_translation_matrix4(position) * rotation_matrix(Matrix4, rotation) * make_scale_matrix4(scale);
    for model.meshes  render_draw_mesh(list, it, model.material, transform);
}

load_model :: (renderer: *Renderer, model: Cpu_Model) -> Model
{
    meshes: [..]Mesh_Handle;
    array_reserve(*meshes, model.meshes.count,, context.transient_allocator);
    for mesh: model.meshes  array_add(*meshes, renderer_load_mesh(renderer, mesh));

    return Model.{
        meshes   = meshes,
        material = renderer_load_textures_using_material(renderer, model.material),
    };
}

Model :: struct {
    meshes: []Mesh_Handle;
    material: Material;
}

// @TEST: One-off entity for drawing. In general, shouldn't be used for drawing things.
Object :: struct {
    model: Model;

    position: Vector3;
    rotation: Quaternion;
    scale:    Vector3 = .{ 1, 1, 1 };
}

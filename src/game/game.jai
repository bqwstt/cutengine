game_init :: (state: *Game_State, renderer: *Renderer)
{
    state.camera = camera_make();

    // Upload sample mesh
    state.obj.mesh = renderer_upload_mesh(renderer, Mesh.{ VERTICES, INDICES });

    camera_move(*state.camera, .{ 0, 0, 1 }); // Move the camera a bit back
}

/// Constructs the game render list with commands to be executed by the renderer.
/// These commands are graphics API-agnostic, which means each individual API will implement
/// code that will execute these commands in their own layer.
game_construct_render_list :: (list: *Render_List, prev_state: *Game_State, curr_state: *Game_State, alpha: float64)
{
    view_proj := curr_state.camera.projection_matrix * curr_state.camera.view_matrix;
    render_list_begin(list, view_proj);

    obj: Object;

    // Lerp values
    // @TODO: If this grows to lots of lerps, it might be useful to have a utility that automatically adds lerp calls for us.
    t := cast(float) alpha;
    obj.mesh = curr_state.obj.mesh;
    obj.position =  lerp(prev_state.obj.position, curr_state.obj.position, t);
    obj.rotation = nlerp(prev_state.obj.rotation, curr_state.obj.rotation, t);
    obj.scale    =  lerp(prev_state.obj.scale, curr_state.obj.scale, t);
    render_draw_object(list, *obj);
}

game_update :: (state: *Game_State, input: *Input, dt: float64)
{
    camera_move(*state.camera, .{ 0, 0, 0.01 });

    // @TODO: Test code, remove
    state.obj.spin_angle += 4.0 * cast(float) dt;
    set_from_axis_and_angle(*state.obj.rotation, 1, 1, 1, state.obj.spin_angle);
}

Game_State :: struct {
    camera: Camera;
    obj: Object;
}

#scope_file

render_draw_object :: (list: *Render_List, using obj: *Object)
{
    transform := make_translation_matrix4(position) * rotation_matrix(Matrix4, rotation) * make_scale_matrix4(scale);
    render_draw_mesh(list, mesh, transform);
}

// @TODO: Test code, remove
VERTICES :: Vertex.[
    //       Position (NDC)                   Texture (UV)
    Vertex.{ position = .{ -0.5, -0.5, 0.0 }, texture_coords = .{ 0, 1 } }, // Bottom-left
    Vertex.{ position = .{  0.5, -0.5, 0.0 }, texture_coords = .{ 1, 1 } }, // Bottom-right
    Vertex.{ position = .{ -0.5,  0.5, 0.0 }, texture_coords = .{ 0, 0 } }, // Top-left
    Vertex.{ position = .{  0.5,  0.5, 0.0 }, texture_coords = .{ 1, 0 } }  // Top-right
];

INDICES :: u32.[
    0, 1, 2, // Face 1: Bottom-left -> Bottom-right -> Top-left
    1, 3, 2  // Face 2: Bottom-right -> Top-right -> Top-left
];
/// Constructs the game render list with commands to be executed by the renderer.
/// These commands are graphics API-agnostic, which means each individual API will implement
/// code that will execute these commands in their own layer.
///
/// @FIXME, @REFACTOR:
/// 1. We probably want to remove the interpolation from `prev_state` to `state` and instead
/// interpolate each individual entity later. Think this through later.
/// 2. We want to produce a Render_List to offload to the renderer, instead of rendering ourselves directly.
game_construct_render_list :: (list: *Render_List, prev_state: *Game_State, curr_state: *Game_State, alpha: float64)
{
    // @TODO: Lerp whatever is needed here.
    render_list_begin(list, clear_color = .{ 1.0, 0.0, 0.0, 1.0 });
}

game_update :: (state: *Game_State, input: *Input, dt: float64)
{
    // Do stuff!    
}

Game_State :: struct {
    camera: Camera;
}

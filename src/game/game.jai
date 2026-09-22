// @FIXME, @REFACTOR:
// 1. We probably want to remove the interpolation from `prev_state` to `state` and instead
// interpolate each individual entity later. Think this through later.
// 2. We want to produce a Render_List to offload to the renderer, instead of rendering ourselves directly.
game_build_render_list :: (prev_state: *Game_State, curr_state: *Game_State, alpha: float64) -> Render_List
{
    // @TODO: Lerp whatever is needed here.
    list: Render_List;
    render_list_init(*list, clear_color = .{ 1.0, 0.0, 0.0, 1.0 });
    return list;
}

game_update :: (state: *Game_State, input: *Input, dt: float64)
{
    // Do stuff!    
}

Game_State :: struct {
    camera: Camera;
}

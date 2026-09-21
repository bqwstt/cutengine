// @FIXME, @REFACTOR:
// 1. We probably want to remove the interpolation from `prev_state` to `state` and instead
// interpolate each individual entity later. Think this through later.
// 2. We want to produce a Render_List to offload to the renderer, instead of rendering ourselves directly.
game_draw :: (ren: *Renderer, prev_state: *Game_State, curr_state: *Game_State, alpha: float64)
{
    // @TODO: Lerp whatever is needed here.
    renderer_draw(ren, *curr_state.camera);
}

game_update :: (state: *Game_State, input: *Input, dt: float64)
{
    // Do stuff!    
}

Game_State :: struct {
    camera: Camera;
}

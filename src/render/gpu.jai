Gpu_Renderer_Data :: struct {}

gpu_renderer_draw :: (sdl_renderer: *SDL_Renderer)
{
    SDL_SetRenderDrawColor(sdl_renderer, 0, 0, 0, 255);
    SDL_RenderClear(sdl_renderer);
}

#import "SDL3";
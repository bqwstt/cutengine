framebuffer_make :: (width: s32, height: s32) -> Framebuffer
{
    fb: Framebuffer;
    fb.width = width;
    fb.height = height;
    fb.pixels = NewArray(width * height, u32);
    return fb;
}

framebuffer_drop :: (fb: *Framebuffer)
{
    array_free(fb.pixels);
    fb.* = .{};
}

framebuffer_clear :: (fb: Framebuffer, color: Color)
{
    for * fb.pixels  it.* = xx color;
}

framebuffer_draw_model :: (fb: Framebuffer, camera: Camera, model: Model, color: Color)
{
    // Draw all projected vertices in the form of triangles
    for model.faces {
        face: Face = it;
        vertex_a := model.vertices[face.a];
        vertex_b := model.vertices[face.b];
        vertex_c := model.vertices[face.c];

        triangle := Triangle.{ vertex_a, vertex_b, vertex_c };
        draw_projected_triangle(fb, camera, triangle, color);
    }
}

software_renderer_make :: (window: *Window, width: s32, height: s32) -> Software_Renderer_Data, bool
{
    // @FIXME: Not sure if I like these things.
    // Right now this depends on SDL, where it really shouldn't.
    surface := SDL_GetWindowSurface(convert_to_sdl_window(window));
    defer SDL_DestroySurface(surface);

    // Create internal SDL renderer and texture to draw to
    sdl_renderer := SDL_CreateSoftwareRenderer(surface);
    if !sdl_renderer {
        log_error("Couldn't create SDL renderer: %", SDL_GetErrorString());
        return .{}, false;
    }

    texture := SDL_CreateTexture(sdl_renderer, .ARGB8888, .STREAMING, width, height);
    if !texture {
        log_error("Couldn't create texture for software renderer: %", SDL_GetErrorString());
        return .{}, false;
    }

    framebuffer := framebuffer_make(width, height);

    data: Software_Renderer_Data;
    data.framebuffer = framebuffer;
    data.texture = texture;
    data.sdl_renderer = sdl_renderer;
    return data, true;
}

software_renderer_drop :: (data: *Software_Renderer_Data)
{
    if data.texture  SDL_DestroyTexture(data.texture);
    if data.sdl_renderer  SDL_DestroyRenderer(data.sdl_renderer);
    framebuffer_drop(*data.framebuffer);
}

software_renderer_draw :: (data: *Software_Renderer_Data)
{
    // Clear framebuffer and update the texture with the new data, then present it.
    fb := data.framebuffer;
    framebuffer_clear(fb, .BLACK);
    SDL_UpdateTexture(data.texture, null, fb.pixels.data, fb.width * size_of(u32));
    SDL_RenderTexture(data.sdl_renderer, data.texture, null, null);
    SDL_RenderPresent(data.sdl_renderer);
}

Framebuffer :: struct {
    pixels: []u32;
    width: s32;
    height: s32;
}

Software_Renderer_Data :: struct {
    framebuffer: Framebuffer;
    texture: *SDL_Texture;
    sdl_renderer: *SDL_Renderer;
}

#scope_file

/// Color pixel at (x, y)
put_pixel :: (fb: Framebuffer, x: s32, y: s32, color: Color)
{
    if x < 0 || x >= fb.width || y < 0 || y >= fb.height  return; 
    fb.pixels[(fb.width * y) + x] = xx color;
}

/// Draw a line between two points (ax, ay) and (bx, by)
/// References:
/// * https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
/// * https://haqr.eu/tinyrenderer/bresenham/
draw_segment :: (fb: Framebuffer, ax: s32, ay: s32, bx: s32, by: s32, color: Color)
{
    // If the line is too steep, and given that we increment by x later, we want
    // to preserve the smooth filling, we can swap x and y together to not lose
    // pixels on the way
    //
    //     * │          * │      Notice the extra space when on the x-axis,
    //       │y        *  │x     these get eliminated once we iterate over y.
    //    *  │'        *  │'     Think of rotating the screen when filling.
    //       │a       *   │a
    //   *   │x ───>  *   │x
    //       │i      *    │i
    //  *    │s      *    │s
    //  ─────┘       ─────┘
    //  x-axis       y-axis
    steep := abs(ax-bx) < abs(ay-by);
    if steep {
        swap(*ax, *ay);
        swap(*bx, *by);
    }

    // Our loop goes from x0-->x1, which assumes we're going from left to right.
    // In case that we're starting from the right, we have to swap these points.
    if ax > bx {
        swap(*ax, *bx);
        swap(*ay, *by);
    }

    y := ay;
    ierror := 0;

    for x: ax..bx {
        // If transposed, de-transpose
        if steep  put_pixel(fb, y, x, color);
        else      put_pixel(fb, x, y, color);

        ierror += 2 * abs(by-ay);
        if ierror > (bx-ax) {
            y += xx ifx by > ay then 1 else -1;
            ierror -= 2 * (bx-ax);
        }
    }
}

/// Draw 2D line into 3D space
draw_projected_line :: (fb: Framebuffer, camera: Camera, line: Line, color: Color)
{
    from := project_to_screen(camera, line.from);
    to := project_to_screen(camera, line.to);
    draw_segment(fb, xx from.x, xx from.y, xx to.x, xx to.y, color);
}

/// Draw a projected 3D triangle
draw_projected_triangle :: (fb: Framebuffer, camera: Camera, triangle: Triangle, color: Color)
{
    a_b := Line.{ triangle.points[0], triangle.points[1] };
    b_c := Line.{ triangle.points[1], triangle.points[2] };
    c_a := Line.{ triangle.points[2], triangle.points[0] };

    draw_projected_line(fb, camera, a_b, color);
    draw_projected_line(fb, camera, b_c, color);
    draw_projected_line(fb, camera, c_a, color);
}

convert_to_sdl_window :: (w: *Window) -> *SDL_Window
{
    return cast(*SDL_Window) w.native;
}

#import "Math";
#import "SDL3"; // @FIXME: This shouldn't really be dependant on SDL
#scope_file

Color :: enum u32 {
    BLACK :: 0xFF_00_00_00;
    WHITE :: 0xFF_FF_FF_FF;

    RED   :: 0xFF_FF_00_00;
    GREEN :: 0xFF_00_FF_00;
    BLUE  :: 0xFF_00_00_FF;
}

Line :: struct {
    from, to: Vector3;

    #overlay (from) points: [2]Vector3;
}

Triangle :: struct {
    a, b, c: Vector3;

    #overlay (a) points: [3]Vector3;
}

project :: (camera: Camera, point: Vector3) -> Vector2 {
    v: Vector2;
    v.x = camera.fov * point.x / point.z;
    v.y = camera.fov * point.y / point.z;
    return v;
}

project_to_screen :: (camera: Camera, point: Vector3) -> Vector2 {
    v := project(camera, point - camera.position);
    v.x += WINDOW_WIDTH / 2.0;
    v.y += WINDOW_HEIGHT / 2.0;
    return v;
}

put_pixel :: (fb: Framebuffer, camera: Camera, x: s32, y: s32, color: Color)
{
    tx := x - cast(s32) camera.position.x;
    ty := y - cast(s32) camera.position.y;

    if tx < 0 || tx >= fb.width || ty < 0 || ty >= fb.height  return; 
    fb.pixels[(fb.width * ty) + tx] = xx color;
}

draw_segment :: (fb: Framebuffer, camera: Camera, ax: s32, ay: s32, bx: s32, by: s32, color: Color)
{
    steep := abs(ax-bx) < abs(ay-by);
    if steep {
        swap(*ax, *ay);
        swap(*bx, *by);
    }

    if ax > bx {
        swap(*ax, *bx);
        swap(*ay, *by);
    }

    y := ay;
    ierror := 0;

    for x: ax..bx {
        if steep  put_pixel(fb, camera, y, x, color);
        else      put_pixel(fb, camera, x, y, color);

        ierror += 2 * abs(by-ay);
        if ierror > (bx-ax) {
            y += xx ifx by > ay then 1 else -1;
            ierror -= 2 * (bx-ax);
        }
    }
}

draw_projected_line :: (fb: Framebuffer, camera: Camera, line: Line, color: Color)
{
    from := project_to_screen(camera, line.from);
    to := project_to_screen(camera, line.to);
    draw_segment(fb, camera, xx from.x, xx from.y, xx to.x, xx to.y, color);
}

draw_projected_triangle :: (fb: Framebuffer, camera: Camera, triangle: Triangle, color: Color)
{
    a_b := Line.{ triangle.points[0], triangle.points[1] };
    b_c := Line.{ triangle.points[1], triangle.points[2] };
    c_a := Line.{ triangle.points[2], triangle.points[0] };

    draw_projected_line(fb, camera, a_b, color);
    draw_projected_line(fb, camera, b_c, color);
    draw_projected_line(fb, camera, c_a, color);
}

#import "Math";

#scope_export

Camera :: struct {
    position: Vector3;
    fov: float;
}

Framebuffer :: struct {
    pixels: []u32;
    width: s32;
    height: s32;
}

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

framebuffer_clear :: (fb: *Framebuffer, color: Color)
{
    for * fb.pixels  it.* = xx color;
}

framebuffer_draw_model :: (fb: *Framebuffer, camera: Camera, model: Model, color: Color)
{
    for model.faces {
        face: Vector3 = it;
        vertex_a := model.vertices[xx face.x];
        vertex_b := model.vertices[xx face.y];
        vertex_c := model.vertices[xx face.z];

        triangle := Triangle.{ vertex_a, vertex_b, vertex_c };
        draw_projected_triangle(fb, camera, triangle, color);
    }
}
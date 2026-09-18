// #region 3D

Camera :: struct {
    position: Vector3;
    fov: float;

    aspect_ratio: float;
    view_matrix: Matrix4;
    projection_matrix: Matrix4;
}

camera_make :: () -> Camera
{
    camera: Camera;
    camera.position = .{ 0, 0, 0 };
    camera.fov = 90;
    camera.aspect_ratio = WINDOW_WIDTH / cast(float) WINDOW_HEIGHT;

    camera.projection_matrix = make_projection_matrix(
        camera.fov * PI / 180.0,
        camera.aspect_ratio,
        0.1, 1000.0, depth_range_01 = true);

    return camera;
}

camera_move :: (c: *Camera, delta: Vector3)
{
    c.position += delta;
    c.view_matrix = make_translation_matrix4(-c.position);
}

// #region 2D

/// Project a 3D point to a 2D plane
project :: (camera: Camera, point: Vector3) -> Vector2 {
    v: Vector2;
    v.x = camera.fov * point.x / point.z;
    v.y = camera.fov * point.y / point.z;
    return v;
}

/// Project a 3D point to a 2D plane relative to the camera
project_to_screen :: (camera: Camera, point: Vector3) -> Vector2 {
    v := project(camera, point - camera.position);
    v.x += WINDOW_WIDTH / 2.0;
    v.y += WINDOW_HEIGHT / 2.0;
    return v;
}

// @TODO: Change these, make them modifiable and query during runtime.
WINDOW_WIDTH  :: 1920;
WINDOW_HEIGHT :: 1080;

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

#import "Math";
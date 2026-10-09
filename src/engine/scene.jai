Camera :: struct {
    position: Vector3;     // Position of the camera in world space
    rotation: Quaternion;  // Rotation of the camera (pitch, yaw - roll not used)
    euler_angles: Vector2; // Rotation in euler angles (x, y) used to calculate rotation

    fov: float;
    aspect_ratio: float;

    // The following aren't supposed to be editable but computed.
    view_matrix: Matrix4;
    projection_matrix: Matrix4;
}

camera_make :: (window: *Window, $is_2d_camera := false) -> Camera
{
    camera: Camera;
    camera.position = .{ 0, 0, 0 };

    camera.view_matrix = make_translation_matrix4(make_vector3(0));

    window_width, window_height := platform_get_window_width(window);

    #if is_2d_camera {
        camera.projection_matrix = orthographic_projection_matrix(
            0, window_width,
            window_height, 0,
            0.1, 1000.0, depth_range_01 = true);
    } else {
        camera.fov = 90;
        camera.aspect_ratio = window_width / cast(float) window_height;
        camera.projection_matrix = make_projection_matrix(
            camera.fov * PI / 180.0,
            camera.aspect_ratio,
            0.1, 1000.0, depth_range_01 = true);
    }

    return camera;
}

/// Moves the camera by `delta` steps, in all x, y and z components.
camera_move :: (using c: *Camera, delta: Vector3)
{
    position += delta;
    view_matrix = make_translation_matrix4(-position) * rotation_matrix(Matrix4, rotation);
}

/// Rotates the camera using `amount` (x and y components only).
/// This effectively is the camera's pitch and yaw. Does not roll the camera (i.e., rotation around the z axis).
camera_rotate :: (using c: *Camera, amount: Vector2)
{
    yaw:   Quaternion;
    pitch: Quaternion;

    euler_angles.x += amount.x;
    euler_angles.y += amount.y;

    // Clamp to void gimbal lock
    // Taken from examples/skeletal-animation/camera.jai
    euler_angles.y = clamp(euler_angles.y, -89.0 * PI / 180.0, 89.0 * PI / 180.0);

    set_from_axis_and_angle(*yaw, 0, 1, 0, euler_angles.x);
    set_from_axis_and_angle(*pitch, 1, 0, 0, euler_angles.y);
    rotation = yaw * pitch;

    view_matrix = make_translation_matrix4(-position) * rotation_matrix(Matrix4, rotation);
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

#import "Math";
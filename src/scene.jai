Color :: enum u32 {
    BLACK :: 0xFF_00_00_00;
    WHITE :: 0xFF_FF_FF_FF;

    RED   :: 0xFF_FF_00_00;
    GREEN :: 0xFF_00_FF_00;
    BLUE  :: 0xFF_00_00_FF;
}

Camera :: struct {
    position: Vector3;
    fov: float;
}

Line :: struct {
    from, to: Vector3;

    #overlay (from) points: [2]Vector3;
}

Triangle :: struct {
    a, b, c: Vector3;

    #overlay (a) points: [3]Vector3;
}

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

#import "Math";
/// This is an example Boids simulation game.

game_init :: (state: *Game_State, renderer: *Renderer)
{
    state.camera = camera_make(is_2d_camera = true);
    state.flock.boid_mesh = renderer_upload_mesh(renderer, Mesh.{ VERTICES, INDICES });

    for i: 0 .. N-1 {
        pos := Vector2.{
            x = random_get_zero_to_one() * WINDOW_WIDTH,
            y = random_get_zero_to_one() * WINDOW_HEIGHT
        };
        state.flock.positions[i] = pos;
        state.flock.velocities[i] = Vector2.{
            random_get_within_range(-100.0, 100.0),
            random_get_within_range(-100.0, 100.0),
        };
    }

    clean_and_rebuild_grid(*state.grid, *state.flock);
}

/// Constructs the game render list with commands to be executed by the renderer.
/// These commands are graphics API-agnostic, which means each individual API will implement
/// code that will execute these commands in their own layer.
game_construct_render_list :: (list: *Render_List, prev_state: *Game_State, curr_state: *Game_State, alpha: float)
{
    view_proj := curr_state.camera.projection_matrix * curr_state.camera.view_matrix;
    render_list_begin(list, view_proj);

    draw_boids(list, *prev_state.flock, *curr_state.flock, alpha);
}

game_update :: (state: *Game_State, input: *Input, dt: float64)
{
    clean_and_rebuild_grid(*state.grid, *state.flock);
    update_boids(*state.grid, *state.flock, dt);
}

Game_State :: struct {
    camera: Camera;

    grid: Grid;
    flock: Flock;
}

#scope_file

Flock :: struct {
    boid_mesh: Mesh_Handle;

    positions:  [N]Vector2;
    velocities: [N]Vector2;
}

Cell_Coord :: #type,distinct Vector2;
Cell_Bucket :: #type [..]int;

hash_coords :: (coord: Cell_Coord) -> u32
{
    return get_hash(coord.y, get_hash(coord.x));
}

compare_coords :: (a: Cell_Coord, b: Cell_Coord) -> bool
{
    return a.x == b.x && a.y == b.y;
}

Grid :: struct {
    coord_to_bucket: Table(
        Cell_Coord,
        Cell_Bucket,
        given_hash_function = hash_coords,
        given_compare_function = compare_coords);
}

boid_coord :: (boid_pos: Vector2) -> Cell_Coord
{
    return Cell_Coord.{
        x = floor(boid_pos.x / GRID_CELL_SIZE),
        y = floor(boid_pos.y / GRID_CELL_SIZE),
    };
}

clean_and_rebuild_grid :: (grid: *Grid, flock: *Flock)
{
    for *grid.coord_to_bucket  it.* = [..]int.{};

    for flock.positions {
        coord := boid_coord(it);
        bucket := table_find_pointer(*grid.coord_to_bucket, coord);
        if !bucket  bucket = table_add(*grid.coord_to_bucket, coord, [..]int.{});
        array_add(bucket, it_index,, context.per_frame_allocator);
    }
}

N :: 10_000;
VISIBLE_RANGE :: 100.0;
PROTECTED_RANGE :: 20.0;
AVOID_FACTOR :: 2.0;
MATCHING_FACTOR :: 1.8;
CENTERING_FACTOR :: 0.5;
TURN_FACTOR :: 8.0;
MAX_SPEED :: 400.0;
MIN_SPEED :: 200.0;

GRID_CELL_SIZE :: VISIBLE_RANGE;
GRID_ROWS :: WINDOW_HEIGHT / GRID_CELL_SIZE;
GRID_COLUMNS :: WINDOW_WIDTH / GRID_CELL_SIZE;

MAX_NEIGHBORS :: 24;

update_boids :: (grid: *Grid, flock: *Flock, dt: float64)
{
    for i: 0 .. N-1 {
        boid_pos := *flock.positions[i];
        boid_vel := *flock.velocities[i];

        close_vel: Vector2;
        neighbors_avg_velocities: Vector2;
        avg_pos: Vector2;
        neighboring_boids: float;
        speed := cast(float) 0.0;

        _, n := table_find(*grid.coord_to_bucket, boid_coord(boid_pos));
        for n {
            index_from_bucket := it;
            if i == index_from_bucket  continue;

            other_pos := flock.positions[index_from_bucket];
            other_vel := flock.velocities[index_from_bucket];

            // In debug builds, operator overloading costs an extra function call,
            // which can hurt performance. (They won't affect release builds, though.)
            diff := Vector2.{boid_pos.x - other_pos.x, boid_pos.y - other_pos.y};
            distance := diff.x * diff.x + diff.y * diff.y; // a^2 + b^2

            if distance < PROTECTED_RANGE*PROTECTED_RANGE {
                close_vel += boid_pos - other_pos;
            } else if distance < VISIBLE_RANGE*VISIBLE_RANGE {
                neighbors_avg_velocities.x += other_vel.x;
                neighbors_avg_velocities.y += other_vel.y;
                avg_pos.x += other_pos.x;
                avg_pos.y += other_pos.y;
                neighboring_boids += 1;
            }

            // Do not look for more then 24 boids at a time.
            if neighboring_boids >= MAX_NEIGHBORS  break;
        }

        if neighboring_boids > 0 {
            neighbors_avg_velocities /= neighboring_boids;
            avg_pos /= neighboring_boids;
            boid_vel.x += cast(float)
                ((avg_pos.x - boid_pos.x) * CENTERING_FACTOR * dt +
                (neighbors_avg_velocities.x - boid_vel.x) * MATCHING_FACTOR * dt);
            boid_vel.y += cast(float)
                ((avg_pos.y - boid_pos.y) * CENTERING_FACTOR * dt +
                (neighbors_avg_velocities.y - boid_vel.y) * MATCHING_FACTOR * dt);
        }

        boid_vel.x += close_vel.x * AVOID_FACTOR * cast(float) dt;
        boid_vel.y += close_vel.y * AVOID_FACTOR * cast(float) dt;

        if boid_pos.x < 0              boid_vel.x += TURN_FACTOR;
        if boid_pos.x > WINDOW_WIDTH   boid_vel.x -= TURN_FACTOR;
        if boid_pos.y < 0              boid_vel.y += TURN_FACTOR;
        if boid_pos.y > WINDOW_HEIGHT  boid_vel.y -= TURN_FACTOR;

        speed = length(boid_vel);
        if speed > MAX_SPEED {
            boid_vel.x = (boid_vel.x / speed) * MAX_SPEED;
            boid_vel.y = (boid_vel.y / speed) * MAX_SPEED;
        }
        if speed < MIN_SPEED {
            boid_vel.x = (boid_vel.x / speed) * MIN_SPEED;
            boid_vel.y = (boid_vel.y / speed) * MIN_SPEED;
        }

        boid_pos.x += boid_vel.x * cast(float) dt;
        boid_pos.y += boid_vel.y * cast(float) dt;
    }

}

draw_boids :: (list: *Render_List, prev_flock: *Flock, flock: *Flock, alpha: float)
{
    // Fill in instances to draw
    instances: [N]Render_Instance;
    for i: 0 .. N-1
        instances[i].position = make_vector3(lerp(prev_flock.positions[i], flock.positions[i], alpha), 0.0);

    // Make boids very small
    transform := make_scale_matrix4(.{ 1, 1, 1 });
    render_draw_mesh_instances(list, flock.boid_mesh, transform, instances);
}

VERTICES :: Vertex.[
    //       Position (NDC)                   Texture (UV)
    Vertex.{ position = .{ -1.0,  1.0, 0.0 }, texture_coords = .{ 0,   1 } }, // Bottom-left
    Vertex.{ position = .{  0.0, -1.0, 0.0 }, texture_coords = .{ 0.5, 0 } }, // Top-middle
    Vertex.{ position = .{  1.0,  1.0, 0.0 }, texture_coords = .{ 1,   1 } }, // Bottom-right
];

INDICES :: u32.[ 0, 1, 2 ];

#import "Hash_Table";
#import "Hash";
#import "Random";
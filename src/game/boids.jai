game_init :: (state: *Game_State, renderer: *Renderer)
{
    state.camera = camera_make(is_2d_camera = true);
    state.flock.boid_mesh = renderer_upload_mesh(renderer, Mesh.{ VERTICES, INDICES });

    for i: 0 .. N-1 {
        pos := Vector2.{
            x = WINDOW_WIDTH / 2 + random_get_zero_to_one() * WINDOW_WIDTH / 3,
            y = WINDOW_HEIGHT / 2 + random_get_zero_to_one() * WINDOW_HEIGHT / 3
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
game_construct_render_list :: (list: *Render_List, prev_state: *Game_State, curr_state: *Game_State, alpha: float64)
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
    for *grid.coord_to_bucket {
        array_reset_keeping_memory(it);
    }

    for flock.positions {
        coord := boid_coord(it);
        bucket := table_find_pointer(*grid.coord_to_bucket, coord);
        if !bucket  bucket = table_add(*grid.coord_to_bucket, coord, [..]int.{});
        array_add(bucket, it_index,, context.transient_allocator);
    }
}

N :: 5000;
VISIBLE_RANGE :: 100.0;
PROTECTED_RANGE :: 20.0;
AVOID_FACTOR :: 2.0;
MATCHING_FACTOR :: 1.8;
CENTERING_FACTOR :: 0.5;
TURN_FACTOR :: 8.0;
MAX_SPEED :: 400.0;
MIN_SPEED :: 200.0;

GRID_CELL_SIZE :: VISIBLE_RANGE;
GRID_ROWS :: WINDOW_WIDTH / GRID_CELL_SIZE;
GRID_COLUMNS :: WINDOW_HEIGHT / GRID_CELL_SIZE;

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
            other_pos := flock.positions[index_from_bucket];
            other_vel := flock.velocities[index_from_bucket];
            if boid_pos != other_pos {
                dis := distance(boid_pos, other_pos);
                if dis < PROTECTED_RANGE {
                    close_vel += boid_pos - other_pos;
                } else {
                    neighbors_avg_velocities += other_vel;
                    avg_pos += other_pos;
                    neighboring_boids += 1;
                }
            }
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

draw_boids :: (list: *Render_List, prev_flock: *Flock, flock: *Flock, alpha: float64)
{
    f: Flock;
    t := cast(float) alpha;
    f.boid_mesh = flock.boid_mesh;

    for i: 0 .. N-1 {
        f.positions[i] =  lerp(prev_flock.positions[i], flock.positions[i], t);
        f.velocities[i] = lerp(prev_flock.velocities[i], flock.velocities[i], t);

        boid_pos := make_vector3(f.positions[i], 0.0);
        transform := make_translation_matrix4(boid_pos) * make_scale_matrix4(.{ 3, 3, 0 });
        render_draw_mesh(list, f.boid_mesh, transform);
    }
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
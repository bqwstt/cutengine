// #region Handles

Handle :: struct($T: Type) {
    index: u32;
    generation: u32;
}

Mesh_Handle    :: #type Handle(Cpu_Mesh);
Texture_Handle :: #type Handle(Cpu_Texture);

// #region CPU-side data
// Not sure if I like the name "Cpu_<...>" but they show intent!

Cpu_Mesh :: struct {
    vertices: []Vertex;
    indices:  []u32;
    material: Material;
}

Cpu_Texture :: struct {
    width:  u32;
    height: u32;
    pixels: *u8;
    pitch:  u32;
}

Cpu_Model :: struct {
    meshes:   []Cpu_Mesh;
    material: Material;
}

// @FIXME: Should these be called "Cpu_<...>"? :)
Material :: struct {
    albedo: Cpu_Texture;
}

Vertex :: struct {
    position:       Vector3;
    normal:         Vector3;
    texture_coords: Vector2;
}

#import "Basic";
#import "Math";
#import "File";
#import "String";
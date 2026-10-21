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
}

// @TODO: Add format field here and populate it from the asset file.
Cpu_Texture :: struct {
    width:  u32;
    height: u32;
    pixels: *u8;
    pitch:  u32;
}

Cpu_Shader :: struct {
    stage:   Asset_Shader_Stage;
    backend: Asset_Shader_Backend;
    num_samplers:         u32;
    num_storage_textures: u32;
    num_storage_buffers:  u32;
    num_uniforms:         u32;
    code: string; // SPIR-V/DXIL bytecode or MSL source
}

Cpu_Model :: struct {
    meshes:   []Cpu_Mesh;
    material: Cpu_Material;
}

Cpu_Material :: struct {
    albedo:     Cpu_Texture;
    properties: Material_Properties;
}

Material_Properties :: struct {
    base_color:         Vector4 = .{ 0.8, 0.8, 0.8, 1.0 }; // Grey-ish color
    specular_intensity: float = 1.0;
    shininess:          u32 = 1;
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
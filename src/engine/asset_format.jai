// NOTE: Even though these structs have #no_padding, they may contain some padding inside.
// This is because #no_padding removes padding at the _end_ of the struct, not between fields.
// In order to pack things nicely, we have to manually write each field to disk (as opposed to the whole struct).

Asset_Header :: struct {
    magic:        u32;         // 4 bytes - Used to tell whether a file is in this format or not
    version:      u32;         // 4 bytes - Format version
    type:         Asset_Type;  // 1 byte  - Kind: texture, material, shader...
    entry_count:  u32;         // 4 bytes - How many entries for this asset
    entry_offset: u32;         // 4 bytes - Where to start reading from  @TODO: Do we need this? We can just use size_of.
} #no_padding

Asset_Texture_Header :: struct {
    width:       u32;                   // 4 bytes - Texture width in pixels
    height:      u32;                   // 4 bytes - Texture height in pixels
    format:      Asset_Texture_Format;  // 1 byte  - Texture format
    compressed:  u8;                    // 1 byte  - Whether the texture is compressed or not
    stored_size: u32;                   // 4 bytes - How many bytes does the compressed texture take
    raw_size:    u32;                   // 4 bytes - How many bytes does the uncompressed texture take
} #no_padding

Asset_Shader_Header :: struct {
    stage:               Asset_Shader_Stage;    // 1 byte  - Shader stage (vertex, fragment, compute)
    backend:             Asset_Shader_Backend;  // 1 byte  - Shader backend (Vulkan's, D3D's formats etc.)
    num_samplers:        u8;                    // 1 byte  - Number of samplers to use
    num_uniforms:        u8;                    // 1 byte  - Number of uniforms to use
    num_storage_buffers: u8;                    // 1 byte  - Number of storage buffers to use
    code_size:           u32;                   // 4 bytes - Size of the shader code in the blob
} #no_padding

Asset_Material_Header :: struct {
    albedo_name_len: u32;  // 4 bytes - Size of the asset name to use as albedo texture
    shader_name_len: u32;  // 4 bytes - Size of the shader name to use
} #no_padding

Asset_Model_Header :: struct {
    vertices_count:    u32;  // 4 bytes - How many vertices the model has
    indices_count:     u32;  // 4 bytes - How many indices the model uses
    material_name_len: u32;  // 4 bytes - Length of the asset name to use as material
} #no_padding

Asset_Type :: enum u8 #specified {
    NOT_SUPPORTED :: 0x00;

    TEXTURE  :: 0x01;
    MATERIAL :: 0x02;
    MODEL    :: 0x05;
}

Asset_Texture_Format :: enum u8 #specified {
    RGBA8 :: 0x01;
    BC7   :: 0x0A;
}

Asset_Shader_Stage :: enum u8 #specified {
    VERTEX   :: 0x01;
    FRAGMENT :: 0x02;
    COMPUTE  :: 0x03;
}

Asset_Shader_Backend :: enum u8 #specified {
    SPIRV :: 0x01;
    MSL   :: 0x02;
    DXIL  :: 0x03;
}

MAGIC   :: 0x45545543; // 'CUTE' in little-endian
VERSION :: 1;

#import "stb_image";
#import "File";
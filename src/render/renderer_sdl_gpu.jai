// #region GPU data

#scope_export

sdl_gpu_renderer_make :: (window: *Window) -> Gpu_Renderer_Data, bool
{
    // Create device, pipeline and vertex buffer
    sdl_window := convert_to_sdl_window(window);
    format_flags: SDL_GPUShaderFormat = SDL_GPU_SHADERFORMAT_SPIRV | SDL_GPU_SHADERFORMAT_DXIL | SDL_GPU_SHADERFORMAT_MSL;
    device := SDL_CreateGPUDevice(format_flags, DEBUG, null);
    if !device {
        log_error("Couldn't create GPU device: %", SDL_GetErrorString());
        return .{}, false;
    }

    device_window_ok := SDL_ClaimWindowForGPUDevice(device, sdl_window);
    assert(device_window_ok, "Couldn't claim window for GPU device: %", SDL_GetErrorString());

    pipeline := create_pipeline(sdl_window, device);
    if !pipeline {
        log_error("Couldn't create graphics pipeline: %", SDL_GetErrorString());
        return .{}, false;
    }

    sampler_create_info := SDL_GPUSamplerCreateInfo.{
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
        mipmap_mode = .NEAREST,
        address_mode_u = .CLAMP_TO_EDGE,
        address_mode_v = .CLAMP_TO_EDGE,
        address_mode_w = .CLAMP_TO_EDGE,
    };
    sampler := SDL_CreateGPUSampler(device, *sampler_create_info);
    assert(sampler != null, "Couldn't create sampler: %", SDL_GetErrorString());

    mesh, ok := mesh_create_and_upload(device, VERTICES, INDICES);
    if !ok {
        log_error("Couldn't create mesh: %", SDL_GetErrorString());
        return .{}, false;
    }

    data: Gpu_Renderer_Data;
    data.device = device;
    data.pipeline = pipeline;
    data.sampler = sampler;
    data.mesh = mesh;
    return data, true;
}

sdl_gpu_renderer_drop :: (window: *Window, data: *Gpu_Renderer_Data)
{
    sdl_window := convert_to_sdl_window(window);
    mesh_drop(data, *data.mesh);
    SDL_ReleaseGPUSampler(data.device, data.sampler);
    SDL_ReleaseGPUGraphicsPipeline(data.device, data.pipeline);
    SDL_ReleaseWindowFromGPUDevice(data.device, sdl_window);
    SDL_DestroyGPUDevice(data.device);
}

sdl_gpu_renderer_draw :: (window: *Window, data: *Gpu_Renderer_Data)
{
    sdl_window := convert_to_sdl_window(window);

    // Create command buffer for batching requests to the GPU
    cmd := SDL_AcquireGPUCommandBuffer(data.device);
    assert(cmd != null, "Couldn't acquire GPU command buffer: %", SDL_GetErrorString());

    // Create a swapchain texture to draw in between frames
    swapchain_texture: *SDL_GPUTexture;
    ok := SDL_WaitAndAcquireGPUSwapchainTexture(cmd, sdl_window, *swapchain_texture, null, null); 
    assert(ok, "Couldn't acquire swapchain texture: %", SDL_GetErrorString());

    // Check needed: the swapchain texture can be null in certain cases, i.e. the window is minimized.
    if swapchain_texture {
        cti: SDL_GPUColorTargetInfo;
        cti.texture = swapchain_texture;
        cti.clear_color = SDL_FColor.{ 0.0, 0.0, 0.0, 1.0 };
        cti.load_op = .CLEAR;
        cti.store_op = .STORE;

        // Render pass: bind pipeline, vertex buffers and draw primitives
        render_pass := SDL_BeginGPURenderPass(cmd, *cti, 1, null);

        vertex_buffers := SDL_GPUBufferBinding.[
            .{ buffer = data.mesh.vertex_buffer, offset = 0 }
        ];
        index_buffer := SDL_GPUBufferBinding.{ buffer = data.mesh.index_buffer, offset = 0 };

        // @FIXME: Revert
        // texture_sampler := SDL_GPUTextureSamplerBinding.{
        //     texture = data.mesh.texture,
        //     sampler = data.sampler,
        // };

        SDL_BindGPUGraphicsPipeline(render_pass, data.pipeline);
        SDL_BindGPUVertexBuffers(render_pass, 0, vertex_buffers.data, vertex_buffers.count);
        SDL_BindGPUIndexBuffer(render_pass, *index_buffer, SDL_GPUIndexElementSize._32BIT);
        // SDL_BindGPUFragmentSamplers(render_pass, 0, *texture_sampler, 1);
        SDL_DrawGPUIndexedPrimitives(render_pass, INDICES.count, 1, 0, 0, 0);

        SDL_EndGPURenderPass(render_pass);
    }

    // Send commands to the GPU
    ok = SDL_SubmitGPUCommandBuffer(cmd);
    assert(ok, "Couldn't submit command buffer to GPU: %", SDL_GetErrorString());
}

Gpu_Renderer_Data :: struct {
    device: *SDL_GPUDevice;
    pipeline: *SDL_GPUGraphicsPipeline;
    sampler: *SDL_GPUSampler;
    mesh: Gpu_Mesh;
}

// #region Shaders

#scope_file

get_texture :: (data: *Gpu_Renderer_Data, h: Texture_Handle) -> *SDL_GPUTexture
{
    return null;
}

/// @TODO: This can be done at compile time, probably
load_shader :: (device: *SDL_GPUDevice, path: string, num_samplers: u32 = 0) -> *SDL_GPUShader
{
    stage: SDL_GPUShaderStage;
    if ends_with(path, ".vert")       stage = .VERTEX;
    else if ends_with(path, ".frag")  stage = .FRAGMENT;
    else {
        log_error("Couldn't deduce shader stage from filename: %", path);
        return null;
    }

    // @FIXME: Relative path used here
    full_path := path_join(to_string(SDL_GetBasePath()), "../assets/shader");

    entrypoint: *u8;
    format: SDL_GPUShaderFormat = SDL_GPU_SHADERFORMAT_INVALID;
    backend_formats := SDL_GetGPUShaderFormats(device);

    // Grab path + entrypoint depending on target API
    if backend_formats & SDL_GPU_SHADERFORMAT_SPIRV {
        // Vulkan
        full_path = path_join(full_path, tprint("%.%", path, "spv"),, temp);
        format = SDL_GPU_SHADERFORMAT_SPIRV;
        entrypoint = "main";
    } else if backend_formats & SDL_GPU_SHADERFORMAT_MSL {
        // Metal
        full_path = path_join(full_path, tprint("%.%", path, "msl"),, temp);
        format = SDL_GPU_SHADERFORMAT_MSL;
        entrypoint = "main0";
    } else if backend_formats & SDL_GPU_SHADERFORMAT_DXIL {
        // DirectX
        full_path = path_join(full_path, tprint("%.%", path, "dxil"),, temp);
        format = SDL_GPU_SHADERFORMAT_DXIL;
        entrypoint = "main";
    } else {
        log_error("Couldn't find a supported shader format for backend %", SDL_GetGPUDeviceDriver(device));
        return null;
    }

    code, ok := read_entire_file(full_path);
    if !ok {
        log_error("Couldn't load shader file from disk: %", full_path);
        return null;
    }
    defer free(code);

    shader_info: SDL_GPUShaderCreateInfo;
    shader_info.code_size = xx code.count;
    shader_info.code = code.data;
    shader_info.entrypoint = entrypoint;
    shader_info.format = format;
    shader_info.stage = stage;
    // @FIXME: Revert
    // shader_info.num_samplers = num_samplers;

    return SDL_CreateGPUShader(device, *shader_info);
}

load_image :: (path: string) -> *SDL_Surface
{
    // @FIXME: Relative path used here
    full_path := path_join(to_string(SDL_GetBasePath()), "../assets/texture", path);
    return SDL_LoadPNG(to_c_string(full_path));
}

create_pipeline :: (window: *SDL_Window, device: *SDL_GPUDevice) -> *SDL_GPUGraphicsPipeline
{
    // Load vertex and fragment shaders
    vertex_shader := load_shader(device, "position.vert");
    assert(vertex_shader != null, "Couldn't create vertex shader: %", SDL_GetErrorString());
    defer SDL_ReleaseGPUShader(device, vertex_shader);

    fragment_shader := load_shader(device, "texture.frag", 1);
    assert(fragment_shader != null, "Couldn't create fragment shader: %", SDL_GetErrorString());
    defer SDL_ReleaseGPUShader(device, fragment_shader);

    color_target_description := SDL_GPUColorTargetDescription.[
        .{ format = SDL_GetGPUSwapchainTextureFormat(device, window) }
    ];

    // Create pipeline info:
    // - specify vertex and fragment shaders
    // - specify vertex descriptions and vertex attributes
    // - specify primitive type and fill mode
    pci := SDL_GPUGraphicsPipelineCreateInfo.{
        vertex_shader = vertex_shader,
        fragment_shader = fragment_shader,
        vertex_input_state = SDL_GPUVertexInputState.{
            vertex_buffer_descriptions = VERTEX_BUFFER_DESCRIPTIONS.data,
            num_vertex_buffers = VERTEX_BUFFER_DESCRIPTIONS.count,
            vertex_attributes = VERTEX_ATTRIBUTES.data,
            num_vertex_attributes = VERTEX_ATTRIBUTES.count
        },
        primitive_type = .TRIANGLELIST,
        rasterizer_state = SDL_GPURasterizerState.{
            fill_mode = .FILL,
        },
        target_info = SDL_GPUGraphicsPipelineTargetInfo.{
            color_target_descriptions = color_target_description.data,
            num_color_targets = color_target_description.count
        }
    };

    return SDL_CreateGPUGraphicsPipeline(device, *pci);
}

mesh_create_and_upload :: (device: *SDL_GPUDevice, vertices: []Vertex, indices: []u32) -> Gpu_Mesh, bool
{
    // Create vertex buffer
    vertex_buffer_info := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_VERTEX,
        size = cast(u32) vertices.count * size_of(Vertex)
    };

    vertex_buffer := SDL_CreateGPUBuffer(device, *vertex_buffer_info);
    assert(vertex_buffer != null, "Couldn't create vertex buffer: %", SDL_GetErrorString());

    // Create index buffer
    index_buffer_info := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_INDEX,
        size = cast(u32) indices.count * size_of(u32)
    };

    index_buffer := SDL_CreateGPUBuffer(device, *index_buffer_info);
    assert(index_buffer != null, "Couldn't create index buffer: %", SDL_GetErrorString());

    // Transfer vertices between CPU -> GPU
    vertices_size := cast(u32) vertices.count * size_of(Vertex);
    indices_size  := cast(u32) indices.count * size_of(u32);
    transfer_size := vertices_size + indices_size;

    transfer_buffer_info := SDL_GPUTransferBufferCreateInfo.{
        usage = .UPLOAD,
        size = transfer_size
    };

    transfer_buffer := SDL_CreateGPUTransferBuffer(device, *transfer_buffer_info);
    assert(transfer_buffer != null, "Couldn't create transfer buffer: %", SDL_GetErrorString());
    defer SDL_ReleaseGPUTransferBuffer(device, transfer_buffer);

    // Map transfer buffer and copy vertex + index data into it
    transfer_data: *u8 = SDL_MapGPUTransferBuffer(device, transfer_buffer, false);
    assert(transfer_data != null, "Couldn't map transfer data: %", SDL_GetErrorString());

    // Copy vertices and indices
    memcpy(transfer_data, vertices.data, vertices_size);
    memcpy(transfer_data + vertices_size, indices.data, indices_size);

    SDL_UnmapGPUTransferBuffer(device, transfer_buffer);

    // Create texture
    texture_image := load_image("awesomeface.png");
    if !texture_image {
        log_error("Couldn't load texture image: %", SDL_GetErrorString());
        return .{}, false;
    }
    defer SDL_DestroySurface(texture_image);

    tex_w := cast(u32) texture_image.w;
    tex_h := cast(u32) texture_image.h;

    texture_create_info := SDL_GPUTextureCreateInfo.{
        type = .SDL_GPU_TEXTURETYPE_2D,
        format = .R8G8B8A8_UNORM,
        usage = SDL_GPU_TEXTUREUSAGE_SAMPLER,
        width = tex_w,
        height = tex_h,
        layer_count_or_depth = 1,
        num_levels = 1,
    };
    texture := SDL_CreateGPUTexture(device, *texture_create_info);
    assert(texture != null, "Couldn't create texture: %", SDL_GetErrorString());
    SDL_SetGPUTextureName(device, texture, "awesomeface");

    texture_transfer_buffer_info := SDL_GPUTransferBufferCreateInfo.{
        usage = .UPLOAD,
        size = tex_w * tex_h * 4
    };
    texture_transfer_buffer := SDL_CreateGPUTransferBuffer(device, *texture_transfer_buffer_info);
    assert(texture_transfer_buffer != null, "Couldn't create texture transfer buffer: %", SDL_GetErrorString());
    defer SDL_ReleaseGPUTransferBuffer(device, texture_transfer_buffer);

    // Map texture transfer buffer and texture into it
    texture_transfer_data: *u8 = SDL_MapGPUTransferBuffer(device, texture_transfer_buffer, false);
    assert(texture_transfer_data != null, "Couldn't map texture transfer buffer: %", SDL_GetErrorString());

    // Copy texture
    memcpy(texture_transfer_data, texture_image.pixels, tex_w * tex_h * 4);

    SDL_UnmapGPUTransferBuffer(device, texture_transfer_buffer);

    upload_cmd_buf := SDL_AcquireGPUCommandBuffer(device);
    assert(upload_cmd_buf != null, "Couldn't acquire GPU command buffer: %", SDL_GetErrorString());

    // Copy pass: use command buffer to send the data via the transfer buffer
    copy_pass := SDL_BeginGPUCopyPass(upload_cmd_buf);

    // Position (from)
    vertex_buffer_from := SDL_GPUTransferBufferLocation.{
        transfer_buffer = transfer_buffer, 
        offset = 0
    };

    index_buffer_from := SDL_GPUTransferBufferLocation.{
        transfer_buffer = transfer_buffer,
        offset = vertices_size // offset by previous vertices
    };

    // Position (to)
    vertex_buffer_to := SDL_GPUBufferRegion.{
        buffer = vertex_buffer,
        offset = 0,
        size = vertices_size,
    };

    index_buffer_to := SDL_GPUBufferRegion.{
        buffer = index_buffer,
        offset = 0,
        size = indices_size,
    };

    // Texture (from)
    texture_buffer_from := SDL_GPUTextureTransferInfo.{
        transfer_buffer = texture_transfer_buffer,
        offset = 0,
    };

    // Texture (to)
    texture_buffer_to := SDL_GPUTextureRegion.{
        texture = texture,
        w = tex_w,
        h = tex_h,
        d = 1
    };

    // Perform the copy and submit the command to the command buffer
    SDL_UploadToGPUBuffer(copy_pass, *vertex_buffer_from, *vertex_buffer_to, false);
    SDL_UploadToGPUBuffer(copy_pass, *index_buffer_from, *index_buffer_to, false);
    SDL_UploadToGPUTexture(copy_pass, *texture_buffer_from, *texture_buffer_to, false);

    SDL_EndGPUCopyPass(copy_pass);

    ok := SDL_SubmitGPUCommandBuffer(upload_cmd_buf); 
    assert(ok, "Couldn't submit GPU command buffer: %", SDL_GetErrorString());

    // @FIXME: Fill in actual textures
    textures := Texture_Handle.[];
    
    m: Gpu_Mesh;
    m.vertex_buffer = vertex_buffer;
    m.index_buffer  = index_buffer;
    m.textures = textures;
    return m, true;
}

mesh_drop :: (renderer: *Gpu_Renderer_Data, m: *Gpu_Mesh)
{
    SDL_ReleaseGPUBuffer(renderer.device, m.vertex_buffer);
    SDL_ReleaseGPUBuffer(renderer.device, m.index_buffer);

    for m.textures {
        tex := get_texture(renderer, it);
        if tex {
            SDL_ReleaseGPUTexture(renderer.device, tex);
        }
    }
}


// @FIXME: For now, until I think how to overlap the two layers together, this is
// copied from platform_sdl.jai
convert_to_sdl_window :: (w: *Window) -> *SDL_Window
{
    return cast(*SDL_Window) w.native;
}

Gpu_Mesh :: struct {
    using #as m: Mesh_Data;

    vertex_buffer: *SDL_GPUBuffer;
    // vertex_attributes: [field_count(Vertex)]SDL_GPUVertexAttribute;
    index_buffer: *SDL_GPUBuffer;
}

Gpu_Texture :: struct {
    handle: *SDL_GPUTexture;
}

VERTICES :: Vertex.[
    //       Position (NDC)                   Texture (UV)
    Vertex.{ position = .{ -0.5, -0.5, 0.0 }, texture_coords = .{ 0, 1 } }, // Bottom-left
    Vertex.{ position = .{  0.5, -0.5, 0.0 }, texture_coords = .{ 1, 1 } }, // Bottom-right
    Vertex.{ position = .{ -0.5,  0.5, 0.0 }, texture_coords = .{ 0, 0 } }, // Top-left
    Vertex.{ position = .{  0.5,  0.5, 0.0 }, texture_coords = .{ 1, 0 } }  // Top-right
];

// What am I going to send?
VERTEX_BUFFER_DESCRIPTIONS :: SDL_GPUVertexBufferDescription.[
    .{ slot = 0, pitch = size_of(Vertex), input_rate = .VERTEX, instance_step_rate = 0 }
];

// How is the thing I am going to send look like?
VERTEX_ATTRIBUTES :: SDL_GPUVertexAttribute.[
    .{ location = 0, buffer_slot = 0, format = .FLOAT3, offset = #run offset_of(Vertex, "position") }, // Position attribute
    .{ location = 1, buffer_slot = 0, format = .FLOAT2, offset = #run offset_of(Vertex, "texture_coords") },  // Texture attribute
];

INDICES :: u32.[
    0, 1, 2, // Face 1: Bottom-left -> Bottom-right -> Top-left
    1, 3, 2  // Face 2: Bottom-right -> Top-right -> Top-left
];


#import "SDL3";
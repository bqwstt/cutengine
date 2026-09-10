// #region GPU data

#scope_export

Gpu_Renderer_Data :: struct {
    device: *SDL_GPUDevice;
    pipeline: *SDL_GPUGraphicsPipeline;
    mesh: Mesh;
}

gpu_renderer_make :: (window: *SDL_Window) -> Gpu_Renderer_Data, bool
{
    // Create device, pipeline and vertex buffer
    format_flags: SDL_GPUShaderFormat = SDL_GPU_SHADERFORMAT_SPIRV | SDL_GPU_SHADERFORMAT_DXIL | SDL_GPU_SHADERFORMAT_MSL;
    device := SDL_CreateGPUDevice(format_flags, DEBUG, null);
    if !device {
        log_error("Couldn't create GPU device: %", SDL_GetErrorString());
        return .{}, false;
    }

    if !SDL_ClaimWindowForGPUDevice(device, window) {
        log_error("Couldn't claim window for GPU device: %", SDL_GetErrorString());
        return .{}, false;
    }

    pipeline := create_pipeline(window, device);
    if !pipeline {
        log_error("Couldn't create graphics pipeline: %", SDL_GetErrorString());
        return .{}, false;
    }

    mesh := create_buffers(device, VERTICES, INDICES);
    if !mesh.vertex_buffer || !mesh.index_buffer {
        log_error("Couldn't create mesh: %", SDL_GetErrorString());
        return .{}, false;
    }

    data: Gpu_Renderer_Data;
    data.device = device;
    data.pipeline = pipeline;
    data.mesh = mesh;
    return data, true;
}

gpu_renderer_drop :: (window: *SDL_Window, data: *Gpu_Renderer_Data)
{
    SDL_ReleaseWindowFromGPUDevice(data.device, window);
    SDL_DestroyGPUDevice(data.device);
}

gpu_renderer_draw :: (window: *SDL_Window, data: *Gpu_Renderer_Data)
{
    // Create command buffer for batching requests to the GPU
    cmd := SDL_AcquireGPUCommandBuffer(data.device);
    if !cmd {
        log_error("Couldn't acquire GPU command buffer: %", SDL_GetErrorString());
        return;
    }

    // Create a swapchain texture to draw in between frames
    swapchain_texture: *SDL_GPUTexture;
    if !SDL_WaitAndAcquireGPUSwapchainTexture(cmd, window, *swapchain_texture, null, null) {
        log_error("Couldn't acquire swapchain texture: %", SDL_GetErrorString());
        return;
    }

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

        SDL_BindGPUGraphicsPipeline(render_pass, data.pipeline);
        SDL_BindGPUVertexBuffers(render_pass, 0, vertex_buffers.data, vertex_buffers.count);
        SDL_BindGPUIndexBuffer(render_pass, *index_buffer, SDL_GPUIndexElementSize._32BIT);
        // SDL_DrawGPUPrimitives(render_pass, VERTICES.count, 1, 0, 0);
        SDL_DrawGPUIndexedPrimitives(render_pass, INDICES.count, 1, 0, 0, 0);

        SDL_EndGPURenderPass(render_pass);
    }

    // Send commands to the GPU
    if !SDL_SubmitGPUCommandBuffer(cmd) {
        log_error("Couldn't submit command buffer to GPU: %", SDL_GetErrorString());
        return;
    }
}

// #region Shaders

#scope_file

Mesh :: struct {
    vertex_buffer: *SDL_GPUBuffer;
    index_buffer: *SDL_GPUBuffer;
}

Vertex :: struct {
    position: Vector3;
    color: Vector4;
}

VERTICES :: Vertex.[
    //       Position (NDC)                   Color (NDC)
    Vertex.{ position = .{ -0.5, -0.5, 0.0 }, color = .{ 1.0, 0.0, 0.0, 1.0 } }, // Bottom-left
    Vertex.{ position = .{  0.5, -0.5, 0.0 }, color = .{ 0.0, 1.0, 0.0, 1.0 } }, // Bottom-right
    Vertex.{ position = .{ -0.5,  0.5, 0.0 }, color = .{ 0.0, 0.0, 1.0, 1.0 } }, // Top-left
    Vertex.{ position = .{  0.5,  0.5, 0.0 }, color = .{ 1.0, 0.0, 1.0, 1.0 } }  // Top-right
];

INDICES :: u32.[
    0, 1, 2, // Face 1: Bottom-left -> Bottom-right -> Top-left
    1, 3, 2  // Face 2: Bottom-right -> Top-right -> Top-left
];

load_shader :: (device: *SDL_GPUDevice, path: string) -> *SDL_GPUShader
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

    shader := SDL_CreateGPUShader(device, *shader_info);
    if !shader {
        log_error("Couldn't create shader from file: %", SDL_GetErrorString());
        return null;
    }

    return shader;
}

create_pipeline :: (window: *SDL_Window, device: *SDL_GPUDevice) -> *SDL_GPUGraphicsPipeline
{
    // Load vertex and fragment shaders
    vertex_shader := load_shader(device, "position.vert");
    if !vertex_shader {
        log_error("Couldn't create vertex shader");
        return null;
    }
    defer SDL_ReleaseGPUShader(device, vertex_shader);

    fragment_shader := load_shader(device, "solid_color.frag");
    if !fragment_shader {
        log_error("Couldn't create fragment shader");
        return null;
    }
    defer SDL_ReleaseGPUShader(device, fragment_shader);

    // What am I going to send?
    VERTEX_BUFFER_DESCRIPTIONS :: SDL_GPUVertexBufferDescription.[
        .{ slot = 0, pitch = size_of(Vertex), input_rate = .VERTEX, instance_step_rate = 0 }
    ];

    // How is the thing I am going to send look like?
    VERTEX_ATTRIBUTES :: SDL_GPUVertexAttribute.[
        .{ location = 0, buffer_slot = 0, format = .FLOAT3, offset = #run offset_of(Vertex, "position") }, // Position attribute
        .{ location = 1, buffer_slot = 0, format = .FLOAT4, offset = #run offset_of(Vertex, "color") }, // Color attribute
    ];

    COLOR_TARGET_DESCRIPTION := SDL_GPUColorTargetDescription.[
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
            color_target_descriptions = COLOR_TARGET_DESCRIPTION.data,
            num_color_targets = COLOR_TARGET_DESCRIPTION.count
        }
    };

    return SDL_CreateGPUGraphicsPipeline(device, *pci);
}

create_buffers :: (device: *SDL_GPUDevice, vertices: []Vertex, indices: []u32) -> Mesh
{
    // Create vertex buffer
    vertex_buffer_info := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_VERTEX,
        size = cast(u32) vertices.count * size_of(Vertex)
    };

    vertex_buffer := SDL_CreateGPUBuffer(device, *vertex_buffer_info);
    if !vertex_buffer {
        log_error("Couldn't create vertex buffer: %", SDL_GetErrorString());
        return .{};
    }

    // Create index buffer
    index_buffer_info := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_INDEX,
        size = cast(u32) indices.count * size_of(u32)
    };

    index_buffer := SDL_CreateGPUBuffer(device, *index_buffer_info);
    if !index_buffer {
        log_error("Couldn't create index buffer: %", SDL_GetErrorString());
        return .{};
    }

    // Transfer vertices between CPU -> GPU
    vertices_size := cast(u32) vertices.count * size_of(Vertex);
    indices_size  := cast(u32) indices.count * size_of(u32);
    transfer_size := vertices_size + indices_size;

    transfer_buffer_info := SDL_GPUTransferBufferCreateInfo.{
        usage = .UPLOAD,
        size = transfer_size
    };

    transfer_buffer := SDL_CreateGPUTransferBuffer(device, *transfer_buffer_info);
    if !transfer_buffer {
        log_error("Couldn't create transfer buffer: %", SDL_GetErrorString());
        return .{};
    }
    defer SDL_ReleaseGPUTransferBuffer(device, transfer_buffer);

    // Map transfer buffer and copy vertex + index data into it
    transfer_data: *u8 = SDL_MapGPUTransferBuffer(device, transfer_buffer, false);
    if !transfer_data {
        log_error("Couldn't map transfer buffer: %", SDL_GetErrorString());
        return .{};
    }

    // Copy vertices and indices
    memcpy(transfer_data, vertices.data, vertices_size);
    memcpy(transfer_data + vertices_size, indices.data, indices_size);

    SDL_UnmapGPUTransferBuffer(device, transfer_buffer);

    upload_cmd_buf := SDL_AcquireGPUCommandBuffer(device);
    if !upload_cmd_buf {
        log_error("Couldn't acquire GPU command buffer: %", SDL_GetErrorString());
        return .{};
    }

    // Copy pass: use command buffer to send the data via the transfer buffer
    copy_pass := SDL_BeginGPUCopyPass(upload_cmd_buf);

    // (From)
    vertex_buffer_from := SDL_GPUTransferBufferLocation.{
        transfer_buffer = transfer_buffer, 
        offset = 0
    };

    index_buffer_from := SDL_GPUTransferBufferLocation.{
        transfer_buffer = transfer_buffer,
        offset = vertices_size // offset by previous vertices
    };

    // (To)
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

    // Perform the copy and submit the command to the command buffer
    SDL_UploadToGPUBuffer(copy_pass, *vertex_buffer_from, *vertex_buffer_to, false);
    SDL_UploadToGPUBuffer(copy_pass, *index_buffer_from, *index_buffer_to, false);

    SDL_EndGPUCopyPass(copy_pass);

    if !SDL_SubmitGPUCommandBuffer(upload_cmd_buf) {
        log_error("Coulnd't submit GPU command buffer: %", SDL_GetErrorString());
        return .{};
    }

    return Mesh.{ vertex_buffer, index_buffer };
}

/// Helper for grabbing the offsite of a member in a struct
offset_of :: ($T: Type, $member: string) -> int
#modify {
    ti := cast(*Type_Info) T;
    if ti.type != .STRUCT return false;

    return true;
} {
    for type_info(T).members {
        if it.name == member  return it.offset_in_bytes;
    }

    assert(false, "Type '%' does not have member '%'", T, member);
    return -1;
}

#import "SDL3";
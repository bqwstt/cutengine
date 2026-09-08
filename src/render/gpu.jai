// #region GPU data

#scope_export

Gpu_Renderer_Data :: struct {
    device: *SDL_GPUDevice;
    pipeline: *SDL_GPUGraphicsPipeline;
    vertex_buffer: *SDL_GPUBuffer;
}

gpu_renderer_make :: (window: *SDL_Window) -> Gpu_Renderer_Data, bool
{
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

    // Create vertices

    vertex_buffer := create_vertex_buffer(device, VERTICES);
    if !vertex_buffer {
        log_error("Couldn't create vertex buffer: %", SDL_GetErrorString());
        return .{}, false;
    }

    data: Gpu_Renderer_Data;
    data.device = device;
    data.pipeline = pipeline;
    data.vertex_buffer = vertex_buffer;
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
        cti.clear_color = SDL_FColor.{ 0.4, 0.6, 0.9, 1.0 };
        cti.load_op = .CLEAR;
        cti.store_op = .STORE;

        // Empty render pass for now
        render_pass := SDL_BeginGPURenderPass(cmd, *cti, 1, null);

        VERTEX_BUFFERS := SDL_GPUBufferBinding.[
            .{ buffer = data.vertex_buffer, offset = 0 }
        ];

        SDL_BindGPUGraphicsPipeline(render_pass, data.pipeline);
        SDL_BindGPUVertexBuffers(render_pass, 0, VERTEX_BUFFERS.data, VERTEX_BUFFERS.count);
        SDL_DrawGPUPrimitives(render_pass, VERTICES.count, 1, 0, 0);

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

Vertex :: struct {
    position: Vector3;
}

VERTICES :: Vertex.[
    Vertex.{ Vector3.{ -1.0, -1.0, 0.0 } }, // Bottom-left
    Vertex.{ Vector3.{  1.0, -1.0, 0.0 } }, // Bottom-Right
    Vertex.{ Vector3.{  0.0,  1.0, 0.0 } }  // Top-middle
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

    if backend_formats & SDL_GPU_SHADERFORMAT_SPIRV {
        full_path = path_join(full_path, tprint("%.%", path, "spv"),, temp);
        format = SDL_GPU_SHADERFORMAT_SPIRV;
        entrypoint = "main";
    } else if backend_formats & SDL_GPU_SHADERFORMAT_MSL {
        full_path = path_join(full_path, tprint("%.%", path, "msl"),, temp);
        format = SDL_GPU_SHADERFORMAT_MSL;
        entrypoint = "main0";
    } else if backend_formats & SDL_GPU_SHADERFORMAT_DXIL {
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

    VERTEX_BUFFER_DESCRIPTIONS :: SDL_GPUVertexBufferDescription.[
        .{ slot = 0, pitch = size_of(Vertex), input_rate = .VERTEX, instance_step_rate = 0 }
    ];

    VERTEX_ATTRIBUTES :: SDL_GPUVertexAttribute.[
        .{ location = 0, buffer_slot = 0, format = .FLOAT3, offset = #run offset_of(Vertex, "position") },
    ];

    COLOR_TARGET_DESCRIPTION := SDL_GPUColorTargetDescription.[
        .{ format = SDL_GetGPUSwapchainTextureFormat(device, window) }
    ];

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

create_vertex_buffer :: (device: *SDL_GPUDevice, vertices: []Vertex) -> *SDL_GPUBuffer
{
    vertices_size := vertices.count * size_of(Vertex);
    vbci := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_VERTEX,
        size = xx vertices_size
    };

    vertex_buffer := SDL_CreateGPUBuffer(device, *vbci);
    if !vertex_buffer {
        log_error("Couldn't create vertex buffer: %", SDL_GetErrorString());
        return null;
    }

    tbci := SDL_GPUTransferBufferCreateInfo.{
        usage = .UPLOAD,
        size = xx vertices_size
    };

    transfer_buffer := SDL_CreateGPUTransferBuffer(device, *tbci);
    if !transfer_buffer {
        log_error("Couldn't create transfer buffer: %", SDL_GetErrorString());
        return null;
    }
    defer SDL_ReleaseGPUTransferBuffer(device, transfer_buffer);

    transfer_data: *Vertex = SDL_MapGPUTransferBuffer(device, transfer_buffer, false);
    if !transfer_data {
        log_error("Couldn't map transfer buffer: %", SDL_GetErrorString());
        return null;
    }
    defer SDL_UnmapGPUTransferBuffer(device, transfer_buffer);

    memcpy(transfer_data, vertices.data, vertices_size);

    upload_cmd_buf := SDL_AcquireGPUCommandBuffer(device);
    if !upload_cmd_buf {
        log_error("Couldn't acquire GPU command buffer: %", SDL_GetErrorString());
        return null;
    }

    copy_pass := SDL_BeginGPUCopyPass(upload_cmd_buf);

    buffer_location := SDL_GPUTransferBufferLocation.{
        transfer_buffer = transfer_buffer, 
        offset = 0
    };

    buffer_region := SDL_GPUBufferRegion.{
        buffer = vertex_buffer,
        offset = 0,
        size = xx vertices_size,
    };

    SDL_UploadToGPUBuffer(copy_pass, *buffer_location, *buffer_region, false);
    SDL_EndGPUCopyPass(copy_pass);

    if !SDL_SubmitGPUCommandBuffer(upload_cmd_buf) {
        log_error("Coulnd't submit GPU command buffer: %", SDL_GetErrorString());
        return null;
    }

    return vertex_buffer;
}

offset_of :: ($T: Type, $member: string) -> int {
    for type_info(T).members {
        if it.name == member  return it.offset_in_bytes;
    }

    assert(false, "Type '%' does not have member '%'", T, member);
    return -1;
}

#import "SDL3";
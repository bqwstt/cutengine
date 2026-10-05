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

    // Try to enable VSync
    if !SDL_SetGPUSwapchainParameters(device, sdl_window, .SDR, .VSYNC) {
        log_error("Couldn't enable VSync: %", SDL_GetErrorString());
    }

    pipeline := create_pipeline(sdl_window, device);
    instanced_pipeline := create_instanced_pipeline(sdl_window, device);
    if !pipeline || !instanced_pipeline {
        log_error("Couldn't create graphics pipelines: %", SDL_GetErrorString());
        return .{}, false;
    }

    // Create GPU buffer for storing batch instances positions
    INSTANCE_BUFFER_SIZE :: MAX_RENDER_INSTANCES * size_of(Render_Instance);
    instance_data_info := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_GRAPHICS_STORAGE_READ,
        size = cast(u32) INSTANCE_BUFFER_SIZE,
    };

    instance_buffer := SDL_CreateGPUBuffer(device, *instance_data_info);
    assert(instance_buffer != null, "Couldn't create instance buffer: %", SDL_GetErrorString());

    data: Gpu_Renderer_Data;
    data.device = device;
    data.pipeline = pipeline;
    data.instanced_pipeline = instanced_pipeline;
    data.instance_buffer = instance_buffer;
    return data, true;
}

sdl_gpu_renderer_drop :: (window: *Window, data: *Gpu_Renderer_Data)
{
    sdl_window := convert_to_sdl_window(window);
    SDL_ReleaseGPUGraphicsPipeline(data.device, data.pipeline);
    SDL_ReleaseGPUGraphicsPipeline(data.device, data.instanced_pipeline);
    SDL_ReleaseGPUBuffer(data.device, data.instance_buffer);
    SDL_ReleaseWindowFromGPUDevice(data.device, sdl_window);
    SDL_DestroyGPUDevice(data.device);
}

sdl_gpu_upload_mesh :: (data: *Gpu_Renderer_Data, mesh_data: Mesh) -> Mesh_Handle
{
    vertices := mesh_data.vertices;
    indices := mesh_data.indices;

    // Create vertex buffer
    vertex_buffer_info := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_VERTEX,
        size = cast(u32) vertices.count * size_of(Vertex)
    };

    vertex_buffer := SDL_CreateGPUBuffer(data.device, *vertex_buffer_info);
    assert(vertex_buffer != null, "Couldn't create vertex buffer: %", SDL_GetErrorString());

    // Create index buffer
    index_buffer_info := SDL_GPUBufferCreateInfo.{
        usage = SDL_GPU_BUFFERUSAGE_INDEX,
        size = cast(u32) indices.count * size_of(u32)
    };

    index_buffer := SDL_CreateGPUBuffer(data.device, *index_buffer_info);
    assert(index_buffer != null, "Couldn't create index buffer: %", SDL_GetErrorString());

    // Transfer vertices between CPU -> GPU
    vertices_size := cast(u32) vertices.count * size_of(Vertex);
    indices_size  := cast(u32) indices.count * size_of(u32);
    transfer_size := vertices_size + indices_size;

    transfer_buffer_info := SDL_GPUTransferBufferCreateInfo.{
        usage = .UPLOAD,
        size = transfer_size
    };

    transfer_buffer := SDL_CreateGPUTransferBuffer(data.device, *transfer_buffer_info);
    assert(transfer_buffer != null, "Couldn't create transfer buffer: %", SDL_GetErrorString());
    defer SDL_ReleaseGPUTransferBuffer(data.device, transfer_buffer);

    // Map transfer buffer and copy vertex + index data into it
    transfer_data: *u8 = SDL_MapGPUTransferBuffer(data.device, transfer_buffer, false);
    assert(transfer_data != null, "Couldn't map transfer data: %", SDL_GetErrorString());

    // Copy vertices and indices
    memcpy(transfer_data, vertices.data, vertices_size);
    memcpy(transfer_data + vertices_size, indices.data, indices_size);

    SDL_UnmapGPUTransferBuffer(data.device, transfer_buffer);

    // Create texture
    texture_image := load_image("boid.png");
    if !texture_image {
        log_error("Couldn't load texture image: %", SDL_GetErrorString());
        return .{};
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
    texture := SDL_CreateGPUTexture(data.device, *texture_create_info);
    assert(texture != null, "Couldn't create texture: %", SDL_GetErrorString());
    SDL_SetGPUTextureName(data.device, texture, "boid");

    texture_transfer_buffer_info := SDL_GPUTransferBufferCreateInfo.{
        usage = .UPLOAD,
        size = tex_w * tex_h * 4
    };
    texture_transfer_buffer := SDL_CreateGPUTransferBuffer(data.device, *texture_transfer_buffer_info);
    assert(texture_transfer_buffer != null, "Couldn't create texture transfer buffer: %", SDL_GetErrorString());
    defer SDL_ReleaseGPUTransferBuffer(data.device, texture_transfer_buffer);

    // Map texture transfer buffer and texture into it
    texture_transfer_data: *u8 = SDL_MapGPUTransferBuffer(data.device, texture_transfer_buffer, false);
    assert(texture_transfer_data != null, "Couldn't map texture transfer buffer: %", SDL_GetErrorString());

    // Copy texture
    memcpy(texture_transfer_data, texture_image.pixels, tex_w * tex_h * 4);

    SDL_UnmapGPUTransferBuffer(data.device, texture_transfer_buffer);

    sampler_create_info := SDL_GPUSamplerCreateInfo.{
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
        mipmap_mode = .NEAREST,
        address_mode_u = .CLAMP_TO_EDGE,
        address_mode_v = .CLAMP_TO_EDGE,
        address_mode_w = .CLAMP_TO_EDGE,
    };
    sampler := SDL_CreateGPUSampler(data.device, *sampler_create_info);
    assert(sampler != null, "Couldn't create sampler: %", SDL_GetErrorString());

    upload_cmd_buf := SDL_AcquireGPUCommandBuffer(data.device);
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
    m.m = mesh_data;
    m.vertex_buffer = vertex_buffer;
    m.index_buffer  = index_buffer;
    m.sampler = sampler;
    m.texture = texture;
    m.handle.index = xx data.meshes.count;
    m.handle.generation = 1;

    push(*data.meshes, m);
    return m.handle;
}

sdl_gpu_renderer_execute_commands :: (window: *Window, data: *Gpu_Renderer_Data, list: *Render_List)
{
    frame, ok := renderer_begin_frame(window, data, list);
    if ok {
        // Push camera uniform
        SDL_PushGPUVertexUniformData(frame.command_buffer, 0, *list.view_projection, size_of(Matrix4));

        // Execute all commands
        for command: render_list_commands(list) {
            if #complete command.kind == {
            case .DRAW_INDEXED;
                cmd := command.draw_indexed;

                // Grab GPU mesh and bind buffers and samplers
                mesh := get_gpu_mesh(data, cmd.mesh);
                if !mesh  continue;

                vertex_binding  := SDL_GPUBufferBinding.{ buffer = mesh.vertex_buffer, offset = 0 };
                index_binding   := SDL_GPUBufferBinding.{ buffer = mesh.index_buffer, offset = 0 };
                sampler_binding := SDL_GPUTextureSamplerBinding.{ texture = mesh.texture, sampler = mesh.sampler };

                SDL_BindGPUGraphicsPipeline(frame.pass, data.pipeline);
                SDL_BindGPUVertexBuffers(frame.pass, 0, *vertex_binding, 1);
                SDL_BindGPUIndexBuffer(frame.pass, *index_binding, SDL_GPUIndexElementSize._32BIT);
                SDL_BindGPUFragmentSamplers(frame.pass, 0, *sampler_binding, 1);
                SDL_PushGPUVertexUniformData(frame.command_buffer, 1, *cmd.transform, size_of(Matrix4));
                SDL_DrawGPUIndexedPrimitives(frame.pass, xx mesh.indices.count, 1, 0, 0, 0);
            case .DRAW_INDEXED_INSTANCES;
                cmd := command.draw_indexed_instances;

                // Grab GPU mesh and bind buffers and samplers
                mesh := get_gpu_mesh(data, cmd.mesh);
                if !mesh  continue;

                vertex_binding  := SDL_GPUBufferBinding.{ buffer = mesh.vertex_buffer, offset = 0 };
                index_binding   := SDL_GPUBufferBinding.{ buffer = mesh.index_buffer, offset = 0 };
                sampler_binding := SDL_GPUTextureSamplerBinding.{ texture = mesh.texture, sampler = mesh.sampler };

                SDL_BindGPUGraphicsPipeline(frame.pass, data.instanced_pipeline);
                SDL_BindGPUVertexBuffers(frame.pass, 0, *vertex_binding, 1);
                SDL_BindGPUVertexStorageBuffers(frame.pass, 0, *data.instance_buffer, 1);
                SDL_BindGPUIndexBuffer(frame.pass, *index_binding, SDL_GPUIndexElementSize._32BIT);
                SDL_BindGPUFragmentSamplers(frame.pass, 0, *sampler_binding, 1);
                SDL_PushGPUVertexUniformData(frame.command_buffer, 1, *cmd.transform, size_of(Matrix4));
                SDL_DrawGPUIndexedPrimitives(frame.pass, xx mesh.indices.count, xx cmd.instances, 0, 0, 0);
            }
        }
    }

    renderer_end_frame(*frame);
}

Gpu_Renderer_Data :: struct {
    device:   *SDL_GPUDevice;
    pipeline: *SDL_GPUGraphicsPipeline;
    instanced_pipeline: *SDL_GPUGraphicsPipeline;

    instance_buffer: *SDL_GPUBuffer;

    // @TODO: Is this the right place to store meshes?
    // @TODO: Change in favor of Handle_Array type
    meshes: Fixed_Array(Gpu_Mesh, 64);
}

#scope_file

// #region Renderer Frames

renderer_begin_frame :: (window: *Window, data: *Gpu_Renderer_Data, list: *Render_List) -> Renderer_Frame, bool
{
    frame: Renderer_Frame;

    // Create command buffer for batching requests to the GPU
    frame.command_buffer = SDL_AcquireGPUCommandBuffer(data.device);
    assert(frame.command_buffer != null, "Couldn't acquire GPU command buffer: %", SDL_GetErrorString());

    // Create a swapchain texture to draw in between frames
    swapchain_texture: *SDL_GPUTexture;
    ok := SDL_WaitAndAcquireGPUSwapchainTexture(
        frame.command_buffer,
        convert_to_sdl_window(window),
        *swapchain_texture,
        *frame.width, *frame.height); 
    assert(ok, "Couldn't acquire swapchain texture: %", SDL_GetErrorString());

    // Upload instance positions to the GPU every frame
    // This has to get run even if the swapchain is not present, such that entities get updated
    // even if e.g. the window is minimized.
    upload_instance_data(data, render_list_instances(list));

    // The swapchain texture can be null in certain cases, i.e. the window is minimized.
    if !swapchain_texture  return frame, false;

    cti: SDL_GPUColorTargetInfo;
    cti.texture = swapchain_texture;
    cti.clear_color = cast,force(SDL_FColor) list.clear_color;
    cti.load_op = .CLEAR;
    cti.store_op = .STORE;

    frame.pass = SDL_BeginGPURenderPass(frame.command_buffer, *cti, 1, null);
    return frame, true;
}

renderer_end_frame :: (frame: *Renderer_Frame)
{
    if frame.pass  SDL_EndGPURenderPass(frame.pass);

    // Send commands to the GPU
    ok := SDL_SubmitGPUCommandBuffer(frame.command_buffer);
    assert(ok, "Couldn't submit command buffer to GPU: %", SDL_GetErrorString());
}

get_gpu_mesh :: (data: *Gpu_Renderer_Data, handle: Mesh_Handle) -> *Gpu_Mesh
{
    // Check handle before returning ref
    if handle.index >= data.meshes.count  return null;
    mesh := *data.meshes.data[handle.index];
    if mesh.handle.generation != handle.generation  return null;

    return mesh;
}

upload_instance_data :: (data: *Gpu_Renderer_Data, instances: []Render_Instance)
{
    if instances.count == 0  return;

    size := cast(u32) instances.count * size_of(Render_Instance);

    // Create transfer buffer to send buffer to GPU
    transfer_buffer_info := SDL_GPUTransferBufferCreateInfo.{
        usage = .UPLOAD,
        size = size,
    };

    transfer_buffer := SDL_CreateGPUTransferBuffer(data.device, *transfer_buffer_info);
    assert(transfer_buffer != null, "Couldn't create transfer buffer: %", SDL_GetErrorString());
    defer SDL_ReleaseGPUTransferBuffer(data.device, transfer_buffer);

    // Move positions to transfer buffer
    transfer_data: *u8 = SDL_MapGPUTransferBuffer(data.device, transfer_buffer, true);
    assert(transfer_data != null, "Couldn't map transfer data: %", SDL_GetErrorString());

    memcpy(transfer_data, instances.data, size);

    SDL_UnmapGPUTransferBuffer(data.device, transfer_buffer);

    // @TODO: Should we be acquiring a new command buffer here, or reuse an existing one?
    upload_cmd_buf := SDL_AcquireGPUCommandBuffer(data.device);
    assert(upload_cmd_buf != null, "Couldn't acquire GPU command buffer: %", SDL_GetErrorString());

    // Copy positions from transfer buffer to GPU
    copy_pass := SDL_BeginGPUCopyPass(upload_cmd_buf);

    from := SDL_GPUTransferBufferLocation.{
        transfer_buffer = transfer_buffer,
        offset = 0
    };

    to := SDL_GPUBufferRegion.{
        buffer = data.instance_buffer,
        offset = 0,
        size = size,
    };

    SDL_UploadToGPUBuffer(copy_pass, *from, *to, true);
    SDL_EndGPUCopyPass(copy_pass);

    ok := SDL_SubmitGPUCommandBuffer(upload_cmd_buf);
    assert(ok, "Couldn't submit GPU command buffer: %", SDL_GetErrorString());
}

// #region Shaders

/// @TODO: This can be done at compile time, probably
load_shader :: (device: *SDL_GPUDevice, path: string, num_samplers: u32 = 0, num_storage_buffers: u32 = 0) -> *SDL_GPUShader
{
    stage: SDL_GPUShaderStage;
    if ends_with(path, ".vert")       stage = .VERTEX;
    else if ends_with(path, ".frag")  stage = .FRAGMENT;
    else {
        log_error("Couldn't deduce shader stage from filename: %", path);
        return null;
    }

    // @FIXME: Relative path used here
    full_path := path_join(to_string(SDL_GetBasePath()), "../assets/shader/out");

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
    shader_info.num_samplers = num_samplers;
    shader_info.num_storage_buffers = num_storage_buffers;
    shader_info.num_uniform_buffers = 2;

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

    fragment_shader := load_shader(device, "texture.frag", num_samplers = 1);
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

create_instanced_pipeline :: (window: *SDL_Window, device: *SDL_GPUDevice) -> *SDL_GPUGraphicsPipeline
{
    // Load vertex and fragment shaders
    vertex_shader := load_shader(device, "position_instanced.vert", num_storage_buffers = 1);
    assert(vertex_shader != null, "Couldn't create vertex shader for instance pipeline: %", SDL_GetErrorString());
    defer SDL_ReleaseGPUShader(device, vertex_shader);

    fragment_shader := load_shader(device, "texture.frag", num_samplers = 1);
    assert(fragment_shader != null, "Couldn't create fragment shader: %", SDL_GetErrorString());
    defer SDL_ReleaseGPUShader(device, fragment_shader);

    color_target_description := SDL_GPUColorTargetDescription.[.{
        format = SDL_GetGPUSwapchainTextureFormat(device, window),
        blend_state = .{
            enable_blend = true,
            color_blend_op = .ADD,
            alpha_blend_op = .ADD,
            src_color_blendfactor = .SRC_ALPHA,
            dst_color_blendfactor = .ONE_MINUS_SRC_ALPHA,
            src_alpha_blendfactor = .SRC_ALPHA,
            dst_alpha_blendfactor = .ONE_MINUS_SRC_ALPHA,
        }
    }];

    pci := SDL_GPUGraphicsPipelineCreateInfo.{
        primitive_type = .TRIANGLELIST,
        vertex_shader = vertex_shader,
        fragment_shader = fragment_shader,
        vertex_input_state = SDL_GPUVertexInputState.{
            vertex_buffer_descriptions = VERTEX_BUFFER_DESCRIPTIONS.data,
            num_vertex_buffers = VERTEX_BUFFER_DESCRIPTIONS.count,
            vertex_attributes = VERTEX_ATTRIBUTES.data,
            num_vertex_attributes = VERTEX_ATTRIBUTES.count
        },
        target_info = SDL_GPUGraphicsPipelineTargetInfo.{
            color_target_descriptions = color_target_description.data,
            num_color_targets = color_target_description.count,
        }
    };

    return SDL_CreateGPUGraphicsPipeline(device, *pci);
}

// @TODO: This should be backend-specific but used by the game layer, maybe?
// Note that when dropping the mesh, we must increment the generation for the handle it has.
mesh_drop :: (renderer: *Gpu_Renderer_Data, m: *Gpu_Mesh)
{
    SDL_ReleaseGPUBuffer(renderer.device, m.vertex_buffer);
    SDL_ReleaseGPUBuffer(renderer.device, m.index_buffer);
    SDL_ReleaseGPUSampler(renderer.device, m.sampler);
    SDL_ReleaseGPUTexture(renderer.device, m.texture);
}

// @FIXME: For now, until I think how to overlap the two layers together, this is
// copied from platform_sdl.jai
convert_to_sdl_window :: (w: *Window) -> *SDL_Window
{
    return cast(*SDL_Window) w.native;
}

Renderer_Frame :: struct {
    command_buffer: *SDL_GPUCommandBuffer;
    pass:           *SDL_GPURenderPass;
    width:          u32;
    height:         u32;
    view_proj:      Matrix4;
}

Gpu_Mesh :: struct {
    using #as m: Mesh;

    handle: Mesh_Handle;

    vertex_buffer: *SDL_GPUBuffer;
    index_buffer: *SDL_GPUBuffer;

    sampler: *SDL_GPUSampler;
    texture: *SDL_GPUTexture;
}

Gpu_Texture :: struct {
    handle: *SDL_GPUTexture;
}

// What am I going to send?
VERTEX_BUFFER_DESCRIPTIONS :: SDL_GPUVertexBufferDescription.[
    .{ slot = 0, pitch = size_of(Vertex), input_rate = .VERTEX, instance_step_rate = 0 }
];

VERTEX_ATTRIBUTES_COUNT :: #run field_count(Vertex);
VERTEX_ATTRIBUTES :: #run make_vertex_attributes(Vertex); // How is the thing I am going to send look like?

field_count :: ($T: Type) -> int #compile_time
#modify {
    ti := cast(*Type_Info) T;
    if ti.type != .STRUCT return false;

    return true;
} {
    ti := cast(*Type_Info_Struct) T;
    n := 0;

    for ti.members {
        if !(it.flags & .CONSTANT)  n += 1;
    }

    return n;
}

make_vertex_attributes :: ($T: Type) -> [VERTEX_ATTRIBUTES_COUNT]SDL_GPUVertexAttribute #compile_time
{
    attributes: [VERTEX_ATTRIBUTES_COUNT]SDL_GPUVertexAttribute;
    ti := cast(*Type_Info_Struct) T;

    i := 0;
    for member: ti.members {
        if member.flags & (.CONSTANT | .OVERLAY)  continue;

        format: SDL_GPUVertexElementFormat;
        if member.type == type_info(Vector2)       format = .FLOAT2;
        else if member.type == type_info(Vector3)  format = .FLOAT3;
        else if member.type == type_info(Vector4)  format = .FLOAT4;
        else if member.type == type_info(float32)  format = .FLOAT;
        else assert(false, "Vertex member '%' has type with no vertex format mapping.", member.name);

        attributes[i] = .{
            location = xx i,
            buffer_slot = 0,
            format = format,
            offset = xx member.offset_in_bytes,
        };
        i += 1;
    }

    return attributes;
}


#import "SDL3";
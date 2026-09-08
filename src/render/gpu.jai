Gpu_Renderer_Data :: struct {
    device: *SDL_GPUDevice;
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

    data: Gpu_Renderer_Data;
    data.device = device;
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
        SDL_EndGPURenderPass(render_pass);
    }

    // Send commands to the GPU
    SDL_SubmitGPUCommandBuffer(cmd);
}

#import "SDL3";
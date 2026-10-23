# Cutengine 🐾
Cutengine is an early-stage 3D game engine written in Jai based on a platform- and graphics API-agnostic API, with heavy inspiration from [Handmade Hero](https://hero.handmade.network/).

![Demo](docs/demo.gif)

## Focus
Cutengine does not aim to be a general-purpose engine for any kind of games, it is rather specific to a certain (personal) game. This has only been tested on macOS (Metal) as of 22 Oct, 2026.

The engine currently implements forward rendering using SDL3_gpu, but its API is designed in a way that is easy to extend to other APIs (such as Vulkan, Metal or DirectX).
Windowing is implemented with SDL3 for a portability-first approach, with the ability to add a OS-specific layer if needed (such as Win32 for Windows, Cocoa for macOS or X11/Wayland for Linux).
Layer independence not only allows us to extend to other platforms with ease: it also cleanly separates what each layer is responsible for.

## Support
✅ Supported · 🚧 In progress · 📋 Planned · 🤔 Considering · ❌ Not planned

### Graphics APIs
| API              | Status | Notes                                                              |
|------------------|:------:|--------------------------------------------------------------------|
| SDL3_gpu         | ✅     | Current backend. Runs on Metal (tested); Vulkan and D3D12 through SDL |
| Vulkan (native)  | 📋     |                                                                    |
| Metal (native)   | 📋     |                                                                    |
| DirectX (native) | 📋     |                                                                    |

### Operating systems
| OS      | Status | Notes                                                          |
|---------|:------:|----------------------------------------------------------------|
| macOS   | ✅     | Only tested platform (Apple Silicon, Metal)                    |
| Windows | 📋     | Shader baking needs DXIL output (the baker writes to `/dev/stdout`) |
| Linux   | 📋     | SPIR-V shader path exists but is untested                      |

### Platform layer
| API           | Status | Notes             |
|---------------|:------:|-------------------|
| SDL3          | ✅     | Portable fallback |
| Win32         | 🤔     |                   |
| Cocoa         | 🤔     |                   |
| X11 / Wayland | 🤔     |                   |

### Rendering
Rendering aims for a stylized look, not photorealism.

| Feature                                          | Status |
|--------------------------------------------------|:------:|
| Forward rendering, depth testing                 | ✅     |
| Instanced drawing                                | ✅     |
| Shader hot reloading                             | ✅     |
| Toon shading                                     | 🚧     |
| HDR + tonemapping                                | 📋     |
| Shadows                                          | 📋     |
| Ray tracing                                      | 🤔     |
| Global illumination                              | 🤔     |

### Assets
| Format / feature                    | Status |
|-------------------------------------|:------:|
| PNG → texture (RGBA8)               | ✅     |
| OBJ → model                         | ✅     |
| HLSL → shader (via `shadercross`)   | ✅     |
| Material assets                     | 📋     |
| BC7 texture compression             | 📋     |
| OGG → audio                         | 📋     |
| Packed per-type files for release   | 📋     |

## Layers
Separating the engine into layers (or "levels") allows us to think more about each component individually without having to worry about other pieces (OS calls, game code, rendering bugs). The engine currently separates between (from high to lower level):
- Game layer: where all the game code lives. Communicates with the rendering layer (via uniforms and direct calls to a command list) and engine layer.
- Rendering layer: where the rendering code lives. This includes API-specific code for each graphics API.
- Engine layer: consists of utilities and bricks where the game builds on - memory, asset baking/loading, input and scene management.
- Platform layer: implements OS-specific code such as opening and closing a window, event handling, tracking time.

The engine's main loop runs at a fixed 60 FPS simulation. It keeps the previous and current game state and blends between them when drawing.

## Memory management
The engine does **not** allocate after initialization. This is enforced by Jai's `trap_allocator` which is set after the game is initialized, and any allocation will trap.
Memory is managed by *pools* which are tied to specific **lifetimes**; these pools are statically allocated when the program starts and their memory live as long as the program is running.

There are currently three types of pools:
- **Permanent memory**: used for objects that will live for **the entire program** (e.g., the window and renderer). Defaults to 64 MiB.
- **Transient memory**: used for objects that will live for **the duration of one or more frames** (e.g., a model, a particle effect, animations). Defaults to 4 GiB.
- **Per-frame memory**: used for objects that will live for **the duration of a single frame** (e.g. constructing a temporary string, populating an array). Defaults to 8 MiB.

These pools store data contiguously and it is not possible to deallocate a single object from themselves; the user must deallocate the entire pool.
For transient storage, this means the game layer must group objects by lifetime and deallocate once they're no longer needed. (Example: a game area may hold multiple models, once the player moves to another area, these can get thrown away.)
For per-frame storage, the deallocation happens automatically at the end of the frame by the engine code.

## Asset management
Assets are processed by an **asset baker** utility (run at compile time) that will transform source formats (`.png`, `.obj`, `.ogg`) into a custom format understood by the engine (`.ca`). This format acts as an intermediate layer between all other assets.
Given that the engine uses its own format, it is possible to transform the resulting data in any way we want. For example, we may apply heavy compression on the source data and use encoders/decoders on the fly when an asset is requested to be loaded.

In debug modes, each assets produces one or more `.ca` files, and the engine then loads any necessary asset referenced by another.
In release modes (PLANNED, not yet done), each asset type (texture, model, audio, shader, etc.) is packed into a single file (e.g. `textures.ca`) which contains all (compressed) assets of that type. When the game requests an asset, a lookup is done inside the asset header + data and the engine loads this asset.

Assets can reference each other. For example, two models `model_a.ca` and `model_b.ca` can use the same material `material.ca` without duplicating assets and GPU loads.

## Rendering commands
The game layer does not call API-specific draw calls directly. Instead, it issues **draw commands** that tell the renderer *what* to do, not *how* to do it.
For example, we may want to draw a single object, we may then issue a `DRAW_INDEXED_COMMAND`. Or we may want to draw multiple instances of a single mesh optimally, then we issue a `DRAW_INDEXED_INSTANCES_COMMAND`.

The game code results in, roughly:
```jai
// Begin render list
uniforms: Render_Uniforms;
// Fill uniforms here ...

render_list_begin(list, uniforms);
render_draw_mesh(list, tree_mesh, tree_material, tree_transform);
render_draw_mesh_instances(list, particle_mesh, particle_material, particle_transform, particle_instances);
```

Once the render list is populated, the engine can either (a) directly execute the required graphics calls bound to the current graphics API, or (b) reorder draw calls first, remove unnecessary draws, etc.
This command list is populated every frame.

## Building
Cutengine is built with Jai, so unfortunately you will need a working Jai compiler, which is in closed beta at the time of writing.

Cutengine requires a [SDL3](https://wiki.libsdl.org/SDL3/FrontPage) dylib located in a `lib/` directory at the root of the repository. SDL 3.4.4 is a good patch to use.
For cross-compiling shaders, [`SDL_shadercross`](https://github.com/libsdl-org/SDL_shadercross) is required.
```sh
$ jai first.jai               # Compile with debug mode, no optimizations. Builds go in build_debug/
$ jai first.jai - debug       # Optionally pass in a debug argument (same as above)
$ jai first.jai - bake_assets # Compile in debug mode, converts updated assets to .ca format
$ jai first.jai - release     # Compile in release mode - always rebuilds all assets. Builds go in build_release/
```

Game code goes in `src/game/` and must be included by `main.jai`. Example code is provided in `game.jai` and `boids.jai`.

#run build();

build :: ()
{
    build_options := get_build_options();
    build_options.output_executable_name = "cutengine";
    build_options.additional_linker_arguments = .["-rpath", "@loader_path/../lib"]; // Link SDL3
    build_options.temporary_storage_size = 8 * 1024 * 1024; // Default to 8 MiB for per-frame allocations
    set_build_options_dc(.{do_output = false});
    set_working_directory(#filepath);

    release := false;
    for build_options.compile_time_command_line {
        if it == {
            case "release"; release = true;
            case "debug";
            case; compiler_report(tprint("Unknown argument '%'. Use 'debug' or 'release'.", it));
        }
    }

    if release {
        set_optimization(*build_options, .OPTIMIZED);
        build_options.output_path = "build_release";
    } else {
        set_optimization(*build_options, .DEBUG);
        build_options.output_path = "build_debug";
    }

    make_directory_if_it_does_not_exist(build_options.output_path);

    // Add DEBUG for debug builds -- that way we can do #if DEBUG checks
    w := compiler_create_workspace("cutengine");
    set_build_options(build_options, w);
    add_build_string(tprint("DEBUG :: %;", ifx release then "false" else "true"), w);
    add_build_file("src/main.jai", w);

    result := rebuild_shaders();
    if !result.ok {
        compiler_report(tprint("Couldn't compile shaders. SDL_ShaderCross Error:\n%", result.error));
        exit(1);
    }
}

rebuild_shaders :: () -> Shader_Compilation_Info
{
    SHADER_DIR :: "assets/shader";

    out_dir := tprint("%/out", SHADER_DIR);
    make_directory_if_it_does_not_exist(out_dir);

    compilation_info: Shader_Compilation_Info;
    compilation_info.out_dir = out_dir;
    compilation_info.ok = true;

    shader_proc :: (info: *File_Visit_Info, data: *Shader_Compilation_Info) {
        if !ends_with(info.short_name, ".hlsl")  return;
        base := path_strip_extension(info.short_name);

        out_path: string;
        #if OS == {
            case .WINDOWS; out_path = tprint("%/%.%", data.out_dir, base, "dxil");
            case .LINUX;   out_path = tprint("%/%.%", data.out_dir, base, "spv");
            case .MACOS;   out_path = tprint("%/%.%", data.out_dir, base, "msl");
        }

        result, stdout, stderr := run_command(
            "shadercross", info.full_name,
            "-o", out_path,
            capture_and_return_output = true,
            print_captured_output = false);

        if result.exit_code == 1 {
            data.ok = false;
            data.error = stderr;
        }
    }

    visit_files(
        dir_name=tprint("%/src", SHADER_DIR),
        recursive=true,
        user_data=*compilation_info,
        proc=shader_proc,
        visit_files=true,
        visit_directories=true
    );

    return compilation_info;
}

Shader_Compilation_Info :: struct {
    out_dir: string;
    ok:      bool;
    error:   string;
};

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "String";
#import "Process";
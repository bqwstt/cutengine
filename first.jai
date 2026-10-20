ROOT_DIR   :: #filepath;
ASSETS_DIR :: #run path_join(ROOT_DIR, "assets");
SHADER_DIR :: #run path_join(ASSETS_DIR, "shader");

// Need `stallable` as the statements above have to finish executing first.
#run,stallable build();

build :: ()
{
    build_options := get_build_options();
    build_options.output_executable_name = "cutengine";
    build_options.additional_linker_arguments = .["-rpath", "@loader_path/../lib"]; // Link SDL3
    build_options.temporary_storage_size = 8 * 1024 * 1024; // Default to 8 MiB for per-frame allocations
    set_build_options_dc(.{do_output = false});
    set_working_directory(#filepath);

    force_asset_rebake := false;
    release := false;
    for build_options.compile_time_command_line {
        if it == {
            case "release"; release = true;
            case "debug";
            case "bake_assets"; force_asset_rebake = true;
            case; compiler_report(tprint("Unknown argument '%'. Use 'debug' or 'release'.", it));
        }
    }

    if release {
        set_optimization(*build_options, .OPTIMIZED);
        build_options.output_path = "build_release";
        force_asset_rebake = true;
    } else {
        set_optimization(*build_options, .DEBUG);
        build_options.output_path = "build_debug";
    }

    bake_shaders();
    convert_assets(force_asset_rebake);
    if force_asset_rebake  print("\n");

    make_directory_if_it_does_not_exist(build_options.output_path);

    // Add DEBUG for debug builds -- that way we can do #if DEBUG checks
    w := compiler_create_workspace("cutengine");
    set_build_options(build_options, w);
    add_build_string(tprint("DEBUG :: %;", ifx release then "false" else "true"), w);
    add_build_file("src/main.jai", w);
}

bake_shaders :: ()
{
    shader_proc :: (info: *File_Visit_Info, data: *void) {
        if ends_with(info.short_name, ".hlsl")  write_asset(info.full_name);
    }

    visit_files(
        dir_name=SHADER_DIR,
        recursive=true,
        user_data=null,
        proc=shader_proc,
    );
}

convert_assets :: (force_rebake: bool)
{
    convert_proc :: (info: *File_Visit_Info, force_rebake: *bool) {
        if ends_with(info.full_name, ".ca")  return;
        if ends_with(info.full_name, ".hlsl")  return; // Baked on every build by bake_shaders()
        write_asset(info.full_name, force_rebake.*);
    }

    visit_files(
        dir_name=ASSETS_DIR,
        recursive=true,
        user_data=*force_rebake,
        proc=convert_proc,
    );
}

#load "src/engine/asset_baker.jai";

#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "String";
#import "Process";
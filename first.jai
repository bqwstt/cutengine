#import "Basic";
#import "Compiler";
#import "File";
#import "File_Utilities";

#run build();

build :: ()
{
    build_options := get_build_options();
    build_options.output_executable_name = "cutengine";
    build_options.additional_linker_arguments = .["-rpath", "@loader_path/../lib"]; // Link SDL3
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
}
# CAKE_BINARY_DIR_PREFIX
#     binary dirs will be created using this as a base
#     if not defined, defaults to the temporary dir

# CAKE_OPTIONS
#     options parsed by cake, most of these passed to cmake
#     The options after the '--' must be listed in CAKE_NATIVE_TOOL_OPTIONS
#     Supported options:
#         -C, -D, -U, -G, -T, -W[no-]dev, -N
#         --rm-bin, -m, -c|--config, -R|--debug-release
#         -t|--target, -i|--install, --clean_first, --use_stderr

# CAKE_NATIVE_TOOL_OPTIONS
#     options passed to the native tool in cmake build step
#     These are the options listed after the '--' in
#     cmake --build ... -- ...

# CAKE_LINK_BINARY_DIR
#     Controls the automatic linking of a CMake source-dir
#     to a binary dir.
#     Possible values:
#     - none: don't link source dirs to binary dirs
#     - inside: automatically create a file <source-dir>/.cmake_binary_dir
#         which contains the location of the binary dir
#     - beside: automatically create a file <source-dir>.cmake_binary_dir
#         which contains the location of the binary dir
#     If it's undefined, defaults to 'inside'

# CAKE_GENERATE_ALWAYS
#     If true or undefined then the generate step of CMake
#     will always be called before other operations (--ide, --gui, --build)

# CAKE_MODULE_PATH
#     list of search paths for cake modules. Defaults to
#     ${CAKE_ROOT}/modules
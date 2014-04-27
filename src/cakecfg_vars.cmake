# CAKE_BINARY_DIR_PREFIX
#     binary dirs will be created using this as a base
#     if not defined, defaults to the temporary dir

# CAKE_BINARY_DIR
#     defines the CMake binary dir
#     (1) Leave it undefined to make cake automatically calculate a
#         binary directory below CAKE_BINARY_DIR_PREFIX
#     (2) You can set it to a relative path. It will be
#         relative to CAKE_BINARY_DIR_PREFIX
#     (3) You can set it to an absolute path
#     In all cases when using single-config (non-IDE)
#     generator, the directory name will be postfixed
#     with the configuration (Debug, Release, ...)

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

# CAKE_GENERATE_ALWAYS
#     If true or undefined then the generate step of CMake
#     will always be called before other operations (--ide, --gui, --build)

# CAKE_MODULE_PATH
#     list of search paths for cake modules. Defaults to
#     ${CAKE_ROOT}/modules
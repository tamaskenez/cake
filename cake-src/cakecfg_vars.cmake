# CAKE_BINARY_DIR_PREFIX
#     binary dirs will be created using this as a base
#     if not defined, defaults to the temporary dir

# CAKE_CMAKE_ARGS
#     options parsed by cake, most of these passed to cmake
#     The options after the '--' must be listed in CAKE_CMAKE_NATIVE_TOOL_ARGS
#     Supported options:
#         -C, -D, -U, -G, -T, -W[no-]dev, -N
#         --rm-bin, -m, -c|--config, -R|--debug-release
#         -t|--target, -i|--install, --clean_first, --use_stderr

# CAKE_NATIVE_TOOL_ARGS
#     options passed to the native tool in cmake build step
#     These are the options listed after the '--' in
#     cmake --build ... -- ...


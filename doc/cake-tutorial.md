Cake Tutorial
=============

The `cake` command is implemented as a plain CMake script. You can use it both in a Unix-like or in a Windows shell, too. The two files `cake` and `cake.cmd` forwards the parameters to the platform-independent `cake.cmake` script.

List of features
----------------

- Frequently-used CMake options can be read from environment variables of config file.
- The CMake binary (build) directory is automatically created or assigned to the source directory under a predefined binary-dir-prefix directory so you launch your CMake operations with the source dir: `cake mysourcedir --target tests`
- Launch your IDE or `cmake-gui` from the command-line: `cake --ide mysourcedir`, `cake --gui mysourcedir`
- Configure & build multiple configurations or targets in one step with simple command lines: `cake mysourcedir --install --debug-release`

Cake Configuration Variables
----------------------------

The following environment variables control the `cake` command:

### CAKE_CMAKE_ARGS

The arguments fir the `cmake` command listed here will be forwarded the `cmake` configuration phase. Example:

    export CAKE_CMAKE_ARGS="-DINSTALL_PREFIX=$PWD/_install -GXcode"
    cake . # appends the args defined above
    
### CAKE_CMAKE_NATIVE_TOOL_ARGS

Similar to `CAKE_CMAKE_ARGS`, `CAKE_CMAKE_NATIVE_TOOL_ARGS` will be passed after the '--' in the `cmake --build` command:

    export CAKE_CMAKE_NATIVE_TOOL_ARGS="-j"
    cake . --build # calls `cmake --build ... -- -j` in turn

### CAKE_BINARY_DIR_PREFIX

When given a source directory `cake` will automatically create a build directory with the name of the source directory under this directory prefix. Example:

    export CAKE_BINARY_DIR_PREFIX=$HOME/_build
    cake . # calls `cmake` with the binary dir in $HOME/_build/<source-dir-name>

If `CAKE_BINARY_DIR_PREFIX` is not set it defaults to the system temporary directory.

### Cake Configuration File
You can also set the enviroment variable `CAKE_CONFIG_FILE` point to a configuration file which is a plain *CMake* script where you set the configuration variables as *CMake* variables. Example:

    export CAKE_CONFIG_FILE=$HOME/my-cake-cfg.cmake
    
And the content of `$HOME/my-cake-cfg.cmake`:

    set(CAKE_BINARY_PREFIX ${CMAKE_CURRENT_LIST_DIR}/_build)
    set(CAKE_CMAKE_ARGS -GXcode
        -DCMAKE_INSTALL_PREFIX=${CMAKE_CURRENT_LIST_DIR}/_install
        -DCMAKE_PREFIX_PATH=${CMAKE_CURRENT_LIST_DIR}/_install)

For more information please consult the help in the file [cake.cmake](https://github.com/tamaskenez/cake/blob/pkg/cake-src/cake.cmake).

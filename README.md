cake for CMake
====

cake for CMake, helper script for launching cmake and managing options

The **cake** is a CMake script which you can use in place of calling cmake directly. Main purpose of **cake** is to save typing the same parameters for cmake again and again.
You can use it both in a Unix-like or in a Windows shell, too. The two files `cake` and `cake.cmd` forwards the parameters to the platform-independent `src/cake.cmake` script.

With **cake** you can place the frequently-used options in various places:

- in environment variables
- in config files (.cakecfg.cmake) in directories like cake install directory, your user directory, a source directory (where the CMakeLists.txt is located)
- in cake-module files (also simple cmake script files)

You can use any text editor to manage the cakecfg.cmake files.

Extensive list of features:

- Place frequently-used CMake options in various files and variables to save typing and managing sets of options (like configuring a toolchain)
- Bind a CMake binary (build) directory to a source directory so you launch your CMake operations with the source dir: `cake mysourcedir --target tests`
- You can let **cake** calculate a build directory automatically
- Launch your IDE or cmake-gui from the command-line: `cake --ide mysourcedir`, `cake --gui mysourcedir`
- Build multiple configurations or targets with simple command lines: `cake mysourcedir --install --debug-release`

Variables That Control Cake 
====================

You can set environment variables or CMake variables in files located in these files:

- `$HOME/cakecfg.cmake` (`%HOMEDRIVE%\%HOMEPATH%\cakecfg.cmake`)
- `<cake-install-dir>/cakecfg.cmake`
- `<source-dir>/cakecfg.cmake`
- a cake-module: a file located in one of the paths from `CAKE_MODULE_PATH`

### CAKE_OPTIONS

Options passed to the cake or cmake command line, like `-DFOO=bar -G Xcode`. If you set this variable either in a file of on command line, it will be *appended* to options set in other sources (other config files, command-line)

Supported options:

- `-C`, `-D`, `-U`, `-G`, `-T`, `-W[no-]dev`, `-N` (see cmake help)
- `--rm-bin`, `-m`, `-c`|`--config`, `-R`|`--debug-release` (see cake help)
- `-t`|`--target`, `-i`|`--install`, `--clean_first`, `--use_stderr` (see cake help)


### CAKE_NATIVE_TOOL_OPTIONS

Options passed to the native build tool (the options after the '--' in `cmake --build ... --` )
The value of this variable will be *appended* to other options.

### CAKE_GENERATE_ALWAYS

Controls if the CMake config/generate step should always be executed first. Defaults to TRUE if not defined. Set this variable only in one place.

### CAKE_BINARY_DIR_PREFIX

The base directory for automatically generated binary directory names. Defaults to the temp dir. You can set this variable only in one place.

### CAKE_BINARY_DIR

Defines the binary (build) directory. There are three options:

1. If you leave it undefined the name of the binary directory defaults to the name of the source dir (the last component of the source dir). It will be created under `CAKE_BINARY_DIR_PREFIX` 
2. You can set it to a relative path. It will be relative to `CAKE_BINARY_DIR_PREFIX`
3. You can set it to an absolute path

If at one place you set a relative binary dir, it can be overridden by an absolute path set in another place. The binary dir you set on the command line has always overrides any previous setting. 

### CAKE_MODULE_PATH

Similar to CMAKE_MODULE_PATH. A list of search paths for cake-modules. A cake-module is a CMake script file which you can include in a cake-call.
Defaults the `modules` subdir in the cake installation.

## Examples

Suppose you have source dir (a directory containing CMakeLists.txt) in ./mysrc.
A call to

    cake mysrc

calls cmake with a binary dir in `CAKE_BINARY_DIR_PREFIX/mysrc`. Since we didn't set CAKE_BINARY_DIR_PREFIX to any value, it will defaults to the current temporary dir.


If you need to specify an exact binary dir, call cake with an absolute path

    cake mysrc $HOME/builds/mybuilddir

This will create a .cakecfg.cmake file in mysrc/.cakecfg.cmake and set the value of the CAKE_BINARY_DIR to the absolute path you specified. So next time when you call:

    cake mysrc

cmake will be called with $HOME/builds/mybuilddir as a binary dir.

You can set an environment variable to control the cmake calls, like

    export CAKE_OPTIONS="-G Xcode"

From that on, all cake calls you issue will call cmake with the `-G Xcode` options added.

### Modules

You can write a set of options in a file, for example, let the file `<cake-install-dir>/modules/android.cmake` contain:

    set(CAKE_OPTIONS
        -G "Unix Makefiles"
        -DCMAKE_TOOLCHAIN_FILE=${CMAKE_CURRENT_LIST_DIR}/android-toolchain.cmake
        -DANDROID_ABI=armeabi-v7a)

Then you can call

    cake mysrc -m android

to include all the options you specified in the cake-module `android.cmake` in the cmake call.
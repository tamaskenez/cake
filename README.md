Cake for CMake
==============

*Cake* is a lightweight package management system for *CMake*, implemented in a few *CMake* functions and a shell command.

- Supports both external dependencies (built in their own source trees) and subprojects (`add_subdirectory`).
- Requires minimal change in your projects, supports legacy *CMake*-enabled packages (zero change).
- Supports optional dependencies (like a `--with-sqlite` option)
- Supports organizing master projects.

*Cake* also provides a convenience shell command `cake` which is a drop-in replacement for the `cmake` command for managing parameters passed to `cmake`.

Package Management
------------------

As a quick demonstration the *CMakeLists.txt* of a project using *libpng* looks like this:

    cmake_minimum_required(VERSION 3.1)
    project(pngtest)
    
    include(${CAKE_ROOT}/Cake.cmake)
    
    cake_find_package(PNG REQUIRED URL git://git.code.sf.net/p/libpng/code) # the official libpng repo
    
    include_directories(${PNG_INCLUDE_DIRS})
    add_definitions(${PNG_DEFINITIONS})
    add_executable(pngtest main.cpp)
    target_link_libraries(pngtest ${PNG_LIBRARIES})</pre>

The `cake_find_package()` macro clones, builds and installs *libpng* and its dependency, *zlib*, in configure time and calls `find_package(PNG)`.

For a package management tutorial please see the article: [cake-package-management-tutorial](https://github.com/tamaskenez/cake/blob/master/doc/cake_codeproject_article.html).

The `cake` shell command
------------------------

The `cake` is a shell command (implemented in a *CMake* script) which you can use in place of calling cmake directly. The main purpose of `cake` is to save typing the same parameters for `cmake` and perform common operations more conveniently. Examples:

- `cake .`: runs `cmake` for the current directory as source-dir, with other parameters like binary-dir location, cmake-generator read from environment variables or a config file.
- `cake . -R -n`: runs `cmake` for the current  directory then builds the install target for Debug and Release configurations.
- `cake . --ide`: opens the IDE (XCode or Visual Studio) for the current dir.
- 

For more information about the `cake` command please see this tutorial: (cake-tutorial)[https://github.com/tamaskenez/cake/blob/master/doc/cake-tutorial.md].

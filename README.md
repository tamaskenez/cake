Cake for CMake
==============

*Cake* is a lightweight project and package management system for CMake, implemented in CMake scripts which can be used from the command-line or from your *CMakeList.txt*. Features:

- Provides a (very simple) project file to manage and organize your CMake projects and directories, something like [Maven](https://maven.apache.org)
- Provides tool to manage multiple repositories (a bit like [Google's repo-tool](https://code.google.com/p/git-repo))
- Clone, build and install dependencies in configuration time, retrieve dependencies recursively
- Supports both external dependencies (built in their own build trees) and subprojects (`add_subdirectory`).
- Requires minimal change in your projects, supports legacy *CMake* dependencies (zero change).
- Supports optional dependencies (like a `--with-sqlite` option)


---- from this on UNDER CONSTRUCTION ----


Project Management
------------------

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
    target_link_libraries(pngtest ${PNG_LIBRARIES})

The `cake_find_package()` macro clones, builds and installs *libpng* and its dependency, *zlib*, in configure time and calls `find_package(PNG)`.

For a package management tutorial please see the article: [cake-package-management-tutorial](http://tamaskenez.github.io/cake_codeproject_article.html). For reference see the help in the files in this directory: [/Modules](https://github.com/tamaskenez/cake/tree/master/Modules) and also the [/samples](https://github.com/tamaskenez/cake/tree/master/samples).

The `cake` shell command
------------------------

The `cake` is a shell command (implemented in a *CMake* script) which you can use in place of calling `cmake` directly. The main purpose of `cake` is to save typing and perform common operations more conveniently. Examples:

- `cake .`: runs `cmake` for the current directory as source-dir, with other parameters like binary-dir location, cmake-generator read from environment variables or a config file.
- `cake . -R -n`: runs `cmake` for the current  directory then builds the install target for Debug and Release configurations.
- `cake . --ide`: opens the IDE (XCode or Visual Studio) for the current dir.

For more information about the `cake` command please see this tutorial: [cake-tutorial](https://github.com/tamaskenez/cake/blob/master/doc/cake-tutorial.md) and the help in the file [/cake-src/cake.cmake](https://github.com/tamaskenez/cake/blob/master/cake-src/cake.cmake).

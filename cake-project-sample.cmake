# This file lists the project setting variables you can use in the
# `cake-project.cmake` and `cake-project-local.cmake` files, along with their
# default values and brief descriptions.
#
# For most of the time you can leave them unset to use their default
# values shown below.
#
# Directory Layout
# ----------------
#
# CAKE_BINARY_DIR_PREFIX controls the automatic locations of the binary
# (build) directories, both for the main projects and packages.
#
#     set(CAKE_BINARY_DIR_PREFIX "${CAKE_PROJECT_DIR}/build")
#
# Packages without explicit DESTINATION will be cloned to CAKE_PKG_CLONE_DIR.
#
#     set(CAKE_PKG_CLONE_DIR "${CAKE_PROJECT_DIR}/clone")
#
# CMAKE_INSTALL_PREFIX and CMAKE_PREFIX_PATH are the regular CMake variables.
# These defaults will be used both for the main projects and packages.
#
#     set(CMAKE_INSTALL_PREFIX "${CAKE_PROJECT_DIR}/install")
#     set(CMAKE_PREFIX_PATH "${CMAKE_INSTALL_PREFIX}")
#
#
# Packages Variables
# -----------------
#
# CAKE_PKG_CLONE_DEPTH can be
# - "0" for default git-clone operation (unlimited depth)
# - "1" or more for an explicit clone depth
# The default value "" will be resolved to "0" or "1" for packages with or
# without the DESTINATION argument specified:
#
#     set(CAKE_PKG_CLONE_DEPTH "")
#
# CAKE_PKG_CONFIGURATION_TYPES controls in what configurations the packages will be
# installed:
#
#     set(CAKE_PKG_CONFIGURATION_TYPES Debug Release)
#
# For all the packages don't specify explicit DESTINATION, optionally you can
# use another, external Cake project which can be shared among multiple
# projects. CAKE_PKG_PROJECT_DIR defines this external project:
#
#     set(CAKE_PKG_PROJECT_DIR "")
#
# CMAKE_ARGS and CMAKE_NATIVE_TOOLS_ARGS will be passed to the 'cmake' command
# in configuration and build runs:
#
#     set(CMAKE_ARGS "")
#     set(CMAKE_NATIVE_TOOL_ARGS "")
#
# CAKE_PKG_REGISTRIES is a list of local files or URLs which usually
# contain a list of cake_pkg(REGISTER <name> [URL <url>] [CODE <code>]) commands
# which describe the locations and dependencies of packages on a server.
#
#     set(CAKE_PKG_REGISTRIES "")
#
# CMake-Generator
# ---------------
#
# Setting the CMake generator variables should go to the non-version-controlled
# `cake-project-local.cmake` file.
#
#     set(CMAKE_GENERATOR "")
#     set(CMAKE_GENERATOR_TOOLSET "")
#     set(CMAKE_GENERATOR_PLATFORM "")
     




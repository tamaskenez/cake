#.rst:
# CakeFindPackage
# ---------------
#
# Convenience function that fetches and installs the package (with `cake_pkg`) then calls `find_package()`.
#
# ::
#
#   CAKE_FIND_PACKAGE(<regular find_package args>
#                     URL <repo-url>)
# 
# CAKE_FIND_PACKAGE first calls `cake_pkg(INSTALL ...)` to clone the package repo and
# to build and install the package if needed (see there) then calls `find_package` with the
# remainder of the parameters.
# It's a no-op if this package has already been added as a subdirectory with `cake_add_subdirectory()`.

if(NOT CAKE_FIND_PACKAGE_INCLUDED)
  
  set(CAKE_FIND_PACKAGE_INCLUDED 1)

  if(NOT CAKE_INCLUDED)
    message(FATAL_ERROR "[cake] Include Cake.cmake, don't include this file directly.")
  endif()

  include(CMakeParseArguments)

  if(NOT CAKE_PKG_INCLUDED)
    include(${CMAKE_CURRENT_LIST_DIR}/CakePkg.cmake)
  endif()
  
  if(NOT CAKE_PRIVATE_UTILS_INCLUDED)
    include(${CMAKE_CURRENT_LIST_DIR}/CakePrivateUtils.cmake)
  endif()

  macro(cake_find_package CAKE_FP_ARG_PACKAGE)

    # set lists for cmake_parse_arguments
    if(NOT DEFINED CAKE_FP_ARG_OPTIONS)
      set(CAKE_FP_ARG_OPTIONS
        EXACT QUIET MODULE REQUIRED CONFIG NO_MODULE NO_POLICY_SCOPE
        NO_DEFAULT_PATH NO_CMAKE_ENVIRONMENT_PATH NO_CMAKE_PATH NO_SYSTEM_ENVIRONMENT_PATH
        NO_CMAKE_PACKAGE_REGISTRY NO_CMAKE_BUILDS_PATH NO_CMAKE_SYSTEM_PATH NO_CMAKE_SYSTEM_PACKAGE_REGISTRY
        CMAKE_FIND_ROOT_PATH_BOTH ONLY_CMAKE_FIND_ROOT_PATH NO_CMAKE_FIND_ROOT_PATH)
      set(CAKE_FP_ARG_SV_EXTRA URL)
      set(CAKE_FP_ARG_MV COMPONENTS NAMES CONFIGS HINTS PATHS PATH_SUFFIXES OPTIONAL_COMPONENTS )
    endif()

    unset(CAKE_FP_ARG_VERSION)
    set(CAKE_FP_ARGS_REST "${ARGN}")
    # ARGV1 can be the version (major)(.minor(.patch(.tweak)?)?)?
    if("${ARGV1}" MATCHES "^(0|[1-9][0-9]*)(\\.[0-9]+(\\.[0-9]+(\\.[0-9]+)?)?)?$")
      list(GET CAKE_FP_ARGS_REST 0 CAKE_FP_ARG_VERSION)
      list(REMOVE_AT CAKE_FP_ARGS_REST 0)
    endif()

    cmake_parse_arguments(CAKE_FP "${CAKE_FP_ARG_OPTIONS}" "${CAKE_FP_ARG_SV_EXTRA}" "${CAKE_FP_ARG_MV}" ${ARGN})

    # CAKE_FP_ARGS will be the argument list forwarded to find_package
    # it's the same we received here minus the additional arguments
    set(CAKE_FP_ARGS ${CAKE_FP_ARG_PACKAGE} ${CAKE_FP_ARG_VERSION})
    foreach(i ${CAKE_FP_ARG_OPTIONS})
      if(CAKE_FP_${i})
        list(APPEND CAKE_FP_ARGS ${i})
      endif()
    endforeach()
    foreach(i ${CAKE_FP_ARG_MV})
      if(CAKE_FP_${i})
        list(APPEND CAKE_FP_ARGS ${i} ${CAKE_FP_${i}})
      endif()
    endforeach()

    # must have URL
    if(NOT CAKE_FP_URL)
      message(FATAL_ERROR "[cake] cake_find_package: missing URL parameter")
    endif()

    # If this package is mentioned first time in this CMake configuration run, then it's simple.
    # If this has already been cloned and installed as an external package, cake_pkg will not clone again and not build again,
    # that's also fine.
    # If this package is part of this CMake project as a subdirectory then it must be handled differently.

    cake_parse_pkg_url(${CAKE_FP_URL} _cake_repo_url _cake_repo_cid _ _)

    if(CAKE_PKG_${_cake_repo_cid}_ADDED_AS_SUBDIRECTORY)
      # Can't call find package since the requested package
      # is added as a subdirectory to this project. Its build will be triggered
      # by the dependency graph of the build system. But what is more unfortunate: it
      # won't be installed until everything (projects depending on it) has been been built.
      # That's why projects depending on it must not call find_package since they will find
      # either nothing or the previously (= outdated) installation of this package.
      # Instead, CMake's target_*() commands should be used extensively:
      # - All packages intended to be used as subprojects (add_subdirectory) must
      #   1. set their properties using the target_*() commands
      #   2. they must install a config module which creates an import library
      # - All non-top-level projects that are using packages which may be both
      #       - external packages (built in a separate top-level CMakeList.txt), or
      #       - subprojects (added by cake_add_subdirectory() by a top-level CMakeLists.txt)
      #   must
      #   1. Find the dependent package by cake_find_package(<dep-pack> ...)
      #   2. Use a single target_link_libraries(<my-target> <dep-pack> ...) to link to the package.
      #   The <dep-pack> will be either an import library provided by the config-module or an actual
      #   library target if that package is used within the top-level project.

      # so here we have nothing to do
      # - the package has already been cloned and added as a subdirectory
      # - its build will be triggered by CMake before building the project that called this cake_find_package()
      # - its build settings (include dirs, libs) will be found by specifying its a target with target_link_libraries()
      #   so no need to call find_package()
    else()

      cake_pkg(INSTALL URL ${CAKE_FP_URL})

      find_package(${CAKE_FP_ARGS})

    endif()

  endmacro()
  
endif()

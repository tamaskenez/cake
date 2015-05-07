#.rst:
# CakeLoadConfig
# --------------
#
# Loads the Cake configuration variables from the shell environment or configuration file. You don't need
# call this macro directly, it's called automatically whenever it's needed.
# This file is provided here to document the Cake configuration variables and also the usage of the
# `CAKE_PKG_URL_OF*` variables and `cake_pkg_depends()` which describe additional (optional) information
# about the location of the packages and their dependencies.
#
# ::
#
#   CAKE_LOAD_CONFIG()
#
# This command (called automatically) loads the configuration variables from shell environment variables. See below the list of variables.
# 
# If the ``CAKE_CONFIG_FILE`` environment variable is set then that file will also be included. The script usually contains
# simple CMake `set()` commands to set the configuration variables, like ``set(CAKE_CMAKE_ARGS -GXcode)``
#
# You can also set the configuration variables in your CMakeLists.txt as plain CMake variables. Note that
# variables set this way will not be available in child `cmake` processes launched by ``cake_pkg(INSTALL ...)`` while
# variables from the environment and set in the config file will be.
#
# The CAKE_LOAD_CONFIG macro also ensures the correct priority between variables set in the environment, set in the config file and
# set in in the CMakeLists.txt:
#
# - plain CMake variables have the highest priority
# - variables set in the environment have the next highest priority
# - variables set in the config file have the lowest priority
#
# In the config file, besides the Cake configuration variables you can also
#
# - define URLs for package names by setting ``CAKE_PKG_URL_OF_<name>`` variables:
# - define scripts for packages which install the dependencies of the package (see `CakePkgDepends.cmake`).
#
# You can add the calls directly to your Cake config file, or (better) create separate files which you
# include in the config file.
#
# Example ``CAKE_PKG_URL_OF_<name>`` commands:
# Instead of installing zlib and png with
#
#    cake_pkg(INSTALL URL https://github.com/madler/zlib.git)
#    cake_pkg(INSTALL URL git://git.code.sf.net/p/libpng/code)
#
# You can create a file which contains the URL of all the packages you need. The URLs
# must be assigned to variables named according to this pattern: ``CAKE_PKG_URL_OF_<name>``
# where <name> is the find-package name (identical case, not upper-case!)
#
#    set(CAKE_PKG_URL_OF_ZLIB git://git.code.sf.net/p/libpng/code)
#    set(CAKE_PKG_URL_OF_PNG https://github.com/madler/zlib.git)
#    set(CAKE_PKG_URL_OF_Boost ...) # must be the same case
#
# You can include this file in the Cake config file and it will be effective in all
# ``cmake`` processes launched during the configuration of your project (``cake_pkg(INSTALL )``
# launches child ``cmake`` processes.)
#
# After setting the variables above you can simply write:
#
#    cake_pkg(INSTALL NAME ZLIB)
#    cake_pkg(INSTALL NAME PNG)
#
# The Cake configuration variables
# ================================
#
# They can be set in the environment or in the Cake configuration file:
#
# ``CAKE_CMAKE_ARGS``
#   Options passed to ``cmake`` by the ``cake`` command-line tool when performing CMake generate/configuration phase
# ``CAKE_BINARY_DIR_PREFIX``
#   The automatically generated CMAKE_BINARY_DIR will be created in this directory.
#   Used by the ``cake`` command line tool for creating and finding the binary dir corresponding to the given source dir.
# ``CAKE_CMAKE_NATIVE_TOOL_ARGS``
#   These option will be passed to the ``cmake --build`` command by the ``cake`` command for CMake building phase
# ``CAKE_PKG_CONFIGURATION_TYPES``
#   Used by the ``cake pkg`` command: the packages will be installed for these configuration types (Debug, Relese, ...)
#   Default: Release
# ``CAKE_PKG_CMAKE_ARGS``
#   Like CAKE_CMAKE_ARGS but used for installing packages
# ``CAKE_PKG_CMAKE_NATIVE_TOOL_ARGS``
#   Like CAKE_CMAKE_NATIVE_TOOL_ARGS but used for installing packages
# ``CAKE_PKG_CLONE_DEPTH``
#   For the ``cake_pkg(INSTALL|CLONE ...)`` commands this variable controls the depth parameter
#   of the ``git clone --depth <d>`` command.
#   Set to zero to clone at unlimited depth. If undefined or set to ``""`` the default behaviour will be used, which is to
#   - clone at unlimited depth when the DESTINATION parameter is set (for example, when `cake_add_subdirectory`
#     calls ``cake_PKG(CLONE ...)``.
#   - clone with ``--depth=1`` when the DESTINATION parameter is not given

if(NOT CAKE_LOAD_CONFIG_INCLUDED)
  set(CAKE_LOAD_CONFIG_INCLUDED 1)

  include(CMakePrintHelpers)

  if(NOT CAKE_PRIVATE_UTILS_INCLUDED)
    include(${CMAKE_CURRENT_LIST_DIR}/private/CakePrivateUtils.cmake)
  endif()

  if(NOT CAKE_PKG_DEPENDS_INCLUDED)
    include(${CMAKE_CURRENT_LIST_DIR}/CakePkgDepends.cmake)
  endif()

  unset(CAKE_LOAD_CONFIG_DONE)

  set(CAKE_CONFIG_VARS
    CAKE_BINARY_DIR_PREFIX
    CAKE_CMAKE_ARGS
    CAKE_CMAKE_NATIVE_TOOL_ARGS
    CAKE_PKG_CONFIGURATION_TYPES
    CAKE_PKG_CMAKE_ARGS
    CAKE_PKG_CMAKE_NATIVE_TOOL_ARGS
    CAKE_PKG_CLONE_DEPTH
    )

  # run-once code after the definitions

  # - save the config vars defined currently
  # - include the config file
  # - restore the saved vars
  # That way the currently set config vars will not be overwritten
  macro(_cake_stash_config_vars)
    set(CAKE_STASHED_CONFIG_VARS "") # contains the list of vars defined now
    foreach(_v ${CAKE_CONFIG_VARS})
      if(DEFINED ${_v})
        list(APPEND CAKE_STASHED_CONFIG_VARS ${_v})
      endif()
    endforeach()

    # save the variables
    foreach(_v ${_l})
      set(CAKE_STASHED_CONFIG_VAR_${_v} "${${_v}}")
    endforeach()
  endmacro()

  macro(_cake_restore_stashed_config_vars)
    # restore what was stashed
    foreach(_v ${CAKE_STASHED_CONFIG_VARS})
      set(${_v} "${CAKE_STASHED_CONFIG_VAR_${_v}}")
      unset(CAKE_STASHED_CONFIG_VAR_${_v})
    endforeach()
endmacro()

  macro(cake_load_config)

    set(CAKE_LOAD_CONFIG_DONE 0)

    include(${CAKE_ROOT}/cake-depends-db.cmake)

    _cake_stash_config_vars()

    if(NOT "$ENV{CAKE_CONFIG_FILE}" STREQUAL "")
      if(NOT IS_ABSOLUTE "$ENV{CAKE_CONFIG_FILE}")
        message(FATAL_ERROR "[cake] CAKE_CONFIG_FILE ($ENV{CAKE_CONFIG_FILE}) must be an absolute path")
      endif()
      cake_message(STATUS "Loading Cake configuration from $ENV{CAKE_CONFIG_FILE}")
      include("$ENV{CAKE_CONFIG_FILE}")
    endif()

    # load from env var
    if(NOT WIN32 OR DEFINED ENV{MSYSTEM})
      set(_cake_system UNIX)
    else()
      set(_cake_system WINDOWS)
    endif()
    foreach(_v ${CAKE_CONFIG_VARS} )
      if(DEFINED ENV{${_v}})
        separate_arguments(${_v} ${_cake_system}_COMMAND "$ENV{${_v}}")
      endif()
    endforeach()

    _cake_restore_stashed_config_vars()

    if(0)
      foreach(i ${CAKE_CONFIG_VARS})
        if(NOT DEFINED ${i})
          message(STATUS "${i} is not defined")
        elseif("${i}" STREQUAL "")
          message(STATUS "${i} is empty")
        else()
          cmake_print_variables(${i})
        endif()
      endforeach()
    endif()
    
    set(CAKE_LOAD_CONFIG_DONE 1)

  endmacro()

  # extracts a definition (-D<...> or -D <...>) from a (cmake) command line, e.g.:
  # argslist could be the options for cmake like ... -DCMAKE_PREFIX_PATH=foo/bar ...
  # define could be CMAKE_PREFIX_PATH
  # then this function returns foo/bar in the variable ${var_out}
  function(_cake_extract_define_from_command_line argslist defname var_out)
    set(prev_was_dash_D 0)
    set(result "")
    foreach(i ${argslist})
      if("${i}" MATCHES "^-D${defname}(:[^=]*)?=(.*)$")
        set(result ${CMAKE_MATCH_2})
      elseif(prev_was_dash_D AND ("${i}" MATCHES "^${defname}(:[^=]*)?=(.*)$"))
        set(result ${CMAKE_MATCH_2})
      endif()
      if(NOT "${v}" STREQUAL "")
        break()
      endif()
      if("${i}" STREQUAL "-D")
        set(prev_was_dash_D 1)
      else()
        set(prev_was_dash_D 0)
      endif()
    endforeach()
    set(${var_out} "${result}" PARENT_SCOPE)
  endfunction()

  macro(_cake_get_pkg_configuration_types)
    if(DEFINED CAKE_PKG_CONFIGURATION_TYPES AND CAKE_PKG_CONFIGURATION_TYPES)
      set(ans "${CAKE_PKG_CONFIGURATION_TYPES}")
    else()
      set(ans Release) # default value
    endif()
  endmacro()

  # mode must be EXTERN or SUBDIR
  macro(_cake_get_clone_depth mode)
    if("${CAKE_PKG_CLONE_DEPTH}" STREQUAL "")
      if("${mode}" STREQUAL "EXTERN")
        set(ans 1)
      elseif("${mode}" STREQUAL "SUBDIR")
        set(ans 0)
      else()
        message(FATAL_ERROR "[cake] Internal error in _cake_get_clone_depth, mode is ${mode}.")
      endif()
    else()
      set(ans "${CAKE_PKG_CLONE_DEPTH}")
    endif()
  endmacro()

  # run-once code
  cake_load_config()

  # extract CMAKE_INSTALL_PREFIX from CAKE_PKG_CMAKE_ARGS
  unset(CAKE_PKG_INSTALL_PREFIX)
  _cake_extract_define_from_command_line("${CAKE_PKG_CMAKE_ARGS}" CMAKE_INSTALL_PREFIX CAKE_PKG_INSTALL_PREFIX)

  if(NOT CAKE_PKG_INSTALL_PREFIX)
    set(CAKE_PKG_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}") # try to use the default value
  endif()

  # need a valid CAKE_PKG_INSTALL_PREFIX except if in script mode
  if(CMAKE_HOME_DIRECTORY AND NOT CAKE_PKG_INSTALL_PREFIX)
    message(FATAL_ERROR "[cake] Missing CMAKE_INSTALL_PREFIX: define it in CAKE_PKG_CMAKE_ARGS")
  endif()

endif()

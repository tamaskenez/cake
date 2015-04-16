#.rst:
# CakeLoadConfig
# -----------
#
# Loads the Cake configuration variables from the shell environment or configuration file. You don't need
# call this macro directly. This help is provided to document the Cake configuration variables.
#
# ::
#
#   CAKE_LOAD_CONFIG()
#
# CAKE_LOAD_CONFIG sets the Cake configuration variables from the shell environment or from an optional config file:
#
# If ``CAKE_CONFIG_FILE`` environment variable is set then this file will be included. The script usually contains
#   simple CMake `set()` commands to set the configuration variables, like ``set(CAKE_CMAKE_OPTIONS -GXcode)``
#
# If a configuration variables is already defined as a CMake variable it will not be overwritten.
# The environment variables have the next higher precedence then the Cake config file.
#
#
# The Cake configuration variables (can be set in the environment or in the Cake configuration file):
#
# ``CAKE_CMAKE_OPTIONS``
#   Options passed to ``cmake`` by the ``cake`` command-line tool when performing CMake generate/configuration phase
# ``CAKE_BINARY_DIR_PREFIX``
#   The automatically generated CMAKE_BINARY_DIR will be created in this directory.
#   Used by the ``cake`` command line tool for creating and finding the binary dir corresponding to the given source dir.
# ``CAKE_CMAKE_NATIVE_TOOL_OPTIONS``
#   These option will be passed to the ``cmake --build`` command by the ``cake`` command for CMake building phase
# ``CAKE_PKG_CONFIGURATION_TYPES``
#   Used by the ``cake pkg`` command: the packages will be installed for these configuration types (Debug, Relese, ...)
#   Default: Release
# ``CAKE_PKG_CMAKE_OPTIONS``
#   Like CAKE_CMAKE_OPTIONS but used for installing packages
# ``CAKE_PKG_CMAKE_NATIVE_TOOL_OPTIONS``
#   Like CAKE_CMAKE_NATIVE_TOOL_OPTIONS but used for installing packages

if(NOT CAKE_LOAD_CONFIG_INCLUDED)
  set(CAKE_LOAD_CONFIG_INCLUDED 1)

  include(CMakePrintHelpers)

  if(NOT CAKE_PRIVATE_UTILS_INCLUDED)
    include(${CMAKE_CURRENT_LIST_DIR}/CakePrivateUtils.cmake)
  endif()

  unset(CAKE_LOAD_CONFIG_DONE)

  set(CAKE_ENV_VARS
    CAKE_BINARY_DIR_PREFIX
    CAKE_CMAKE_OPTIONS
    CAKE_CMAKE_NATIVE_TOOL_OPTIONS
    CAKE_PKG_CONFIGURATION_TYPES
    CAKE_PKG_CMAKE_OPTIONS
    CAKE_PKG_CMAKE_NATIVE_TOOL_OPTIONS
    )

  # run-once code after the definitions

  function(_cake_load_config_file)
    set(l "") # contains the list of vars defined now
    foreach(v ${CAKE_ENV_VARS})
      if(DEFINED ${v})
        list(APPEND l ${v})
      endif()
    endforeach()
    include("$ENV{CAKE_CONFIG_FILE}")
    foreach(v ${CAKE_ENV_VARS})
      list(FIND l ${v} r)
      if(r EQUAL -1 AND DEFINED ${v}) # was not defined but it is now
        set(${v} "${${v}}" PARENT_SCOPE)
      endif()
    endforeach()
  endfunction()

  macro(cake_load_config)

    set(CAKE_LOAD_CONFIG_DONE 0)

    if(NOT WIN32 OR DEFINED ENV{MSYSTEM})
      set(_cake_s UNIX)
    else()
      set(_cake_s WINDOWS)
    endif()

    # load from env var which is not defined here
    foreach(_cake_v ${CAKE_ENV_VARS} )
      if(NOT DEFINED ${_cake_v} AND DEFINED ENV{${_cake_v}})
        separate_arguments(${_cake_v} ${_cake_s}_COMMAND "$ENV{${_cake_v}}")
      endif()
    endforeach()


    if(NOT "$ENV{CAKE_CONFIG_FILE}" STREQUAL "")
      if(NOT IS_ABSOLUTE "$ENV{CAKE_CONFIG_FILE}")
        message(FATAL_ERROR "[cake] CAKE_CONFIG_FILE ($ENV{CAKE_CONFIG_FILE}) must be an absolute path")
      endif()
      cake_message(STATUS "Loading Cake configuration from $ENV{CAKE_CONFIG_FILE}")
      _cake_load_config_file()
    endif()

    # set default values
    if("${CAKE_PKG_CONFIGURATION_TYPES}" STREQUAL "")
      set(CAKE_PKG_CONFIGURATION_TYPES Release)
    endif()

    if(0)
      foreach(i ${CAKE_ENV_VARS})
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

  # run-once code
  cake_load_config()

  # extract CMAKE_INSTALL_PREFIX from CAKE_PKG_CMAKE_OPTIONS
  unset(CAKE_PKG_INSTALL_PREFIX)
  _cake_extract_define_from_command_line("${CAKE_PKG_CMAKE_OPTIONS}" CMAKE_INSTALL_PREFIX CAKE_PKG_INSTALL_PREFIX)

  if(NOT CAKE_PKG_INSTALL_PREFIX)
    set(CAKE_PKG_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}") # try to use the default value
  endif()

  # need a valid CAKE_PKG_INSTALL_PREFIX except if in script mode
  if(CMAKE_HOME_DIRECTORY AND NOT CAKE_PKG_INSTALL_PREFIX)
    message(FATAL_ERROR "[cake] Missing CMAKE_INSTALL_PREFIX: define it in CAKE_PKG_CMAKE_OPTIONS")
  endif()

endif()

if(NOT CAKE_PROJECT_INCLUDED)
  set(CAKE_PROJECT_INCLUDED 1)

  if(NOT CAKE_PRIVATE_UTILS_INCLUDED)
    include(${CAKE_ROOT}/Modules/private/CakePrivateUtils.cmake)
  endif()

  set(_CAKE_PROJECT_VARS
    CMAKE_GENERATOR CMAKE_GENERATOR_TOOLSET CMAKE_GENERATOR_PLATFORM 
    CMAKE_INSTALL_PREFIX CMAKE_PREFIX_PATH
    CMAKE_ARGS CMAKE_NATIVE_TOOL_ARGS
    CAKE_BINARY_DIR_PREFIX
    CAKE_PKG_CONFIGURATION_TYPES
    CAKE_PKG_PROJECT_DIR
    CAKE_PKG_CLONE_DIR
    CAKE_PKG_REGISTRIES
    CAKE_PKG_CLONE_DEPTH
    )

  # run-once code after the definitions

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

  set(_CAKE_PROJECT_FILE_NAME "cake-project.cmake")
  set(_CAKE_LOCAL_PROJECT_FILE_NAME "cake-project-local.cmake")

  macro(_cake_determine_project_dir)
    if(CAKE_PROJECT_DIR)
      # make sure it's cached
        set(CAKE_PROJECT_DIR "${CAKE_PROJECT_DIR}" CACHE INTERNAL "" FORCE)
    else()
      # 1. try environment
      file(TO_CMAKE_PATH "$ENV{CAKE_PROJECT_DIR}" _ENV_CAKE_PROJECT_DIR)
      if(IS_DIRECTORY "${_ENV_CAKE_PROJECT_DIR}")
        set(CAKE_PROJECT_DIR "${_ENV_CAKE_PROJECT_DIR}" CACHE INTERNAL "" FORCE)
      else()
        # 2. try current dir and above (script mode) or CMAKE_HOME_DIRECTORY (configure mode)
        if(CMAKE_SCRIPT_MODE_FILE)
          if(NOT CAKE_CURRENT_DIRECTORY)
            message(FATAL_ERROR "[cake] Internal error: CAKE_CURRENT_DIRECTORY is not set.")
          endif()
          set(CMAKE_PROJECT_DIR "${CAKE_CURRENT_DIRECTORY}")
        else()
          set(CMAKE_PROJECT_DIR "${CMAKE_HOME_DIRECTORY}")
        endif()
        while(1)
          if(EXISTS "${CMAKE_PROJECT_DIR}/${_CAKE_PROJECT_FILE_NAME}")
            break()
          endif()
          set(_cake_prev_project_dir "${CAKE_PROJECT_DIR}")
          string(REGEX_REPLACE "/[^/]*$" "" CAKE_PROJECT_DIR "${CAKE_PROJECT_DIR}")
          if(CAKE_PROJECT_DIR STREQUAL _cake_prev_project_dir)
            set(CAKE_PROJECT_DIR "")
            break()
          endif()
        endwhile()
        set(CAKE_PROJECT_DIR "${CAKE_PROJECT_DIR}" CACHE INTERNAL "" FORCE)
      endif()
      if(NOT CAKE_PROJECT_DIR)
        if(CMAKE_SCRIPT_MODE_FILE)
          message(FATAL_ERROR "[cake] Can't locate ${_CAKE_PROJECT_FILE_NAME}, either run from or below a directory that contains it or set the CAKE_PROJECT_DIR environment or CMake variable to an existing directory.")
        else()
          message(FATAL_ERROR "[cake] Can't locate ${_CAKE_PROJECT_FILE_NAME}, either create one in or above the top-level of the source tree or set the CAKE_PROJECT_DIR environment or CMake variable to an existing directory.")
        endif()
      endif()
    endif()
  endmacro()

  macro(_cake_ps_try_set var_name var_value)
    if(${var_name})
      if(NOT "${${var_name}}" STREQUAL "${var_value}")
        message(FATAL_ERROR "[cake] Can't set project variable ${var_name} to ${var_value} because it's already set to ${${var_name}}. Possible reason: the same variable is set both as a standalone variable and as a CMAKE_ARGS option (e.g. CMAKE_GENERATOR and -G).")
      endif()
    else()
      set(${var_name} "${var_value}")
    endif()
  endmacro()

  macro(_cake_set_project_var var_name var_value)
    set(CAKE_PROJECT_VAR_${var_name} "${var_value}" CACHE INTERNAL "" FORCE)
  endmacro()

  macro(_cake_get_project_var mode var_name)

    set(ans "${CAKE_PROJECT_VAR_${var_name}}")
    
    if("x${mode}x" STREQUAL "xEFFECTIVEx")
      if(ans STREQUAL "")
        if("x${var_name}x" STREQUAL "xCMAKE_INSTALL_PREFIXx")
          set(ans "${CAKE_PROJECT_DIR}/install")
        elseif("x${var_name}x" STREQUAL "xCMAKE_PREFIX_PATHx")
          set(ans "${CAKE_PROJECT_DIR}/install")
        elseif("x${var_name}x" STREQUAL "xCAKE_PKG_CONFIGURATION_TYPESx")
          set(ans Debug Release)
        elseif("x${var_name}x" STREQUAL "xCAKE_PKG_CLONE_DIRx")
          set(ans "${CAKE_PROJECT_DIR}/clone")
        elseif("x${var_name}x" STREQUAL "xCAKE_BINARY_DIR_PREFIXx")
          set(ans "${CAKE_PROJECT_DIR}/build")
        endif()
      endif()
    elseif("x${mode}x" STREQUAL "xRAWx")
      # nothing to do
    else()
      message(FATAL_ERROR "[cake] Internal error, _cake_get_project_var: mode is ${mode}")
    endif()

  endmacro()

  function(_cake_load_project_settings)
    # at this point CAKE_PROJECT_DIR is set
    # load the optional project file and the optional local project file

    # clear the project setting variables for this function scope
    foreach(i ${_CAKE_PROJECT_VARS})
      set(${i} "")
    endforeach()

    if(EXISTS "${CAKE_PROJECT_DIR}/${_CAKE_PROJECT_FILE_NAME}")
      message(STATUS "[cake] Loading ${CAKE_PROJECT_DIR}/${_CAKE_PROJECT_FILE_NAME}")
      include("${CAKE_PROJECT_DIR}/${_CAKE_PROJECT_FILE_NAME}")
    endif()
    if(EXISTS "${CAKE_PROJECT_DIR}/${_CAKE_LOCAL_PROJECT_FILE_NAME}")
      message(STATUS "[cake] Loading ${CAKE_PROJECT_DIR}/${_CAKE_LOCAL_PROJECT_FILE_NAME}")
      include("${CAKE_PROJECT_DIR}/${_CAKE_LOCAL_PROJECT_FILE_NAME}")
    endif()

    # move CMAKE_GENERATOR CMAKE_GENERATOR_TOOLSET CMAKE_GENERATOR_PLATFORM 
    # CMAKE_INSTALL_PREFIX CMAKE_PREFIX_PATH options from CMAKE_ARGS
    # to standalone variables

    # concatenate args given in separate list items ("-G;Xcode" -> "-GXcode")
    string(REGEX REPLACE "(^|;)-([CDUGTA]);([^-])" "\\1-\\2\\3" CMAKE_ARGS "${CMAKE_ARGS}")
    set(CMAKE_ARGS2 "")
    foreach(i ${CMAKE_ARGS})
      string(REPLACE ";" "\;" i "${i}") # restore nested lists
      if(i MATCHES "^-G(.*)$")
        _cake_ps_try_set(CMAKE_GENERATOR "${CMAKE_MATCH_1}")
      elseif(i MATCHES "^-T(.*)$")
        _cake_ps_try_set(CMAKE_GENERATOR_TOOLSET "${CMAKE_MATCH_1}")
      elseif(i MATCHES "^-A(.*)$")
        _cake_ps_try_set(CMAKE_GENERATOR_PLATFORM "${CMAKE_MATCH_1}")
      elseif(i MATCHES "^-DCMAKE_PREFIX_PATH(:[^=]*)?=(.*)$")
        _cake_ps_try_set(CMAKE_PREFIX_PATH "${CMAKE_MATCH_2}")
      elseif(i MATCHES "^-DCMAKE_INSTALL_PREFIX(:[^=]*)?=(.*)$")
        _cake_ps_try_set(CMAKE_INSTALL_PREFIX "${CMAKE_MATCH_2}")
      else()
        list(APPEND CMAKE_ARGS2 "${i}")
      endif()
    endforeach()
    set(CMAKE_ARGS "${CMAKE_ARGS2}")

    foreach(i ${_CAKE_PROJECT_VARS})
      _cake_set_project_var(${i} "${${i}}")
    endforeach()

    _cake_get_project_var(EFFECTIVE CAKE_BINARY_DIR_PREFIX)
    set(CAKE_PKG_BUILD_DIR ${ans})

  endfunction()

  # run-once code
  _cake_determine_project_dir()
  message(STATUS "[cake] CAKE_PROJECT_DIR: ${CAKE_PROJECT_DIR}")
  _cake_load_project_settings()

endif()

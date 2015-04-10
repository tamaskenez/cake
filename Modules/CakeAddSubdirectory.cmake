#.rst:
# CakeAddSubdirectory
# ---------------
#
# Convenience function that fetches the package (with `cake_pkg()`) into the specified directory
# then calls `add_subdirectory()`.
#
# ::
#
#   CAKE_ADD_SUBDIRECTORY(<source-dir> [<binary-dir>]
#                         [EXCLUDE_FROM_ALL]
#                         URL <repo-url>)
# 
# CAKE_ADD_SUBDIRECTORY first calls `cake_pkg(CLONE ...)` to clone the package repo to <source-dir>
# then calls `add_subdirectory` with the remainder of the parameters.

if(NOT CAKE_ADD_SUBDIRECTORY_INCLUDED)
  
  set(CAKE_ADD_SUBDIRECTORY_INCLUDED 1)

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

  macro(cake_add_subdirectory CAKE_ASD_ARG_SOURCEDIR)

    if(NOT IS_ABSOLUTE "${CAKE_ASD_ARG_SOURCEDIR}")
      get_filename_component(CAKE_ASD_ARG_SOURCEDIR_ABS "${CMAKE_CURRENT_LIST_DIR}/${CAKE_ASD_ARG_SOURCEDIR}" ABSOLUTE)
    else()
      set(CAKE_ASD_ARG_SOURCEDIR_ABS "${CAKE_ASD_ARG_SOURCEDIR}")
    endif()

    cmake_parse_arguments(CAKE_ASD "EXCLUDE_FROM_ALL" "URL" "" ${ARGN})

    set(_cake_asd_add_subdirectory_args "${CAKE_ASD_ARG_SOURCEDIR}")

    list(LENGTH CAKE_ASD_UNPARSED_ARGUMENTS _cake_l)
    if(_cake_l EQUAL 1)
      list(APPEND _cake_asd_add_subdirectory_args "${CAKE_ASD_UNPARSED_ARGUMENTS}") #add binary dir
    elseif(_cake_l GREATER 1)
      message(FATAL_ERROR "[cake] Invalid arguments.")
    endif()

    if(CAKE_ASD_EXCLUDE_FROM_ALL)
      list(APPEND _cake_asd_add_subdirectory_args EXCLUDE_FROM_ALL)
    endif()

    if(NOT CAKE_ASD_URL)
      message(FATAL_ERROR "[cake] Missing URL.")
    endif()

    cake_parse_pkg_url(${CAKE_ASD_URL} _cake_repo_url _cake_repo_cid _ _cake_asd_definitions)

    if(CAKE_PKG_${_cake_repo_cid}_ADDED_AS_SUBDIRECTORY)
      message(FATAL_ERROR "[cake] Package ${_cake_repo_url} already added as subdirectory")
    endif()

    if(CAKE_PKG_${_cake_repo_cid}_LOCAL_REPO_DIR)
      message(FATAL_ERROR "[cake] Package ${_cake_repo_url} already added as external package (with cake_find_package()). "
        "Solution: move this cake_add_subdirectory() call before the cake_find_package() or cake_add_subdirectory() "
        "command of the package that needs this package.")
    endif()

    cake_set_session_var(CAKE_PKG_${_cake_repo_cid}_ADDED_AS_SUBDIRECTORY 1)

    cake_pkg(CLONE URL "${CAKE_ASD_URL}" DESTINATION "${CAKE_ASD_ARG_SOURCEDIR_ABS}")

    # execute the repo's cake-depends.cmake script, if exists
    # also try to execute the hardcoded dependency script from cake-depends-db*.cmake

    # find dependencies:
    # - try to run the repo's cake-depends.cmake
    # - if no cake-depends.cmake consult the cake pkg db and run that script if found
    set(_cake_depends_cmake_file "${CAKE_ASD_ARG_SOURCEDIR_ABS}/cake-depends.cmake")
    set(_case_asd_randomfile "")
    if(NOT EXISTS "${_cake_depends_cmake_file}" AND DEFINED CAKE_DEPENDS_DB_${_cake_repo_cid})
      string(RANDOM _case_asd_randomfile)
      set(_case_asd_randomfile "${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_tmp/${_case_asd_randomfile}")
      file(WRITE "${_case_asd_randomfile}" "${CAKE_DEPENDS_DB_${_cake_repo_cid}}")
      set(_cake_depends_cmake_file "${_case_asd_randomfile}")
    endif()

    if(EXISTS "${_cake_depends_cmake_file}")
      set(CAKE_DEFINITIONS ${_cake_asd_definitions})
      # _call_cake_depends executes either the cake-depends.script or
      # or the script defined in the cake-depends-db*.cmake
      # The script usually contains cake_pkg(INSTALL ...) calls which
      # fetch and install dependencies
      _call_cake_depends("${_cake_depends_cmake_file}")
    endif()

    if(_case_asd_randomfile)
      file(REMOVE "${_case_asd_randomfile}")
    endif()

    add_subdirectory(${_cake_asd_add_subdirectory_args})

  endmacro()
endif()

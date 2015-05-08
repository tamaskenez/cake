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
#                         NAME <pkg-name> | URL <repo-url>
#                         [GROUP <group>])
# 
# CAKE_ADD_SUBDIRECTORY first calls `cake_pkg(CLONE ...)` to clone the package repo to <source-dir>
# then calls `add_subdirectory` with the remainder of the parameters.
#
# ``<group>`` can be used to group packages, defaults to ``${PROJECT_NAME}``.
#
# For the description of the `NAME` and `URL` options see `CakePkg()`.

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
    include(${CMAKE_CURRENT_LIST_DIR}/private/CakePrivateUtils.cmake)
  endif()

  function(cake_add_subdirectory ARG_SOURCEDIR)

    if(IS_ABSOLUTE "${ARG_SOURCEDIR}")
      set(ARG_SOURCEDIR_ABS "${ARG_SOURCEDIR}")
    else()
      get_filename_component(ARG_SOURCEDIR_ABS "${CMAKE_CURRENT_SOURCE_DIR}/${ARG_SOURCEDIR}" ABSOLUTE)
    endif()

    cmake_parse_arguments(ARG "EXCLUDE_FROM_ALL" "URL;NAME;GROUP" "" ${ARGN})

    set(add_subdir_args "${ARG_SOURCEDIR}")

    list(LENGTH ARG_UNPARSED_ARGUMENTS len)
    if(len EQUAL 1)
      list(APPEND add_subdir_args "${ARG_UNPARSED_ARGUMENTS}") #add binary dir
    elseif(len GREATER 1)
      message(FATAL_ERROR "[cake] Invalid arguments.")
    endif()

    if(ARG_EXCLUDE_FROM_ALL)
      list(APPEND add_subdir_args EXCLUDE_FROM_ALL)
    endif()

    set(opts "")
    if(ARG_URL)
      list(APPEND opts URL "${ARG_URL}")
    endif()

    if(ARG_NAME)
      list(APPEND opts NAME "${ARG_NAME}")
    endif()

    if(NOT opts)
        message(FATAL_ERROR "[cake_add_subdirectory] Either URL or NAME must be specified.")
    endif()

    if(ARG_GROUP)
      list(APPEND opts GROUP "${ARG_GROUP}")
    else()
      list(APPEND opts GROUP "${PROJECT_NAME}")
    endif()

    cake_pkg(CLONE ${opts} DESTINATION "${ARG_SOURCEDIR_ABS}" PK_OUT pk)

    if(NOT pk)
      message(FATAL_ERROR "[cake_add_subdirectory] Internal error: package just cloned not found in repo_db.")
    endif()

    cake_repo_db_get_field_by_pk(cid "${pk}")
    set(cid "${ans}")
    cake_repo_db_get_field_by_pk(name "${pk}")
    set(name "${ans}")
    cake_repo_db_get_field_by_pk(definitions "${pk}")
    set(definitions "${ans}")

    cake_set_session_var(CAKE_PKG_${cid}_ADDED_AS_SUBDIRECTORY 1)

    # execute the repo's cake-pkg-depends.cmake script, if exists
    # otherwise try to execute the dependency script in CAKE_PKG_DEPENDS_<name> or CAKE_PKG_DEPENDS_<cid>
    _cake_include_cake_pkg_depends(
      "${ARG_SOURCEDIR_ABS}/cake-pkg-depends.cmake"
      "${cid}" "${name}" "${definitions}")

    add_subdirectory(${add_subdir_args})

  endfunction()
endif()

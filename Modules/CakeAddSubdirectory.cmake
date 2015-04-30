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
#                         NAME <pkg-name> | URL <repo-url>)
# 
# CAKE_ADD_SUBDIRECTORY first calls `cake_pkg(CLONE ...)` to clone the package repo to <source-dir>
# then calls `add_subdirectory` with the remainder of the parameters.
#
# For the description of the `NAME` and `URL` options please see `CakePkg()`.
#

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

  function(cake_add_subdirectory ARG_SOURCEDIR)

    if(IS_ABSOLUTE "${ARG_SOURCEDIR}")
      set(ARG_SOURCEDIR_ABS "${ARG_SOURCEDIR}")
    else()
      get_filename_component(ARG_SOURCEDIR_ABS "${CMAKE_CURRENT_SOURCE_DIR}/${ARG_SOURCEDIR}" ABSOLUTE)
    endif()

    cmake_parse_arguments(ARG "EXCLUDE_FROM_ALL" "URL;NAME" "" ${ARGN})

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

    set(url_and_name_opts "")
    if(ARG_URL)
      list(APPEND url_and_name_opts URL "${ARG_URL}")
    endif()

    if(ARG_NAME)
      list(APPEND url_and_name_opts NAME "${ARG_NAME}")
    endif()

    if(NOT url_and_name_opts)
        message(FATAL_ERROR "[cake_add_subdirectory] Either URL or NAME must be specified.")
    endif()


    cake_pkg(CLONE URL "${ARG_URL}" DESTINATION "${ARG_SOURCEDIR_ABS}")

    # retrieve the cid and definitions of this package, either by NAME or URL
    set(pk "")
    if(ARG_NAME)
      cake_repo_db_get_pk_by_field(name "${ARG_NAME}")
      set(pk "${ans}")
    endif()
    if(NOT pk)
      cake_parse_pkg_url(${ARG_URL} _ repo_cid _ _)
      cake_repo_db_get_pk_by_field(cid "${repo_cid}")
      set(pk "${ans}")
    endif()

    if(NOT pk)
      message(FATAL_ERROR "[cake_add_subdirectory] Internal error: package just cloned not found in repo_db.")
    endif()

    cake_repo_db_get_field_by_pk(repo_cid "${pk}")
    set(repo_cid "${ans}")
    cake_repo_db_get_field_by_pk(definitions "${pk}")
    set(definitions "${ans}")

    # execute the repo's cake-depends.cmake script, if exists
    # otherwise try to execute the hardcoded dependency script from cake-depends-db*.cmake

    set(cake_depends_file "${ARG_SOURCEDIR_ABS}/cake-depends.cmake")
    set(random_file "")
    if(NOT EXISTS "${cake_depends_file}" AND DEFINED CAKE_DEPENDS_DB_${repo_cid})
      string(RANDOM random_file)
      set(random_file "${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_tmp/${random_file}")
      file(WRITE "${random_file}" "${CAKE_DEPENDS_DB_${repo_cid}}")
      set(cake_depends_file "${random_file}")
    endif()

    if(EXISTS "${cake_depends_file}")
      # execute either the cake-depends.script
      # or the script defined in the cake-depends-db*.cmake
      # The script usually contains cake_pkg(INSTALL ...) calls to
      # fetch and install dependencies
      _cake_apply_definitions("${definitions}")
      include("${cake_depends_cmake_file}")
    endif()

    if(random_file)
      file(REMOVE "${random_file}")
    endif()

    add_subdirectory(${add_subdir_args})

  endfunction()
endif()

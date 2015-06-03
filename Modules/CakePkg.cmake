#.rst:
# CakePkg
# -------
#
# CAKE_PKG() performs various operations on a single package or on multiple packages.
# The operations are cloning, installation, removal and status reports.
#
# ::
#
# 1. CLONE
#
#   CAKE_PKG(CLONE
#            NAME <name> | URL <repo-url>
#            [GROUP <group>]
#            [DESTINATION <dest-dir>])
#
# The command clones the repository to the given `<dest-dir>` or to an automatic location.
# Relative `<dest-dir>` is interpreted relative to the current source directory. In script mode it must be absolute.
#
# Either ``<repo-url>`` or ``<pkg-name>`` must be given. If ``<pkg-name>`` is given
# the command looks up ``<pkg-name>`` in the Cake package registry, see `CakeRegisterPkg()`.
# If both ``<repo-url>`` and ``<pkg-name>`` are given the ``<repo-url>`` is only a hint, will be
# used only if no ``<pkg-name>`` is found in the registry.
#
# If the package of the same ``<pkg-name>`` or ``<repo-url>`` has already been cloned the
# function does nothing. Even if both the `<name>` and `<repo_url>` are specified but
# the package `<name>` has already been cloned from a different URL, the command will succeed
# without making any changes.
#
# It is an error if the existing location differs from `<dest-dir>`.
#
# If no `<dest-dir>` given the function uses the value of ``CMAKE_INSTALL_PREFIX`` set in ``CAKE_PKG_CMAKE_ARGS`` and create a directory
# under ${CMAKE_INSTALL_PREFIX}/src. The actual name of the directory will be derived from ``<repo-url>``.
# See also `CakeLoadConfig.cmake`.
#
# Usually you don't call `cake_pkg(CLONE ...)` with `DESTINATION` directly, instead you call `cake_add_subdirectory()`.
#
# ``<group>`` can be used to group packages, defaults to ``_ungrouped_``
#
# 2. INSTALL
#
#   CAKE_PKG(CLONE
#            NAME <name> | URL <repo-url>
#            [GROUP <group>]
#            [DESTINATION <dest-dir>]
#            [DEFINITIONS <definitions>...])
#
# The INSTALL signature implies a CLONE step first so everything written for CLONE applies here.
#
# After the CLONE the command attemts to install the dependencies of the cloned repository:
# - attempts to find and execute (`include`) the file ``cake-pkg-depends.cmake`` in the root of the repository
# - if the file cannot be found, attempts to look up the repository in the Cake package registry and
#   execute the code found there
#
# After executing the dependency script (if found) the commands finished by configuring and building
# the ``install`` target of the repository using the ``cmake`` command.
#
# The `<definitions>` is a list of -Dname=value strings (value is optional). The URL also may contain definitions
# (see the next section). These definitions will be passed to the dependency script and also the the ``cmake``
# configuration phase.
#
# The INSTALL phase saves the package's SHA1 commit-ids after successful builds. The next time the INSTALL
# phase checks the saved SHA and will not launch the CMake build operation for an unchanged package.
#
# About the cake environment variables controlling these operations see `cake_load_config()`
#
# Format of the ``<repo-url>``
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#
# The ``<repo-url>`` is what you would pass to ``git clone``. Optionally it can be extended with other parameters using
# the URL query format. For example:
#
#     https://github.com/me/my.git?branch=devel&-DWITH_SQLITE=1
#
# Key values starting with -D will be passed to CMake when building the package. Other options will
# be passed to git clone:
#
# - ``branch=<branch>`` -> ``git clone ... --branch <branch>``
#
# Determining dependencies from ``cake-pkg-depends.cmake``:
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#
# The root directory of the package may contain the file ``cake-pkg-depends.cmake``. This is a plain Cmake script
# which usually contains a `cake_pkg(INSTALL ...)` commands for the dependencies of the package, for example::
#
#    cake_pkg(INSTALL https://github.com/madler/zlib.git)
#
# The -D options of the ``<repo-url>`` are also passed to the ``cake-pkg-depends.cmake`` script so it
# can install the dependencies accordingly::
#
#    if(WITH_SQLITE)
#        cake_pkg(INSTALL https://github.com/myaccount/sqlite-cmake)
#    endif()
#
# Extracting dependencies from Cake package database:
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#
# Sometimes you can't add a ``cake-pkg-depends.cmake`` file to a third-party library. In this
# case you can add the dependency information by calling `cake_pkg_depends`, see CakePkgDepends.cmake.
#

include(CMakePrintHelpers)

if(NOT CAKE_PKG_INCLUDED)

  set(CAKE_PKG_INCLUDED 1)

  if(NOT CAKE_INCLUDED)
    message(FATAL_ERROR "[cake] Include Cake.cmake, don't include this file directly.")
  endif()

  include(CMakeParseArguments)
  
  if(NOT CAKE_PRIVATE_UTILS_INCLUDED)
    include(${CAKE_ROOT}/Modules/private/CakePrivateUtils.cmake)
  endif()

  if(NOT CAKE_PROJECT_INCLUDED)
    include(${CAKE_ROOT}/Modules/private/CakeProject.cmake)
  endif()

  if(NOT CAKE_PKG_REGISTRIES_INCLUDED)
    include(${CAKE_ROOT}/Modules/private/CakePkgRegistries.cmake)
  endif()

  if(NOT CAKE_URL_INCLUDED)
    include(${CAKE_ROOT}/Modules/private/CakeUrl.cmake)
  endif()

  macro(cake_list_sort_unique_keep_nested_lists listname)
    string(REPLACE "\;" "\t" ${listname} "${${listname}}")
    list(SORT ${listname})
    list(REMOVE_DUPLICATES ${listname})
    string(REPLACE "\t" "\;" ${listname} "${${listname}}")
  endmacro()

  # there is run-once code after the function definitions
  macro(_cake_apply_definitions definitions)
    foreach(i ${definitions})
      if(i MATCHES "^-D([^=]+)=(.*)$")
        set(${CMAKE_MATCH_1} "${CMAKE_MATCH_2}")
      else()
        message(FATAL_ERROR "[cake] Internal error, definition does not match regex (-DX=Y): ${i}")
      endif()
    endforeach()
  endmacro()

  # input (options) and output (branch) args are from the parent scope
  # branch will be empty if options does not list a branch parameter
  function(_cake_get_branch_from_options)
    set(branch "" PARENT_SCOPE)
    foreach(i ${options})
      if(i MATCHES "^([^=]+)=(.*)$")
        if(CMAKE_MATCH_1 STREQUAL "branch")
          set(branch "${CMAKE_MATCH_2}" PARENT_SCOPE)
          return()
        endif()
      endif()
    endforeach()
  endfunction()

  # _cake_execute_git_command_in_repo(<command-line> <work-dir> <out-var-our> [<res-var-out>])
  # command-line is a list not a string separated by spaces
  # if no res-var-out given then nonzero $? is a FATAL_ERROR
  # Specify _ for output_var_out to ignore OUTPUT_VARIABLE from execute_process
  function(_cake_execute_git_command_in_repo command_line pkg_dir output_var_out)
    cake_list_to_command_line_like_string(s "${command_line}")
    set(output_variable "")
    if(pkg_dir)
      set(wd WORKING_DIRECTORY ${pkg_dir})
      cake_message(STATUS "cd ${pkg_dir}")
    else()
      set(wd "")
    endif()
    cake_message(STATUS "git ${s}")
    if(output_var_out STREQUAL _)
      set(output_var_option "")
    else()
      set(output_var_option OUTPUT_VARIABLE output_variable OUTPUT_STRIP_TRAILING_WHITESPACE)
    endif()
    execute_process(
      COMMAND ${GIT_EXECUTABLE} ${command_line}
      ${wd}
      ${output_var_option}
      RESULT_VARIABLE result_variable)
    if(NOT ARGV3 AND result_variable)
      message(FATAL_ERROR "[cake] git command failed")
    endif()
    if(NOT output_var_out STREQUAL _)
      set(${output_var_out} "${output_variable}" PARENT_SCOPE)
    endif()
    if(ARGV3)
      set(${ARGV3} "${result_variable}" PARENT_SCOPE)
    endif()
  endfunction()


  # uses pkg_dir and branch variables from current scope
  # checks if ${branch} (if not empty) resolves to the
  # existing HEAD
  # returns result in $ans
  macro(_cake_is_repo_sha_compatible_with_requested_sha)
    set(ans 1)
    if(branch)
      # read current commit and rev-parse branch

      _cake_execute_git_command_in_repo("log;-1;--pretty=format:%H" "${pkg_dir}" repo_sha)
      _cake_execute_git_command_in_repo("rev-parse;${branch}" "${pkg_dir}" branch_sha)

      if(NOT repo_sha STREQUAL branch_sha)
        set(ans 0)
      endif()
    endif()
  endmacro()

  # uses pkg_dir and branch variables from current scope
  # checks if ${branch} (if not empty) resolves to the
  # existing HEAD
  macro(_cake_make_sure_repo_sha_compatible_with_requested_sha)
    _cake_is_repo_sha_compatible_with_requested_sha()
    if(NOT ans)
      message(FATAL_ERROR "[cake] The repository ${pkg_url} is at ${repo_sha} which differs from what is requested ${branch}. "
        "Solution: make sure all projects that specify a commit (branch or tag) for a common dependency, "
        "request the same commit.")
    endif()
  endmacro()

  include(${CAKE_ROOT}/Modules/private/CakePkgClone.cmake)

  function(cake_repo_db_get_project_title pk)
    cake_repo_db_get_field_by_pk(name "${pk}")
    if(ans)
      set(ans "${ans}" PARENT_SCOPE)
    else()
      cake_repo_db_get_field_by_pk(url "${pk}")
      cake_get_humanish_part_of_url(${ans})
      set(ans "${ans}" PARENT_SCOPE)
    endif()
  endfunction()

  # includes the file 'cake_pkg_depends_file'
  # if that doesn't exist, looks up CAKE_PKG_DEPENDS_* variables and includes those
  # also applies the variables in 'definitions'
  macro(_cake_include_cake_install_deps cake_pkg_depends_file_arg cid name definitions)
    set(_cake_pkg_depends_file "${cake_pkg_depends_file_arg}")
    set(randomfile "")
    if(NOT EXISTS "${_cake_pkg_depends_file}")
      if(NOT "${name}" STREQUAL "" AND DEFINED CAKE_PKG_REGISTRY_${name}_CODE)
        string(RANDOM LENGTH 10 randomfile)
        set(randomfile "${CAKE_PROJECT_DIR}/tmp/${name}_install_deps_code_${randomfile}")
        file(WRITE "${randomfile}" "${CAKE_PKG_REGISTRY_${name}_CODE}")
        set(_cake_pkg_depends_file "${randomfile}")
      endif()
    endif()
  
    if(EXISTS "${_cake_pkg_depends_file}")
      # execute either the cake-install-deps.script
      # or the script registered to ${name}
      # The script usually contains cake_pkg(INSTALL ...) calls to
      # fetch and install dependencies
      _cake_apply_definitions("${definitions}")
      include("${_cake_pkg_depends_file}")
    endif()

    if(randomfile)
      file(REMOVE "${randomfile}")
    endif()
  endmacro()

  function(_cake_update_last_build_time shortcid)
    _cake_get_project_var(EFFECTIVE CAKE_PKG_CONFIGURATION_TYPES)
    set(configuration_types "${ans}")

    foreach(c ${configuration_types})
      set(last_build_pars_path ${CAKE_PKG_BUILD_DIR}/${shortcid}_${c}/cake_pkg_last_build_pars.txt)
      if(EXISTS "${last_build_pars_path}")
        file(TIMESTAMP "${last_build_pars_path}" this_build_time UTC)
        if(NOT CAKE_LAST_BUILD_TIME OR (CAKE_LAST_BUILD_TIME STRLESS this_build_time))
          cake_set_session_var(CAKE_LAST_BUILD_TIME "${this_build_time}")
        endif()
      endif()
    endforeach()
  endfunction()

  include(${CAKE_ROOT}/Modules/private/CakePkgInstall.cmake)
  
# CAKE_PKG_REGISTRY_<NAME> = URL [DEFINITIONS]
# CLONE:
# - CLONE URL [DESTINATION] [NAME] [GROUP]
# - CLONE NAME [DESTINATION] [GROUP]
# INSTALL single:
# - INSTALL URL [DESTINATION] [NAME] [GROUPS] [DEFINITIONS]
# - INSTALL NAME [DESTINATION] [GROUPS] [DEFINITIONS]
# REPORT batch:
# - STATUS|DIFFLOG|COMMAND|CMDC|SHC
# REMOVE single
# - REMOVE NAME
# - LIST NAME

  function(cake_pkg ARG_C)

    set(option_args "")
    set(sv_args "")
    set(mv_args "")

    string(REPLACE "\;" "\t" argv "${ARGN}") # needed to keep nested lists

    # prepend argv with NAME if first item is not a keyword
    macro(_cake_fix_name)
      if(argv)
        set(all_args ${option_args} ${sv_args} ${mv_args})
        list(GET argv 0 head)
        list(FIND all_args "${head}" idx)
        if(idx EQUAL -1)
          # the first item in ARGN (= the second arg) is not a keyword, it musts be a NAME
          list(INSERT argv 0 "NAME")
        endif()
      endif()
    endmacro()

    if(ARG_C MATCHES "^CLONE$")
      set(sv_args URL DESTINATION NAME GROUP PK_OUT)
      _cake_fix_name()
    elseif(ARG_C MATCHES "^INSTALL$")
      set(sv_args URL DESTINATION NAME GROUP PK_OUT)
      set(mv_args DEFINITIONS)
      _cake_fix_name()
    elseif(ARG_C MATCHES "^STATUS$")
      set(mv_args "GROUPS")
    elseif(ARG_C MATCHES "^DIFFLOG$")
      set(mv_args "GROUPS")
    elseif(ARG_C MATCHES "^COMMAND|CMDC|SHC$")
      set(mv_args ${ARG_C} GROUPS)
      list(INSERT argv 0 ${ARG_C}) # put back so we can still use cmake_parse_arguments to multi-arg-parse the COMMAND|CMDC|SHC
    elseif(ARG_C MATCHES "^REMOVE$")
      _cake_fix_name()
    elseif(ARG_C MATCHES "^LIST$")
      set(mv_args "GROUPS")
      _cake_fix_name()
    elseif(ARG_C MATCHES "^REGISTER$")
      set(sv_args URL CODE NAME)
      _cake_fix_name()
    else()
      message(FATAL_ERROR "[cake] First argument must be one of these: CLONE, INSTALL, STATUS, DIFFLOG, COMMAND, CMDC, SHC, REMOVE, LIST.")
    endif()

    cmake_parse_arguments(ARG
      "${option_args}"
      "${sv_args}"
      "${mv_args}"
      "${argv}")

    # restore tabs to escpaped ;
    foreach(i URL ${sv_args} ${mv_args})
      string(REPLACE "\t" "\;" ARG_${i} "${ARG_${i}}")
    endforeach()


    if(ARG_C MATCHES "^CLONE|INSTALL$")
      # Project files may contain dynamic elements
      # that depend on CMake/environment variables that may
      # have changed since we first loaded the project settings,
      # so we re-read project settings before
      # executing the project-settings sensitive CLONE/INSTALL
      # operations.
      # Other operations depend only of CAKE_PROJECT_DIR which
      # cannot be changed on-the-fly.
      _cake_load_project_settings()
      
      if(NOT CAKE_PKG_BUILD_DIR)
        message(FATAL_ERROR "[cake] Internal error, CAKE_PKG_BUILD_DIR must not be empty.")
      endif()

      # make ARG_DESTINATION absolute
      if(ARG_DESTINATION)
        if(NOT IS_ABSOLUTE "${ARG_DESTINATION}")
          if(DEFINED CMAKE_SCRIPT_MODE_FILE)
            message(FATAL_ERROR "[cake_pkg] In script mode <destination-dir> must be absolute path.")
          else()
            get_filename_component(ARG_DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/${ARG_DESTINATION}" ABSOLUTE)
          endif()
        endif()
      else()
        _cake_get_project_var(EFFECTIVE CAKE_PKG_PROJECT_DIR)
        set(pkg_project_dir "${ans}")
        if(pkg_project_dir)
          if(NOT IS_DIRECTORY "${pkg_project_dir}")
            message(FATAL_ERROR "[cake] CAKE_PKG_PROJECT_DIR: \"${pkg_project_dir}\" does not exist.")
          endif()
          # cake_pkg INSTALL/CLONE without DESTINATION and alternative pkg_project dir defined ->
          # forward entire call to child process launched in other project dir
          message(STATUS "[cake] Execute cake_pkg in CAKE_PKG_PROJECT_DIR (\"${pkg_project_dir}\").")
          cake_save_session_vars()
          execute_process(
            COMMAND ${CMAKE_COMMAND}
              "-DCAKE_CURRENT_DIRECTORY=${pkg_project_dir}"
              "-DCAKE_PROJECT_DIR=${pkg_project_dir}"
              "-DCAKE_PKG_LOAD_THE_SESSION_VARS=${CAKE_PKG_SESSION_VARS_FILE}"
              -P "${CAKE_ROOT}/cakepkg-src/cakepkg.cmake"
              ${ARGV}
            WORKING_DIRECTORY "${pkg_project_dir}"
            RESULT_VARIABLE r)
          if(r)
            message(FATAL_ERROR "[cake] cake_pkg failed in CAKE_PKG_PROJECT_DIR (\"${pkg_project_dir}\").")
          endif()
          return()
        endif()
      endif()

      _cake_load_pkg_registries()
      if(ARG_GROUP)
        set(group "${ARG_GROUP}")
      else()
        set(group "_ungrouped_")
      endif()
      if(NOT (ARG_NAME OR ARG_URL))
        message(FATAL_ERROR "[cake_pkg] Either URL or NAME (or both) must be specified.")
      endif()
      if(ARG_PK_OUT)
        set(${ARG_PK_OUT} "" PARENT_SCOPE)
      endif()

      if(ARG_URL)
        cake_parse_pkg_url("${ARG_URL}" repo_url repo_cid repo_options repo_definitions)
      else()
        set(repo_url "")
        set(repo_cid "")
        set(repo_options "")
        set(repo_definitions "")
      endif()
      _cake_pkg_clone("${ARG_URL}" "${ARG_DESTINATION}" "${group}" "${ARG_NAME}")
      set(pk "${ans}")
      if(ARG_C MATCHES "^INSTALL$")
        set(defs "${repo_definitions}" "${ARG_DEFINITIONS}")
        _cake_pkg_install("${pk}" "${defs}")
      endif()
      if(ARG_PK_OUT)
        set(${ARG_PK_OUT} "${pk}" PARENT_SCOPE)
      endif()
    elseif(ARG_C MATCHES "^STATUS|DIFFLOG|COMMAND|CMDC|SHC|LIST$")
      # batch report
      set(command "")
      if(ARG_COMMAND)
        set(command ${ARG_COMMAND})
      elseif(ARG_CMDC)
        set(command cmd /c ${ARG_CMDC})
      elseif(ARG_SHC)
        string(REPLACE \; " " v "${ARG_SHC}")
        set(command sh -c "${v}")
      elseif(ARG_C STREQUAL "STATUS" OR ARG_C STREQUAL "DIFFLOG" OR ARG_C STREQUAL "LIST")
        # nothing to do
      else()
        message(FATAL_ERROR "[cake_pkg] internal error while assembling command")
      endif()
      string(REGEX MATCHALL "\t[0-9]+cid=" pks "${CAKE_REPO_DB}")
      string(REGEX MATCHALL "[0-9]+" pks "${pks}")
      cake_list_to_command_line_like_string(s "${command}")
      foreach(pk ${pks})
        set(needed 1)
        cake_repo_db_get_field_by_pk(group "${pk}")
        set(group "${ans}")
        if(ARG_GROUPS)
          list(FIND ARG_GROUPS "${group}" gidx)
          if(gidx LESS 0)
            set(needed 0)
          endif()
        endif()
        if(needed)
          cake_repo_db_get_field_by_pk(destination "${pk}")
          set(destination "${ans}")
          cake_repo_db_get_field_by_pk(branch "${pk}")
          set(branch "${ans}")
          cake_repo_db_get_project_title("${pk}")
          set(title "${ans}")
          if(CMAKE_SCRIPT_MODE_FILE AND CAKE_CURRENT_DIRECTORY)
            file(RELATIVE_PATH relpath "${CAKE_CURRENT_DIRECTORY}" "${destination}")
            if(relpath STREQUAL "")
              set(relpath "<current directory>")
            endif()
          else()
            set(relpath "${destination}")
          endif()
          set(header "${title}: ${relpath}")
          if(command)
            message(STATUS "cd ${destination}")
            execute_process(COMMAND ${command}
              WORKING_DIRECTORY "${destination}"
              RESULT_VARIABLE r)
            if(r)
              message(FATAL_ERROR "[cake_pkg] Result: ${r}")
            endif()
          elseif(ARG_C STREQUAL "LIST")
            cake_repo_db_get_field_by_pk(name "${pk}")
            set(name "${ans}")
            cake_repo_db_get_field_by_pk(url "${pk}")
            set(url "${ans}")
            if(name)
              set(s "[${name}] ")
            else()
              set(s "")
            endif()
            set(s "${s}group: ${group}, branch: ${branch}")
            message("")
            message(STATUS "${url}")
            message("\t${s}")
            message("\tpath: ${destination}")
          elseif(ARG_C STREQUAL "STATUS" OR ARG_C STREQUAL "DIFFLOG")
            execute_process(COMMAND ${GIT_EXECUTABLE} status -s
              WORKING_DIRECTORY "${destination}"
              OUTPUT_VARIABLE o_gs
              ERROR_VARIABLE e
              RESULT_VARIABLE r)
            if(r)
              message(FATAL_ERROR "[cake_pkg] 'git status -s' failed: ${r} (${e})")
            endif()
            execute_process(COMMAND ${GIT_EXECUTABLE} log --oneline origin/${branch}..HEAD
              WORKING_DIRECTORY "${destination}"
              OUTPUT_VARIABLE o_before
              ERROR_VARIABLE e
              RESULT_VARIABLE r)
            if(r)
              message(FATAL_ERROR "[cake_pkg] 'git log --oneline origin/${branch}..HEAD' failed: ${r} (${e})")
            endif()
            execute_process(COMMAND ${GIT_EXECUTABLE} log --oneline HEAD..origin/${branch}
              WORKING_DIRECTORY "${destination}"
              OUTPUT_VARIABLE o_behind
              ERROR_VARIABLE e
              RESULT_VARIABLE r)
            if(r)
              message(FATAL_ERROR "[cake_pkg] 'git log --oneline HEAD..origin/${branch}' failed: ${r} (${e})")
            endif()
            string(REGEX REPLACE "[^\n]" "" o_before "${o_before}")
            string(REGEX REPLACE "[^\n]" "" o_behind "${o_behind}")
            string(LENGTH "${o_before}" o_before)
            string(LENGTH "${o_behind}" o_behind)
            if(ARG_C STREQUAL "STATUS")
              if(NOT o_before EQUAL 0 OR NOT o_behind EQUAL 0 OR o_gs)
                set(s "")
                if(o_before EQUAL 0 AND o_behind EQUAL 0)
                  set(s "up to date with origin/${branch}")
                else()
                  if(o_before EQUAL 0)
                    set(s "${o_behind} to pull from")
                  elseif(o_behind EQUAL 0)
                    set(s "${o_before} to push to")
                  else()
                    set(s "diverged (-${o_behind}/+${o_before}) from")
                  endif()
                  set(s "${s} origin/${branch}")
                endif()
                if(o_gs)
                  set(s "${s} + local changes")
                endif()
                message("")
                message(STATUS "${header}")
                message("\t${s}")
                execute_process(COMMAND ${GIT_EXECUTABLE} status -sb
                  WORKING_DIRECTORY ${destination}
                  RESULT_VARIABLE r)
                if(r)
                  message(FATAL_ERROR "[cake_pkg] 'git status -sb' returned ${r} (${e})")
                endif()
              endif()
            else()
              # DIFFLOG
              if(NOT o_before EQUAL 0 OR NOT o_behind EQUAL 0)
                message("")
                message(STATUS "${header}")
                if(NOT o_behind EQUAL 0)
                  message("\t${o_behind} to pull from [origin/${branch}]:")
                  execute_process(COMMAND ${GIT_EXECUTABLE} log --oneline HEAD..origin/${branch}
                    WORKING_DIRECTORY ${destination}
                    RESULT_VARIABLE r)
                  if(r)
                    message(FATAL_ERROR "[cake_pkg] 'git log --oneline HEAD..origin/${branch}' returned ${r} (${e})")
                  endif()
                endif()
                if(NOT o_before EQUAL 0)
                  message("\t${o_before} to push to origin/${branch}:")
                  execute_process(COMMAND ${GIT_EXECUTABLE} log --oneline origin/${branch}..HEAD
                    WORKING_DIRECTORY ${destination}
                    RESULT_VARIABLE r)
                  if(r)
                    message(FATAL_ERROR "[cake_pkg] 'git log --oneline origin/${branch}..HEAD' returned ${r} (${e})")
                  endif()
                endif()
              endif()
            endif()
          endif()
        endif()
      endforeach()
    elseif(ARG_C STREQUAL "REMOVE")
      message(FATAL_ERROR "[cake] REMOVE is not implemented.")
    elseif(ARG_C STREQUAL "REGISTER")
      if(NOT ARG_NAME)
        message(FATAL_ERROR "[cake] cake_pkg(REGISTER ...) missing NAME argument.")
      endif()
      if(ARG_URL AND NOT DEFINED CAKE_PKG_REGISTRY_${ARG_NAME}_URL)
        set(CAKE_PKG_REGISTRY_${ARG_NAME}_URL "${ARG_URL}" CACHE INTERNAL "")
      endif()
      if(ARG_CODE AND NOT DEFINED CAKE_PKG_REGISTRY_${ARG_NAME}_CODE)
        set(CAKE_PKG_REGISTRY_${ARG_NAME}_CODE "${ARG_CODE}" CACHE INTERNAL "")
      endif()
    else()
      message(FATAL_ERROR "[cake_pkg] internal error in arg parsing")
    endif()
  endfunction()

# ---- run-once code ----

  find_package(Git REQUIRED QUIET)

  if(CAKE_PKG_UPDATE_NOW)
    cake_set_session_var(CAKE_PKG_UPDATE_NOW 1)
  endif()

  include(${CMAKE_CURRENT_LIST_DIR}/private/CakeRepoDb.cmake)

endif()

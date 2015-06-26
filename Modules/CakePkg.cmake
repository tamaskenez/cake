#.rst:
# CakePkg
# -------
#
# CAKE_PKG() performs various operations on a single package or on
# multiple packages. The operations are cloning, installation, removal
# and status reports and registering packages.
#
# ::
#
# 1. CLONE
# ========
#
#   CAKE_PKG(CLONE [name>]
#            NAME <name> | URL <repo-url>
#            [GROUP <group>]
#            [DESTINATION <dest-dir>])
#
# The command clones the repository to the given `<dest-dir>` or to an
# automatic location.
# Relative `<dest-dir>` is interpreted relative to the current source
# directory. In script mode it must be absolute.
#
# Either ``<repo-url>`` or ``<pkg-name>`` must be given. If ``<pkg-name>``
# is given the command looks up ``<pkg-name>`` in the Cake package
# registry, see `CakeRegisterPkg()`.
# If both ``<repo-url>`` and ``<pkg-name>`` are given the ``<repo-url>``
# is only a hint, will be used only if no ``<pkg-name>`` is found in the
# registry.
#
# If the package of the same ``<pkg-name>`` or ``<repo-url>`` has already
# been cloned the function does nothing. Even if both the `<name>` and
# `<repo_url>` are specified but the package `<name>` has already been
# cloned from a different URL, the command will succeed without making
# any changes.
#
# It is an error if the existing location differs from `<dest-dir>`.
#
# If no `<dest-dir>` given the repository will be cloned under the
# directory ``CAKE_PKG_CLONE_DIR`` (see ``cake-project-sample.cmake``
# or ``cake-src/cake.cmake``). The actual name of the directory will be
# derived from ``<repo-url>``.
#
# Usually you don't call `cake_pkg(CLONE ...)` with `DESTINATION` directly,
# instead you call `cake_add_subdirectory()`.
#
# ``<group>`` can be used to group packages, defaults to ``_ungrouped_``
#
# 2. INSTALL
# ==========
#
#   CAKE_PKG(INSTALL <name>
#            NAME <name> | URL <repo-url>
#            [GROUP <group>]
#            [DESTINATION <dest-dir>]
#            [CMAKE_ARGS <cmake-args>...]
#            [SOURCE_DIR <source-dir>])
#
# The INSTALL signature implies a CLONE step first so everything written
# for CLONE applies here, too.
#
# After the CLONE the command attemts to install the dependencies of the
# cloned repository:
#
# - attempts to find and execute (`include`) the file
# ``cake-install-deps.cmake`` next to the ``CMakeLists.txt``
# - if the file cannot be found, attempts to look up the repository in
#  the Cake package registry and execute the code found there
#
# After installing the dependencies (if found) the command
# - configures the project with ``cmake`` using the root of the package
#   or the directory ``<source-dir>`` (relative to the root)
# - builds the ``install`` target in the configurations listed in
#   ``CAKE_PKG_CONFIGURATION_TYPES``
#
# The `<cmake-args>` is a list of -Dname=value strings (value is
# optional). The arguments will also be passed to the code that
# installs the dependencies and ``cmake`` configuration phase.
#
# The INSTALL phase saves the package's SHA1 commit-ids after successful
# builds. The next time the INSTALL phase checks the saved SHA and will
# not launch the CMake build operation for an unchanged package.
# Note that uncommitted changes will be not detected. Of course, for packages
# added with ``cake_add_subdirectory`` the change detection is handled
# by the underlying build system, as usual.
#
# Format of the ``<repo-url>``
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#
# The ``<repo-url>`` is what you would pass to ``git clone``. Optionally
# it can be extended with other parameters using the URL query format.
# For example:
#
#     https://github.com/me/my.git?branch=devel
#
# Currently the only supported parameter is ``branch``:
#
# - ``branch=<branch>`` -> ``git clone ... --branch <branch>``
#
# Determining dependencies from ``cake-install-deps.cmake``:
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#
# The root directory (or the one specified with ``SOURCE_DIR``) may
# contain the file ``cake-pkg-depends.cmake``. This is a plain Cmake script
# which usually contains `cake_pkg(INSTALL ...)` commands for the
# dependencies of the package, for example::
#
#    cake_pkg(INSTALL https://github.com/madler/zlib)
#
# The CMAKE_ARGS options of the ``cake_pkg(INSTALL ...)`` command are also
# passed to the ``cake-install-deps.cmake`` script so it can install the
# dependencies accordingly::
#
#    if(MYLIB_WITH_SQLITE)
#        cake_pkg(INSTALL https://github.com/tamaskenez/sqlite3-cmake)
#    endif()
#
# Extracting dependencies from Cake package database:
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#
# Sometimes you can't add a ``cake-install-deps.cmake`` file to a
# third-party repository. In this case you can add the code that
# install the dependencies with ``cake_pkg(REGISTER ...)``.
#
# 3. REGISTER
# ===========
#
#   CAKE_PKG(REGISTER <name>
#            NAME <name> | URL <repo-url>
#            [CMAKE_ARGS <cmake-args>...]
#            [SOURCE_DIR <source-dir>]
#            [CODE <install-deps-code>])
#
# With the command you can specify information about package in advance,
# and for all the subsequent ``cake_pkg(CLONE/INSTALL)`` commands.
#
# Conveniently, a list of ``cake_pkg(REGISTER ...)`` commands can be put
# into a file (local or remote) and be referenced in the your project file
# (``cake-project.cmake``) in the variable ``CAKE_PKG_REGISTRIES``.
# This will make sure the information will be available to the ``cakepkg``
# shell commands, too.
#
# All the arguments of ``cake_pkg(REGISTER ...)`` has the same meaning
# as for the ``CLONE`` and ``INSTALL`` subcommands. The ``CODE`` option
# can be used instead of the ``cake-install-deps.cmake`` file placed
# next to the ``CMakeLists.txt`` of a package.
#
# 3. COMMAND|CMDC|SHC
# ===================
#
#   CAKE_PKG(COMMAND|CMDC|SHC <cmd> [args1...])
#
# 4. LIST|STATUS|DIFFLOG
# ======================
#
#   CAKE_PKG(LIST|STATUS|DIFFLOG)
#
# 5. REMOVE
# =========
#
#   CAKE_PKG(REMOVE <name>)
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
    if(output_var_out MATCHES "^_$")
      set(output_var_option "")
    else()
      set(output_var_option OUTPUT_VARIABLE output_variable OUTPUT_STRIP_TRAILING_WHITESPACE)
    endif()
    execute_process(
      COMMAND ${GIT_EXECUTABLE} ${command_line}
      ${wd}
      ${output_var_option}
      RESULT_VARIABLE result_variable)
    if(ARGC LESS 4 AND result_variable)
      message(FATAL_ERROR "[cake] git command failed")
    endif()
    if(NOT output_var_out MATCHES "^_$")
      set(${output_var_out} "${output_variable}" PARENT_SCOPE)
    endif()
    if(ARGC GREATER 3)
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

  # includes the file ``cake_pkg_depends_file_arg``
  # if that doesn't exist, looks up CAKE_PKG_REGISTRY_${name}_CODE variables and includes those
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
      set(sv_args URL DESTINATION NAME GROUP PK_OUT BRANCH)
      _cake_fix_name()
    elseif(ARG_C MATCHES "^INSTALL$")
      set(sv_args URL DESTINATION NAME GROUP PK_OUT BRANCH SOURCE_DIR)
      set(mv_args CMAKE_ARGS)
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
      set(sv_args URL CODE NAME CMAKE_ARGS SOURCE_DIR)
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
      endif()
      _cake_pkg_clone("${ARG_URL}" "${ARG_DESTINATION}" "${group}" "${ARG_NAME}" "${ARG_BRANCH}")
      set(pk "${ans}")
      if(ARG_C MATCHES "^INSTALL$")
        _cake_pkg_install("${pk}" "${ARG_CMAKE_ARGS}" "${ARG_SOURCE_DIR}")
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
      foreach(p URL CODE SOURCE_DIR CMAKE_ARGS)
        if(ARG_${p} AND NOT DEFINED CAKE_PKG_REGISTRY_${ARG_NAME}_${p})
          set(CAKE_PKG_REGISTRY_${ARG_NAME}_${p} "${ARG_${p}}" CACHE INTERNAL "")
        endif()
      endforeach()
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

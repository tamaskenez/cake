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
#            [PROJECT <project-name>]
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
# If no `<dest-dir>` given the function uses the value of ``CMAKE_INSTALL_PREFIX`` set in ``CAKE_PKG_CMAKE_OPTIONS`` and create a directory
# under ${CMAKE_INSTALL_PREFIX}/var. The actual name of the directory will be derived from ``<repo-url>``.
# See also `CakeLoadConfig.cmake`.
#
# Usually you don't call `cake_pkg(CLONE ...)` with `DESTINATION` directly, instead you call `cake_add_subdirectory()`.
#
# ``<project-name>`` can be used to group packages, defaults to ``${PROJECT_NAME}`` or to ``non-project`` in script mode.
#
# 2. INSTALL
#
#   CAKE_PKG(CLONE
#            NAME <name> | URL <repo-url>
#            [PROJECT <project-name>]
#            [DESTINATION <dest-dir>]
#            [DEFINITIONS <definitions>...])
#
# The INSTALL signature implies a CLONE step first so everything written for CLONE applies here.
#
# After the CLONE the command attemts to install the dependencies of the cloned repository:
# - attempts to find and execute (`include`) the file ``cake-depends.cmake`` in the root of the repository
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
# - ``depth=<depth>`` -> ``git clone ... --depth <depth>``
#
# Determining dependencies from ``cake-depends.cmake``:
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#
# The root directory of the package may contain the file ``cake-depends.cmake``. This is a plain Cmake script
# which usually contains a `cake_pkg(INSTALL ...)` commands for the dependencies of the package, for example::
#
#    cake_pkg(INSTALL https://github.com/madler/zlib.git)
#
# The -D options of the ``<repo-url>`` are also passed to the ``cake-depends.cmake`` script so it
# can install the dependencies accordingly::
#
#    if(WITH_SQLITE)
#        cake_pkg(INSTALL https://github.com/myaccount/sqlite-cmake)
#    endif()
#
# Extracting dependencies from Cake package database:
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#
# Sometimes you can't add a ``cake-depends.cmake`` file to a third-party library. In this
# case you can add the dependency information to a text file in the Cake package database
# which is simply the text files in in the Cake distribution's ``/db`` directory.
# Any file name with the pattern ``cake-depends-db*`` is accepted. The files contains single lines of this format::
#
#    URL <url1> [DEPENDS <url2> [<url3> ...]]
#
# Which describes that the repo at url1 depends on url2, url3, etc...
#
# The INSTALL phase saves the package's SHA1 commit-ids after successful builds. The next time the INSTALL
# phase checks the saved SHA and will not launch the CMake build operation for an unchanged package.
#
# About the cake environment variables controlling these operations see `cake_load_config()`
#

include(CMakePrintHelpers)

if(NOT CAKE_PKG_INCLUDED)

  set(CAKE_PKG_INCLUDED 1)

  if(NOT CAKE_INCLUDED)
    message(FATAL_ERROR "[cake] Include Cake.cmake, don't include this file directly.")
  endif()

  include(CMakeParseArguments)
  
  if(NOT CAKE_PRIVATE_UTILS_INCLUDED)
    include(${CMAKE_CURRENT_LIST_DIR}/CakePrivateUtils.cmake)
  endif()

  if(NOT CAKE_LOAD_CONFIG_INCLUDED)
    include(${CMAKE_CURRENT_LIST_DIR}/CakeLoadConfig.cmake)
  endif()

  include(${CMAKE_CURRENT_LIST_DIR}/CakeDependsDbAdd.cmake)

  # there is run-once code after the function definitions

  # strips URL scheme, .git extension, splits trailiing :commitish
  # for an input url like http://user:psw@a.b.com/c/d/e.git?branch=release/2.3&-DWITH_SQLITE=1&-DBUILD_SHARED_LIBS=1&depth=1
  # we need the following parts:
  # repo_url: http://user:psw@a.b.com/c/d/e.git
  #   this is used for git clone
  # repo_url_cid: a_b_com_c_d_e (scheme, user:psw@ and .git stripped, made c identifier)
  #   this identifies a repo and also the name of directory of the local copy
  # options: "branch=release/2.3;depth=1" list of the query items that do not begin with -D
  # definitions: "-DWITH_SQLITE=1;-DBUILD_SHARED_LIBS=1" list of the query items that begins with -D
  #   used for passing build parameters to the package, like autoconf's --with... and macports' variants
  function(cake_parse_pkg_url URL REPO_URL_OUT REPO_URL_CID_OUT OPTIONS_OUT DEFINITIONS_OUT)

    string(REGEX MATCH "^([^:]+://)?([^/]*)(/[^?]+)(\\?(.*))?$" v "${URL}")

    set(repo_url "${CMAKE_MATCH_1}${CMAKE_MATCH_2}${CMAKE_MATCH_3}")

    string(FIND "${CMAKE_MATCH_2}" @ at_pos)
    if(at_pos GREATER -1)
      math(EXPR at_pos_plus_one "${at_pos}+1")
      string(SUBSTRING "${CMAKE_MATCH_2}" ${at_pos_plus_one} -1 cm2)
    else()
      set(cm2 "${CMAKE_MATCH_2}")
    endif()

    set(cm3 "${CMAKE_MATCH_3}")
    string(REPLACE & \; query "${CMAKE_MATCH_5}")

    # remove trailing / and .git 
    if(cm3 MATCHES "/?(.git)?/?$")
      string(LENGTH "${cm3}" al)
      string(LENGTH "${CMAKE_MATCH_0}" l)
      math(EXPR al_minus_l "${al}-${l}")
      string(SUBSTRING "${cm3}" 0 ${al_minus_l} cm3)
    endif()
    string(MAKE_C_IDENTIFIER "${cm2}${cm3}" repo_url_cid)

    set(options "")
    set(definitions "")
    foreach(i ${query})
      if("${i}" MATCHES "^([^=]+)=(.*)$")
        if("${CMAKE_MATCH_1}" MATCHES "^-D?") # -D and at least one character
          list(APPEND definitions "${i}")
        else()
          list(APPEND options "${i}")
        endif()
      else()
        message(FATAL_ERROR "[cake] Invalid item (${i}) in URL query string, URL: ${URL}")
      endif()
    endforeach()

    set(${REPO_URL_OUT} "${repo_url}" PARENT_SCOPE)
    set(${REPO_URL_CID_OUT} "${repo_url_cid}" PARENT_SCOPE)
    set(${OPTIONS_OUT} "${options}" PARENT_SCOPE)
    if(definitions)
      list(SORT definitions) # to provide canonical order
    endif()
    set(${DEFINITIONS_OUT} "${definitions}" PARENT_SCOPE)
  endfunction()

  macro(_cake_apply_definitions definitions)
    foreach(i ${definitions})
      if(i MATCHES "^-D([^=]+)=(.*)$")
        set(${CMAKE_MATCH_1} "${CMAKE_MATCH_2}")
      elseif(i MATCHES "^-U([^=]+)$")
        unset(${CMAKE_MATCH_1})
        unset(${CMAKE_MATCH_1} CACHE)
      else()
        message(FATAL_ERROR "[cake] Internal error, definition does not match regex (-DX=Y or -UX): ${i}")
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
      set(output_var_option OUTPUT_VARIABLE output_variable)
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

  macro(_cake_remove_if_stale pk_var)
    cake_repo_db_get_field_by_pk(destination "${${pk_var}}")
    if(NOT EXISTS "${ans}")
      cake_repo_db_erase_by_pk("${${pk_var}}")
      set(${pk_var} "")
    endif()
  endmacro()

  macro(_cake_need_empty_directory dn)
    if(EXISTS "${dn}")
      if(IS_DIRECTORY "${dn}")
        file(GLOB g "${dn}/*")
        if(g)
          set(ans 0) # non-empty dir
        else()
          set(ans 1) # empty-dir
        endif()
      else()
        set(ans 0) # existing file
      endif()
    endif()
    file(MAKE_DIRECTORY "${dn}") # does not exist
    set(ans 1)
  endmacro()

  # pkg_url is the full, decorated URL (with optional query part to specify key-value pairs)
  # destination can be empty (= calculate destination under CAKE_PKG_REPOS_DIR)
  #   or non-empty (= this packaged has been added by a cake_add_subdirectory() call and will be part of the CMake project)
  # if destination is empty, since the package will not be built as a part of the CMake project (not a subdirectory)
  # project is the the resolved project (either specified or default)
  # name is the specified name
  # returns (ans) the cloned repo's primary key
  function(_cake_pkg_clone pkg_url destination project name)
    if(pkg_url)
      cake_parse_pkg_url("${pkg_url}" _ url_cid _ _)
      cake_repo_db_get_pk_by_field(cid "${url_cid}")
      set(pk_from_url "${ans}")
      _cake_remove_if_stale(pk_from_url)
    else()
      set(pk_from_url "")
    endif()

    if(name)
      cake_repo_db_get_pk_by_field(name "${name}")
      set(pk_from_name "${ans}")
      _cake_remove_if_stale(pk_from_name)
    else()
      set(pk_from_name "")
    endif()

    if(pk_from_name)
      if(pk_from_url)
        if(pk_from_name EQUAL pk_from_url)
          set(pk "${pk_from_name}")
        else()
          cake_repo_db_get_field_by_pk("${pk_from_name}" url)
          set(other_url "${ans}")
          cake_repo_db_get_field_by_pk("${pk_from_url}" name)
          set(other_name "${ans}")
          message(FATAL_ERROR "[cake_pkg] You requested cloning the package ${name} from the url ${pkg_url}.
            The package ${name} has already been cloned from url ${other_url} and
            the url ${pkg_url} has already been cloned under the name ${other_name}. Please change
            either the names of the urls to avoid confusion.")
        endif()
      else()
        set(pk "${pk_from_name}")
      endif()
    else()
      if(pk_from_url)
        set(pk "${pk_from_url}")
      else()
        set(pk "")
      endif()
    endif()      

    if(pk)
      cake_repo_db_get_field_by_pk(destination "${pk}")
      set(existing_destination "${ans}")
    else()
      set(existing_destination "")
    endif()

    if(existing_destination)
      # nothing to do, if no explicit destination specified, or it's the same as previous
      if(NOT destination OR destination STREQUAL existing_destination)
        set(ans "${pk}" PARENT_SCOPE)
        return()
      else()
        message(FATAL_ERROR
"[cake_pkg] The repository ${repo_url} has already been cloned to
    ${existing_destination},
the current request is to clone it to
    ${destination}.
This sitatuation usually comes up when a repository is cloned as an external
dependency to an automatic location then later you add the same repository as
a subdirectory to your project.
Possible solution: add this repository as subdirectory before all other
references to it. You also need to remove the current clone manually, either
by removing the directory ${existing_destination}
or by calling 'cakepkg REMOVE ...'.")
      endif()
    endif()

    if(pkg_url)
      cake_parse_pkg_url("${pkg_url}" repo_url url_cid options _)
    else()
      message(FATAL_ERROR "Package registry is not implemented, can't look up ${name}")
    endif()

    if(NOT destination)
      set(resolved_destination ${CAKE_PKG_REPOS_DIR}/${url_cid})
    else()
      if(NOT IS_ABSOLUTE "${destination}")
        message(FATAL_ERROR "[cake_pkg] internal error, destination must be absolute.")
      endif()
      if(destination MATCHES "^${CAKE_PKG_REPOS_DIR}/")
        message(FATAL_ERROR "[cake_pkg] <destination> must not be under ${CAKE_PKG_REPOS_DIR}.")
      endif()
      set(resolved_destination "${destination}")
    endif()

    # clone new repo
    _cake_need_empty_directory("${resolved_destination}")
    if(NOT ans)
      message(FATAL_ERROR "[cake_pkg] About to clone into directory ${resolved_destination} but the directory exists. 
        Inspect it for possible unsaved changes and remove it manually.")
    endif()

    # prepare parameters for git clone
    set(command_line clone)
    foreach(i ${options})
      if("${i}" MATCHES "^branch=(.+)$")
        list(APPEND command_line -b "${CMAKE_MATCH_1}")
      elseif("${i}" MATCHES "^depth=(.+)$")
        list(APPEND command_line --depth "${CMAKE_MATCH_1}")
        set(depth_set 1)
      endif()
    endforeach()
    list(APPEND command_line --recursive)

    # prepare command line for git clone
    list(APPEND command_line "${repo_url}" "${resolved_destination}")
    # git clone
    _cake_execute_git_command_in_repo("${command_line}" "" res_var)

    if(res_var)
      message(FATAL_ERROR "[cake_pkg] git clone failed")
    endif()

    if(NOT name)
      set(name "${url_cid}")
    endif()

    cake_repo_db_next_pk()

    set(pk "${ans}")

    cake_repo_db_add_fields(${pk}
      cid "${url_cid}"
      url "${repo_url}"
      project "${project}"
      name "${name}"
      destination "${resolved_destination}")

    set(ans "${pk}" PARENT_SCOPE)

  endfunction()

  # build_pars_now_var and last_build_pars_var name lists containing items like
  # COMMIT=02394702394234
  # -DSOME_PAR=
  # -DSOME_OTHER_PAR=foo
  # return result in 'ans'
  # Build-pars-now are compatible with existing build pars if:
  # - if the same variable listed in both list, they must be identical
  # - if a variable is listed in last_build_pars but not build_pars_now (= don't care), it's okay
  # - if a variable is not listed in last_build_pars but it is on build_pars_now, it's not okay
  #   reason: the package could be rebuilt with the new, more specific build parameters but
  #   that would change the already existing and already found targets the rebuilt package export
  function(_cake_are_build_par_lists_compatible last_build_pars_var build_pars_now_var)
    # we expect short lists so the N^2 algorithm is fine
    set(ans 0 PARENT_SCOPE)
    foreach(i1 ${${build_pars_now_var}})
      string(REGEX MATCH "^([^=]+)=(.*)$" _ "${i1}")
      if(NOT CMAKE_MATCH_0)
        message(FATAL_ERROR "[cake] Build parameter ${i1} is invalid")
      endif()
      set(i1_key "${CMAKE_MATCH_1}")
      set(i1_value "${CMAKE_MATCH_2}")
      set(i1_key_found 0)
      foreach(i2 ${${last_build_pars_var}})
        string(REGEX MATCH "^([^=]+)=(.*)$" _ "${i2}")
        if(NOT CMAKE_MATCH_0)
          message(FATAL_ERROR "[cake] Build parameter ${i2} is invalid")
        endif()
        set(i2_key "${CMAKE_MATCH_1}")
        set(i2_value "${CMAKE_MATCH_2}")
        if(i1_key STREQUAL i2_key)
          if(i1_key_found)
            message(FATAL_ERROR "[cake] The build parameter ${i1_key} is found multiple times in another build configuration")
          endif()
          set(i1_key_found 1)
          if(NOT i1_value STREQUAL i2_value)
            return() # not compatible, differing values
          endif()
        endif() # not the same key
      endforeach() # for each items in last build pars
      if(NOT i1_key_found)
        return() # not compatible, a setting in build_pars_now was not specified in last_build_pars
      endif()
    endforeach() # for each items in build pars now
    set(ans 1 PARENT_SCOPE)
  endfunction()

  # pk: primary key of entry in repo_db
  function(_cake_pkg_install pk definitions)
    cake_repo_db_get_field_by_pk(destination "${pk}")
    set(destination "${ans}")
    cake_repo_db_get_field_by_pk(cid "${pk}")
    set(cid "${ans}")
    # check if destination is a subdirectory
    if(CAKE_PKG_${cid}_ADDED_AS_SUBDIRECTORY)
      cake_message(STATUS "The package ${repo_url} has already been added as subdirectory, skipping installation. "
        "The consumer of this package (${CMAKE_CURRENT_SOURCE_DIR}) must be prepared to use the package as a target as opposed to"
        " a package found by find_package() or cake_find_package().")
      return()
    endif()

    _cake_execute_git_command_in_repo("log;-1;--pretty=format:%H" "${destination}" repo_sha)
    set(build_pars_now "COMMIT=${repo_sha}")
    list(APPEND build_pars_now ${definitions})

    # if we've already installed this in this session just make sure the
    # current build settings are compatible with the first time's build settings
    if(CAKE_PKG_${cid}_TRAVERSED_BY_PKG_INSTALL_NOW)
      #todo this one should be reimplemented after introducing required definitions
      #_cake_are_build_par_lists_compatible(CAKE_PKG_${cid}_LAST_BUILD_PARS build_pars_now)
      set(ans 1)
      if(NOT ans)
        cmake_print_variables(last_build_pars build_pars_now)
        message(FATAL_ERROR "[cake] The package ${pkg_url} has just been installed and now "
          "another package triggered the installation with different build parameters. "
          "Solution: make sure all packages having a shared dependency specify the same build "
          "settings (defines) for the dependency.")
      else()
        return()
      endif()
    endif()

    cake_set_session_var(CAKE_PKG_${cid}_TRAVERSED_BY_PKG_INSTALL_NOW 1)
    cake_set_session_var(CAKE_PKG_${cid}_LAST_BUILD_PARS "${build_pars_now}")

    # find dependencies:
    # - try to run the repo's cake-depends.cmake
    # - if no cake-depends.cmake consult the cake pkg db and run that script if found
    set(cake_depends_cmake_file "${destination}/cake-depends.cmake")
    set(randomfile "")
    if(NOT EXISTS "${cake_depends_cmake_file}" AND DEFINED CAKE_DEPENDS_DB_${cid})
      string(RANDOM randomfile)
      set(randomfile "${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_tmp/${randomfile}")
      file(WRITE "${randomfile}" "${CAKE_DEPENDS_DB_${cid}}")
      set(cake_depends_cmake_file "${randomfile}")
    endif()

    if(EXISTS "${cake_depends_cmake_file}")
      # _call_cake_depends executes either the cake-depends.script or
      # or the script defined in the cake-depends-db*.cmake
      # The script usually contains cake_pkg(INSTALL ...) calls which
      # fetch and install dependencies
      _cake_apply_definitions("${definitions}")
      include("${cake_depends_cmake_file}")
    endif()

    if(randomfile)
      file(REMOVE "${randomfile}")
    endif()

    # now configure and build the install target of this package with cmake

    if(NOT CAKE_PKG_CONFIGURATION_TYPES)
      message(FATAL_ERROR "[cake] CAKE_PKG_CONFIGURATION_TYPES is empty. It should be left undefined (then defaults to 'Release') or set to valid values.")
    endif()

    cake_repo_db_get_field_by_pk(name "${pk}")
    if(ans STREQUAL cid)
      cake_repo_db_get_field_by_pk(url "${pk}")
    endif()
    set(descriptive_name "${ans}")

    foreach(c ${CAKE_PKG_CONFIGURATION_TYPES})
      # read pars of last build (install)
      set(last_build_pars_path ${CAKE_PKG_LAST_BUILD_PARS_DIR}/${cid}_${c})
      set(last_build_pars "")
      if(EXISTS "${last_build_pars_path}")
        file(STRINGS "${last_build_pars_path}" last_build_pars)
      else()
        set(last_build_pars "COMMIT=")
      endif()

      if(NOT last_build_pars STREQUAL build_pars_now) # last install is non-existent or outdated
        cake_message(STATUS "Building the install target (${c}) for package ${descriptive_name}")

        # remove pars from last build
        set(first_par 1)
        set(unset_definitions "")
        foreach(i ${last_build_pars})
          if(first_par)
            set(first_par 0) # first par is the SHA1 commit, skip it
          else()
            string(REGEX MATCH "^-D([^=]+)=.*$" _ "${i}")
            if(CMAKE_MATCH_1)
              list(APPEND unset_definitions "-U${CMAKE_MATCH_1}")
            endif()
          endif()
        endforeach()

        # call cmake configure
        set(binary_dir ${CAKE_PKG_BUILD_DIR}/${cid}_${c})
        set(command_line
            -H${destination} -B${binary_dir}
            -DCMAKE_BUILD_TYPE=${c}
            -DCAKE_ROOT=${CAKE_ROOT}
            ${CAKE_PKG_CMAKE_OPTIONS}
            ${unset_definitions}
            ${definitions}
            -DCAKE_PKG_LOAD_THE_SESSION_VARS=1
        )

        cake_list_to_command_line_like_string(s "${command_line}")
        cake_message(STATUS "cmake ${s}")
        execute_process(COMMAND ${CMAKE_COMMAND} ${command_line} RESULT_VARIABLE res_var)
        if(res_var)
          message(FATAL_ERROR "[cake] CMake configuration failed, check the previous lines for the actual error.")
        endif()

        # call cmake build
        set(command_line --build "${binary_dir}" --target install --config ${c} -- ${CAKE_PKG_NATIVE_TOOL_OPTIONS})
        cake_list_to_command_line_like_string(s "${command_line}")
        cake_message(STATUS "cmake ${s}")
        execute_process(COMMAND ${CMAKE_COMMAND} ${command_line} RESULT_VARIABLE res_var)
        if(res_var)
          message(FATAL_ERROR "[cake] CMake build failed, check the previous lines for the actual error.")
        endif()

        # update last build pars
        set(s "")
        foreach(i ${build_pars_now})
          set(s "${s}${i}\n")
        endforeach()
        file(WRITE ${last_build_pars_path} "${s}")
      else()
        cake_message(STATUS "Configuration '${c}' already installed from commit ${repo_sha} with same definitions, skipping build.")
      endif()
    endforeach()

  endfunction()

# CAKE_PKG_REGISTRY_<NAME> = URL [DEFINITIONS]
# CLONE:
# - CLONE URL [DESTINATION] [NAME] [PROJECT]
# - CLONE NAME [DESTINATION] [PROJECT]
# INSTALL single:
# - INSTALL URL [DESTINATION] [NAME] [PROJECT] [DEFINITIONS]
# - INSTALL NAME [DESTINATION] [PROJECT] [DEFINITIONS]
# INSTALL batch:
# - INSTALL ALL^(PROJECT|IF)
# REPORT single:
# - STATUS|DIFFLOG|COMMAND|CMDC|SHC NAME
# REPORT batch:
# - STATUS|DIFFLOG|COMMAND|CMDC|SHC ALL^(PROJECT|IF)
# REMOVE single
# - REMOVE NAME|(ALL^(PROJECT|IF))
# - LIST NAME|(ALL^(PROJECT|IF))
  function(cake_pkg)

    set(option_commands CLONE INSTALL STATUS DIFFLOG REMOVE LIST)
    set(mv_commands COMMAND CMDC SHC)
    set(all_commands ${option_commands} ${mv_commands})

    cmake_parse_arguments(ARG
      "${option_commands}"
      "URL;DESTINATION;NAME;PROJECT"
      "${mv_commands};IF;DEFINITIONS"
      ${ARGV})

    set(count 0)
    foreach(c ${all_commands})
      if(ARG_${c})
        math(EXPR count "${count}+1")
      endif()
    endforeach()
    if(count EQUAL 0 OR count GREATER 1)
      string(REPLACE \; ", " s "${all_commands}")
      message(FATAL_ERROR "[cake_pkg] Exactly one of these options must be specified: ${s}")
    endif()

    # make ARG_DESTINATION absolute
    if(NOT ("${ARG_DESTINATION}" STREQUAL "") AND NOT IS_ABSOLUTE "${ARG_DESTINATION}")
      if(DEFINED CMAKE_SCRIPT_MODE_FILE)
        message(FATAL_ERROR "[cake_pkg] In script mode <destination-dir> must be absolute path.")
      else()
        get_filename_component(ARG_DESTINATION "${CMAKE_CURRENT_SOURCE_DIR}/${ARG_DESTINATION}")
      endif()
    endif()

    if(ARG_PROJECT)
      set(project "${ARG_PROJECT}")
    elseif("${PROJECT_NAME}" STREQUAL "")
      set(project "non-project")
    else()
      set(project "${PROJECT_NAME}")
    endif()

    if((NOT ARG_NAME AND NOT ARG_URL) AND (ARG_CLONE OR ARG_INSTALL))
      message(FATAL_ERROR "[cake_pkg] Either URL or NAME (or both) must be specified.")
    endif()

    if(ARG_CLONE OR ARG_INSTALL)
      if(ARG_URL)
        cake_parse_pkg_url("${ARG_URL}" repo_url repo_cid repo_options repo_definitions)
      else()
        set(repo_url "")
        set(repo_cid "")
        set(repo_options "")
        set(repo_definitions "")
      endif()
      _cake_pkg_clone("${ARG_URL}" "${ARG_DESTINATION}" "${project}" "${ARG_NAME}")
      set(pk "${ans}")
      if(ARG_INSTALL)
        set(defs "")
        list(APPEND defs ${repo_definitions})
        list(APPEND defs ${ARG_DEFINITIONS})
        list(SORT defs)
        list(REMOVE_DUPLICATES defs)
        _cake_pkg_install("${pk}" "${defs}")
      endif()
    elseif(ARG_STATUS OR ARG_DIFFLOG OR ARG_COMMAND OR ARG_CMDC OR ARG_SHC)
      if(ARG_NAME)
        message(FATAL_ERROR "[cake_pkg] this option is not implemented")
      else()
        # batch report
        file(GLOB dirs ${CAKE_PKG_REPOS_DIR}/*)
        foreach(d ${dirs})
          if(IS_DIRECTORY "${d}")
            if(ARG_COMMAND)
              set(command ${ARG_COMMAND})
            elseif(ARG_CMDC)
              set(command cmd /c ${ARG_CMDC})
            elseif(ARG_SHC)
              string(REPLACE \; " " v "${ARG_SHC}")
              cmake_print_variables(ARG_SHC v)
              set(command sh -c "${v}")
            else()
              message(FATAL_ERROR "[cake_pkg] internal error while assembling command")
            endif()
            cake_list_to_command_line_like_string(s "${command}")
            message(STATUS "cd ${d}")
            message(STATUS "${s}")
            execute_process(COMMAND ${command}
              WORKING_DIRECTORY ${d}
              RESULT_VARIABLE r)
            if(r)
              message(FATAL_ERROR "[cake_pkg] Result: ${r}")
            endif()
          endif()
        endforeach()
      endif()
    else()
      message(FATAL_ERROR "[cake_pkg] internal error in arg parsing")
    endif()
  endfunction()

  macro(cake_load_pkg_db)
    FILE(GLOB _cake_db_files ${CAKE_ROOT}/cake-depends-db*.cmake)
    foreach(i ${_cake_db_files})
      include("${i}")
    endforeach()
  endmacro()

# ---- run-once code ----

  find_package(Git REQUIRED QUIET)

  if(CAKE_PKG_UPDATE_NOW)
    cake_set_session_var(CAKE_PKG_UPDATE_NOW 1)
  endif()

  cake_load_pkg_db()

  set(CAKE_PKG_REPOS_DIR ${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_repos)
  set(CAKE_PKG_BUILD_DIR ${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_build)
  set(CAKE_PKG_LAST_BUILD_PARS_DIR ${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_last_build_pars)

  include(${CMAKE_CURRENT_LIST_DIR}/CakeRepoDb.cmake)

endif()
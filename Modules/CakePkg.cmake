#.rst:
# CakePkg
# -------
#
# CAKE_PKG() clones or updates the git repository and builds and installs the package.
#
# ::
#
#   CAKE_PKG(CLONE|UPDATE|INSTALL
#            URL <repo-url>
#            [DESTINATION <target-dir>])
#
#
# If no ``DESTINATION`` is given then the location of the local copy of the repository will be determined by the
# the CAKE_PKG_CMAKE_OPTIONS configuration variable (see `CmakeLoadConfig.cmake`):
#
# The function uses the value of ``CMAKE_INSTALL_PREFIX`` set in ``CAKE_PKG_CMAKE_OPTIONS`` and create a directory`
# under ${CMAKE_INSTALL_PREFIX}/var. The actual name of the directory will be derived from ``<repo-url>``.
#
# If ``CAKE_PKG_CMAKE_OPTIONS`` doesn't set ``CMAKE_PREFIX_PATH`` then the current value of ``CMAKE_PREFIX_PATH``
# will be used.
#
# If ``DESTINATION`` is given then the package will be cloned into ``<target-dir>`` instead. However ``DESTINATION``
# affects only this package. If this package has any dependencies which has not yet been added as a subdirectory (see
# `cake_add_subdirectory()`) then the location of those dependencies will be determined according
# to the previous paragraph.
#
# The function has the following modes of working:
#
# - CLONE: git clone (if target-dir is missing)
# - UPDATE: git pull (implies CLONE if target-dir is missing)
# - INSTALL: build the ``install`` target, implies CLONE
#
# If you specifyu only CLONE or INSTALL you can still force updating by specifying ``-DCAKE_PKG_UPDATE_NOW=1``
# for the CMake configuration run (the variable will be removed from the cache after the update took place).
#
# CAKE_PKG() also recursively calls CAKE_PKG() for the dependencies of the current package. It can determine
# the dependencies from two sources: either from a file ``cake-depends.cmake`` in the root
# of the package or consulting the Cake package database.
#
# Usually you don't need to call CAKE_PKG directly. Instead:
#
# - call `cake_find_package()` to add an external dependent package. This will call ``cake_pkg(INSTALL ...)``
# - call `cake_add_subdirectory()` to add an in-project dependent package. This will call ``cake_pkg(CLONE ...)```
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
# - ``recursive`` or ``recurse_submodules`` -> ``git clone ... --recursive``
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

    unset(options)
    unset(definitions)
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
    if(DEFINED definitions)
      list(SORT definitions) # to provide canonical order
    endif()
    set(${DEFINITIONS_OUT} "${definitions}" PARENT_SCOPE)
  endfunction()

  function(_call_cake_depends cake_depends_file)
    # extract definitions into CMake variables
    foreach(i ${CAKE_DEFINITIONS})
      string(REGEX MATCH "^-D([^=]+)=(.*)$" v "${i}")
      if(NOT CMAKE_MATCH_1)
        message(FATAL_ERROR "[cake] Internal error, definition does not match regex: ${i}")
      endif()
      set(${CMAKE_MATCH_1} "${CMAKE_MATCH_2}")
    endforeach()
    # call cake_depends.cmake
    include("${cake_depends_file}")
  endfunction()


  # input (options) and output (branch) args are from the parent scope
  # branch will be empty if options does not list a branch parameter
  function(_cake_get_branch_from_options)
    unset(branch PARENT_SCOPE)
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
  function(_cake_execute_git_command_in_repo command_line pkg_dir output_var_out)
    cake_list_to_command_line_like_string(s "${command_line}")
    cake_message(STATUS "cd ${pkg_dir}")
    cake_message(STATUS "git ${s}")
    unset(output_variable)
    if(pkg_dir)
      set(wd WORKING_DIRECTORY ${pkg_dir})
    else()
      unset(wd)
    endif()
    execute_process(
      COMMAND ${GIT_EXECUTABLE} ${command_line}
      ${wd}
      OUTPUT_VARIABLE output_variable
      RESULT_VARIABLE result_variable)
    if(NOT ARGV3 AND result_variable)
      message(FATAL_ERROR "[cake] git command failed")
    endif()
    set(${output_var_out} "${output_variable}" PARENT_SCOPE)
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

  # session vars
  # - CAKE_PKG_<CID>_TRAVERSED_BY_PKG_PULL_NOW
  # - CAKE_PKG_<CID>_TRAVERSED_BY_PKG_INSTALL_NOW
  # - CAKE_PKG_<CID>_LOCAL_REPO_DIR
  # - CAKE_PKG_<CID>_ADDED_AS_SUBDIRECTORY

  # pkg_url is the full, decorated URL (with optional query part to specify key-value pairs)
  # if pull_always is FALSE it only clones if target directory is missing
  # if pull_always is TRUE it clones if target dir missing, pulls if not missing
  # destination can be empty (= calculate destination under CAKE_PKG_REPOS_DIR)
  #   or non-empty (= this packaged has been added by a cake_add_subdirectory() call and will be part of the CMake project)
  # if destination is empty, since the package will not be built as a part of the CMake project (not a subdirectory)
  function(_cake_pkg_pull pkg_url pull_always destination)
    cake_parse_pkg_url(${pkg_url} repo_url pkg_subdir options definitions)

    # Logic to determine where this package should be cloned to
    # - 'destination' can be empty (= clone to automatic location below CAKE_PKG_REPOS_DIR)
    #   or non-empty (= clone to specific location, probably a cake_add_subdirectory() call)
    # - this package may have already been cloned to a location 
    # These are 2 x 2 possibilities:
    if(destination)
      # if this repo has not been cloned yet, use destination instead of calculated pkg_dir
      # otherwise if destination differs from the already installed one, error
      if(NOT DEFINED CAKE_PKG_${pkg_subdir}_LOCAL_REPO_DIR)
        set(pkg_dir "${destination}")
        cake_set_session_var(CAKE_PKG_${pkg_subdir}_LOCAL_REPO_DIR ${pkg_dir})
      elseif(NOT "${CAKE_PKG_${pkg_subdir}_LOCAL_REPO_DIR}" STREQUAL "${destination}")
        message(FATAL_ERROR "[cake] Package ${repo_url} already cloned into ${CAKE_PKG_${pkg_subdir}_LOCAL_REPO_DIR}, "
          "now requested to clone into ${destination}. Possible reason: "
          "This package is a automatically cloned dependency of another package and later explicitly "
          "added with cake_add_subdirectory. Solution: move the cake_add_subdirectory() for this package "
          "before the first cake_add_subdirectory()/cake_find_package()/cake_pkg command which it is a dependecy of.")
      endif()
    else()
      if(NOT DEFINED CAKE_PKG_${pkg_subdir}_LOCAL_REPO_DIR)
        set(pkg_dir ${CAKE_PKG_REPOS_DIR}/${pkg_subdir})
        cake_set_session_var(CAKE_PKG_${pkg_subdir}_LOCAL_REPO_DIR ${pkg_dir})
        # repos cloned to ${CAKE_PKG_REPOS_DIR} (as opposed to added with cake_add_subdirectory)
        # should be auto-installed in configuration time since they're not part of the project
      else()
        set(pkg_dir "${CAKE_PKG_${pkg_subdir}_LOCAL_REPO_DIR}")
      endif()
    endif()

    # if there's a cloned git repo there it's current commit
    # and the requested commit should be the same
    _cake_get_branch_from_options() # input: $options, output: $branch

    # if this package has already been traversed (= this function has been called
    # for this package in this cmake configuration session) then we don't want
    # to modify the commit of package's repo. We only check if
    # the existing commit is compatible with the requested one
    if(CAKE_PKG_${pkg_subdir}_TRAVERSED_BY_PKG_PULL_NOW)
        _cake_make_sure_repo_sha_compatible_with_requested_sha()
        return()
    endif()

    cake_set_session_var(CAKE_PKG_${pkg_subdir}_TRAVERSED_BY_PKG_PULL_NOW 1)

    if(NOT IS_DIRECTORY "${pkg_dir}")

      file(MAKE_DIRECTORY ${pkg_dir})

      # prepare parameters for git clone
      set(command_line clone)
      foreach(i ${options})
        if("${i}" MATCHES "^branch=(.+)$")
          list(APPEND command_line -b "${CMAKE_MATCH_1}")
        elseif("${i}" MATCHES "^depth=(.+)$")
          list(APPEND command_line --depth "${CMAKE_MATCH_1}")
        elseif("${i}" MATCHES "^(recursive|recurse-submodules)=(.*)$")
          if(CMAKE_MATCH_2)
            list(APPEND command_line --recursive)
          endif()
        endif()
      endforeach()

      # prepare command line for git clone
      list(APPEND command_line ${repo_url} ${pkg_dir})
      # git clone
      _cake_execute_git_command_in_repo("${command_line}" "" res_var)

      if(res_var)
        message(FATAL_ERROR "[cake] git clone failed")
      endif()
    else()
      set(need_fetch 0)
      if(branch)
        _cake_execute_git_command_in_repo("checkout;${branch}" "${pkg_dir}" _ git_result)
        if(git_result)
          set(need_fetch 1)
        endif()
      endif()

      if(NOT need_fetch AND pull_always)
          # git checkout succeeded (or not executed). If we're not on detached head then
          # we're on branch. If in that case pull_always is TRUE then we need to fetch
          # next git command gives error if detached HEAD
          _cake_execute_git_command_in_repo("symbolic-ref;-q;HEAD" "${pkg_dir}" _ git_result)
          if(NOT git_result) # not detached: on branch
            set(need_fetch 1)
          endif()
      endif()

      if(need_fetch)
        if(NOT pull_always)
          message(FATAL_ERROR "[cake] The commitish '${branch}' does not exist in the local ${repo_url} repository. It should be "
            "fetched either manually or by specifying -DCAKE_PKG_UPDATE_NOW=1")
        endif()
        _cake_execute_git_command_in_repo("fetch" "${pkg_dir}" _)
        if(branch)
          _cake_execute_git_command_in_repo("checkout;${branch}" "${pkg_dir}" _ git_result)
          if(git_result)
            message(FATAL_ERROR "[cake] The commitish '${branch}' does not exist in the local ${repo_url} repository even after fetch. ")
          endif()
        endif()
          # if we're not on detached HEAD do a git merge FETCH_HEAD
          _cake_execute_git_command_in_repo("symbolic-ref;-q;HEAD" "${pkg_dir}" _ git_result)
          if(NOT git_result) # not detached: on branch
            _cake_execute_git_command_in_repo("merge;--ff-only;FETCH_HEAD" "${pkg_dir}" _)
          endif()
      endif()
    endif()
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

  function(_cake_pkg_install pkg_url)
    cake_parse_pkg_url(${pkg_url} repo_url pkg_subdir options definitions)

    if(CAKE_PKG_${pkg_subdir}_ADDED_AS_SUBDIRECTORY)
      cake_message(STATUS "The package ${repo_url} has already been added as subdirectory, skipping installation. "
        "The consumer of this package (${CMAKE_CURRENT_SOURCE_DIR}) must be prepared to use the package as a target as opposed to"
        " a package found by find_package() or cake_find_package().")
      return()
    endif()

    set(pkg_dir ${CAKE_PKG_REPOS_DIR}/${pkg_subdir})

    _cake_execute_git_command_in_repo("log;-1;--pretty=format:%H" "${pkg_dir}" repo_sha)
    set(build_pars_now "COMMIT=${repo_sha};${definitions}")

    # if we've already installed this in this session just make sure the
    # current build settings are compatible with the first time's build settings
    if(CAKE_PKG_${pkg_subdir}_TRAVERSED_BY_PKG_INSTALL_NOW)
      _cake_are_build_par_lists_compatible(CAKE_PKG_${pkg_subdir}_LAST_BUILD_PARS build_pars_now)
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

    cake_set_session_var(CAKE_PKG_${pkg_subdir}_TRAVERSED_BY_PKG_INSTALL_NOW 1)
    cake_set_session_var(CAKE_PKG_${pkg_subdir}_LAST_BUILD_PARS "${build_pars_now}")

    # find dependencies:
    # - try to run the repo's cake-depends.cmake
    # - if no cake-depends.cmake consult the cake pkg db and run that script if found
    set(cake_depends_cmake_file "${pkg_dir}/cake-depends.cmake")
    set(randomfile "")
    if(NOT EXISTS "${cake_depends_cmake_file}" AND DEFINED CAKE_DEPENDS_DB_${pkg_subdir})
      string(RANDOM randomfile)
      set(randomfile "${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_tmp/${randomfile}")
      file(WRITE "${randomfile}" "${CAKE_DEPENDS_DB_${pkg_subdir}}")
      set(cake_depends_cmake_file "${randomfile}")
    endif()

    if(EXISTS "${cake_depends_cmake_file}")
      set(CAKE_DEFINITIONS ${definitions})
      # _call_cake_depends executes either the cake-depends.script or
      # or the script defined in the cake-depends-db*.cmake
      # The script usually contains cake_pkg(INSTALL ...) calls which
      # fetch and install dependencies
      _call_cake_depends("${cake_depends_cmake_file}")
    endif()

    if(randomfile)
      file(REMOVE "${randomfile}")
    endif()

    # now configure and build the install target of this package with cmake

    if(NOT CAKE_PKG_CONFIGURATION_TYPES)
      message(FATAL_ERROR "[cake] CAKE_PKG_CONFIGURATION_TYPES is empty. It should be left undefined (then defaults to 'Release') or set to valid values.")
    endif()

    foreach(c ${CAKE_PKG_CONFIGURATION_TYPES})
      # read pars of last build (install)
      set(last_build_pars_path ${CAKE_PKG_LAST_BUILD_PARS_DIR}/${pkg_subdir}_${c})
      unset(last_build_pars)
      if(EXISTS "${last_build_pars_path}")
        file(STRINGS "${last_build_pars_path}" last_build_pars)
      else()
        set(last_build_pars "COMMIT=")
      endif()

      _cake_are_build_par_lists_compatible(last_build_pars build_pars_now)

      if(NOT ans) # last install is non-existent or outdated

        cake_message(STATUS "Building the install target (${c}) for package ${pkg_url}")

        # remove pars from last build
        set(first_par 1)
        unset(unset_definitions)
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
        set(binary_dir ${CAKE_PKG_BUILD_DIR}/${pkg_subdir}_${c})
        set(command_line
            -H${pkg_dir} -B${binary_dir}
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

  # cake_pkg(CLONE|UPDATE) -> clone or update only
  # cake_pkg(INSTALL) -> execute DEPENDS script if found then build install target
  # cake_find_package() -> no-op if subdir, otherwise cake_pkg(INSTALL) + find_package
  # cake_add_subdirectory -> cake_pkg(CLONE) + execute depends script if found + add_subdirectory() which
  #     executes the package's cmakelists which can pull down further dependencies with cake_find_package calls

  function(cake_pkg)

    cmake_parse_arguments(CAKE_PKG "CLONE;INSTALL;UPDATE" "URL;DESTINATION" "" ${ARGV})

    if(NOT CAKE_PKG_URL)
      message(FATAL_ERROR "[cake] Missing URL.")
    endif()

    set(CAKE_PKG_REPOS_DIR ${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_repos)
    set(CAKE_PKG_BUILD_DIR ${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_build)
    set(CAKE_PKG_LAST_BUILD_PARS_DIR ${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_last_build_pars)

    if(CAKE_PKG_UPDATE_NOW OR CAKE_PKG_UPDATE)
      set(_cake_pull_now 1)
    else()
      set(_cake_pull_now 0)
    endif()
    
    _cake_pkg_pull(${CAKE_PKG_URL} ${_cake_pull_now} "${CAKE_PKG_DESTINATION}")

    if(CAKE_PKG_INSTALL)
      _cake_pkg_install(${CAKE_PKG_URL})
    endif()

  endfunction()

  macro(cake_load_pkg_db)
    FILE(GLOB _cake_db_files ${CAKE_ROOT}/cake-depends-db*.cmake)
    foreach(i ${_cake_db_files})
      include("${i}")
    endforeach()
  endmacro()

# ---- run-once code ----

  find_package(Git REQUIRED)

  if(CAKE_PKG_UPDATE_NOW)
    cake_set_session_var(CAKE_PKG_UPDATE_NOW 1)
  endif()

  cake_load_pkg_db()

endif()

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
  if(NOT CAKE_PKG_BUILD_DIR)
    message(FATAL_ERROR "[cake] Internal error, CAKE_PKG_BUILD_DIR must not be empty.")
  endif()

  cake_repo_db_get_field_by_pk(destination "${pk}")
  set(destination "${ans}")
  cake_repo_db_get_field_by_pk(cid "${pk}")
  set(cid "${ans}")
  cake_repo_db_get_field_by_pk(shortcid "${pk}")
  set(shortcid "${ans}")
  # check if destination is a subdirectory
  if(CAKE_PKG_${cid}_ADDED_AS_SUBDIRECTORY)
    cake_message(STATUS "The package ${repo_url} has already been added as subdirectory, skipping installation. "
      "The consumer of this package (${CMAKE_CURRENT_SOURCE_DIR}) must be prepared to use the package as a target as opposed to"
      " a package found by find_package() or cake_find_package().")
    return()
  endif()

  _cake_execute_git_command_in_repo("log;-1;--pretty=format:%H" "${destination}" repo_sha)

  # call cmake configure
  _cake_get_project_var(EFFECTIVE CMAKE_ARGS)
  set(cmake_args ${ans})

  _cake_get_project_var(EFFECTIVE CMAKE_GENERATOR)
  if(ans)
    list(APPEND cmake_args -G "${ans}")
  endif()

  _cake_get_project_var(EFFECTIVE CMAKE_GENERATOR_TOOLSET)
  if(ans)
    list(APPEND cmake_args -T "${ans}")
  endif()

  _cake_get_project_var(EFFECTIVE CMAKE_GENERATOR_PLATFORM)
  if(ans)
    list(APPEND cmake_args -A "${ans}")
  endif()

  _cake_get_project_var(EFFECTIVE CMAKE_INSTALL_PREFIX)
  if(ans)
    list(APPEND cmake_args "-DCMAKE_INSTALL_PREFIX=${ans}")
  endif()

  _cake_get_project_var(EFFECTIVE CMAKE_PREFIX_PATH)
  if(ans)
    string(REPLACE ";" "\;" ans "${ans}")
    list(APPEND cmake_args "-DCMAKE_PREFIX_PATH=${ans}")
  endif()

  set(build_pars_now "")
  foreach(c ${definitions} ${cmake_args})
    if(c MATCHES "^-D[^=]+=.*$")
      string(REPLACE ";" "\;" c "${c}")
      list(APPEND build_pars_now "${c}")
    endif()
  endforeach()
  cake_list_sort_unique_keep_nested_lists(SORT build_pars_now) # canonical ordering
  set(build_pars_now "COMMIT=${repo_sha}" "${build_pars_now}")

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
      _cake_update_last_build_time("${shortcid}")
      return()
    endif()
  endif()

  cake_set_session_var(CAKE_PKG_${cid}_TRAVERSED_BY_PKG_INSTALL_NOW 1)
  cake_set_session_var(CAKE_PKG_${cid}_LAST_BUILD_PARS "${build_pars_now}")

  # execute the repo's cake-install-deps.cmake script, if exists
    # otherwise try to execute the script (CODE) registered to the name

  cake_repo_db_get_field_by_pk(name "${pk}")
  set(name "${ans}")

  set(CAKE_LAST_BUILD_TIME_SAVED "${CAKE_LAST_BUILD_TIME}")
  cake_set_session_var(CAKE_LAST_BUILD_TIME "")

  _cake_include_cake_install_deps(
    "${destination}/cake-install-deps.cmake"
    "${cid}" "${name}" "${definitions}")

  set(dependencies_last_build_time "${CAKE_LAST_BUILD_TIME}")
  cake_set_session_var(CAKE_LAST_BUILD_TIME "${CAKE_LAST_BUILD_TIME_SAVED}")

  # now configure and build the install target of this package with cmake
  _cake_get_project_var(EFFECTIVE CAKE_PKG_CONFIGURATION_TYPES)
  set(configuration_types "${ans}")

  cake_repo_db_get_project_title("${pk}")
  set(project_title "${ans}")

  foreach(c ${configuration_types})
    # read pars of last build (install)
    set(last_build_pars_path ${CAKE_PKG_BUILD_DIR}/${shortcid}_${c}/cake_pkg_last_build_pars.txt)
    set(last_build_pars "")
    if(EXISTS "${last_build_pars_path}")
      file(TIMESTAMP "${last_build_pars_path}" last_build_time UTC)
      file(STRINGS "${last_build_pars_path}" last_build_pars) # reads semicolons as backslash+semicolon, that's good
    else()
      set(last_build_pars "COMMIT=")
      set(last_build_time "")
    endif()

    if(
      (NOT dependencies_last_build_time STRLESS last_build_time) OR
      (NOT last_build_pars STREQUAL build_pars_now) # last install is non-existent or outdated
    )
      cake_message(STATUS "Building the install target (${c}) for package ${project_title}")

      # remove pars from last build
      set(unset_definitions "")
      foreach(i ${last_build_pars})
        if(i MATCHES "^-D([^=]+)=.*$")
          set(varname "${CMAKE_MATCH_1}")
          # check if this variable is not set
          set(found 0)
          foreach(j ${build_pars_now})
            if(j MATCHES "^-D([^=]+)=.*$")
              if(CMAKE_MATCH_1 STREQUAL varname)
                set(found 1)
                break()
              endif()
            endif()
          endforeach()
          if(NOT found)
            list(APPEND unset_definitions "-U${varname}")
          endif()
        endif()
      endforeach()

      set(command_line
          "-DCMAKE_BUILD_TYPE=${c}"
          "-DCAKE_ROOT=${CAKE_ROOT}"
          "${cmake_args}"
          "${unset_definitions}"
          "${definitions}"
          "-DCAKE_PKG_LOAD_THE_SESSION_VARS=${CAKE_PKG_SESSION_VARS_FILE}"
          "${destination}"
      )

      set(binary_dir ${CAKE_PKG_BUILD_DIR}/${shortcid}_${c})
      cake_message(STATUS "cd ${binary_dir}")
      cake_list_to_command_line_like_string(s "${command_line}")
      cake_message(STATUS "cmake ${s}")
      file(MAKE_DIRECTORY "${binary_dir}")
      cake_save_session_vars()
      execute_process(COMMAND ${CMAKE_COMMAND} ${command_line}
        RESULT_VARIABLE res_var
        WORKING_DIRECTORY "${binary_dir}")
      if(res_var)
        message(FATAL_ERROR "[cake] CMake configuration failed, check the previous lines for the actual error.")
      endif()

      # call cmake build
      _cake_get_project_var(EFFECTIVE CMAKE_NATIVE_TOOL_ARGS)
      if(ans)
        set(native_tool_string -- ${ans})
      else()
        set(native_tool_string "")
      endif()

      set(command_line
        --build "${binary_dir}"
        --target install
        --config ${c}
        ${native_tool_string}
        )
      cake_list_to_command_line_like_string(s "${command_line}")
      cake_message(STATUS "cmake ${s}")
      execute_process(
        COMMAND ${CMAKE_COMMAND} ${command_line}
        RESULT_VARIABLE res_var)
      if(res_var)
        message(FATAL_ERROR "[cake] CMake build failed, check the previous lines for the actual error.")
      endif()

      # update last build pars
      set(s "")
      foreach(i ${build_pars_now})
        set(s "${s}${i}\n")
      endforeach()
      file(WRITE "${last_build_pars_path}" "${s}")
    else()
      cake_message(STATUS "Configuration '${c}' already installed from commit ${repo_sha} with same definitions, skipping build.")
    endif()
  endforeach()

  _cake_update_last_build_time("${shortcid}")

endfunction()

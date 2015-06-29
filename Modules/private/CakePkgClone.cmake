macro(_cake_remove_if_stale pk_var)
  cake_repo_db_get_field_by_pk(destination "${${pk_var}}")
  if(NOT EXISTS "${ans}")
    cake_repo_db_get_field_by_pk(shortcid "${${pk_var}}")
    set(_cris_shortcid "${ans}")
    cake_repo_db_erase_by_pk("${${pk_var}}")
    set(${pk_var} "")
    # erase binary dirs
    file(GLOB _cris_g "${CAKE_PKG_BUILD_DIR}/${_cris_shortcid}_*")
    foreach(_cris_i ${_cris_g})
      if(IS_DIRECTORY "${_cris_i}")
        file(REMOVE_RECURSE "${_cris_i}")
      endif()
    endforeach()
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
  else()
    file(MAKE_DIRECTORY "${dn}") # does not exist
    set(ans 1)
  endif()
endmacro()

# pkg_url is the full, decorated URL (with optional query part to specify key-value pairs)
# destination can be empty (= calculate destination under CAKE_PKG_CLONE_DIR)
#   or non-empty (= this packaged has been added by a cake_add_subdirectory() call and will be part of the CMake project)
# if destination is empty, since the package will not be built as a part of the CMake project (not a subdirectory)
# group is the the resolved group (either specified or default)
# name is the specified name
# returns (ans) the cloned repo's primary key
function(_cake_pkg_clone pkg_url destination group name branch)
  if(NOT name AND NOT pkg_url)
    message(FATAL_ERROR "[cake_pkg]: Internal error, neither pkg_url nor name is specified in _cake_pkg_clone.")
  endif()

  if(name AND CAKE_PKG_REGISTRY_${name}_URL)
    set(pkg_url "${CAKE_PKG_REGISTRY_${name}_URL}")
  endif()

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

  # following hack is to solve for example "c:/" != "C:/" problems
  if(destination)
    get_filename_component(destination "${destination}" ABSOLUTE)
  endif()
  if(existing_destination)
    get_filename_component(existing_destination "${existing_destination}" ABSOLUTE)
  endif()

  if(existing_destination)
    # nothing to do, if no explicit destination specified, or it's the same as previous
    if(NOT destination OR destination STREQUAL existing_destination)
      set(ans "${pk}" PARENT_SCOPE)
      return()
    else()
      message(FATAL_ERROR "[cake_pkg] The repository ${repo_url} has already been cloned to "
        "${existing_destination}, the current request is to clone it to ${destination}. This sitatuation "
        "usually comes up when a repository is cloned as an external dependency to an automatic location "
        "then later you add the same repository as a subdirectory to your project. Possible solution: "
        "add this repository as subdirectory before all other references to it. You also need to remove "
        "the current clone manually, either by removing the directory ${existing_destination} or by calling "
        "'cakepkg REMOVE ...'.")
    endif()
  endif()

  if(pkg_url)
    cake_parse_pkg_url("${pkg_url}" repo_url url_cid options _)
  else()
    if(name)
      message(FATAL_ERROR "[cake_pkg]: Looking up the package name ${name} failed.")
    else()
      message(FATAL_ERROR "[cake_pkg]: Internal error, pkg_url or name should be set at this point.")
    endif()
  endif()

  cake_get_humanish_part_of_url("${repo_url}")
  get_filename_component(f "${ans}" NAME)
  string(RANDOM LENGTH 2 ALPHABET 0123456789 r)
  set(shortcid "${f}_${r}")
  
  if(NOT destination)
    # last dir of url + random
    _cake_get_project_var(EFFECTIVE CAKE_PKG_CLONE_DIR)
    set(resolved_destination "${ans}/${shortcid}")
  else()
    if(NOT IS_ABSOLUTE "${destination}")
      message(FATAL_ERROR "[cake_pkg] internal error, destination must be absolute.")
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
  if(NOT branch)
    foreach(i ${options})
      if(i MATCHES "^branch=(.+)$")
        set(branch "${CMAKE_MATCH_1}")
      endif()
    endforeach()
  endif()
  if(branch)
    list(APPEND command_line -b "${branch}")
  endif()

  list(APPEND command_line --recursive)
  _cake_get_project_var(EFFECTIVE CAKE_PKG_CLONE_DEPTH)
  set(clone_depth "${ans}")
  if(NOT clone_depth)
    if(destination)
      set(clone_depth 0)
    else()
      set(clone_depth 1)
    endif()
  endif()
  if(NOT clone_depth EQUAL 0)
    list(APPEND command_line --depth "${clone_depth}" --no-single-branch) # clone at depth but fetch all the branches
  endif()

  # prepare command line for git clone
  list(APPEND command_line "${repo_url}" "${resolved_destination}")
  # git clone
  _cake_execute_git_command_in_repo("${command_line}" "" res_var)

  if(res_var)
    message(FATAL_ERROR "[cake_pkg] git clone failed")
  endif()

  # find out the revision what we've just cloned
  execute_process(COMMAND ${GIT_EXECUTABLE} symbolic-ref -q --short HEAD
    WORKING_DIRECTORY ${resolved_destination}
    OUTPUT_VARIABLE o
    ERROR_VARIABLE e
    RESULT_VARIABLE r
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  if(r EQUAL 0)
    # HEAD is a symbolic ref
    set(branch "${o}")
  elseif(r EQUAL 1)
    # detached head
    execute_process(COMMAND ${GIT_EXECUTABLE} rev-parse HEAD
      WORKING_DIRECTORY ${resolved_destination}
      OUTPUT_VARIABLE o
      ERROR_VARIABLE e
      RESULT_VARIABLE r
      OUTPUT_STRIP_TRAILING_WHITESPACE)
      if(r)
        message(FATAL_ERROR "[cake_pkg] 'git rev-parse HEAD' returned ${r} (${e})")
      else()
        set(branch "${o}")
      endif()
  else()
    message(FATAL_ERROR "[cake_pkg] 'git symbolic-ref -q --short HEAD' returned ${r} (${e}).")
  endif()

  cake_repo_db_next_pk()

  set(pk "${ans}")

  cake_repo_db_add_fields(${pk}
    cid "${url_cid}"
    url "${repo_url}"
    group "${group}"
    name "${name}"
    destination "${resolved_destination}"
    branch "${branch}"
    shortcid "${shortcid}")

  set(ans "${pk}" PARENT_SCOPE)

endfunction()

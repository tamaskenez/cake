include(CMakePrintHelpers)

if(NOT CAKE_PKG_REGISTRIES_INCLUDED)
  set(CAKE_PKG_REGISTRIES_INCLUDED 1)

  function(_cake_load_pkg_registries)

    _cake_get_project_var(EFFECTIVE CAKE_PKG_REGISTRIES)

    set(cpr "${ans}")

    foreach(r ${cpr})
      string(MAKE_C_IDENTIFIER "${r}" cid)
      if(EXISTS "${r}")
        if(IS_DIRECTORY "${r}")
          message(FATAL_ERROR "[cake] Registry file ${r} is a directory.")
        else()
          set(filename "${r}")
        endif()
      else()
        set(filename "${CAKE_PROJECT_DIR}/.cake/registry_cache/${cid}")
        if(NOT EXISTS "${filename}")
          message(STATUS "[cake] Downloading ${r}")
          file(DOWNLOAD "${r}" "${filename}" SHOW_PROGRESS)
        endif()
      endif()
      include("${filename}")
    endforeach()  
  endfunction()

endif()

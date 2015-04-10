if(NOT CAKE_PRIVATE_SESSION_INCLUDED)
  set(CAKE_PRIVATE_SESSION_INCLUDED 1)

  if(NOT CAKE_INCLUDED)
    message(FATAL_ERROR "[cake] Include Cake.cmake, don't include this file directly.")
  endif()

  if(NOT CAKE_LOAD_CONFIG_INCLUDED)
    include(${CMAKE_CURRENT_LIST_DIR}/CakeLoadConfig.cmake)
  endif()

  # there is run-once code after the definitions
  macro(cake_set_session_var name value)
    set(${name} "${value}" CACHE INTERNAL "")
    list(APPEND CAKE_PKG_SESSION_VARS ${name})
    list(SORT CAKE_PKG_SESSION_VARS)
    list(REMOVE_DUPLICATES CAKE_PKG_SESSION_VARS)
    set(CAKE_PKG_SESSION_VARS "${CAKE_PKG_SESSION_VARS}" CACHE INTERNAL "")
    set(_s "")
    foreach(i ${CAKE_PKG_SESSION_VARS})
      set(_s "${_s}set(${i} \"${${i}}\" CACHE INTERNAL \"\")\n")
    endforeach()
    set(_s "${_s}set(CAKE_PKG_SESSION_VARS \"${CAKE_PKG_SESSION_VARS}\" CACHE INTERNAL \"\")\n")
    file(WRITE "${CAKE_PKG_SESSION_VARS_FILE}" "${_s}")
  endmacro()

  macro(cake_clear_session_vars)
    foreach(i ${CAKE_PKG_SESSION_VARS})
      unset(${i} CACHE)
    endforeach()
    unset(CAKE_PKG_SESSION_VARS CACHE)
  endmacro()

  # run-once code

  # this assumes CakeLoadConfig has been loaded
  set(CAKE_PKG_SESSION_VARS_FILE "${CAKE_PKG_INSTALL_PREFIX}/var/cake_pkg_session_vars.cmake")

  cake_clear_session_vars()
  if(CAKE_PKG_LOAD_THE_SESSION_VARS)
    unset(CAKE_PKG_LOAD_THE_SESSION_VARS CACHE)
    include("${CAKE_PKG_SESSION_VARS_FILE}")
  else()
    file(REMOVE "${CAKE_PKG_SESSION_VARS_FILE}")
  endif()

  # session variables
  # CAKE_PKG_${pkg_subdir}_ADDED_AS_SUBDIRECTORY
  # CAKE_PKG_${pkg_subdir}_LOCAL_REPO_DIR
  # CAKE_PKG_${pkg_subdir}_TRAVERSED_BY_PKG_PULL_NOW
  # CAKE_PKG_${pkg_subdir}_TRAVERSED_BY_PKG_INSTALL_NOW

endif()

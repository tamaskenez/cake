if(NOT CAKE_PRIVATE_UTILS_INCLUDED)

  set(CAKE_PRIVATE_UTILS_INCLUDED 1)

  set(CAKE_MESSAGE_KEYWORDS STATUS WARNING AUTHOR_WARNING SEND_ERROR FATAL_ERROR DEPRECATION)

  # helper for cake_message
  function(cake_message2 _cm_first _cm_second)
    message("${_cm_first}" "[cake] ${_cm_second}" ${ARGN})
  endfunction()

  # like regular message() but prints [cake] prefix
  function(cake_message _cm_first)
    list(FIND CAKE_MESSAGE_KEYWORDS "${_cm_first}" idx)
    if(idx EQUAL -1)
      message("[cake] ${_cm_first}" ${ARGN})
    else()
      cake_message2("${_cm_first}" ${ARGN})
    endif()
  endfunction()

  function(cake_list_to_command_line_like_string var_out)
    set(s "")
    foreach(i ${ARGN})
      if(NOT (s STREQUAL ""))
        set(s "${s} ")
      endif()
      string(REPLACE ";" "\;" i "${i}")
      string(FIND "${i}" " " idx)
      if(idx EQUAL -1)
        set(s "${s}${i}")
      else()
        set(s "${s}\"${i}\"")
      endif()
    endforeach()
    set(${var_out} "${s}" PARENT_SCOPE)
  endfunction()

endif()

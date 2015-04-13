if(NOT CAKE_INCLUDED)

  # Some global Cake variables are not created on cache but as normal CMake variables
  # To keep things simple we force to include Cake at the top-level of the source tree.
  # Of course this makes sense only when not in script mode
  if(NOT DEFINED CMAKE_SCRIPT_MODE_FILE AND (NOT CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_HOME_DIRECTORY))
    message(FATAL_ERROR "Include Cake.cmake from the top-level CMakeLists.txt first.")
  endif()

  # make sure the CAKE_ROOT CMake variable is set correctly
  if(NOT "${CMAKE_CURRENT_LIST_DIR}" STREQUAL "${CAKE_ROOT}")
    set(CAKE_ROOT "${CMAKE_CURRENT_LIST_DIR}" CACHE PATH "Cake install directory" FORCE)
  endif()

  set(CAKE_INCLUDED 1)
  include(${CMAKE_CURRENT_LIST_DIR}/Modules/CakePrivateSession.cmake) # loads the config in turn and the session vars
  include(${CMAKE_CURRENT_LIST_DIR}/Modules/CakeAddSubdirectory.cmake)
  include(${CMAKE_CURRENT_LIST_DIR}/Modules/CakeFindPackage.cmake)
endif()

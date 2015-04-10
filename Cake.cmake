if(NOT CAKE_INCLUDED)

  # Some global Cake variables are not created on cache but as normal CMake variables
  # To keep things simple we force to include Cake at the top-level of the build tree.
  # If no CMAKE_HOME_DIRECTORY then we're invoked in script mode and that's also fine.
  if(CMAKE_HOME_DIRECTORY AND (NOT CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_HOME_DIRECTORY))
    message(FATAL_ERROR "Include Cake.cmake from the top-level CMakeLists.txt first.")
  endif()

  set(CAKE_INCLUDED 1)
  include(${CMAKE_CURRENT_LIST_DIR}/Modules/CakePrivateSession.cmake) # loads the config in turn and the session vars
  include(${CMAKE_CURRENT_LIST_DIR}/Modules/CakeAddSubdirectory.cmake)
  include(${CMAKE_CURRENT_LIST_DIR}/Modules/CakeFindPackage.cmake)
endif()

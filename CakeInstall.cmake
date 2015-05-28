# Cake install script
# ===================
#
# Git-clones the Cake repository into ${CMAKE_CURRENT_LIST_DIR}
# and sets CAKE_ROOT in cache
#
# Usage:
# ------
#
# There are 3 options to install Cake:
#
# 1. Install Cake in the CMakeLists.txt to the project's binary dir.
#    This is the recommended option for single-project scenarios which
#    contain only one repository you actively work on
#    
# 2. Install Cake in the init-script of your project to the project's top directory
#    This is recommended for master projects containing multiple sub-repositories
#    you actively work on
#
# 3. Install Cake to a user or system location.
#    Choose this if you need to have only one Cake installation
#
# Instructions:
# -------------
#
# 1. Install Cake in the CMakeLists.txt to the project's binary dir:
#
# - Put the following script into your (top) CmakeLists.txt:
#
#    if(NOT EXISTS "${CAKE_ROOT}/Cake.cmake")
#        file(DOWNLOAD https://github.com/tamaskenez/cake/blob/master/CakeInstall.cmake ${CMAKE_BINARY_DIR})
#        include(${CMAKE_BINARY_DIR}/CakeInstall.cmake)
#    endif()
#    include(${CAKE_ROOT}/Cake.cmake)
#
# The script downloads the single-file Cake install script (this one) which in turn
# clones the Cake repository into the (top) binary directory and sets the CAKE_ROOT cache variable
#
# 2. Install Cake in the init-script of your project to the project's top directory
#
# - put these line into your init-script (assuming it's executed in your project's dir)
#
#     export CAKE_ROOT=$PWD/cake_root
#     if test ! -f "$CAKE_ROOT/Cake.cmake" ; then
#         curl https://raw.githubusercontent.com/tamaskenez/cake/master/CakeInstall.cmake -o CakeInstall.cmake
#         cmake -P CakeInstall.cmake     
#     fi
# 
# The script makes sure Cake is installed to ./cake_root and sets the CAKE_ROOT the environment variable.
# In your CMakeLists.txt you can use it directly::
#
#     include($ENV{CAKE_ROOT}/Cake.cmake) # automatically sets the CAKE_ROOT cache var
#
# 3. Install Cake to a user or system location:
#
# - cd into the directory you want to install cake to
# - execute the shell command:
#
#     wget https://github.com/tamaskenez/cake/blob/master/CakeInstall.cmake && cmake -P CakeInstall.cmake
#     

find_package(Git REQUIRED)
set(CAKE_ROOT ${CMAKE_CURRENT_LIST_DIR}/cake_root CACHE PATH "Cake install directory" FORCE)
file(REMOVE_RECURSE ${CAKE_ROOT})
if(DEFINED CMAKE_SCRIPT_MODE_FILE)
  message("Set the CAKE_ROOT environment variable to ${CAKE_ROOT}")
else()
  message(STATUS "CAKE_ROOT set to ${CAKE_ROOT}")
endif()
set(CAKE_GIT_URL https://github.com/tamaskenez/cake)
message(STATUS "git clone --depth 1 ${CAKE_GIT_URL} ${CAKE_ROOT}")
execute_process(
      COMMAND ${GIT_EXECUTABLE} clone
        --depth 1 ${CAKE_GIT_URL}
        --branch feature/project
        ${CAKE_ROOT}
      RESULT_VARIABLE _cake_git_result_variable)
if(_cake_git_result_variable)
  message(FATAL_ERROR "[cake] Failed to clone the Cake repository")
endif()
if(NOT EXISTS ${CAKE_ROOT}/Cake.cmake)
  message(FATAL_ERROR "[cake] Git-clone was successful but Cake.cmake is missing")
endif()
file(REMOVE ${CMAKE_CURRENT_LIST_FILE})

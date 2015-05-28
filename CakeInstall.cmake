# Cake install script
# ===================
#
# Git-clones the Cake repository into ${CMAKE_CURRENT_LIST_DIR}/cake_root
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
#        file(DOWNLOAD https://raw.githubusercontent.com/tamaskenez/cake/master/CakeInstall.cmake ${CMAKE_BINARY_DIR})
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
# In your CMakeLists.txt use the CAKE_ROOT environment variable to find Cake::
#
#     include($ENV{CAKE_ROOT}/Cake.cmake) # also sets the CAKE_ROOT cache variable to $ENV{CAKE_ROOT} in turn
#
# 3. Install Cake to a user or system location:
#
# - cd into the directory you want to install cake to
# - execute the shell command:
#
#     curl https://raw.githubusercontent.com/tamaskenez/cake/master/CakeInstall.cmake -o CakeInstall.cmake && cmake -P CakeInstall.cmake
#     

# set CAKE_ROOT and verify existing environment variable
set(CAKE_ROOT ${CMAKE_CURRENT_LIST_DIR}/cake_root CACHE PATH "Cake install directory" FORCE)
file(TO_CMAKE_PATH "$ENV{CAKE_ROOT}" _CAKE_ROOT_FROM_ENV)
if(_CAKE_ROOT_FROM_ENV AND NOT _CAKE_ROOT_FROM_ENV STREQUAL CAKE_ROOT)
  message(FATAL_ERROR "[cake] The CAKE_ROOT environment variable set to $ENV{CAKE_ROOT} which is different from ${CAKE_ROOT} where CakeInstall.cmake intends to install Cake to. Remove CAKE_ROOT from the environment and re-run CakeInstall.cmake.")
endif()

# remove existing installation
file(REMOVE_RECURSE ${CAKE_ROOT})

message("Installing Cake to ${CAKE_ROOT}")

if(CAKE_INSTALL_FULL_CLONE)
  set(_cake_depth_flags "")
  set(_cake_depth_flags_string "")
else()
  set(_cake_depth_flags --depth 1)
  set(_cake_depth_flags_string "--depth 1 ")
endif()

message(STATUS "[cake] git clone ${_cake_depth_flags_string}${CAKE_GIT_URL} ${CAKE_ROOT}")

find_package(Git REQUIRED)
set(CAKE_GIT_URL https://github.com/tamaskenez/cake)

execute_process(
      COMMAND ${GIT_EXECUTABLE} clone
        ${_cake_depth_flags}
        ${CAKE_GIT_URL}
        ${CAKE_ROOT}
      RESULT_VARIABLE _cake_git_result_variable)

if(_cake_git_result_variable)
  message(FATAL_ERROR "[cake] Failed to clone the Cake repository")
endif()
if(NOT EXISTS ${CAKE_ROOT}/Cake.cmake)
  message(FATAL_ERROR "[cake] Git-clone was successful but Cake.cmake is missing")
endif()

file(REMOVE ${CMAKE_CURRENT_LIST_FILE})

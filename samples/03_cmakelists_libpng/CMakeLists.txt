cmake_minimum_required(VERSION 3.0)
project(sample03 NONE)

include(CmakePrintHelpers)

# the cake command sets CAKE_ROOT
# set it manually when using cmake directly
include(${CAKE_ROOT}/Cake.cmake)

# clone and build the 'install' target of the libpng package
# also clones and installs zlib, the dependency of libpng
# the dependency information is stored in cake-depends-db.txt
# in the root of the cake installation
cake_find_package(PNG REQUIRED URL git://git.code.sf.net/p/libpng/code?depth=1)

cmake_print_variables(PNG_INCLUDE_DIRS PNG_LIBRARIES PNG_DEFINITIONS)

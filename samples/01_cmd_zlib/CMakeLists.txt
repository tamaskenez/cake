cmake_minimum_required(VERSION 3.0)
project(sample01 NONE)

include(CmakePrintHelpers)

find_package(ZLIB REQUIRED)

cmake_print_variables(ZLIB_INCLUDE_DIRS ZLIB_LIBRARIES ZLIB_DEFINITIONS)

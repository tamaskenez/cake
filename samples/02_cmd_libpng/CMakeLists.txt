cmake_minimum_required(VERSION 3.0)
project(sample02 NONE)

include(CmakePrintHelpers)

find_package(PNG REQUIRED)

cmake_print_variables(PNG_INCLUDE_DIRS PNG_LIBRARIES PNG_DEFINITIONS)

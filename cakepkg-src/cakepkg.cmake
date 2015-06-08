#     cakepkg [options]
#
# See the documentation in CakePkg.cmake

cmake_minimum_required(VERSION 3.1)

file(TO_CMAKE_PATH "${CAKE_CURRENT_DIRECTORY}" CAKE_CURRENT_DIRECTORY)

get_filename_component(CAKE_ROOT ${CMAKE_CURRENT_LIST_DIR}/.. ABSOLUTE)

include(${CAKE_ROOT}/Cake.cmake)

# CMAKE_ARGV0: cmake.exe (full path)
# CMAKE_ARGV[x]: -P, x >= 1
# CMAKE_ARGV[x+1]: path to this file
# CMAKE_ARGV[x+2]: first actual arg
# CMAKE_ARGV[CMAKE_ARGC-1]: last actual arg
math(EXPR last_arg_idx "${CMAKE_ARGC}-1")
foreach(i RANGE 1 ${last_arg_idx})
	if("${CMAKE_ARGV${i}}" STREQUAL "-P")
		math(EXPR this_file_path_idx "${i}+1")
		math(EXPR first_arg_idx "${i}+2")
		set(this_file_path "${CMAKE_ARGV${this_file_path_idx}}")
		break()
	endif()
endforeach()

# parse args

if(first_arg_idx GREATER last_arg_idx) # no args after cmake ... -P <path>
	# print help
	file(STRINGS ${CAKE_ROOT}/Modules/CakePkg.cmake v)
	foreach(i ${v})
		string(FIND "${i}" "#" idx)
		if(NOT idx EQUAL 0)
			break()
		endif()
		string(SUBSTRING "${i}" 1 -1 i)
		message("${i}")
	endforeach()
	return()
endif()

unset(CAKE_PKG_ARGS)
foreach(i RANGE ${first_arg_idx} ${last_arg_idx})
	string(REPLACE ";" "\;" j "${CMAKE_ARGV${i}}")
  list(APPEND CAKE_PKG_ARGS "${j}")
endforeach()

cake_pkg(${CAKE_PKG_ARGS})

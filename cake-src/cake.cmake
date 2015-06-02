#     cake [options] <cmake-source-dir>
#
# The `cake` command applies the project settings specified in the Cake
# project file (``cake-project.cmake``) then executes one of the
# following operations:
#
# - calls `cmake` configuration or build steps
# - launches `cmake-gui` or the IDE
#
# The `cake` commands accepts most of the options `cake` accepts so
# you can use `cake` as a drop-in replacement of `cmake`.
# One important difference is that you don't need to specify the binary
# directory, it will be created to an automatic location,
# see the CAKE_BINARY_DIR_PREFIX variable below.
#
# The Cake scripts also implement a lightweight package and repository manager.
# It provides support to download and install packages (libraries), manage
# the dependencies and the repositories.
# Certain project settings control the package manager functionality.
# For more information see the documentation for the `cake_pkg` command.
#
# Options
# =======
#
# [options] can be either the standard CMake configuration options (see CMake documentation)
# or Cake-specific options.
#
# CMake configuration options accepted:
#
#     -C <initial-cache>
#     -D <var>[:<type>]=<value>
#     -U <globbing-expr>
#     -G <generator-name>
#     -T <toolset-name>
#     -A <platform-name>
#     -W[no-]dev
#     -N
#     --debug-trycompile
#     --debug-output
#     --trace
#     --warn-uninitialized
#     --warn-unused-vars
#     --no-warn-unused-cli
#     --check-system-vars
#
# Note: all parametrized options can also be written in one word,
# without space-separator: '-D key=val' and '-Dkey=val'
#
# Cake-specific options for the generator step:
#
#     --rm-bin
#         remove the binary dir before calling `cmake`
#     -c <cfg>, --config <cfg>
#         specifies which configuration to generate
#         (for single-config generators like `make`)
#         or which opt_configs to build (for multi-config
#         generators like `XCode`)
#         <cfg> is one of Debug, Release, ReleaseWithDebInfo, MinSizeRel
#         You can also specify multiple opt_configs:
#         -c Release -c ReleaseWithDebInfo
#     -R, --debug-release
#         same as -c Debug -c Release
#     --ide
#         open the project in the IDE (currently Xcode or Visual Studio)
#     --gui
#         run cmake-gui
#
# Options for the build step:
# (minor differences from cmake --build, for the rest, see cmake --build documentation)
#
#     -b, --build
#         build default target (all)
#         note: no parameter
#     -t <target>, --target=<target>
#         build specific target (implies -b)
#         note: you can specify multiple targets:
#         -t tgt1 -t tgt2
#     -n, --install
#         shortcut for --target=install
#     --clean-first
#     --use-stderr
#     -- <native-tool-options>
#         see cmake --build docs
#         note: to build you need to specify either -b or -t
#
# Note: all parametrized options can be written in one word,
# without space space-separator: '-t mytarget' and '-tmytarget'.
# The long form can be written with space instead of '=':
# '--target mytarget' and '--target=mytarget'
#
# Cake project file
# =====================
#
# You need to specify project settings in a ``cake-project.cmake``
# file or use the default project settings.
# Certain project settings (like CMAKE_INSTALL_PREFIX) can also be
# specified on the command line. The command line takes precedence in
# those cases.
#
# The ``cake-project.cmake`` file is searched in the current directory
# and above.
# If the CAKE_PROJECT_DIR environment variable is set it will be
# considered as project directory even if there's no ``cake-project.cmake``
# file in that directory. The default values will be used for
# all project settings.
# 
# After loading ``cake-project.cmake`` the command also attempts to load
# ``cake-project-user.cmake`` from the same directory. This file can
# contain settings specific to the local machine and should no be put
# under version control.
#
# The ``cake-project.cmake`` and ``cake-project-user.cmake`` files usually
#  contains ``set(<var> <value>)`` commands but may contain any CMake script.
#
# When configuring a CMake project without `cake` (i.e. running `cmake` directly)
# and the CAKE_PROJECT_DIR is not set, the CMAKE_HOME_DIRECTORY will be
# used instead of the current directory for searching the ``cake-project.cmake``
# file.
#
# Cake project settings
# =====================
#
# Following is the list of the Cake project configuration variables
# that can be set in the ``cake-project.cmake`` file (all variables
# must be normal, non-cache CMake variables):
#
# Usual CMake settings:
#
# - CMAKE_GENERATOR, CMAKE_GENERATOR_TOOLSET and CMAKE_GENERATOR_PLATFORM:
#   they correspond to `cmake` options -G, -A and -T
# - CMAKE_INSTALL_PREFIX, CMAKE_PREFIX_PATH (can be a list)
# - CMAKE_ARGS: any option that can be passed to `cmake`
# - CMAKE_NATIVE_TOOL_ARGS: options passed to the native build tool
#   (options after '--' when invoking ``cmake --build``)
#
# Note: You can specify any options with CMAKE_ARGS including options
# listed here (CMAKE_GENERATOR, etc..) but certain settings
# are easier to set and modify using the standalone variables.
#
# These options can be overridden on the `cake` command line, too.
#
# Cake settings:
#
# - CAKE_BINARY_DIR_PREFIX: the binary directory of the project will
#   be created under this directory. The default value is ${CAKE_PROJECT_DIR}/build
# 
# Cake package settings:
# 
# - CAKE_PKG_CONFIGURATION_TYPES: list of configuration values (Debug, Release).
#   The installed packages (see `cake_pkg`) will be built and installed in
#   these configurations. Default value is ``Release``.
# - CAKE_PKG_PROJECT_DIR: by default the installed packages will be configured
#   with the same project settings as the project that installs them.
#   You can specify another project (for example, your local package library in
#   your user directory. This allows sharing the same packages between projects.
# - CAKE_PKG_CLONE_DIR: Package sources will be cloned into this directory, if
#   not specified otherwise. Default value: ${CAKE_PROJECT_DIR}/clone.
# - CAKE_PKG_REGISTRIES: List of package registry files (local or URLs) containing
#   a list of cake_pkg(REGISTER ...) commands that may describe URLs, dependency
#   information and other data for packages.
#   For example, you can store a package registry file on your local git server
#   which lists all the packages available on the server. You can later install
#   them by name instead of URL.
# - CAKE_PKG_CLONE_DEPTH:
#   For the ``cake_pkg(INSTALL|CLONE ...)`` commands this variable controls the
#   depth parameter of the ``git clone --depth <d>`` command.
#   Set to zero to clone at unlimited depth. If undefined or empty the default
#   behaviour will be used, which is to
#   - clone with ``--depth=1`` when cloning to an automatic location (that is,
#     the DESTINATION parameter is not specified)
#   - clone at unlimited depth when cloning to a specific location (that is, the
#     DESTINATION parameter is set, including, for example, when
#     `cake_add_subdirectory` calls ``cake_PKG(CLONE ...)``.

cmake_minimum_required(VERSION 3.1)

get_filename_component(CAKE_ROOT ${CMAKE_CURRENT_LIST_DIR}/.. ABSOLUTE)
file(TO_CMAKE_PATH "${CAKE_CURRENT_DIRECTORY}" CAKE_CURRENT_DIRECTORY)

include(${CAKE_ROOT}/Modules/private/CakePrivateUtils.cmake)

unset(opt_source_dir) # source dir specified on the command line
unset(opt_binary_dir) # binary dir specified on the command line

# for parameterized options (like -D <par>) it takes 2 iterations
# to parse the option
# this is set to -D after parsing -D, etc..
unset(last_switch)

unset(cake_options) # options from the command line, except (source, bin) directories and options after '--'
unset(cake_native_tool_options) # options from the command line, the ones after '--'
unset(past_double_dash) # true after we're past '--'
unset(opt_ide) # --ide was specified
unset(opt_gui) # --gui was specified
unset(need_build_step) # if -b or -t was specified

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
	file(STRINGS ${this_file_path} v)
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

unset(CAKE_ARGS)
foreach(i RANGE ${first_arg_idx} ${last_arg_idx})
  list(APPEND CAKE_ARGS ${CMAKE_ARGV${i}})
endforeach()

list(GET CAKE_ARGS 0 CAKE_ARGV0)
if("${CAKE_ARGV0}" STREQUAL "pkg")
	set(CAKE_PKG_ARGS ${CAKE_ARGS})
	list(REMOVE_AT CAKE_PKG_ARGS 0)
	include(${CMAKE_CURRENT_LIST_DIR}/cake_pkg.cmake)
	return()
endif()


# parse command-line options
# group them to cake_options, cake_native_tool_options, opt_ide, opt_gui, need_build_step
foreach(i RANGE ${first_arg_idx} ${last_arg_idx})
	set(a "${CMAKE_ARGV${i}}") # current argument
	if(past_double_dash)
		list(APPEND cake_native_tool_options "${a}")
	elseif(a STREQUAL "--")
		if(last_switch)
			message(FATAL_ERROR "[cake] Missing argument after '${last_switch}'")
		else()
			set(past_double_dash 1)
		endif()
	elseif(last_switch)
		if(last_switch MATCHES "^(-C|-D|-U|-G|-T|-c|--config|-t|--target)$")
			list(APPEND cake_options ${last_switch} "${a}")
		else()
			message(FATAL_ERROR "[cake] Internal error, invalid last_switch: '${last_switch}'")
		endif()
		unset(last_switch)
	else()
		if(a MATCHES "^(-C|-D|-U|-G|-T|-c|--config|-t|--target)$")
			set(last_switch "${a}")
		elseif(a MATCHES "^(-C|-D|-U|-G|-T|-c|--config=|-t|--target=)(.*)$")
			string(REPLACE ";" "\;" a "${a}")
			list(APPEND cake_options "${a}")
		elseif(a MATCHES "^(-W(no-)?dev|-N|--rm-bin|-R|--debug-release|-n|--install|--clean-first|--use-stderr|--debug-trycompile|--debug-output|--trace|--warn-uninitialized|--warn-unused-vars|--no-warn-unused-cli|--check-system-vars)$")
			list(APPEND cake_options "${a}")
		elseif(a STREQUAL "--ide")
			set(opt_ide 1)
		elseif(a STREQUAL "--gui")
			set(opt_gui 1)
		elseif(a MATCHES "^(-b|--build)$")
			set(need_build_step 1)
		else()
			if(EXISTS ${a}/CMakeLists.txt)
				list(APPEND opt_source_dir ${a})
			else()
				list(APPEND opt_binary_dir ${a})
			endif()
		endif()
	endif()
endforeach()

if(last_switch)
	message(FATAL_ERROR "[cake] Last option '${last_switch}' missing parameter.")
endif()

# validate source and bin dir args
list(LENGTH opt_source_dir ls)
list(LENGTH opt_binary_dir lb)
math(EXPR lsb "${ls} + ${lb}")
if(lsb EQUAL 0)
	message(FATAL_ERROR "[cake] No directory specified, specify either source or binary dir (or both).")
endif()
if(ls GREATER 1)
	message(FATAL_ERROR "[cake] Multiple source directories specified.")
endif()
if(lb GREATER 1)
	message(FATAL_ERROR "[cake] Multiple binary directories specified.")
endif()

unset(cake_source_dir)
if(opt_source_dir)
	get_filename_component(cake_source_dir "${opt_source_dir}" ABSOLUTE)
endif()

unset(binary_dir_from_args)
if(opt_binary_dir)
	get_filename_component(CAKE_BINARY_DIR ${opt_binary_dir} ABSOLUTE)
	if(NOT opt_source_dir)
		# retrieve source dir from CMakeCache.txt
		if(NOT EXISTS ${CAKE_BINARY_DIR}/CMakeCache.txt)
			message(FATAL_ERROR "[cake] No source dir specified and binary dir (${CAKE_BINARY_DIR}) does not contain CMakeCache.txt to obtain the associated source dir.")
		endif()
		file(STRINGS ${CAKE_BINARY_DIR}/CMakeCache.txt v REGEX "CMAKE_HOME_DIRECTORY")
		string(REGEX MATCH "^[\t ]*CMAKE_HOME_DIRECTORY:INTERNAL=(.*)$" v ${v})
		set(cake_source_dir ${CMAKE_MATCH_1})
		if(NOT cake_source_dir)
			message(FATAL_ERROR "[cake] No source dir specified, and no CMAKE_HOME_DIRECTORY found when parsing ${CAKE_BINARY_DIR}/CMakeCache.txt.")
		endif()
		if(NOT EXISTS "${cake_source_dir}")
			message(FATAL_ERROR "[cake] No source dir specified, and parsing CMAKE_HOME_DIRECTORY from ${CAKE_BINARY_DIR}/CMakeCache.txt yielded a non-existent source dir: '${cake_source_dir}'.")
		endif()
		if(NOT EXISTS "${cake_source_dir}/CMakeLists.txt")
			message(FATAL_ERROR "[cake] No source dir specified, and parsing CMAKE_HOME_DIRECTORY from ${CAKE_BINARY_DIR}/CMakeCache.txt yielded the source dir '${cake_source_dir}' where no CMakeLists.txt can be found.")
		endif()
	endif()
	set(binary_dir_from_args 1)
endif()

if(NOT EXISTS "${cake_source_dir}/CMakeLists.txt")
	message(FATAL_ERROR "[cake] Internal error: at this point we should have a valid cake_source_dir")
endif()

cake_message(STATUS "Source dir: '${cake_source_dir}'")

include(${CMAKE_CURRENT_LIST_DIR}/set_cake_tmp_dir.cmake)

# load config from env vars
include(${CAKE_ROOT}/Modules/private/CakeProject.cmake)

       
     
_cake_get_project_var(EFFECTIVE CMAKE_ARGS)
set(CAKE_ARGS "${ans}")

_cake_get_project_var(EFFECTIVE CMAKE_GENERATOR)
if(ans)
	list(APPEND CAKE_ARGS "-G${ans}")
endif()

_cake_get_project_var(EFFECTIVE CMAKE_GENERATOR_TOOLSET)
if(ans)
	list(APPEND CAKE_ARGS "-T${ans}")
endif()

_cake_get_project_var(EFFECTIVE CMAKE_GENERATOR_PLATFORM)
if(ans)
	list(APPEND CAKE_ARGS "-A${ans}")
endif()

_cake_get_project_var(EFFECTIVE CMAKE_INSTALL_PREFIX)
if(ans)
	list(APPEND CAKE_ARGS "-DCMAKE_INSTALL_PREFIX=${ans}")
endif()

_cake_get_project_var(EFFECTIVE CMAKE_PREFIX_PATH)
if(ans)
	list(APPEND CAKE_ARGS "-DCMAKE_PREFIX_PATH=${ans}")
endif()

list(APPEND CAKE_ARGS "${cake_options}")

_cake_get_project_var(EFFECTIVE CMAKE_NATIVE_TOOL_ARGS)
set(CAKE_NATIVE_TOOL_ARGS "${ans}")

list(APPEND CAKE_NATIVE_TOOL_ARGS "${cake_native_tool_options}")

# initialize variables for parsing the options in CAKE_ARGS

unset(need_generate_step) # if generate step is needed
unset(opt_build) # list of args for the build step
unset(opt_generate) # options for the generation step
unset(opt_targets) # list specific targets to build (collected list of parameters to -t|--target)
unset(opt_configs) # configs to generate or build (Debug, Release, etc..) (collected list of parameters to -c|--config)
unset(opt_rm_bin) # --rm-bin was specified

# parse CAKE_ARGS
# also remember the last value of -G and -DCMAKE_BUILD_TYPE options
unset(last_switch)
unset(cmake_generator_from_command_line)
unset(cmake_build_type)
foreach(a ${CAKE_ARGS})
	if(last_switch)
		if(last_switch MATCHES "^(-A|-C|-D|-U|-G|-T)$")
			list(APPEND opt_generate ${last_switch} "${a}")
			if(last_switch STREQUAL "-G")
				set(cmake_generator_from_command_line "${a}")
			elseif(last_switch STREQUAL "-D" AND a MATCHES "^CMAKE_BUILD_TYPE(:.*)?=(.*)$")
				set(cmake_build_type ${CMAKE_MATCH_2})
			endif()
		elseif(last_switch MATCHES "^(-c|--config)$")
			handle_opt_config("${a}")
		elseif(last_switch MATCHES "^(-t|--target)$")
			handle_opt_target("${a}")
		else()
			message(FATAL_ERROR "[cake] Internal error, invalid last_switch: '${last_switch}'")
		endif()
		unset(last_switch)
	else()
		if(a MATCHES "^(-A|-C|-D|-U|-G|-T|-c|--config|-t|--target)$")
			set(last_switch ${a})
		elseif(a MATCHES "^(-A|-C|-D|-U|-G|-T)(.*)$")
			string(REPLACE ";" "\;" a "${a}")
			list(APPEND opt_generate "${a}")
			if(a MATCHES "^-G(.+)$")
				set(cmake_generator_from_command_line ${CMAKE_MATCH_1})
			elseif(a MATCHES "^-DCMAKE_BUILD_TYPE(:.*)=(.*)$")
				set(cmake_build_type "${CMAKE_MATCH_2}")
			endif()
		elseif(a MATCHES "^(-W(no-)?dev|-N|--debug-trycompile|--debug-output|--trace|--warn-uninitialized|--warn-unused-vars|--no-warn-unused-cli|--check-system-vars)$")
			list(APPEND opt_generate "${a}")
		elseif(a MATCHES "^--rm-bin$")
			set(opt_rm_bin 1)
		elseif(a MATCHES "^(-c|--config=)(.+)^")
			handle_opt_config("${CMAKE_MATCH_2")
		elseif(a MATCHES "^(-R|--debug-release)$")
			handle_opt_config(Debug)
			handle_opt_config(Release)
		elseif(a MATCHES "^(-t|--target=)(.+)^")
			handle_opt_target("${CMAKE_MATCH_2}")
		elseif(a MATCHES "^-n|--install$")
			handle_opt_target(install)
		elseif(a MATCHES "^(--clean-first|--use-stderr)$")
			list(APPEND opt_build "${a}")
		else()
			message(FATAL_ERROR "[cake] Invalid option: '${a}'")
		endif()
	endif()
endforeach()
if(last_switch)
	message(FATAL_ERROR "[cake] Last option '${last_switch}' missing parameter.")
endif()


if(opt_configs)
	list(REMOVE_DUPLICATES opt_configs)
endif()
if(opt_targets)
	list(REMOVE_DUPLICATES opt_targets)
endif()

if(cmake_build_type)
	if(opt_configs)
		message(FATAL_ERROR "[cake] Both CMAKE_BUILD_TYPE and -c|--config specified. Set only one of them.")
	else()
		set(opt_configs "${cmake_build_type}")
	endif()
endif()

# settle on CAKE_BINARY_DIR
if(NOT CAKE_BINARY_DIR)
	_cake_get_project_var(EFFECTIVE CAKE_BINARY_DIR_PREFIX)
	set(CAKE_BINARY_DIR_PREFIX "${ans}")

	file(RELATIVE_PATH proj_to_src_path "${CAKE_PROJECT_DIR}" "${cake_source_dir}")

	get_filename_component(src_dir_name "${cake_source_dir}" NAME)

	if(proj_to_src_path MATCHES "^\\.\\.")
		string(MAKE_C_IDENTIFIER "${cake_source_dir}" cake_source_dir_cid)
		set(CAKE_BINARY_DIR "${CAKE_BINARY_DIR_PREFIX}/${cake_source_dir_cid}")
	elseif(proj_to_src_path STREQUAL "")
		set(CAKE_BINARY_DIR "${CAKE_BINARY_DIR_PREFIX}/${src_dir_name}")
	elseif(proj_to_src_path STREQUAL src_dir_name)
		set(CAKE_BINARY_DIR "${CAKE_BINARY_DIR_PREFIX}/${src_dir_name}_${src_dir_name}")
	else()
		string(MAKE_C_IDENTIFIER "${proj_to_src_path}" proj_to_src_path_cid)
		set(CAKE_BINARY_DIR "${CAKE_BINARY_DIR_PREFIX}/${proj_to_src_path_cid}")
	endif()
endif()

# try to load cmake_generator_from_cmakecache from the binary dir
if(NOT opt_rm_bin AND IS_DIRECTORY ${CAKE_BINARY_DIR} AND EXISTS ${CAKE_BINARY_DIR}/CMakeCache.txt)
	file(STRINGS ${CAKE_BINARY_DIR}/CMakeCache.txt v
		REGEX "CMAKE_GENERATOR")
	string(REGEX MATCH "^[\t ]*CMAKE_GENERATOR:INTERNAL=(.*)$" v ${v})
	set(cmake_generator_from_cmakecache ${CMAKE_MATCH_1})
endif()

if(cmake_generator_from_cmakecache)
	set(cmake_generator ${cmake_generator_from_cmakecache})
else()
	set(cmake_generator ${cmake_generator_from_command_line})
endif()

if(cmake_generator AND cmake_generator MATCHES "^(Visual Studio|Xcode)")
	set(ide_generator 1)
else()
	set(ide_generator 0)
endif()

if(opt_ide AND NOT ide_generator)
	if(cmake_generator_from_cmakecache)
		message(FATAL_ERROR "[cake] You specified the option '--ide' but the generator found in the existing binary dir is ${cmake_generator} which is not an IDE generator.")
	elseif(cmake_generator_from_command_line)
		message(FATAL_ERROR "[cake] You specified the option '--ide' but the requested generator (${cmake_generator}) is not an IDE generator.")
	else()
		message(FATAL_ERROR "[cake] You specified the option '--ide' but the default generator is to be determined by CMake in the initial configuration step. Configure first without '--ide' and re-run 'cake' with '--ide'.")
	endif()
endif()

list(LENGTH opt_configs config_count)
if(config_count GREATER 1)
	if(binary_dir_from_args)
		message(FATAL_ERROR "[cake] Multiple configs specified for a single binary dir")
	endif()
	if(opt_gui)
		message(FATAL_ERROR "[cake] Multiple configs specified with --gui")
	endif()
	if(opt_ide)
		message(FATAL_ERROR "[cake] Multiple configs specified with --ide")
	endif()
endif()

set(multi_config_generator ${ide_generator})

# generate lists of binary dirs, configs:
#     config_list.<num>.config = <Debug|Release|...>
#     config_list.<num>.binary_dir = <binary-dir, postfixed by config, if needed>
#     <num> = 1..config_list_size
if(opt_configs)
	set(config_list_size 0)
	foreach(c ${opt_configs})
		math(EXPR config_list_size "${config_list_size}+1")
		set(config_list.${config_list_size}.config ${c})
		if(multi_config_generator OR binary_dir_from_args)
			set(config_list.${config_list_size}.binary_dir ${CAKE_BINARY_DIR})
		else()
			set(config_list.${config_list_size}.binary_dir ${CAKE_BINARY_DIR}_${c})
		endif()
	endforeach()
else()
	set(config_list_size 1)
	unset(config_list.${config_list_size}.config)
	set(config_list.${config_list_size}.binary_dir ${CAKE_BINARY_DIR})
endif()

if(NOT DEFINED CAKE_GENERATE_ALWAYS OR CAKE_GENERATE_ALWAYS OR opt_generate OR NOT EXISTS ${CAKE_BINARY_DIR}/CMakeCache.txt OR opt_rm_bin)
	set(need_generate_step 1)
endif()

if(need_generate_step)
	foreach(i RANGE 1 ${config_list_size})
		if(need_generate_step)
			set(config ${config_list.${i}.config})
			set(binary_dir ${config_list.${i}.binary_dir})
			cake_message(STATUS "Binary dir: '${binary_dir}'")
			if(opt_rm_bin)
				cake_message(STATUS "Remove binary dir.")
				file(REMOVE_RECURSE ${binary_dir})
			endif()
			if(config AND NOT multi_config_generator)
				set(cbt "-DCMAKE_BUILD_TYPE=${config}")
			else()
				unset(cbt)
			endif()
			set(cmake_command_line
				"-DCAKE_ROOT=${CAKE_ROOT}"
				"-DCAKE_PROJECT_DIR=${CAKE_PROJECT_DIR}"
				"${opt_generate}"
				"${cbt}"
				"${cake_source_dir}"
			)
			file(MAKE_DIRECTORY "${binary_dir}")
			cake_message(STATUS "cd ${binary_dir}")
			cake_list_to_command_line_like_string(s "${cmake_command_line}")
			cake_message(STATUS "cmake ${s}")
			execute_process(COMMAND ${CMAKE_COMMAND}
				${cmake_command_line}
				RESULT_VARIABLE r
				#ERROR_VARIABLE e
				WORKING_DIRECTORY "${binary_dir}"
			)
			if(e)
				cake_message(STATUS "STDERR from the previous CMake configuration/generation run:")
				message("${e}")
			endif()
			if(r)
				message(FATAL_ERROR "[cake] CMake generate step failed, result: ${r}.")
			endif()
		endif()
	endforeach()
endif()

# start cmake-gui
if(opt_gui)
	# there must be only 1 config here (ensured a few lines above)
	if(WIN32)
		set(command_line cmd /C cmake-gui "${config_list.1.binary_dir}")
	else()
		set(command_line cmake-gui "${config_list.1.binary_dir}")
	endif()
	cake_list_to_command_line_like_string(s ${command_line})
	cake_message(STATUS ${s})
	execute_process(COMMAND ${command_line} RESULT_VARIABLE r)
	if(r)
		message(FATAL_ERROR "[cake] result: ${r}")
	endif()
endif()

# start IDE
if(opt_ide)
	if(NOT ide_generator)
		message(FATAL_ERROR "[cake] --ide specified for non-ide generator.")
	endif()
	if(cmake_generator MATCHES "^Visual Studio")
		file(GLOB v ${CAKE_BINARY_DIR}/*.sln)
		if(v)
			set(command_line cmd /C "${v}")
		else()
			message(FATAL_ERROR "[cake] Can't find *.sln file in '${CAKE_BINARY_DIR}'")
		endif()
	elseif(cmake_generator MATCHES "^Xcode")
		file(GLOB v ${CAKE_BINARY_DIR}/*.xcodeproj)
		if(v)
			set(command_line open "${v}")
		else()
			message(FATAL_ERROR "[cake] Can't find *.xcodeproj file in '${CAKE_BINARY_DIR}'")
		endif()
	else()
		message(FATAL_ERROR "[cake] Don't know how to start IDE for generator '${cmake_generator}'")
	endif()

	cake_list_to_command_line_like_string(s ${command_line})
	cake_message(STATUS "${s}")
	execute_process(COMMAND ${command_line}
		RESULT_VARIABLE r)
	if(r)
		message(FATAL_ERROR "[cake] error: ${c}")
	endif()
endif()

if(need_build_step)
	if(opt_targets)
		set(opt_target_for_loop ${opt_targets})
	else()
		set(opt_target_for_loop dummy)
		unset(target_option)
	endif()
	foreach(i RANGE 1 ${config_list_size})
		set(config ${config_list.${i}.config})
		set(binary_dir ${config_list.${i}.binary_dir})
		cake_message(STATUS "Running build tool for binary dir: '${binary_dir}'")
		if(config AND multi_config_generator)
			set(config_option --config ${config})
		else()
			unset(config_option)
		endif()
		foreach(t ${opt_target_for_loop})
			if(opt_targets)
				set(target_option --target ${t})
			endif()
			if(CAKE_NATIVE_TOOL_ARGS)
				set(maybe_two_dashes --)
			else()
				set(maybe_two_dashes "")
			endif()
			set(cmake_command_line
				--build "${binary_dir}"
				${target_option}
				${config_option}
				${opt_build}
				${maybe_two_dashes}
				${CAKE_NATIVE_TOOL_ARGS}
			)
			cake_list_to_command_line_like_string(s ${cmake_command_line})
			cake_message(STATUS "cmake ${s}")
			execute_process(COMMAND ${CMAKE_COMMAND}
				${cmake_command_line}
				RESULT_VARIABLE r
				ERROR_VARIABLE e
			)
			if(e)
				cake_message(STATUS "STDERR from the previous CMake build run:")
				cake_message("${e}")
			endif()
			if(r)
				message(FATAL_ERROR "[cake] CMake build step failed, result: ${r}.")
			endif()
		endforeach()
	endforeach()
endif()

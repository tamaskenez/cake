#     cake [options] <cmake-source-dir>|<cmake-binary-dir>
#
# You can specify either cmake-source-dir or cmake-binary dir
# or both.
#
# The cmake-source-dir must contain CMakeLists.txt. It may
# contain a .cakecfg.cmake file which contains the location
# of binary dir. This is set automatically in the first run
# of cake.
#
# The cmake-binary-dir can be a relative or absolute path.
# If it's relative it will be appended to the value of
# CAKE_BINARY_DIR_PREFIX which can be set by
# - env-var CAKE_BINARY_DIR_PREFIX, or in .cakecfg.cmake located in:
# - ${CAKE_ROOT} (cake install dir)
# - user home directory
# - cmake-source-dir
#
# If no cmake-binary-dir specified, the last component of the
# cake-source-dir will be used as a relative cake-binary-dir
# on the first run of cake.
#
# Standard CMake generator options (see cmake documentation):
#
#     -C <initial-cache>
#     -D <var>[:<type>]=<value>
#     -U <globbing-expr>
#     -G <generator-name>
#     -T <toolset-name>
#     -W[no-]dev
#     -N
#
# Note: all parametrized options can be written in one word,
# without space-separator: '-D key=val' and '-Dkey=val'
#
# Extra options for the generator step:
#
#     --rm-bin
#         remove the binary dir before calling cmake
#     -m <cmake-script>
#         path to a cmake script (cake module) containing further
#         options. If relative it will be searched
#         on the paths listed in CAKE_MODULE_PATH.
#         The cake module may set the following CMake variables:
#             CAKE_BINARY_DIR_PREFIX, CAKE_BINARY_DIR,
#             CAKE_OPTIONS, CAKE_NATIVE_TOOL_OPTIONS, CAKE_MODULE_PATH
#             CAKE_GENERATE_ALWAYS
#         - The value of the CAKE_OPTIONS, CAKE_NATIVE_TOOL_OPTIONS,
#           CAKE_MODULE_PATH will be appended to the list set by
#           other modules, config files and on the cake command line.
#         - CAKE_BINARY_DIR_PREFIX and CAKE_GENERATE_ALWAYS can be
#           set only at one place.
#         - The value of CAKE_BINARY_DIR will override less specific
#           values set previously: e.g. if it is set to a relative dir
#           in a module/config/command-line and to an absolute path in
#           in another location, the absolute path will be used.
#
# Other options:
#     -c <cfg>, --config <cfg>
#         specifies which configuration to generate
#         (for single-config generators like make)
#         or which opt_configs to build (for multi-config
#         generators like XCode)
#         <cfg> is one of Debug, Release, ReleaseWithDebInfo, MinSizeRel
#         You can also specify multiple opt_configs:
#         -c Release -c ReleaseWithDebInfo
#     -R, debug-release
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
#     -i, --install
#         shortcut for --target=install
#     --clean-first
#     --use-stderr
#     --
#         see cmake --build docs
#         note: you need to specify either -b or -t
#
# Note: all parametrized options can be written in one word,
# without space space-separator: '-t mytarget' and '-tmytarget'.
# The long form can be written with space instead of '=':
# '-=target mytarget' and '--target=mytarget'

cmake_minimum_required(VERSION 2.8)

include(${CMAKE_CURRENT_LIST_DIR}/public_vars.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/utils.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/private.cmake)

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
# CMAKE_ARGV[x+2]: sessionid
# CMAKE_ARGV[x+3]: first actual arg
# CMAKE_ARGV[CMAKE_ARGC-1]: last actual arg
math(EXPR last_arg_idx "${CMAKE_ARGC}-1")
foreach(i RANGE 1 ${last_arg_idx})
	if("${CMAKE_ARGV${i}}" STREQUAL "-P")
		math(EXPR this_file_path_idx "${i}+1")
		math(EXPR session_arg_idx "${i}+2")
		math(EXPR first_arg_idx "${i}+3")
		set(this_file_path "${CMAKE_ARGV${this_file_path_idx}}")
		break()
	endif()
endforeach()

# parse args
set(sessionid ${CMAKE_ARGV${session_arg_idx}})

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

# parse command-line options, mostly
# sort them to cake_options, cake_native_tool_options, opt_ide, opt_gui, need_build_step
foreach(i RANGE ${first_arg_idx} ${last_arg_idx})
	set(a "${CMAKE_ARGV${i}}") # current argument
	if(past_double_dash)
		list(APPEND cake_native_tool_options "${a}")
	elseif(a MATCHES "^--$")
		if(last_switch)
			cake_message(FATAL_ERROR "Missing argument after '${last_switch}'")
		else()
			set(past_double_dash 1)
		endif()
	elseif(last_switch)
		if(last_switch MATCHES "^(-C|-D|-U|-G|-T|-m|-c|--config|-t|--target)$")
			list(APPEND cake_options ${last_switch} "${a}")
		else()
			cake_message(FATAL_ERROR "Internal error, invalid last_switch: '${last_switch}'")
		endif()
		unset(last_switch)
	else()
		if(a MATCHES "^(-C|-D|-U|-G|-T|-c|--config|-t|--target|-m)$")
			set(last_switch "${a}")
		elseif(a MATCHES "^(-C|-D|-U|-G|-T|-m|-c|--config=|-t|--target=)(.*)$")
			list(APPEND cake_options "${a}")
		elseif(a MATCHES "^(-W(no-)?dev|-N|--rm-bin|-R|--debug-release|-i|--install|--clean-first|--use-stderr)$")
			list(APPEND cake_options "${a}")
		elseif(a MATCHES "^--ide$")
			set(opt_ide 1)
		elseif(a MATCHES "^--gui$")
			set(opt_gui 1)
		elseif(a MATCHES "^-b|--build$")
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
	cake_message(FATAL_ERROR "Last option '${last_switch}' missing parameter.")
endif()

# validate source and bin dir args
list(LENGTH opt_source_dir ls)
list(LENGTH opt_binary_dir lb)
math(EXPR lsb "${ls} + ${lb}")
if(lsb EQUAL 0)
	cake_message(FATAL_ERROR "No directory specified, specify either source or binary dir (or both).")
endif()
if(ls GREATER 1)
	cake_message(FATAL_ERROR "Multiple source directories specified.")
endif()
if(lb GREATER 1)
	cake_message(FATAL_ERROR "Multiple binary directories specified.")
endif()

unset(cake_source_dir)
if(opt_source_dir)
	get_filename_component(cake_source_dir "${opt_source_dir}" ABSOLUTE)
endif()
# otherwise we need to obtain the source dir from the binary dir

# load defaults
include(${CAKE_ROOT}/src/cakecfg_default.cmake)

# load system config
load_config("${CAKE_ROOT}" root)

# load user config
unset(home)
if(IS_DIRECTORY "$ENV{HOME}")
	set(home "$ENV{HOME}")
elseif(IS_DIRECTORY "$ENV{HOMEDRIVE}$ENV{HOMEPATH}")
	set(home "$ENV{HOMEDRIVE}$ENV{HOMEPATH}")
endif()
if(home)
	load_config("${home}" user)
endif()

unset(binary_dir_from_args)
if(NOT cake_source_dir)
	# if at this point we don't have a source dir
	# we need to settle on a binary dir to be able
	# to find out the corresponding source dir
	if(NOT opt_binary_dir)
		cake_message(FATAL_ERROR "Internal error, neither source nor bin directory is available. Should have exited before.")
	endif()

	set(CAKE_BINARY_DIR ${opt_binary_dir}) # command-line may override anything
	set(binary_dir_from_args 1)

	# we have CAKE_BINARY_DIR
	if(NOT IS_ABSOLUTE "${CAKE_BINARY_DIR}")
		if(NOT CAKE_BINARY_DIR_PREFIX)
			if(NOT CAKE_TMP_DIR)
				cake_message(FATAL_ERROR "Temporary dir not found for generating binary dir. Specify CAKE_BINARY_DIR_PREFIX or absolute path for CAKE_BINARY_DIR.")
			endif()
			set(CAKE_BINARY_DIR ${CAKE_TMP_DIR})
		endif()
		set(CAKE_BINARY_DIR ${CAKE_BINARY_DIR_PREFIX}/${CAKE_BINARY_DIR})
	endif()

	# CAKE_BINARY_DIR must be an existing, configured binary dir
	# we need to extract source dir from CMakeCache.txt
	if(NOT IS_DIRECTORY "${CAKE_BINARY_DIR}")
		cake_message(FATAL_ERROR "No source dir specified and binary dir ${CAKE_BINARY_DIR} does not exist.")
	endif()
	if(NOT EXISTS "${CAKE_BINARY_DIR}/CMakeCache.txt")
		cake_message(FATAL_ERROR "No source dir specified and binary dir ${CAKE_BINARY_DIR} is not configured (CMakeCache.txt not found).")
	endif()

	# retrieve source dir from CMakeCache.txt
	file(STRINGS ${CAKE_BINARY_DIR}/CMakeCache.txt v REGEX "CMAKE_HOME_DIRECTORY")
	string(REGEX MATCH "^[\t ]*CMAKE_HOME_DIRECTORY:INTERNAL=(.*)$" v ${v})
	set(cake_source_dir ${CMAKE_MATCH_1})
	if(NOT cake_source_dir)
		cake_message(FATAL_ERROR "No source dir specified, and no CMAKE_HOME_DIRECTORY found while parsing ${CAKE_BINARY_DIR}/CMakeCache.txt.")
	endif()
endif()

# validate source dir
if(NOT EXISTS ${cake_source_dir}/CMakeLists.txt)
	cake_message(FATAL_ERROR "No CMakeLists.txt found in ${cake_source_dir}.")
endif()

cake_message(STATUS "Source dir: '${cake_source_dir}'")

# Load source dir config
load_config("${cake_source_dir}" "source dir")

# load session config
if(CAKE_TMP_DIR AND sessionid)
	load_config("${CAKE_TMP_DIR}/cakecfg.${sessionid}.cmake" session)
endif()

# load config from env vars
if(NOT "$ENV{CAKE_BINARY_DIR_PREFIX}" STREQUAL "")
	update_binary_dir_prefix("$ENV{CAKE_BINARY_DIR_PREFIX}" "CAKE_BINARY_DIR_PREFIX env-var")
endif()

if(NOT "$ENV{CAKE_BINARY_DIR}" STREQUAL "")
	update_binary_dir("$ENV{CAKE_BINARY_DIR}" "CAKE_BINARY_DIR env-var")
endif()

if(NOT "$ENV{CAKE_GENERATE_ALWAYS}" STREQUAL "")
	update_generate_always("$ENV{CAKE_GENERATE_ALWAYS}" "CAKE_GENERATE_ALWAYS env-var")
endif()

list(APPEND CAKE_OPTIONS $ENV{CAKE_OPTIONS})
list(APPEND CAKE_NATIVE_TOOL_OPTIONS $ENV{CAKE_NATIVE_TOOL_OPTIONS})
list(APPEND CAKE_MODULE_PATH $ENV{CAKE_MODULE_PATH})

# load binary dir
if(opt_binary_dir)
	# if there was no source dir, this has already been set to exactly this value
	# if there was a source dir, we override the value of CAKE_BINARY_DIR because
	# command-line always has priority
	set(CAKE_BINARY_DIR ${opt_binary_dir})
	set(binary_dir_from_args 1)
endif()

if(NOT CAKE_BINARY_DIR)
	get_filename_component(CAKE_BINARY_DIR "${cake_source_dir}" NAME)
endif()

if(NOT IS_ABSOLUTE "${CAKE_BINARY_DIR}")
	if(NOT CAKE_BINARY_DIR_PREFIX)
		if(NOT CAKE_TMP_DIR)
			cake_message(FATAL_ERROR "Temporary dir not found for generating binary dir. Specify CAKE_BINARY_DIR_PREFIX or absolute path for CAKE_BINARY_DIR.")
		endif()
		set(CAKE_BINARY_DIR_PREFIX ${CAKE_TMP_DIR})
	endif()
	set(CAKE_BINARY_DIR ${CAKE_BINARY_DIR_PREFIX}/${CAKE_BINARY_DIR})
endif()

# try to load cmake_generator_from_cmakecache from the binary dir
if(IS_DIRECTORY ${CAKE_BINARY_DIR})
	file(STRINGS ${CAKE_BINARY_DIR}/CMakeCache.txt v
		REGEX "CMAKE_GENERATOR")
	string(REGEX MATCH "^[\t ]*CMAKE_GENERATOR:INTERNAL=(.*)$" v ${v})
	set(cmake_generator_from_cmakecache ${CMAKE_MATCH_1})
endif()

# combine the options from the .cakecfg files with the ones
# specified on the command line
list(APPEND CAKE_OPTIONS ${cake_options})
list(APPEND CAKE_NATIVE_TOOL_OPTIONS ${cake_native_tool_options})

unset(opt_modules)

# load modules in multiple passes (a module can load another module)
while(1)
	list(LENGTH opt_modules opt_modules_size_before)
	collect_modules()
	list(LENGTH opt_modules opt_modules_size_after)
	if(opt_modules_size_after EQUAL opt_modules_size_before)
		break()
	endif()
endwhile()

# we have a final list of opt_modules, load them
load_modules(TRUE)

# initialize variables for parsing the options in CAKE_OPTIONS

unset(need_generate_step) # if generate step is needed
unset(opt_build) # list of args for the build step
unset(opt_generate) # options for the generation step
unset(opt_targets) # list specific targets to build (collected list of parameters to -t|--target)
unset(opt_configs) # configs to generate or build (Debug, Release, etc..) (collected list of parameters to -c|--config)
unset(opt_rm_bin) # --rm-bin was specified
unset(opt_modules2) # collect opt_modules again after we loaded the modules. It's an error for a module to specify a module

# parse CAKE_OPTIONS
# also remember the last value of -G and -DCMAKE_BUILD_TYPE options
unset(last_switch)
unset(cmake_generator_from_command_line)
unset(cmake_build_type)
foreach(a ${CAKE_OPTIONS})
	if(last_switch)
		if(last_switch MATCHES "^(-C|-D|-U|-G|-T)$")
			list(APPEND opt_generate ${last_switch} "${a}")
			if(last_switch MATCHES "^-G$")
				set(cmake_generator_from_command_line "${a}")
			elseif(last_switch MATCHES "^-D$" AND a MATCHES "^CMAKE_BUILD_TYPE(:.*)?=(.*)$")
				set(cmake_build_type ${CMAKE_MATCH_2})
			endif()
		elseif(last_switch MATCHES "^-m$")
			list(APPEND opt_modules2 "${a}")
		elseif(last_switch MATCHES "^(-c|--config)$")
			handle_opt_config("${a}")
		elseif(last_switch MATCHES "^(-t|--target)$")
			handle_opt_target("${a}")
		else()
			cake_message(FATAL_ERROR "Internal error, invalid last_switch: '${last_switch}'")
		endif()
		unset(last_switch)
	else()
		if(a MATCHES "^(-C|-D|-U|-G|-T|-c|--config|-t|--target|-m)$")
			set(last_switch ${a})
		elseif(a MATCHES "^(-C|-D|-U|-G|-T)(.*)$")
			list(APPEND opt_generate "${a}")
			if(a MATCHES "^-G(.+)$")
				set(cmake_generator_from_command_line ${CMAKE_MATCH_1})
			elseif(a MATCHES "^-DCMAKE_BUILD_TYPE(:.*)=(.*)$")
				set(cmake_build_type "${CMAKE_MATCH_2}")
			endif()
		elseif(a MATCHES "^-m(.*)$")
			list(APPEND opt_modules2 "${CMAKE_MATCH_1}")
		elseif(a MATCHES "^(-W(no-)?dev|-N)$")
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
		elseif(a MATCHES "^-i|--install$")
			handle_opt_target(install)
		elseif(a MATCHES "^(--clean-first|--use-stderr)$")
			list(APPEND opt_build "${a}")
		else()
			cake_message(FATAL_ERROR "Invalid option: '${a}'")
		endif()
	endif()
endforeach()
if(last_switch)
	cake_message(FATAL_ERROR "Last option '${last_switch}' missing parameter.")
endif()

if(opt_configs)
	list(REMOVE_DUPLICATES opt_configs)
endif()
if(opt_targets)
	list(REMOVE_DUPLICATES opt_targets)
endif()

if(cmake_build_type)
	if(opt_configs)
		cake_message(FATAL_ERROR "Both CMAKE_BUILD_TYPE and -c|--config specified. Set only one of them.")
	else()
		set(opt_configs "${cmake_build_type}")
	endif()
endif()

if(cmake_generator_from_cmakecache)
	set(cmake_generator ${cmake_generator_from_cmakecache})
else()
	set(cmake_generator ${cmake_generator_from_command_line})
endif()

if(cmake_generator AND cmake_generator MATCHES "Visual Studio|Xcode")
	set(ide_generator 1)
else()
	set(ide_generator 0)
endif()

if(opt_ide AND NOT ide_generator)
	cake_message(FATAL_ERROR "No IDE generator specified for option '--ide'.")
endif()

list(LENGTH opt_configs config_count)
if(config_count GREATER 1)
	if(binary_dir_from_args)
		cake_message(FATAL_ERROR "Multiple configs specified for a single binary dir")
	endif()
	if(opt_gui)
		cake_message(FATAL_ERROR "Multiple configs specified with --gui")
	endif()
	if(opt_ide)
		cake_message(FATAL_ERROR "Multiple configs specified with --ide")
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

if(NOT DEFINED CAKE_GENERATE_ALWAYS OR CAKE_GENERATE_ALWAYS OR opt_generate OR NOT IS_DIRECTORY ${CAKE_BINARY_DIR} OR opt_rm_bin)
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
				set(cbt -DCMAKE_BUILD_TYPE=\"${config}\")
			else()
				unset(cbt)
			endif()
			set(cmake_command_line
				cmake
				"-H${cake_source_dir}"
				"-B${binary_dir}"
				${opt_generate}
				${cbt}
			)
			list_to_command_line_like_string(s ${cmake_command_line})
			cake_message(STATUS "${s}")
			execute_process(COMMAND
				${cmake_command_line}
				RESULT_VARIABLE r
			)
			if(r)
				cake_message(FATAL_ERROR "CMake generate step failed.")
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
	list_to_command_line_like_string(s ${command_line})
	cake_message(STATUS ${s})
	execute_process(COMMAND ${command_line} RESULT_VARIABLE r)
	if(r)
		message(FATAL_ERROR "result: ${r}")
	endif()
endif()

# start IDE
if(opt_ide)
	if(NOT ide_generator)
		cake_message(FATAL_ERROR "--ide specified for non-ide generator.")
	endif()
	if(cmake_generator MATCHES "Visual Studio")
		file(GLOB v ${CAKE_BINARY_DIR}/*.sln)
		if(v)
			set(command_line cmd /C "${v}")
		else()
			cake_message(FATAL_ERROR "Can't find *.sln file in '${CAKE_BINARY_DIR}'")
		endif()
	elseif(cmake_generator MATCHES "Xcode")
		file(GLOB v ${CAKE_BINARY_DIR}/*.xcodeproj)
		if(v)
			set(command_line open "${v}")
		else()
			cake_message(FATAL_ERROR "Can't find *.xcodeproj file in '${CAKE_BINARY_DIR}'")
		endif()
	else()
		cake_message(FATAL_ERROR "Don't know how to start IDE for generator '${cmake_generator}'")
	endif()

	list_to_command_line_like_string(s ${command_line})
	cake_message(STATUS "${s}")
	execute_process(COMMAND ${command_line}
		RESULT_VARIABLE r)
	if(r)
		cake_message(FATAL_ERROR "error: ${c}")
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
			set(cmake_command_line
				cmake
				--build "${binary_dir}"
				${target_option}
				${config_option}
				${opt_build}
			)
			list_to_command_line_like_string(s ${cmake_command_line})
			cake_message(STATUS "${s}")
			execute_process(COMMAND
				${cmake_command_line}
				RESULT_VARIABLE r
			)
			if(r)
				cake_message(FATAL_ERROR "CMake build step failed.")
			endif()
		endforeach()
	endforeach()
endif()

# update source dir .cmakecfg.cmake with the binary dir, if needed
update_source_cmakecfg_with_binary_dir()
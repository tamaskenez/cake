# update CAKE_BINARY_DIR_PREFIX is it's still undefined
macro(update_binary_dir_prefix _ubdp_v _updb_source)
	if(NOT DEFINED CAKE_BINARY_DIR_PREFIX)
		set(CAKE_BINARY_DIR_PREFIX ${_ubdp_v})
	else()
		if(NOT "${CAKE_BINARY_DIR_PREFIX}" STREQUAL "${_ubdp_v}")
			cake_message(FATAL_ERROR "${_ubdp_source} is trying to override the value of CAKE_BINARY_DIR_PREFIX to ${_ubdp_v} which is already set to ${CAKE_BINARY_DIR_PREFIX}")
		endif()
	endif()
endmacro()

# update CAKE_BINARY_DIR to a more specific (undefined -> relative -> absolute) value
macro(update_binary_dir _ubdp_v _updb_source)
	if(NOT DEFINED CAKE_BINARY_DIR OR (NOT IS_ABSOLUTE "${CAKE_BINARY_DIR}" AND IS_ABSOLUTE "${_ubdp_v}"))
		set(CAKE_BINARY_DIR ${_ubdp_v})
	elseif((IS_ABSOLUTE "${CAKE_BINARY_DIR}" AND IS_ABSOLUTE "${_ubdp_v}") OR (NOT IS_ABSOLUTE "${CAKE_BINARY_DIR}" AND NOT IS_ABSOLUTE "${_ubdp_v}"))
		if(NOT "${CAKE_BINARY_DIR}" STREQUAL "${_ubdp_v}")
			cake_message(FATAL_ERROR "${_ubdp_source} is trying to override the value of CAKE_BINARY_DIR_PREFIX to ${_ubdp_v} which is already set to ${CAKE_BINARY_DIR_PREFIX}")
		endif()
	endif()
endmacro()

# update CAKE_GENERATE_ALWAYS is it's still undefined
macro(update_generate_always _ubdp_v _ubdp_source)
	if(NOT DEFINED CAKE_GENERATE_ALWAYS)
		set(CAKE_GENERATE_ALWAYS ${_ubdp_v})
	else()
		if((CAKE_GENERATE_ALWAYS AND NOT "${_ubdp_v}") OR (NOT CAKE_GENERATE_ALWAYS AND "${_ubdp_v}"))
			cake_message(FATAL_ERROR "${_ubdp_source} is trying to override the value of CAKE_GENERATE_ALWAYS to ${_ubdp_v} which is already set to ${CAKE_GENERATE_ALWAYS}")
		endif()
	endif()
endmacro()

set(_load_module_core_vars
	CAKE_BINARY_DIR_PREFIX
	CAKE_BINARY_DIR
	CAKE_OPTIONS
	CAKE_NATIVE_TOOL_OPTIONS
	CAKE_GENERATE_ALWAYS
	CAKE_MODULE_PATH)

function(load_module_core _lmc_path)
	foreach(i ${_load_module_core_vars})
		unset(${i})
	endforeach()
	include("${_lmc_path}")
	foreach(i ${_load_module_core_vars})
		if(DEFINED ${i})
			set(_lmc_${i} "${${i}}" PARENT_SCOPE)
		endif()
	endforeach()
endfunction()

# load a cake module containing cake variables
# apply the variables smartly (override or append)
macro(load_module _lm_path)
	foreach(i ${_load_module_core_vars})
		unset(_lmc_${i})
	endforeach()
	load_module_core("${_lm_path}")
	foreach(i ${_load_module_core_vars})
		if(DEFINED _lmc_${i})
			if(i MATCHES "^CAKE_BINARY_DIR_PREFIX$")
				update_binary_dir_prefix("${_lmc_${i}}" "${_lm_path}")
			elseif(i MATCHES "^CAKE_BINARY_DIR$")
				update_binary_dir("${_lmc_${i}}" "${_lm_path}")
			elseif(i MATCHES "^CAKE_GENERATE_ALWAYS$")
				update_generate_always("${_lmc_${i}}" "${_lm_path}")
			endif()
		endif()
	endforeach()
	list(APPEND CAKE_OPTIONS ${_lmc_CAKE_OPTIONS})
	list(APPEND CAKE_NATIVE_TOOL_OPTIONS ${_lmc_CAKE_NATIVE_TOOL_OPTIONS})
	list(APPEND CAKE_MODULE_PATH ${_lmc_CAKE_MODULE_PATH})
endmacro()

macro(load_config _lc_dir)
	if(EXISTS ${_lc_dir}/.cakecfg.cmake)
		cake_message(STATUS "Loading ${ARGV1} config '${_lc_dir}/.cakecfg.cmake'")
		load_module(${_lc_dir}/.cakecfg.cmake)
	endif()
endmacro()

# load modules
macro(load_modules _lm_log)
	foreach(m ${opt_modules})
		set(m_cmake ${m}.cmake)
		if(IS_ABSOLUTE "${m_cmake}")
			set(m_abs "${m_cmake}")
		else()
			unset(m_abs)
			foreach(p ${CAKE_MODULE_PATH})
				set(m_abs "${p}/${m_cmake}")
				if(EXISTS "${m_abs}" AND NOT IS_DIRECTORY "${m_abs}")
					break()
				else()
					unset(m_abs)
				endif()
			endforeach()
		endif()
		if(NOT EXISTS "${m_abs}")
			cake_message(FATAL_ERROR "Module '${m_cmake}' not found.")
		endif()
		if(IS_DIRECTORY "${m_abs}")
			cake_message(FATAL_ERROR "Module path '${m_cmake}' is a directory.")
		endif()
		if("${_lm_log}")
			get_filename_component(m_dir "${m_abs}" PATH)
			cake_message(STATUS "Loading cake module '${m}' from '${m_dir}'")
		endif()
		load_module("${m_abs}")
	endforeach()
endmacro()

macro(append_to_opt_modules _atom_m)
	list(FIND opt_modules "${_atom_m}" v)
	if(v EQUAL -1)
		list(APPEND opt_modules "${_atom_m}")
	endif()
endmacro()

# collect_modules
# - loads all the modules known so far
# - collects the new modules from -m options
# - sets parent scope opt_modules
function(collect_modules)
	# this function always starts with the unmodified variables, like CAKE_OPTIONS, CAKE_NATIVE_TOOL_OPTIONS
	# it will modify only the opt_modules of the parent scope

	# load modules known so far
	load_modules(FALSE)

	# parse options for -m and append to opt_modules
	unset(last_switch)
	foreach(a ${CAKE_OPTIONS})
		if(last_switch)
			if(last_switch MATCHES "^-m$")
				append_to_opt_modules("${a}")
			endif()
			unset(last_switch)
		else()
			if(a MATCHES "^(-C|-D|-U|-G|-T|-c|--config|-t|--target|-m)$")
				set(last_switch ${a})
			elseif(a MATCHES "^-m(.*)$")
				append_to_opt_modules("${CMAKE_MATCH_1}")
			endif()
		endif()
	endforeach()
	if(last_switch)
		cake_message(FATAL_ERROR "Last option '${last_switch}' missing parameter.")
	endif()

	set(opt_modules ${opt_modules} PARENT_SCOPE)
endfunction()

macro(handle_opt_target _ho_arg)
	set(need_build_step 1)
	list(APPEND opt_targets "${_ho_arg}")
endmacro()

macro(handle_opt_config _ho_arg)
	list(APPEND opt_configs "${_ho_arg}")
endmacro()

function(update_source_cmakecfg_with_binary_dir)
	set(CAKE_BINARY_DIR_PARENT_SCOPE "${CAKE_BINARY_DIR}")
	unset(CAKE_BINARY_DIR)
	set(cakecfg_path ${cake_source_dir}/.cakecfg.cmake)
	if(EXISTS ${cakecfg_path})
		include("${cakecfg_path}")
	endif()
	if(NOT "${CAKE_BINARY_DIR}" STREQUAL "${CAKE_BINARY_DIR_PARENT_SCOPE}")
		cake_message(STATUS "Updating ${cakecfg_path} with binary dir ${CAKE_BINARY_DIR_PARENT_SCOPE}")
		file(APPEND "${cakecfg_path}" "\nset(CAKE_BINARY_DIR \"${CAKE_BINARY_DIR_PARENT_SCOPE}\")\n")
	endif()
endfunction()

# for information about most of the variables see cakecfg_vars.cmake

unset(CAKE_TMP_DIR)
foreach(_i "$ENV{TMP}" "$ENV{TEMP}" "$ENV{TMPDIR}" "/tmp")
	if(IS_DIRECTORY "${_i}")
		set(CAKE_TMP_DIR "${_i}")
		break()
	endif()
endforeach()
if(CAKE_TMP_DIR)
	file(TO_CMAKE_PATH "${CAKE_TMP_DIR}" CAKE_TMP_DIR)
endif()

set(CAKE_MODULE_PATH "${CAKE_ROOT}/modules")

unset(CAKE_LINK_BINARY_DIR)
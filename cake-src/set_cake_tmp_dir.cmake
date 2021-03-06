# set CAKE_TMP_DIR to system temp dir or "" if not found

set(CAKE_TMP_DIR "")
foreach(_i "$ENV{TMP}" "$ENV{TEMP}" "$ENV{TMPDIR}" "/tmp")
	if(IS_DIRECTORY "${_i}")
		set(CAKE_TMP_DIR "${_i}")
		break()
	endif()
endforeach()
if(CAKE_TMP_DIR)
	file(TO_CMAKE_PATH "${CAKE_TMP_DIR}" CAKE_TMP_DIR)
endif()

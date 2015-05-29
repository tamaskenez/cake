rem forward arguments to cake.cmake
rem see help there

cmake "-DCAKE_CURRENT_DIRECTORY=%CD%" -P "%~d0\%~p0\..\cake-src\cake.cmake" %*

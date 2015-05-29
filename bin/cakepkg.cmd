rem forward arguments to cakepkg.cmake
rem see help there

cmake "-DCAKE_CURRENT_DIRECTORY=%CD%" -P "%~d0\%~p0\..\cakepkg-src\cakepkg.cmake" %*

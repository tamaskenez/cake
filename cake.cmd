rem forward arguments to cake.cmake
rem see help there

cmake -P %~d0\%~p0\src\cake.cmake 0 %*

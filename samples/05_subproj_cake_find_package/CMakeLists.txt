cmake_minimum_required(VERSION 3.1)
project(sample05)

include(${CAKE_ROOT}/Cake.cmake)

option(SUBPROJLIB_AS_SUBDIRECTORY "Use subrpojlib as subdirectory as opposed to external project" 0)
option(SUBPROJLIB_WITH_ZLIB "Build subprojlib with zlib" 0)

if(SUBPROJLIB_AS_SUBDIRECTORY)
  cake_add_subdirectory(subprojlib URL https://github.com/tamaskenez/cake-sample-subprojlib-cake-find-package)
endif()

# cake_find_package will be a no-op if SUBPROJLIB_AS_SUBDIRECTORY
cake_find_package(subprojlib REQUIRED
  URL https://github.com/tamaskenez/cake-sample-subprojlib-cake-find-package?-DSUBPROJLIB_WITH_ZLIB=${SUBPROJLIB_WITH_ZLIB})

add_executable(sample05 main.c)

target_link_libraries(sample05 PUBLIC subprojlib)

install(TARGETS sample05 DESTINATION bin)
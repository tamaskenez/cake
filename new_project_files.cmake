# ---- ./cake-project.cmake ----
set(CAKE_BINARY_DIR_PREFIX ${CMAKE_CURRENT_LIST_DIR}/build)
set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_LIST_DIR}.install)
set(CMAKE_PREFIX_PATH ${CMAKE_INSTALL_PREFIX})
set(CAKE_PKG_CONFIGURATION_TYPES Debug Release)
set(scm_reg_root https://scm.kishonti.net/raw/admin/kishonti_pkg_registry.git/master)
set(CAKE_PKG_REGISTRIES ${scm_reg_root}/dependencies.cmake ${scm_reg_root}/urls.cmake)

# ---- ./cake-install-deps.cmake ----
if(ME_WITH_PNG)
  cake_pkg(INSTALL NAME PNG)
endif()

# ---- ./user.cake-project.cmake ----
list(APPEND CMAKE_ARGS -G "Visual Studio 12 2013 Win64" -DBOOST_LIBRARYDIR=c:/Users/tamas.kenez/lib64)
list(APPEND CAKE_PREFIX_PATH ${HOME}/vs12_64_pkg/install)
set(CAKE_PKG_PROJECT_DIR ${HOME}/vs12_64_pkg)


# ---- ${HOME}/vs2013_64_pkg ----
set(CAKE_BINARY_DIR_PREFIX ${CMAKE_CURRENT_LIST_DIR}/build)
set(CAKE_SOURCE_DIR_PREFIX ${CMAKE_CURRENT_LIST_DIR}/src)
set(CMAKE_INSTALL_PREFIX ${CMAKE_CURRENT_LIST_DIR}/install)
set(CMAKE_PREFIX_PATH ${CAKE_INSTALL_PREFIX})
set(CAKE_PKG_CONFIGURATION_TYPES Debug Release)
set(scm_reg_root https://scm.kishonti.net/raw/admin/kishonti_pkg_registry.git/master)
set(CAKE_PKG_REGISTRIES ${scm_reg_root}/dependencies.cmake ${scm_reg_root}/urls.cmake)
set(CMAKE_ARGS -G "Visual Studio 12 2013 Win64")



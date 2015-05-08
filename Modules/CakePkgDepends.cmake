#.rst:
# CakePkgDepends
# -------
#
# CAKE_PKG_DEPENDS() describes the dependencies of a package when the package itself does not
# contain the ``cake-pkg-depends.cmake`` file.
#
# ::
#
#   CAKE_PKG_DEPENDS(URL <repo-url> | NAME <name>
#                    CODE <script-code> | SCRIPT <script-filename>)
#
# To install the dependencies of a package `Cake` looks for a ``cake-pkg-depends.cmake`` file in the root of the package's
# repository. If no such file found it looks up the package in an internal database. This database can be populated
# by the `CAKE_PKG_DEPENDS` commands.
#
# While you can call CAKE_PKG_DEPENDS anywhere from your CMakeLists.txt files, it's advised to use it only
# from the Cake configuration file, either directly or (recommended) by including a file containing CAKE_PKG_DEPENDS calls.
# The reason is that the dependency information the CAKE_PKG_DEPENDS calls describe must be available in all
# `cmake` child processes the ``cake_pkg(INSTALL ...)`` calls spawn.
# For information about the Cake configuration file, see `CakeLoadConfig.cmake`.
#
# Either the URL or the NAME parameter must be given (not both). The NAME parameter should be the same
# what you would call `find_package()` with. 
#
# The CODE option contains the script which installs the dependencies of the package. The alternative SCRIPT option
# defines a file containing the code.
#
# The install code/script defined with the `CAKE_PKG_DEPENDS` command behaves identically to the ``cake-pkg-depends.cmake``
# file:
# - it will be invoked (with `include()`) before building the ``install`` target of the package
# - the definitions you specify for the package will be available for the script, so you can set a script like this:
#
#    cake_pkg_depends(URL <mylib> CODE
#        "if (MYLIB_WITH_ZLIB)
#             cake_pkg(INSTALL NAME ZLIB)
#         endif()")
#
# Examples:
#
#    cake_pkg_depends(URL git://git.code.sf.net/p/libpng/code CODE "cake_pkg(INSTALL URL https://github.com/madler/zlib.git")
#
# Which results in installing ``madler/zlib.git`` before the installation of the `libpng` repository from that URL.
# Alternatively, you can specify find-package-names:
#
#    cake_pkg_depends(NAME ZLIB CODE "cake_pkg(INSTALL NAME PNG")
#
# For this to work you need to specify the corresponding URLs with these commands (see `CakeLoadConfig.cmake`):
#
#    set(CAKE_PKG_URL_OF_ZLIB git://git.code.sf.net/p/libpng/code)
#    set(CAKE_PKG_URL_OF_PNG https://github.com/madler/zlib.git)
#

if(NOT CAKE_PKG_DEPENDS_INCLUDED)
  set(CAKE_PKG_DEPENDS_INCLUDED 1)

  if(NOT CAKE_URL_INCLUDED)
    include(${CMAKE_CURRENT_LIST_DIR}/private/CakeUrl.cmake)
  endif()

  macro(cake_pkg_depends)
    cmake_parse_arguments(_cake_arg "" "URL;NAME;CODE;SCRIPT" "" ${ARGN})

    if(_cake_arg_URL)
      if(_cake_arg_NAME)
        message(FATAL_ERROR "[cake_pkg_depends]: Both URL and NAME are specified.")
      else()
        cake_parse_pkg_url("${_cake_arg_URL}" _ _cake_repo_url_cid _ _)
        set(_cake_pkg_depends_varname "CAKE_PKG_DEPENDS_URL_${_cake_repo_url_cid}")
      endif()
    else()
      if(_cake_arg_NAME)
        set(_cake_pkg_depends_varname "CAKE_PKG_DEPENDS_NAME_${_cake_arg_NAME}")
      else()
        message(FATAL_ERROR "[cake_pkg_depends]: Either URL or NAME must be specified.")
      endif()
    endif()

    if(_cake_arg_CODE)
      if(_cake_arg_SCRIPT)
        message(FATAL_ERROR "[cake_pkg_depends]: Both CODE and SCRIPT are specified.")
      endif()
    else()
      if(_cake_arg_SCRIPT)
        file(READ "${_cake_arg_SCRIPT}" _cake_arg_CODE)
      else()
        message(FATAL_ERROR "[cake_pkg_depends]: Either CODE or SCRIPT must be specified.")
      endif()
    endif()
    set(${_cake_pkg_depends_varname} "${_cake_arg_CODE}")
  endmacro()
endif()

#.rst:
# CakeDependsDbAdd
# -------
#
# CAKE_DEPENDS_DB_ADD() add a dependency to the cake pkg database. Used from the cake-depends-db*.cmake files.
#
# ::
#
#   CAKE_DEPENDS_DB_ADD(URL <repo-url>
#                       CODE <code>)
#
# To install the dependencies of a package `Cake` looks for a ``cake-depends.cmake`` file in the root of the package's
# repository. If there's no such files it consults the hard-coded package dependency database which are
# the ``cake-depends-db*.cmake`` file in the `Cake` distribution.
# The ``cake-depends-db*.cmake`` files are regular ``CMake`` scripts but they're usually contain only simple
# `CAKE_DEPENDS_DB_ADD` lines::
#
#    cake_depends_db_add(URL git://git.code.sf.net/p/libpng/code CODE "cake_pkg(INSTALL URL https://github.com/madler/zlib.git")
#
# The macro registers the package identified by the URL and assigns it the ``<code>``. The code will be
# handled just like the cake-depends.cmake script:
# - it will be executed prior to installing the package
# - the package configuration variables you set in the query part of the url will be supplied to the code, like
#   ``...myrepo.git?WITH_SQLITE=1``
# - it usually contains a single ``cake_pkg(INSTALL ...)`` but may contain additional logic for determining
#   the correct dependencies based on the package configuration settings

if(NOT CAKE_INCLUDED)
  message(FATAL_ERROR "[cake] Include Cake.cmake, don't include this file directly.")
endif()

macro(cake_depends_db_add)
  cmake_parse_arguments(_cake_arg "" "URL;CODE" "" ${ARGN})
  if(NOT _cake_arg_URL)
    message(FATAL_ERROR "[cake] cake_depends_db_add: no URL parameter")
  endif()
  if(NOT _cake_arg_CODE)
    message(FATAL_ERROR "[cake] cake_depends_db_add: no CODE parameter")
  endif()
  cake_parse_pkg_url("${_cake_arg_URL}" _ _cake_repo_url_cid _ _)
  set(CAKE_DEPENDS_DB_${_cake_repo_url_cid} "${_cake_arg_CODE}")
endmacro()

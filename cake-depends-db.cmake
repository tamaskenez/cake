set(CAKE_PKG_URL_OF_ZLIB https://github.com/madler/zlib.git)
set(CAKE_PKG_URL_OF_PNG git://git.code.sf.net/p/libpng/code)
cake_pkg_depends(NAME PNG CODE "cake_pkg(INSTALL NAME ZLIB)")



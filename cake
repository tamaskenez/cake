# forward arguments to cake.cmake
# see help there

cmake -P $(dirname $0)/src/cake.cmake "$$" "$@"

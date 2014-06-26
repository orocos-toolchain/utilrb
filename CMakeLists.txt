
cmake_minimum_required(VERSION 2.6)

project(utilrb)
find_package(Ruby REQUIRED)

include_directories( ${RUBY_INCLUDE_DIRS})
if(NOT ${RUBY_VERSION} VERSION_LESS "1.9")
  add_definitions(-DRUBY_IS_19)
endif()
add_library( utilrb_ext MODULE ext/swap.cc ext/utilrb_ext.cc ext/value_set.cc ext/weakref.cc ext/proc.cc )
set_target_properties(utilrb_ext PROPERTIES PREFIX "")
if(APPLE)
  set_target_properties(utilrb_ext PROPERTIES SUFFIX ".bundle")
endif()
target_link_libraries(utilrb_ext ${RUBY_LIBRARY})
string(REGEX REPLACE ".*lib(32|64)?/?" "lib/" RUBY_EXTENSIONS_INSTALL_DIR ${RUBY_ARCH_DIR})
string(REGEX REPLACE ".*lib(32|64)?/?" "lib/" RUBY_LIBRARY_INSTALL_DIR ${RUBY_RUBY_LIB_PATH})
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/lib/ DESTINATION ${RUBY_EXTENSIONS_INSTALL_DIR} )
install(TARGETS utilrb_ext DESTINATION ${RUBY_EXTENSIONS_INSTALL_DIR} )
install(FILES package.xml DESTINATION share/utilrb)

# Install an env-hook if catkin is found
find_package(catkin QUIET)
if(catkin_FOUND)
  catkin_add_env_hooks(00.utilrb SHELLS sh DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/env-hooks)
endif()


cmake_minimum_required(VERSION 2.6)

project(utilrb)
find_package(Ruby REQUIRED)

include_directories( ${RUBY_INCLUDE_DIRS})
if(${RUBY_VERSION} VERSION_LESS "1.9")
  add_definitions(-DRUBY_IS_18)
endif()

# Find readline
find_library(readline_LIBRARY readline)
if(NOT readline_LIBRARY)
  message(SEND_ERROR "libreadline not found!")
endif()

add_library( utilrb_ext MODULE
  ext/utilrb/proc.c
  ext/utilrb/readline.c
  ext/utilrb/utilrb.cc
  ext/utilrb/value_set.cc
  ext/utilrb/weakref.cc
)
set_target_properties(utilrb_ext PROPERTIES PREFIX "")
if(APPLE)
  set_target_properties(utilrb_ext PROPERTIES SUFFIX ".bundle")
endif()
target_link_libraries(utilrb_ext ${RUBY_LIBRARY} ${readline_LIBRARY})
set_target_properties(utilrb_ext PROPERTIES OUTPUT_NAME utilrb)

string(REGEX REPLACE ".*lib(32|64)?/?" "lib/" RUBY_EXTENSIONS_INSTALL_DIR ${RUBY_ARCH_DIR})
string(REGEX REPLACE ".*lib(32|64)?/?" "lib/" RUBY_LIBRARY_INSTALL_DIR ${RUBY_RUBY_LIB_PATH})
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/lib/ DESTINATION ${RUBY_EXTENSIONS_INSTALL_DIR} )
install(TARGETS utilrb_ext DESTINATION ${RUBY_EXTENSIONS_INSTALL_DIR}/utilrb )
install(FILES package.xml DESTINATION share/utilrb)

# Install an env-hook if catkin is found
find_package(catkin QUIET)
if(catkin_FOUND)
  catkin_add_env_hooks(00.utilrb SHELLS sh DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/env-hooks)
endif()

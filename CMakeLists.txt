
cmake_minimum_required(VERSION 2.6)

project(utilrb)
find_package(Ruby REQUIRED)

string(REGEX REPLACE ".*(lib|share)(32|64)?/?" "\\1/" RUBY_EXTENSIONS_INSTALL_DIR ${RUBY_ARCH_DIR})
string(REGEX REPLACE ".*(lib|share)(32|64)?/?" "\\1/" RUBY_LIBRARY_INSTALL_DIR ${RUBY_RUBY_LIB_PATH})
install(DIRECTORY lib/ DESTINATION ${RUBY_LIBRARY_INSTALL_DIR} )
install(FILES package.xml DESTINATION share/utilrb)

# Install an env-hook in etc/orocos/${OROCOS_TARGET}/profile.d
configure_file(env-hooks/00.utilrb.sh.in ${CMAKE_CURRENT_BINARY_DIR}/env-hooks/00.utilrb.sh @ONLY)
install(
  FILES ${CMAKE_CURRENT_BINARY_DIR}/env-hooks/00.utilrb.sh
  DESTINATION etc/orocos/profile.d
)

message(STATUS "RUBY_RUBY_LIB_DIR: ${RUBY_RUBY_LIB_DIR}")
message(STATUS "RUBY_ARCH_DIR: ${RUBY_ARCH_DIR}")

# Install an env-hook if catkin is found
find_package(catkin QUIET)
if(catkin_FOUND)
  catkin_add_env_hooks(00.utilrb SHELLS sh DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/env-hooks)
endif()

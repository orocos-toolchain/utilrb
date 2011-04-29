ifdef ROS_ROOT
default: install
include $(shell rosstack find orocos_toolchain_ros)/env.mk
install: gems
	rake
gems:
	gem install rake flexmock nokogiri facets
	gem install hoe --version 2.8.0
	touch gems
clean:
	rake clean
	rm -f gems
else
$(warning This Makefile only works with ROS rosmake. Without rosmake, create a build directory and run cmake ..)
endif

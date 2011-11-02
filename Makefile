ifdef ROS_ROOT
default: install
include $(shell rospack find rtt)/../env.mk
install: gems
	rake
gems:
	if [ -d ../rtt_gems ]; then gem install ../rtt_gems/*.gem; else gem install rake flexmock rdoc nokogiri facets; fi
	touch gems
clean:
	rake clean
	rm -f gems
else
$(warning This Makefile only works with ROS rosmake. Without rosmake, create a build directory and run cmake ..)
endif

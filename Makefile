default: install
install:
	rake
gems:
	if [ -d ../rtt_gems ]; then gem install ../rtt_gems/*.gem; else gem install rake flexmock rdoc rake-compiler hoe hoe-yard facets; fi
	touch gems
clean:
	rake clean

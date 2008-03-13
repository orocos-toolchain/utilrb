Utilrb
    http://utilrb.rubyforge.org
    http://www.rubyforge.org/projects/utilrb
    http://github.com/doudou/util-rb (git repository)

Copyright (c) 2006-2008
    Sylvain Joyeux <sylvain.joyeux@m4x.org>
    LAAS/CNRS <openrobots@laas.fr>

This work is licensed under the BSD license. See License.txt for details

== What is Utilrb ?
Utilrb is yet another Ruby toolkit, in the spirit of facets. It includes all
the standard class extensions I use in my own projects like Genom.rb.

== Installation
The only dependency Utilrb has is flexmock if you want to run tests. It is
available as a gem, so you can run

  gem install flexmock

== Utilrb's C extension
Utilrb includes a C extension in ext/. It is optional, but some of the
functionalities will be disabled if it is not present. Trying to require
a file in which there is a C-only feature will yield a warning on STDOUT.

* some features have a Ruby version, but a C version is provided for
  performance:
  - Enumerable#each_uniq

* some features are C-only
  - ValueSet class
  - Kernel#swap!

The environment variable <tt>UTILRB_FASTER_MODE</tt> controls the extension
loading. Set it to +no+ to disable the extension, to +yes+ to force it 
(an error is generated if the extension is not available). If the variable
is not set, the extension is loaded if available.

== CHANGES
:include: Changes.txt

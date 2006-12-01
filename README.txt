Utilrb
    http://utilrb.rubyforge.org
    http://www.laas.fr/~sjoyeux/darcs/utilrb (dev repository)
    http://www.laas.fr/~sjoyeux/research.php

Copyright (c) 2006 
    Sylvain Joyeux <sylvain.joyeux@m4x.org>
    LAAS/CNRS <openrobots@laas.fr>

This work is licensed under the BSD license. See License.txt for details

== What is Utilrb ?
Utilrb is yet another Ruby toolkit, in the spirit of facets. It includes all
the standard class extensions I use in my own projects like Genom.rb.

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

== TODO
* put the +block+ argument in front in Module#define_method_with_block. This
  would allow to do 

    define_method_with_block(:bla) do |block, *args| 
    end

  [DONE 20061101125259-1e605-fef189550540b8e096f0bbe6c219d892bf3e13fc.gz]

== CHANGES
:include: Changes.txt

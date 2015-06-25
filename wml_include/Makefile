##
##  wml_include/Makefile
##  Copyright (c) 1997 Ralf S. Engelschall, All Rights Reserved. 
##

# ------------------------------------------------
#   DEFINITIONS
# ------------------------------------------------


SHELL = /bin/sh

top_srcdir      = ..
srcdir          = .


PATH_PERL       = /usr/bin/perl
INSTALL_PROGRAM = $(top_srcdir)/etc/shtool install -c -m 755 -s
INSTALL_DATA    = $(top_srcdir)/etc/shtool install -c -m 644
MKDIR           = $(top_srcdir)/etc/shtool mkdir -f -p -m 755

prefix          = /usr/local
exec_prefix     = $(prefix)
bindir          = $(prefix)/bin
libsubdir       = /wml
libdir          = $(prefix)/lib$(libsubdir)
mandir          = $(prefix)/man

INSTALLPRIVLIB  = $(libdir)/perl/lib
INSTALLARCHLIB  = $(libdir)/perl/lib/x86_64-linux

DCOLON		= ::

# ------------------------------------------------
#   TARGETS
# ------------------------------------------------

all: sys/bootp3.src
	@set -e; \
	files=`echo [a-z]*.src [a-z]*/*.src`; \
	for file in $$files; do \
	    base=`echo $$file | sed -e 's/\.src$$//g'`; \
	    name=`echo wml/$$base | sed -e 's/\//$(DCOLON)/g'`; \
	    if ls -1t $$base.wml $$base.src 2>/dev/null \
	       | sed 1q | grep "^$$base.wml\$$" >/dev/null 2>&1; then \
	        :; \
	    else \
	        echo "Creating $$name"; \
	        sed -e '/^=head1/,/^=cut/d' -e '/^__END__/,$$d' \
                   <$$base.src >$$base.wml; \
	        cp $$base.src $$name.pod; \
	        pod2man --section=1 \
	            --center="EN Tools" \
	            --release="EN Tools" \
	                $$name.pod >$$base.3; \
	        rm -f $$name.pod; \
	    fi; \
	done

sys/bootp3.src: sys/bootp3.src.in
	sed -e 's|\@INSTALLPRIVLIB\@|$(INSTALLPRIVLIB)|g' \
	    -e 's|\@INSTALLARCHLIB\@|$(INSTALLARCHLIB)|g' \
	    <$? >$@

install:
	@set -e; \
	files=`echo [a-z]*.wml [a-z]*/*.wml`; \
	for file in $$files; do \
	    base=`echo $$file | sed -e 's/\.wml$$//g'`; \
	    dir=`echo $$file | sed -e 's/[a-zA-Z0-9_]*.wml$$//g'`; \
	    name=`echo wml/$$base | sed -e 's/\//$(DCOLON)/g'`; \
	    if [ ! -d "$(libdir)/include/$$dir" ]; then \
	        echo "$(MKDIR) $(libdir)/include/$$dir"; \
	        $(MKDIR) $(libdir)/include/$$dir; \
	    else :; \
	    fi; \
          echo "$(INSTALL_DATA) $$file $(libdir)/include/$$file"; \
          $(INSTALL_DATA) $$file $(libdir)/include/$$file; \
          echo "$(INSTALL_DATA) $$base.3 $(mandir)/man3/$$name.3"; \
          $(INSTALL_DATA) $$base.3 $(mandir)/man3/$$name.3; \
	done

clean:
	-rm -f *.wml */*.wml
	-rm -f *.3   */*.3
	-rm -f sys/bootp3.src

distclean: clean
	-rm -f Makefile

realclean: distclean

##EOF##

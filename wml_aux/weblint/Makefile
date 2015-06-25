##
##  wml_aux/weblint/Makefile
##  Copyright (c) 1997-2000 Ralf S. Engelschall, <rse@engelschall.com>
##  Copyright (c) 2000 Denis Barbier
##


SHELL           = /bin/sh

top_srcdir      = ../..
srcdir          = .


INSTALL_PROGRAM = $(top_srcdir)/etc/shtool install -c -m 755 -s
INSTALL_DATA    = $(top_srcdir)/etc/shtool install -c -m 644

prefix          = /usr/local
exec_prefix     = $(prefix)
bindir          = $(prefix)/bin
libsubdir       = /wml
libdir          = $(prefix)/lib$(libsubdir)
mandir          = $(prefix)/man

PATH_PERL       = /usr/bin/perl
INSTALLPRIVLIB  = $(libdir)/perl/lib
INSTALLARCHLIB  = $(libdir)/perl/lib/x86_64-linux

SRC_FILES       = weblint.src

EXE_FILES       = $(SRC_FILES:.src=.pl)

.SUFFIXES:
.SUFFIXES: .pl .src

.src.pl:
	sed -e 's|\@libdir\@|$(libdir)|g' \
	-e 's|\@PATH_PERL\@|$(PATH_PERL)|g' \
        -e 's|\@INSTALLPRIVLIB\@|$(INSTALLPRIVLIB)|g' \
        -e 's|\@INSTALLARCHLIB\@|$(INSTALLARCHLIB)|g' \
          <$< >$@ && chmod a+x $@

all: $(EXE_FILES)

clean: 
	-rm -f $(EXE_FILES)

distclean: clean
	-rm -f Makefile

realclean: distclean

##EOF##

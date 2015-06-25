##
##  wml_aux/linklint/Makefile
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

SRC_FILES       = linklint.src

EXE_FILES       = $(SRC_FILES:.src=.pl)
MAN_FILES       = $(SRC_FILES:.src=.1)

.SUFFIXES:
.SUFFIXES: .pl .src .1 .pod

.src.pl:
	sed -e 's|\@libdir\@|$(libdir)|g' \
   -e 's|\@PATH_PERL\@|$(PATH_PERL)|g' \
   -e 's|\@INSTALLPRIVLIB\@|$(INSTALLPRIVLIB)|g' \
   -e 's|\@INSTALLARCHLIB\@|$(INSTALLARCHLIB)|g' \
          <$< >$@ && chmod a+x $@

.pod.1:
	pod2man --section=1 $< > $@

all: $(EXE_FILES) $(MAN_FILES)

clean: 
	-rm -f $(EXE_FILES) $(MAN_FILES)

distclean: clean
	-rm -f Makefile

realclean: distclean

##EOF##

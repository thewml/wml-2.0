##
##  wml_docs/Makefile
##  Copyright (c) 1997-2001 Ralf S. Engelschall, <rse@engelschall.com>
##


SHELL           = /bin/sh

top_srcdir      = ..
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

.SUFFIXES:
.SUFFIXES: .7 .pod
.pod.7:
	pod2man --section=7 \
            --center="EN Tools" \
            --release="EN Tools" \
        $< > $@

MANPAGES = wml_intro.7 wml_tutorial.7 wml_faq.7 wml_tags.7 wml_macros.7

all: $(MANPAGES)

wml_tags.pod: wml_tags.pod.in wml_tags.L.main wml_tags.L.incl 
	$(PATH_PERL) ./wml_tags.pod.pl

clean: 
	-rm -f $(MANPAGES) wml_tags.pod

distclean: clean
	-rm -f Makefile

realclean: distclean

##EOF##

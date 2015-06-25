##
##  wml_frontend/Makefile
##  Copyright (c) 1997-2001 Ralf S. Engelschall, <rse@engelschall.com>
##  Copyright (c) 2000-2001 Denis Barbier
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

WML_VERSION     = 2.0.11 (19-Aug-2006)
WML_CONFIG_ARGS = 

PATH_PERL       = /usr/bin/perl
INSTALLPRIVLIB  = $(libdir)/perl/lib
INSTALLARCHLIB  = $(libdir)/perl/lib/x86_64-linux

built_system    = x86_64-whatever-linux-gnu3
built_user      = twim@localhost
built_date      = 24-Jun-2015
perlprog        = /usr/bin/perl
perlvers        = 5.020

compat          = @compat@

SRC_FILES       = wmk.src wml.src wmb.src wmd.src wmu.src

MAN_FILES       = $(SRC_FILES:.src=.1) wmd_missing.1
EXE_FILES       = $(SRC_FILES:.src=.pl)

.SUFFIXES:
.SUFFIXES: .pl .1 .src

.src.pl:
	sed -e '/^=head1/,/^=cut/d' \
        -e '/^__END__/,$$d' \
        -e 's|\@WML_VERSION\@|$(WML_VERSION)|g' \
        -e 's|\@WML_CONFIG_ARGS\@|$(WML_CONFIG_ARGS)|g' \
        -e 's|\@perlprog\@|$(perlprog)|g' \
        -e 's|\@perlvers\@|$(perlvers)|g' \
        -e 's|\@built_system\@|$(built_system)|g' \
        -e 's|\@built_user\@|$(built_user)|g' \
        -e 's|\@built_date\@|$(built_date)|g' \
        -e 's|\@compat\@|$(compat)|g' \
        -e 's|\@prefix\@|$(prefix)|g' \
        -e 's|\@bindir\@|$(bindir)|g' \
        -e 's|\@libdir\@|$(libdir)|g' \
        -e 's|\@mandir\@|$(mandir)|g' \
        -e 's|\@PATH_PERL\@|$(PATH_PERL)|g' \
        -e 's|\@INSTALLPRIVLIB\@|$(INSTALLPRIVLIB)|g' \
        -e 's|\@INSTALLARCHLIB\@|$(INSTALLARCHLIB)|g' \
          <$< >$@ && chmod a+x $@

.src.1:
	cp $< $*.pod
	pod2man --section=1 --center="EN Tools" --release="EN Tools" $*.pod |\
    sed -e 's|\@WML_VERSION\@|$(WML_VERSION)|g' > $@
	rm -f $*.pod

all: $(EXE_FILES) $(MAN_FILES)

clean: 
	-rm -f $(EXE_FILES) $(MAN_FILES)

distclean: clean
	-rm -f Makefile

realclean: distclean

##EOF##

#ifndef SC_H
#define SC_H
/*
**
**  sc.h -- STATIC configuration header file
**  Copyright (c) Ralf S. Engelschall, <rse@engelschall.com>
**
*/

#define AC_perl_prog      "/usr/bin/perl"
#define AC_perl_vers      "5.020"
#define AC_perl_archlib   "/usr/lib64/perl5/5.20.2/x86_64-linux"
#define AC_perl_libs      "-lnsl -lgdbm -ldb -ldl -lm -lcrypt -lutil -lc -lgdbm_compat"
#define AC_perl_dla       "/usr/lib64/perl5/5.20.2/x86_64-linux/auto/DynaLoader/DynaLoader.a"

#define AC_prefix         "/usr/local"

#define AC_build_user     "twim@localhost"
#define AC_build_time_iso "24-Jun-2015"

#endif /* SC_H */

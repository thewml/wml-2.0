#!/usr/bin/perl
eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if $running_under_some_shell;
##
##  WML -- Website META Language
##  
##  Copyright (c) 1996-2001 Ralf S. Engelschall.
##  Copyright (c) 1999-2001 Denis Barbier.
##  
##  This program is free software; you can redistribute it and/or modify
##  it under the terms of the GNU General Public License as published by
##  the Free Software Foundation; either version 2 of the License, or
##  (at your option) any later version.
##  
##  This program is distributed in the hope that it will be useful,
##  but WITHOUT ANY WARRANTY; without even the implied warranty of
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
##  GNU General Public License for more details.
##  
##  You should have received a copy of the GNU General Public License
##  along with this program; if not, write to
##  
##      Free Software Foundation, Inc.
##      59 Temple Place - Suite 330
##      Boston, MA  02111-1307, USA
##  
##  Notice, that ``free software'' addresses the fact that this program
##  is __distributed__ under the term of the GNU General Public License
##  and because of this, it can be redistributed and modified under the
##  conditions of this license, but the software remains __copyrighted__
##  by the author. Don't intermix this with the general meaning of 
##  Public Domain software or such a derivated distribution label.
##  
##  The author reserves the right to distribute following releases of
##  this program under different conditions or license agreements.
##

require 5.003;

BEGIN { $^W = 0; } # get rid of nasty warnings

$VERSION = "2.0.11 (19-Aug-2006)";

use lib "/usr/local/lib/wml/perl/lib";
use lib "/usr/local/lib/wml/perl/lib/x86_64-linux";

if ($ENV{'PATH'} !~ m|/usr/local/bin|) {
    $ENV{'PATH'} = '/usr/local/bin:'.$ENV{'PATH'};
}

use Getopt::Long 2.13;
use File::PathConvert;
use IO::File 1.06;
use Term::ReadKey;
use Cwd;

sub ctime {
    my ($time) = @_;
    return scalar(localtime($time));
}
 
sub isotime {
    my ($time) = @_;
  
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = 
        localtime($time);
    my ($str) = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
         $year+1900, $mon+1, $mday, $hour, $min, $sec);
    return $str;
}

sub gmt_ctime {
    my ($time) = @_;
    return scalar(gmtime($time));
}
 
sub gmt_isotime {
    my ($time) = @_;
  
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = 
        gmtime($time);
    my ($str) = sprintf("%04d-%02d-%02d %02d:%02d:%02d",
         $year+1900, $mon+1, $mday, $hour, $min, $sec);
    return $str;
}

sub usage {
    my ($progname) = @_;

    print STDERR "Usage: $progname [options] [inputfile]\n";
    print STDERR "\n";
    print STDERR "Input Options:\n";
    print STDERR "  -I, --include=PATH      adds an include directory\n";
    print STDERR "  -i, --includefile=PATH  pre-include a particular include file\n";
    print STDERR "  -D, --define=NAME[=STR] define a variable\n";
    print STDERR "  -D, --define=NAME~PATH  define an auto-adjusted path variable\n";
    print STDERR "  -n, --noshebang         no shebang-line parsing (usually used by WMk)\n";
    print STDERR "  -r, --norcfile          no .wmlrc files are read\n";
    print STDERR "  -c, --nocd              read .wmlrc files without changing to input file directory\n";
    print STDERR "\n";
    print STDERR "Output Options:\n";
    print STDERR "  -O, --optimize=NUM      specify the output optimization level\n";
    print STDERR "  -o, --outputfile=PATH   specify the output file(s)\n";
    print STDERR "  -P, --prolog=PATH       specify one or more prolog filters\n";
    print STDERR "  -E, --epilog=PATH       specify one or more epilog filters\n";
    print STDERR "  -t, --settime           sets mtime of outputfile(s) to mtime+1 of inputfile\n";
    print STDERR "\n";
    print STDERR "Processing Options:\n";
    print STDERR "  -M, --depend[=OPTIONS]  dump dependencies as gcc does\n";
    print STDERR "  -p, --pass=STR          specify which passed should be run\n";
    print STDERR "  -W, --passoption[=PASS,OPTIONS]\n";
    print STDERR "                          set options for a specific pass\n";
    print STDERR "  -s, --safe              don't use precompile/inline hacks to speedup processing\n";
    print STDERR "  -v, --verbose[=NUM]     verbose mode\n";
    print STDERR "  -q, --quiet             quiet mode\n";
    print STDERR "\n";
    print STDERR "Giving Feedback:\n";
    print STDERR "  -V, --version[=NUM]     display version and build information\n";
    print STDERR "  -h, --help              display this usage summary\n";
    print STDERR "\n";
    exit(1);
}

sub ProcessOptions {
    local $SIG{'__WARN__'} = sub { 
        print STDERR "WML:Error: $_[0]";
    };
    $Getopt::Long::bundling = 1;
    $Getopt::Long::getopt_compat = 0;
    my (@list_options) = (
        "I|include=s@", 
        "i|includefile=s@", 
        "D|define=s@",
        "n|noshebang",
        "r|norcfile",
        "c|nocd",
        "O|optimize=i",
        "o|outputfile=s@",
        "P|prolog=s@",
        "E|epilog=s@",
        "t|settime",
        "p|pass=s@",
        "W|passoption=s@",
        "M|depend:s",
        "s|safe",
        "v|verbose:i",
        "q|quiet",
        "V|version:i",
        "h|help");
    if (not Getopt::Long::GetOptions(@list_options))
    {
        warn "Try `$0 --help' for more information.\n";
        exit(0);
    }
    &usage($0) if ($opt_h);
    foreach (@list_options) {
        if (m|=s|) {
            s/^(.)\|.*$/opt_$1/;
            my ($arg) = $1;
            if ($#$_ > -1 && $$_[0] =~ m|^=|) {
                warn "An equal sign has been detected after the `-$arg' option\n";
                warn "Try `$0 --help' for more information.\n\n";
                exit(0);
            }
        }
    }
}

#   pre-process argument line for option -r and -v
$opt_r = 0;
$opt_v = -1;
$opt_c = 0;
@ARGVLINE = @ARGV;
&ProcessOptions();
$src  = $ARGV[0];
@ARGV = @ARGVLINE;

#   reset with defaults (except $opt_r and $opt_v)
@opt_I = ();
@opt_i = ();
@opt_D = ();
$opt_n = 0;
$opt_O = '';
@opt_o = ();
@opt_P = ();
@opt_E = ();
$opt_t = 0;
@opt_p = ();
@opt_W = ();
$opt_M = '-';
$opt_s = 0;
$opt_q = 0;
$opt_V = -1;
$opt_h = 0;

#   save argument line
@ARGVLINE = @ARGV;
@ARGV = ();

#   helper function to split argument line
#   the same way Bourne-Shell does:
#   #1: foo=bar quux   => "foo=bar", "quux"
#   #2: "foo=bar quux" => "foo=bar quux"
#   #3: foo="bar quux" => "foo=bar quux"     <-- !!
sub split_argv {
    my ($str) = @_;
    my (@argv) = ();
    my ($r) = '';
    my ($prev) = '';

    while (1) {
        $prev = $str;
        next if $str =~ s|^"([^"\\]*(?:\\.[^"\\]*)*)"(.*)$|$r .= $1, $2|e;
        next if $str =~ s|^'([^'\\]*(?:\\.[^'\\]*)*)'(.*)$|$r .= $1, $2|e;
        next if $str =~ s|^([^\s"']+)(.*)$|$r .= $1, $2|e;
        if ($str =~ m|^[\s\n]+| || $str eq '') {
            if ($r ne '') {
                push(@argv, $r);
                $r = '';
            }
            $str =~ s|^[\s\n]+||;
            last if ($str eq '');
        }
        if ($str eq $prev) {
            #    breaks an infinite loop
            print STDERR "** WML:Error: options can not be correctly parsed\n";
            exit(1);
        }
    }
    return @argv;
}

sub CanonPath {
    my ($path) = @_;
 
    $pathL = '';
    while ($path ne $pathL) {
        $pathL = $path;
        $path =~ s|//|/|g;
        $path =~ s|/\./|/|g;
        $path =~ s|/\.$|/|g;
        $path =~ s|^\./(.)|$1|g;
        $path =~ s|([^/.][^/.]*)/\.\.||;
    }
    return $path;
}

#   escape options if not quoted but
#   when shell metachars exists
sub quotearg {
    my ($arg) = @_;
    if ($arg !~ m|^'.*'$|) {
        if ($arg =~ m|[\$"`]|) {
            $arg =~ s|([\$"`])|\\$1|sg;
        }
    }
    return $arg;
}
#   remove escape backslashes
sub unquotearg {
    my ($arg) = @_;
    $arg =~ s/\\([\$"`])/$1/g;
    return $arg;
}

#   1. process options in WMLOPTS variable
if ($var = $ENV{'WMLOPTS'}) {
    &verbose(2, "Reading WMLOPTS variable");
    $var =~ s|^\s+||;
    $var =~ s|\s+$||;
    #   arguments are not quoted because shell metacharacters
    #   have already been expanded, but dollar sign must be
    #   escaped
    $var =~ s|\$|\\\$|g;
    @ARGV = &split_argv($var);
    &ProcessOptions();
}

##
##  .wmlrc File Parsing
##
if (not $opt_r) {
    my $savedir = '';
    @DIR = ();

    #   First save current directory and go to input file directory
    if (not $opt_c and $src =~ m|/|) {
        $src =~ s|/+[^/]*$||;
        if (-d $src) {
            $savedir = Cwd::cwd;
            chdir($src);
        }
    }
    $src = '' if not $savedir;

    #   2. add all parent dirs .wmlrc files for options
    ($cwd = Cwd::cwd) =~ s|/$||;
    while ($cwd) {
        push(@DIR, $cwd);
        $cwd =~ s|/[^/]+$||;
    }

    #   Restore directory
    chdir($savedir) if $savedir;
    $cwd = Cwd::cwd;

    #   3. add ~/.wmlrc file for options
    @pwinfo = getpwuid($<);
    $home = $pwinfo[7];
    $home =~ s|/$||;
    if (-f "$home/.wmlrc") {
        push(@DIR, $home);
    }
    

    #   now parse these RC files
    foreach $dir (reverse(@DIR)) {
        if (-f "$dir/.wmlrc") {
            &verbose(2, "Reading RC file: $dir/.wmlrc\n");
            open(FP, "<$dir/.wmlrc") || error("Unable to load $dir/.wmlrc: $!");
            @ARGV = ();
            while (<FP>) {
                next if (m|^\s*\n$|);
                next if (m|^\s*#[#\s]*.*$|);
                s|^\s+||;
                s|\s+$||;
                s|\$([A-Za-z_][A-Za-z0-9_]*)|$ENV{$1}|ge;
                @X = &split_argv($_);
                push(@ARGV, @X);
            }
            close(FP) || error("Unable to close $dir/.wmlrc: $!");
            @opt_D_OLD = @opt_D;
            @opt_I_OLD = @opt_I;
            @opt_D = ();
            @opt_I = ();
            &ProcessOptions();
            @opt_D_NEW = @opt_D_OLD;
            @opt_I_NEW = @opt_I_OLD;

            #   adjust -D options
            $reldir = File::PathConvert::abs2rel("$dir", "$src");
            $reldir = "." if $reldir eq '';
            foreach $d (@opt_D) {
                if ($d =~ m|^([A-Za-z0-9_]+)~(.+)$|) {
                    ($var, $path) = ($1, $2);
                    if ($path !~ m|^/|) {
                        if ($path eq '.') {
                            $path = &CanonPath("$reldir");
                        }
                        else {
                            $path = &CanonPath("$reldir/$path");
                        }
                    }
                    $path = '""' if ($path eq '');
                    $d = "$var=$path";
                    push(@opt_D_NEW, $d);
                    next;
                }
                elsif ($d =~ m|^([A-Za-z0-9_]+)$|) {
                    $d = $d.'=1';
                }
                push(@opt_D_NEW, $d);
            }

            #   adjust -I options
            $reldir = File::PathConvert::abs2rel("$dir");
            $reldir = "." if $reldir eq '';
            foreach $path (@opt_I) {
                if ($path !~ m|^/|) {
                    if ($path eq '.') {
                        $path = &CanonPath("$reldir");
                    }
                    else {
                        $path = &CanonPath("$reldir/$path");
                    }
                    $path = '.' if ($path eq '');
                }
                push(@opt_I_NEW, $path);
            }

            @opt_D = @opt_D_NEW;
            @opt_I = @opt_I_NEW;
        }
    }

}

#   4. process the command line options 
@ARGV = @ARGVLINE;
@opt_D_OLD = @opt_D; @opt_D = (); # extra remember -D options from command line
&ProcessOptions();

#   quote the characters the shell have escaped
foreach $d (@opt_D) {
    push(@opt_D_ADD, &quotearg($d));
}
@opt_D = @opt_D_OLD;

#   fix the version level
if ($opt_V == 0) {
    $opt_V = 1; # Getopt::Long sets 0 if -V only
}
if ($opt_V == -1) {
    $opt_V = 0; # we operate with 0 for not set
}
if ($opt_V) {
    print STDERR "This is WML Version $VERSION\n";
    print STDERR "Copyright (c) 1996-2001 Ralf S. Engelschall.\n";
    print STDERR "Copyright (c) 1999-2001 Denis Barbier.\n";
    print STDERR "\n";
    print STDERR "This program is distributed in the hope that it will be useful,\n";
    print STDERR "but WITHOUT ANY WARRANTY; without even the implied warranty of\n";
    print STDERR "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n";
    print STDERR "GNU General Public License for more details.\n";
    if ($opt_V > 1) {
        print STDERR "\n";
        print STDERR "Built Environment:\n";
        print STDERR "    Host: ".'x86_64-whatever-linux-gnu3'."\n";
        print STDERR "    Perl: ".'5.020 (/usr/bin/perl)'."\n";
        print STDERR "    User: ".'twim@localhost'."\n";
        print STDERR "    Date: ".'24-Jun-2015'."\n";
        print STDERR "Built Location:\n";
        print STDERR "    Prefix: ".'/usr/local'."\n";
        print STDERR "    BinDir: ".'/usr/local/bin'."\n";
        print STDERR "    LibDir: ".'/usr/local/lib/wml'."\n";
        print STDERR "    ManDir: ".'/usr/local/man'."\n";
    }
    if ($opt_V > 2) {
        print STDERR "\n";
        print STDERR "Used Perl System:\n";
        print STDERR `/usr/bin/perl -V`;
    }
    exit(0);
}

#   If the -M was the last option and the user forgot
#   to put `--' to end options, we adjust it.
if ($opt_M !~ m%^(-|[MD]*)$% && $#ARGV == -1) {
    push(@ARGV,$opt_M);
    $opt_M = '';
}

#   set the input file
$src = $ARGV[0];

#   if no inputfile is given, WML reads from stdin
#   and forces quiet mode
if ($src eq '') {
    $src = '-';
    $opt_q = 1;
}

$tmpdir = $ENV{'TMPDIR'} || '/tmp';

#   if input is stdin we create a temporary file
$src_istmp = 0;
if ($src eq '-') {
    $src_istmp = 1;
    $src = "$tmpdir/wml.input.$$.tmp";
    unlink($src);
    open(TMP, ">$src") || error("Unable to write into $src: $!");
    while (<STDIN>) {
        print TMP $_
            or error("Unable to write into $src: $!");
    }
    close(TMP) || error("Unable to close $src: $!");
}

if (not $src_istmp and not -f $src) {
    print STDERR "** WML:Error: input file `$src' not found\n";
    exit(1);
}

#   now adjust -D options from command line
#   relative to path to source file
if (not $src_istmp) {
    $reldir = $src;
    $reldir =~ s,(:?/|^)[^/]+$,,;
    ($cwd = Cwd::cwd) =~ s|/$||;
    $reldir = File::PathConvert::abs2rel($cwd, "$cwd/$reldir");
    $reldir = "." if $reldir eq '';
}
else {
    $reldir = '.';
}
foreach $d (@opt_D_ADD) {
    if ($d =~ m|^([A-Za-z0-9_]+)~(.+)$|) {
        ($var, $path) = ($1, $2);
        if ($path !~ m|^/|) {
            if ($path eq '.') {
                $path = &CanonPath("$reldir");
            }   
            else {
                $path = &CanonPath("$reldir/$path");
            }
        }
        $path = '""' if ($path eq '');
        $d = "$var=$path";
    }
    elsif ($d =~ m|^([A-Za-z0-9_]+)$|) {
        $d = $d.'=1';
    }
    push(@opt_D, $d);
}


#   5. process the options from the pseudo-shebang line
if (not $opt_n) {
    open(TMP, "<$src") || error("Unable to load $src: $!");
    $shebang = '';
    while (1) {
        $shebang .= <TMP>;
        if ($shebang =~ m|^(.*)\\\s*$|s) {
            $shebang = $1;
            next;
        }
        last;
    }
    close(TMP) || error("Unable to close $src: $!");
    if ($shebang =~ m|^#!wml\s+(.+\S)\s*$|is) {
        #   split opts into arguments and process them
        @ARGV = &split_argv($1);
        &ProcessOptions();
    }
}

#   6. expand %DIR and %BASE in the -o flags
@opt_o_OLD = @opt_o; @opt_o = ();
foreach $opts (@opt_o_OLD) {
    my ($dir, $base);

    if ($src =~ m|^(.+)/([^/]+)$|) {
        ($dir, $base) = ($1, $2);
    }
    else {
        ($dir, $base) = ('.', $src);
    }
    $base =~ s|\.[a-zA-Z0-9]+$||;
    $opts =~ s|%DIR|$dir|sg;
    $opts =~ s|%BASE|$base|sg;
    push(@opt_o,$opts);
}

#   7. Undefine variables when requested
%new_opt_D = ();
foreach $d (@opt_D) {
    ($var, $val) = ($d =~ m|^(.+?)=(.*)$|);
    if ($val eq 'UNDEF') {
        delete $new_opt_D{$var};
    } else {
        $new_opt_D{$var} = $val;
    }
}
@opt_D = map { $_."=".$new_opt_D{$_} } keys %new_opt_D;

#   fix the verbose level
if ($opt_v == 0) {
    $opt_v = 1; # Getopt::Long sets 0 if -v only
}
if ($opt_v == -1) {
    $opt_v = 0; # we operate with 0 for not set
}

sub verbose {
    my ($level, $str) = @_;

    if ($opt_v >= $level) {
        print STDERR "** WML:Verbose: $str";
    }
}
sub error {
    my ($str) = @_;
    print STDERR "** WML:Error: $str\n";
    exit(1);
}

sub dosystem {
    my ($cmd) = @_;
    my ($rc);

    &verbose(2, "system: $cmd\n");
    $rc = system($cmd);
    return $rc;
}

sub precompile {
    my ($name, $in) = @_;
    my ($error, $func);

    $error = '';
    local $SIG{'__WARN__'} = sub { $error .= $_[0]; };
    local $SIG{'__DIE__'};

    $in =~ s|exit(\s*\(0\))|return$1|sg;
    $in =~ s|exit(\s*\([^0].*?\))|die$1|sg;
    eval("package $name; \$main = sub { \@ARGV = \@_; ".$in."; return 0; }; package main;");
    $error = "$@" if ($@);
    eval("\$func = \$${name}::main;");

    if ($error) {
        $@ = $error;
        return ($func, $error);
    }
    else {
        $@ = '';
        return ($func, '');
    }
}

sub dosource {
    my ($prog, $args) = @_;
    my ($rc, $fp, $src, @argv, $pkgname);
    my ($error, $func);

    &verbose(2, "source: $prog $args\n");
    &verbose(9, "loading: $prog\n");
    $pkgname = $prog;
    $pkgname =~ s|^.*/([^/]+)$|$1|;
    if ($prog !~ m|^/|) {
        foreach $p (split(/:/, $ENV{'PATH'})) {
            if (-f "$p/$prog") {
                $prog = "$p/$prog";
                last;
            }
        }
    }
    $fp = new IO::File;
    $fp->open($prog) || error("Unable to load $prog: $!");
    $src = '';
    while (<$fp>) {
        $src .= $_;
    }
    $fp->close() || error("Unable to close $prog: $!");
    &verbose(9, "loading: succeeded with $prog (".length($src)." bytes)\n");

    &verbose(9, "precompiling script: pkgname=$pkgname\n");
    ($func, $error) = &precompile($pkgname, $src);
    if ($error ne '') {
        &verbose(9, "precompiling script: error: $error\n");
    }
    else {
        &verbose(9, "precompiling script: succeeded\n");
    }

    &verbose(9, "splitting from args: $args\n");
    @argv = ();
    while ($args) {
        redo if $args =~ s|^\s*(-[a-zA-Z0-9]\S+)|push(@argv, &unquotearg($1)), ''|iges;
        redo if $args =~ s|^\s*(-[a-zA-Z0-9])|push(@argv, &unquotearg($1)), ''|iges;
        redo if $args =~ s|^\s*"(.*?(?!\\).)"|push(@argv, &unquotearg($1)), ''|iges;
        redo if $args =~ s|^\s*'([^']*)'|push(@argv, $1), ''|iges;
        redo if $args =~ s|^\s*(\S+)|push(@argv, &unquotearg($1)), ''|iges;
        redo if $args =~ s|^\s+$|''|iges;
    }
    &verbose(9, "splitting to argv: ".join("|", @argv)."\n");

    &verbose(9, "running script\n");
    eval "\$rc = \&{\$func}(\@argv);";
    &verbose(9, "running script: rc=$rc\n");
    $rc = 256 if not defined $rc;

    return $rc;
}

$PROTECT_COUNTER = 0;
%PROTECT_STORAGE = ();

sub protect {
    my ($file, $pass) = @_;
    my ($fp, $data, $prolog, $arg, $body, $key, $p, $pe);

    $fp = new IO::File;
    $fp->open("<$file") || error("Unable to load $file for protection: $!");
    $data = '';
    while (<$fp>) {
        $data .= $_;
    }
    $fp->close() || error("Unable to close $file: $!");
    $fp->open(">$file") || error("Unable to write into $file for protection: $!");
    #   First remove a shebang line
    if ($firstpass and $data =~ m/^#!wml/) {
        while ($data =~ s/^[^\n]*\\\n//s) { 1; }
        $data =~ s/^[^\n]*\n//s;
    }
    #   Following passes will pass through previous test
    $firstpass = 0 if $firstpass;

    #  This loop must take care of nestable <protect> tags 
    while ($data =~ s|^(.*)<protect(.*?)>(.*?)</protect>||is) {
        $p = '123456789';
        ($prolog, $arg, $body) = ($1, $2, $3);
        #    unquote the attribute
        $arg =~ s|(['"])(.*)\1\s*$|$2|;
        if ($arg =~ m|pass=([\d,-]*)|i) {
            $p = $1;
            $p =~ s|,||g;
            $p = "1$p" if $p =~ m|^-|;
            $p = "${p}9" if $p =~ m|-$|;
            $p =~ s|(\d)-(\d)|&expandrange($1, $2)|sge;
        }
        $pe = join ('', sort {$a <=> $b} (split('', $p)));
        $pe =~ s/^.*(\d)$/$1/;
        $key = sprintf("%06d", $PROTECT_COUNTER++);
        $PROTECT_STORAGE{$key} = {
                SPEC => $p,
                MAX  => $pe,
                ARG  => $arg,
                BODY => $body
        };
        $data = $prolog . "-=P[$key]=-" . $data;
    }

    #   And now unprotect passes
    while ($data =~ s|^(.*?)-=P\[(\d+)\]=-||s) {
        $key = $2;
        $fp->print($1) || error("Unable to write into $file for protection: $!");
        if ($PROTECT_STORAGE{$key}->{SPEC} =~ m/$pass/) {
            $fp->print("-=P[$key]=-")
                || error("Unable to write into $file for protection: $!");
        }
        else {
            $data = "<protect" . $PROTECT_STORAGE{$key}->{ARG} . ">" .
                    $PROTECT_STORAGE{$key}->{BODY} . "</protect>" . $data;
        }
    }
    $fp->print($data) || error("Unable to write into $file for protection: $!");
    $fp->close() || error("Unable to close $file: $!");
}

sub unprotect {
    my ($file, $pass) = @_;
    my ($fp, $data, $prefix, $key);

    $fp = new IO::File;
    $fp->open("<$file") || error("Unable to load $file for unprotection: $!");
    $data = '';
    while (<$fp>) {
        $data .= $_;
    }
    $fp->close() || error("Unable to close $file: $!");
    $fp->open(">$file") || error("Unable to write into $file for unprotection: $!");
    while ($data =~ m|^(.*?)-=P\[(\d+)\]=-(.*)$|s) {
        ($prefix, $key, $data) = ($1, $2, $3);
        if ($pass < 9 and $pass < $PROTECT_STORAGE{$key}->{MAX}) {
            $prefix .= "<protect" . $PROTECT_STORAGE{$key}->{ARG} . ">";
            $data = "</protect>" . $data;
        }
        $data = $prefix . $PROTECT_STORAGE{$key}->{BODY} . $data;
    }
    #    Remove useless <protect> tags
    $data =~ s|</?protect.*?>||gs if $pass == 9;
    $fp->print($data) || error("Unable to write into $file for unprotection: $!");
    $fp->close() || error("Unable to close $file: $!");
    foreach $key (%PROTECT_STORAGE) {
        $PROTECT_STORAGE{$key} = undef if $pass < 9;
    }
}

sub pass1 {
    my ($opt, $from, $to, $tmp) = @_;
    my ($rc);

    if ($opt_s) {
        $rc = &dosystem("/usr/local/lib/wml/exec/wml_p1_ipp $opt -o $to $from");
    }
    else {
        $rc = &dosource("/usr/local/lib/wml/exec/wml_p1_ipp", "$opt -o $to $from");
    }
    return $rc;
}

sub pass2 {
    my ($opt, $from, $to, $tmp) = @_;
    my ($buf, $rc);
    local(*TMP, *TO);

    ($cwd = Cwd::cwd) =~ s|/$||;
    $rc = &dosystem("/usr/local/lib/wml/exec/wml_p2_mp4h $opt -I '$cwd' $from >$tmp"); 

    #   remove asterisks which can be entered
    #   by the user to avoid tag interpolation
    open(TMP, "<$tmp") || error("Unable to load $tmp: $!");
    open(TO, ">$to") || error("Unable to write into $to: $!");
    $buf = '';
    while (<TMP>) {
        $buf .= $_;
    }
    $buf =~ s|<\*?([a-zA-Z][a-zA-Z0-9-_]*)\*?([^a-zA-Z0-9-_])|<$1$2|sg;
    $buf =~ s|<\*?(/[a-zA-Z][a-zA-Z0-9-_]*)\*?>|<$1>|sg;
    print TO $buf
        or error("Unable to write into $to: $!");

    close(TMP) || error("Unable to close $tmp: $!");
    close(TO) || error("Unable to close $to: $!");

    return $rc;
}

sub pass3 {
    my ($opt, $from, $to, $tmp) = @_;
    my ($rc);

    $rc = &dosystem("/usr/local/lib/wml/exec/wml_p3_eperl $opt -P -k -B '<:' -E ':>' $from >$to");

    return $rc;
}

sub pass4 {
    my ($opt, $from, $to, $tmp) = @_;
    my ($rc);

    $rc = &dosystem("/usr/local/lib/wml/exec/wml_p4_gm4 $opt --prefix-builtins <$from >$to");

    return $rc;
}

sub pass5 {
    my ($opt, $from, $to, $tmp) = @_;
    my ($rc) = 0;

    if ($opt_s) {
        $rc = &dosystem("/usr/local/lib/wml/exec/wml_p5_divert $opt -o$to $from");
    }
    else {
        $rc = &dosource("/usr/local/lib/wml/exec/wml_p5_divert", "$opt -o$to $from");
    }
    return $rc;
}

sub pass6 {
    my ($opt, $from, $to, $tmp) = @_;
    my ($rc) = 0;

    if ($opt_s) {
        $rc = &dosystem("/usr/local/lib/wml/exec/wml_p6_asubst $opt -o$to $from");
    }
    else {
        $rc = &dosource("/usr/local/lib/wml/exec/wml_p6_asubst", "$opt -o$to $from");
    }
    return $rc;
}

sub pass7 {
    my ($opt, $from, $to, $tmp) = @_;
    my ($rc);

    if ($opt_s) {
        $rc = &dosystem("/usr/local/lib/wml/exec/wml_p7_htmlfix $opt -o$to $from");
    }
    else {
        $rc = &dosource("/usr/local/lib/wml/exec/wml_p7_htmlfix", "$opt -o$to $from");
    }
    return $rc;
}

sub pass8 {
    my ($opt, $from, $to, $tmp) = @_;
    my ($rc);

    if ($opt_s) {
        $rc = &dosystem("/usr/local/lib/wml/exec/wml_p8_htmlstrip $opt -o $to $from");
    }
    else {
        $rc = &dosource("/usr/local/lib/wml/exec/wml_p8_htmlstrip", "$opt -o$to $from");
    }
    return $rc;
}

sub pass9 {
    my ($opt, $from, $to, $tmp) = @_;
    my ($rc, $shebang, @X);

    #   First check whether a shebang line is found and no
    #   output files were assigned on command line.
    #   This is needed to unprotect output files.
    if ($#opt_o == -1) {
        @ARGVLINE = @ARGV;
        @ARGV = ();
        open(SLICE,"<$from") || error("Unable to load $from: $!");
        while ($_ = <SLICE>) {
            if ($_ =~ m|%!slice\s+(.*)$|) {
                @X = &split_argv($1);
                push(@ARGV, @X);
            }
        }
        close(SLICE) || error("Unable to close $from: $!");
        if ($#ARGV > -1) {
            $out_istmp = 0;
            &ProcessOptions();
            &ProcessOutfiles();
            $opt = "$verbose $out";
        }
        @ARGV = @ARGVLINE;
    }
    #   slice contains "package" commands and
    #   other stuff, so we cannot source it.
    $rc = &dosystem("/usr/local/lib/wml/exec/wml_p9_slice $opt $from");

    return $rc;
}

#
#   predefine some useful variables
#

@pwinfo = getpwuid($<);

$gen_username = $pwinfo[0];
$gen_username =~ s|[\'\$\`\"]||g; # make safe for shell interpolation
$gen_username ||= 'UNKNOWN-USERNAME';

$gen_realname = $pwinfo[6];
$gen_realname =~ s|^([^\,]+)\,.*$|$1|;
$gen_realname =~ s|[\'\$\`\"]||g; # make safe for shell interpolation
$gen_realname ||= 'UNKNOWN-REALNAME';

$gen_hostname = `hostname`;
$gen_hostname =~ s|\n$||;
$gen_hostname ||= 'UNKNOWN-HOSTNAME';

if ($gen_hostname =~ m|^[a-zA-Z0-9_-]+$| and 
    -f "/etc/resolv.conf") {
    $domain = '';
    open(TMP, "</etc/resolv.conf")
        || error("Unable to load /etc/resolv.conf: $!");
    while (<TMP>) {
        if (m|^domain\s+\.?(\S+)|) {
            $domain = $1;
            last;
        }
    }
    close(TMP) || error("Unable to close /etc/resolv.conf: $!");
    if ($domain ne '') {
        $gen_hostname = "$gen_hostname.$domain";
    }
}
$gen_time = time();
$gen_ctime = &ctime(time());
$gen_isotime = &isotime(time());
$gen_gmt_ctime = &gmt_ctime(time());
$gen_gmt_isotime = &gmt_isotime(time());

($cwd = Cwd::cwd) =~ s|/+$||;
if ($src_istmp) {
    $src_dirname  = $cwd;
    $src_filename = 'STDIN';
    $src_basename = 'STDIN';
    $src_suffix   = '';
    $src_time     = $gen_time;
    $src_ctime    = $gen_ctime;
    $src_isotime  = $gen_isotime;
    $src_gmt_ctime  = $gen_gmt_ctime;
    $src_gmt_isotime= $gen_gmt_isotime;
    $src_username = $gen_username;
    $src_realname = $gen_realname;
}
else {
    if ($src =~ m|/|) {
        $src_dirname = $src;
        $src_dirname =~ s|/+[^/]*$||;
        $src_dirname = File::PathConvert::realpath("$src_dirname");
    }
    else {
        $src_dirname  = $cwd;
    }
    $src_filename = $src;
    $src_filename =~ s|^.*/+||;
    $src_basename = $src_filename;
    $src_basename =~ s|(\.[a-zA-Z0-9]+)$||;
    $src_suffix   = $1;
    ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
     $atime,$mtime,$ctime,$blksize,$blocks) = stat($src);
    $src_time  = $mtime;
    $src_ctime = &ctime($mtime);
    $src_isotime = &isotime($mtime);
    $src_gmt_ctime = &gmt_ctime($mtime);
    $src_gmt_isotime = &gmt_isotime($mtime);
    @pwinfo = getpwuid($uid);
    $src_username = $pwinfo[0] || 'UNKNOWN-USERNAME';
    $src_username =~ s|[\'\$\`\"]||g; # make safe for shell interpolation
    $src_realname = $pwinfo[6] || 'UNKNOWN-REALNAME';
    $src_realname =~ s|^([^\,]+)\,.*$|$1|;
    $src_realname =~ s|[\'\$\`\"]||g; # make safe for shell interpolation
}

unshift(@opt_D, "WML_SRC_DIRNAME=$src_dirname");
unshift(@opt_D, "WML_SRC_FILENAME=$src_filename");
unshift(@opt_D, "WML_SRC_BASENAME=$src_basename");
unshift(@opt_D, "WML_SRC_TIME=$src_time");
unshift(@opt_D, "WML_SRC_CTIME=$src_ctime");
unshift(@opt_D, "WML_SRC_ISOTIME=$src_isotime");
unshift(@opt_D, "WML_SRC_GMT_CTIME=$src_gmt_ctime");
unshift(@opt_D, "WML_SRC_GMT_ISOTIME=$src_gmt_isotime");
unshift(@opt_D, "WML_SRC_USERNAME=$src_username");
unshift(@opt_D, "WML_SRC_REALNAME=$src_realname");
unshift(@opt_D, "WML_GEN_TIME=$gen_time");
unshift(@opt_D, "WML_GEN_CTIME=$gen_ctime");
unshift(@opt_D, "WML_GEN_ISOTIME=$gen_isotime");
unshift(@opt_D, "WML_GEN_GMT_CTIME=$gen_gmt_ctime");
unshift(@opt_D, "WML_GEN_GMT_ISOTIME=$gen_gmt_isotime");
unshift(@opt_D, "WML_GEN_USERNAME=$gen_username");
unshift(@opt_D, "WML_GEN_REALNAME=$gen_realname");
unshift(@opt_D, "WML_GEN_HOSTNAME=$gen_hostname");
unshift(@opt_D, "WML_LOC_PREFIX=/usr/local");
unshift(@opt_D, "WML_LOC_BINDIR=/usr/local/bin");
unshift(@opt_D, "WML_LOC_LIBDIR=/usr/local/lib/wml");
unshift(@opt_D, "WML_LOC_MANDIR=/usr/local/man");
unshift(@opt_D, "WML_VERSION=$VERSION");
unshift(@opt_D, "WML_TMPDIR=$tmpdir");

#   Create temporary file names as soon as $src_suffix is set
$tmp[0] = "$tmpdir/wml.$$.tmp1" . $src_suffix;
$tmp[1] = "$tmpdir/wml.$$.tmp2" . $src_suffix;
$tmp[2] = "$tmpdir/wml.$$.tmp3" . $src_suffix;
$tmp[3] = "$tmpdir/wml.$$.tmp4" . $src_suffix;

#   Flag set if some output goes to stdout
$out_istmp = 0;

#
#   generate options
#

#   canonicalize -p option(s)
if ($#opt_p == -1) {
    #   no option means all passes
    @opt_p = ( '1-9' );
}
if (not -s $src) {
    #   on empty input optimize to just use pass 9
    @opt_p = ( '9' );
}
$p = join('', @opt_p);
$p =~ s|,||g;
sub expandrange {
    my ($a, $b) = @_;
    $x = ''; 
    for ($i = $a; $i <= $b; $i++) { 
        $x .= $i;
    }
    return $x;
}
$p =~ s|(\d)-(\d)|&expandrange($1, $2)|sge;
if ($p =~ m/!$/) {
    $p =~ s/!$//;
    @p = split('', $p);
}
else {
    @p = sort {$a <=> $b} (split('', $p));
}

#   only pre-processing if -M option specified
@p = ( '1' ) if $opt_M ne '-';

#   determine includes
$inc = '';
foreach $i (@opt_I) {
    $inc .= " -I $i";
}

#   determine preloads
$preload = '';
foreach $p (@p) {
    $preload .= " -s 'sys/bootp${p}.wml'"
      if -f "/usr/local/lib/wml/include/sys/bootp${p}.wml" and $p =~ m/^[34]$/;
}
foreach $i (@opt_i) {
    if ($i =~ m|^<(.+)>$|) {
        $preload .= " -s '$1'";
    }
    else {
        $preload .= " -i '$i'";
    }
}

#   determine prologs
$prolog = '';
foreach $p (@opt_P) {
    $prolog .= ' -P "'.&quotearg($p).'"';
}

$defipp = '';
my $dummy;
foreach $d (@opt_D) {
    ($var, $dummy, $val) = ($d =~ m|^(.+?)=("?)(.*)\2\n*$|);
    $defipp .= " \"-D$var=$val\"";
}
$defipp .= " -M$opt_M" if $opt_M ne '-';
$defipp .= " -DIPP_SRC_REALNAME=$src_filename" if not $src_istmp;

$defmp4h = '';
foreach $d (@opt_D) {
    ($var, $dummy, $val) = ($d =~ m|^(.+?)=("?)(.*)\2\n*$|);
    $defmp4h .= " -D $var=\"$val\"";
}
$cnt=0;
foreach $o (@opt_o) {
    $defmp4h .= " -D SLICE_OUTPUT_FILENAME[$cnt]=\"$o\"" if $o =~ m|\*|;
    $cnt++;
}

$defeperl = '';
foreach $d (@opt_D) {
    ($var, $dummy, $val) = ($d =~ m|^(.+?)=("?)(.*)\2\n*$|);
    $defeperl .= " \"-d$var=$val\"";
}

$defgm4 = '';
foreach $d (@opt_D) {
    ($var, $dummy, $val) = ($d =~ m|^(.+?)=("?)(.*)\2\n*$|);
    $defgm4 .= " \"-Dm4_$var=$val\"";
}

sub ProcessOutfiles {
    my ($o);

    $out = '';
    @outfiles = ();
    foreach $o (@opt_o) {
        next if ($o =~ m|\*[^:]*$|);

        #   create option
        if ($o eq '-') {
            $out .= " -o '".&quotearg($tmp[3])."'";
            $out_istmp = 1;
        } elsif ($o =~ m/(.*):-$/) {
            $out .= " -o '".&quotearg($1.':'.$tmp[3])."'";
            $out_istmp = 1;
        } else {
            $out .= " -o '".&quotearg($o)."'";
        }

        #   unquote the filename
        $o =~ s|^(['"])(.*)\1$|$2|;
    
        #   create output file list for epilog filters
        if ($o =~ m|^([_A-Z0-9~!+u%n\-\\^x*{}()@]+):(.+)\@(.+)$|) {
            push(@outfiles, ($2 ne '-' ? $2 : $tmp[3]));
        }
        elsif ($o =~ m|^([_A-Z0-9~!+u%n\-\\^x*{}()@]+):(.+)$|) {
            push(@outfiles, ($2 ne '-' ? $2 : $tmp[3]));
        }
        elsif ($o =~ m|^(.+)\@(.+)$|) {
            push(@outfiles, ($1 ne '-' ? $1 : $tmp[3]));
        }
        else {
            push(@outfiles, ($o ne '-' ? $o : $tmp[3]));
        }
    }
}
&ProcessOutfiles();

$verbose = '';
if ($opt_v >= 3) {
    $verbose = '-v';
}

$optimize = '';
if ($opt_O ne '') {
    $optimize = "-O$opt_O";
}

if (not $src_istmp) {
    #  Input file is copied because of the protect/unprotect stuff
    $fpin = new IO::File;
    $fpin->open("<$src") || error("Unable to load $src: $!");
    $fpout = new IO::File;
    $fpout->open(">$tmp[0]") || error("Unable to write into $tmp[0]: $!");
    while (<$fpin>) {
        $fpout->print($_) || error("Unable to write into $tmp[0]: $!");
    }
    $fpout->close() || error("Unable to close $tmp[0]: $!");
    $fpin->close() || error("Unable to close $src: $!");

    $from  = $tmp[0];
    $to    = $tmp[1];
    $cnt   = 1;
}
else {
    $from  = $src;
    $to    = $tmp[0];
    $cnt   = 0;
}

if ($out eq '') {
    $out = " -o$tmp[3]";
    $out_istmp = 1;
}

$opt_pass1 = "$defipp $verbose -S /usr/local/lib/wml/include -n $src $inc $preload $prolog";
$opt_pass2 = "$defmp4h";
$opt_pass3 = "$defeperl";
$opt_pass4 = "$defgm4";
$opt_pass5 = "$verbose";
$opt_pass6 = "$verbose";
$opt_pass7 = "$verbose";
$opt_pass8 = "$verbose $optimize";
$opt_pass9 = "$verbose $out";


$pcnt  = 0;
@prop  = ( "-", "\\", "|", "/");
$last  = '';
$final = 0;
$pager = ($ENV{'PAGER'} || 'more');

#
#   clear out any existing CGI environments because some of our
#   passes (currently Pass 2 and 3) get totally confused by these
#   variables.
#
map { delete $ENV{$_} } qw(
    SERVER_SOFTWARE SERVER_NAME GATEWAY_INTERFACE SERVER_PROTOCOL
    SERVER_PORT REQUEST_METHOD PATH_INFO PATH_TRANSLATED SCRIPT_NAME
    QUERY_STRING REMOTE_HOST REMOTE_ADDR AUTH_TYPE REMOTE_USER REMOTE_IDENT
    CONTENT_TYPE CONTENT_LENGTH HTTP_ACCEPT HTTP_USER_AGENT
);

sub unlink_tmp {
    unlink($tmp[0]);
    unlink($tmp[1]);
    unlink($tmp[2]);
    unlink($tmp[3]);
    unlink($src) if ($src_istmp);
}

if ($opt_M ne '-') {
    if ($#outfiles > -1) {
        $o = '"'. join(' ',@outfiles) . '"';
        $opt_pass = '';
        foreach $a (@opt_W) {
            if ($a =~ m|^(\d),(.*)$|) {
                $opt_pass .= " $2 " if $1 == 1;
            }
        }
        eval "\$rc = \&pass1(\$opt_pass1 . \$opt_pass, \$src, \$o, \$tmp[2]);";
        if ($rc != 0) {
            if ($rc % 256 != 0) {
                printf(STDERR "** WML:Break: Error in Pass %d (status=%d, rc=%d).\n", 1, $rc % 256, $rc / 256);
            }
            else {
                printf(STDERR "** WML:Break: Error in Pass %d (rc=%d).\n", 1, $rc / 256);
            }
            &unlink_tmp();
            exit(1);
        }
    }
    &unlink_tmp();
    exit(0);
}

#
#   MAIN PROCESSING LOOP
#
@TIMES = ();
$firstpass = 1;
foreach $p (@p) {
    &verbose(2, "PASS $p:\n");
    print STDERR @prop[$pcnt++ % 4] . "\b" if (not $opt_q); 

    #   run pass
    ($u, $s, $cu, $cs) = times();
    $stime = $u + $s + $cu + $cs;
    &protect($from, $p);
    $opt_pass = '';
    foreach $a (@opt_W) {
        if ($a =~ m|^(\d),(.*)$|) {
            $opt_pass .= " $2 " if $1 == $p;
        }
    }
    eval "\$rc = \&pass$p(\$opt_pass$p . \$opt_pass, \$from, \$to, \$tmp[2]);";
    if ($rc != 0) {
        if ($rc % 256 != 0) {
            printf(STDERR "** WML:Break: Error in Pass %d (status=%d, rc=%d).\n", $p, $rc % 256, $rc / 256);
        }
        else {
            printf(STDERR "** WML:Break: Error in Pass %d (rc=%d).\n", $p, $rc / 256);
        }
        &unlink_tmp();
        exit(1);
    }
    &unprotect($to, $p) if ($p < 9); # pass 9 is a special case
    ($u, $s, $cu, $cs) = times();
    $etime = $u + $s + $cu + $cs;
    $dtime = $etime-$stime;
    $dtime = 0.01 if ($dtime < 0);
    $TIMES[$p] = $dtime;
    
    #   optionally view current result
    if ($opt_v >= 3 && $p < 9) {
        print STDERR "Want to see result after Pass$p [yNq]: ";
        ReadMode 4;
        $key = ReadKey(0);
        ReadMode 0;
        print STDERR "\n";
        if ($key =~ m|[Yy]|) {
            system("$pager $to");
        }
        elsif ($key =~ m|[qQ]|) {
            printf(STDERR "** WML:Break: Manual Stop.\n");
            &unlink_tmp();
            exit(1);
        }
    }

    #   step further
    $last  = $to;
    $final = 1 if $p == 9;
    $from  = $tmp[$cnt % 2];
    $to    = $tmp[($cnt+1) % 2];
    unlink($to);
    $cnt++;
    last if $p == 9;
}

if ($last ne '' and $final and $out_istmp) {
    &unprotect($tmp[3], 9);
} elsif ($last ne '' and not $final) {
    my $i = 0;
    my @fh = ();
    my $fp;
    &unprotect($last, 9);
    if ($#outfiles > -1) {
        foreach $o (@outfiles) {
            $fh[$i] = new IO::File "> $o";
            error("Unable to write into $o") if !defined $fh[$i];
            $i++;
        }
    } else {
        $fh[$i] = new IO::File "> $tmp[3]";
        error("Unable to write into $tmp[3]") if !defined $fh[$i];
    }
    open(FP, "<$last") || error("Unable to load $last: $!");
    while (<FP>) {
        foreach $fp (@fh) {
            print $fp $_
                or error("Unable to write into output file: $!");
        }
    }
    foreach $fp (@fh) {
        $fp->close() || error("Unable to close output file: $!");
    }
    close(FP) || error("Unable to close $last: $!");
}
#   Unprotect output files and run epilog filters
if ($#outfiles > -1) {
    #   unprotect all outputfiles
    foreach $o (@outfiles) {
        &unprotect($o, 9);
    }

    #   optionally set mtime of outputfiles
    #   to mtime of inputfile if inputfile was not STDIN
    if (not $src_istmp and $opt_t) {
        ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
         $atime,$mtime,$ctime,$blksize,$blocks) = stat($src);
         $atime = time();
         foreach $o (@outfiles) {
             utime($atime, $mtime+1, $o);
         }
    }

    #   run epilog filters
    foreach $o (@outfiles) {
        foreach $e (@opt_E) {
            if ($e =~ m|^htmlinfo(.*)|) {
                $e = "/usr/local/lib/wml/exec/wml_aux_htmlinfo$1";
            }
            elsif ($e =~ m|^linklint(.*)|) {
                $e = "/usr/local/lib/wml/exec/wml_aux_linklint$1";
                $e .= " -nocache -one -summary" if ($1 eq '');
            }
            elsif ($e =~ m|^weblint(.*)|) {
                $e = "/usr/local/lib/wml/exec/wml_aux_weblint$1";
            }
            elsif ($e =~ m|^tidy(.*)|) {
                $e = "/usr/local/lib/wml/exec/wml_aux_tidy$1";
                $e .= " -m" if ($1 eq '');
            }
            &verbose(2, "EPILOG: $e $o\n");
            $rc = system("$e $o");
            #   Tidy returns 1 on warnings and 2 on errors :(
            $rc = 0 if ($rc == 256 and $e =~ m|/usr/local/lib/wml/exec/wml_aux_tidy|);
            error("epilog failed: $e $o") if $rc != 0;
        }
    }
}

#   ... and eventually send to stdout
if ($out_istmp) {
    open(FP, "<$tmp[3]") || error("Unable to load $tmp[3]: $!");
    while (<FP>) {
        print $_;
    }
}

&unlink_tmp();

($u, $s, $cu, $cs) = times();
$at = $u + $s + $cu + $cs;
$i  = 1;
$pt = 0;
$timestr = '';
foreach $t (@TIMES[1..9]) {
    $pt += $t;
    if ($i == 2 or $i == 3) {
        $timestr .= sprintf($t ne '' ? "%5.2f " : "   -- ", $t);
    }
    else {
        $timestr .= sprintf($t ne '' ? "%4.2f " : "  -- ", $t);
    }
    $i++;
}
$timestr = sprintf("%4.2f | ", $at-$pt) . $timestr;
$timestr .= sprintf("| %6.2f", $at);
&verbose(1, "Processing time (seconds):\n");
&verbose(1, "main |  ipp  mp4h   epl  gm4  div asub hfix hstr slic |  TOTAL\n");
&verbose(1, "---- | ---- ----- ----- ---- ---- ---- ---- ---- ---- | ------\n");
&verbose(1, "$timestr\n");

#   exit gracefully
exit(0);

##EOF##

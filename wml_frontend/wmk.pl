#!/usr/bin/perl
eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if $running_under_some_shell;
##
##  WMk -- Website META Language Make
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

use Term::Cap;
use Getopt::Long 2.13;
use Cwd;
use File::Find;

##
##  INIT
##

if ($ENV{'PATH'} !~ m|/usr/local/bin|) {
    $ENV{'PATH'} = '/usr/local/bin:'.$ENV{'PATH'};
}

$WML = $ENV{'WML'} || '/usr/local/bin/wml';

eval "\$term = Tgetent Term::Cap { TERM => undef, OSPEED => 9600 }";
if ($@) {
    $bold = '';
    $norm = '';
}
else {
    $bold = $term->Tputs('md', 1, undef);
    $norm = $term->Tputs('me', 1, undef);
}

##
##  PROCESS ARGUMENT LINE
##

sub usage {
    my ($progname) = @_;
    my ($o);

    print STDERR "Usage: $progname [options] [path ...]\n";
    print STDERR "\n";
    print STDERR "Operation Options (WMk intern):\n";
    print STDERR "  -a, --all               run for all files recursively\n";
    print STDERR "  -A, --accept=WILDMAT    accept files via shell wildcard matching\n";
    print STDERR "  -F, --forget=WILDMAT    forget files which were previously accepted\n";
    print STDERR "  -o, --outputfile=PATH   specify the output file(s)\n";
    print STDERR "  -x, --exec-prolog=PATH  execute a prolog program in local context\n";
    print STDERR "  -X, --exec-epilog=PATH  execute a epilog program in local context\n";
    print STDERR "  -f, --force             force outpout generation\n";
    print STDERR "  -n, --nop               no operation (nop) mode\n";
    print STDERR "  -r, --norcfile          no .wmkrc and .wmlrc files are read\n";
    print STDERR "\n";
    $o = `$WML --help 2>&1`;
    $o =~ s|^.+?\n\n||s;
    $o =~ s|^.+?--noshebang.+?\n||m;
    $o =~ s|^.+?--norcfile.+?\n||m;
    $o =~ s|^.+?--outputfile.+?\n||m;
    print STDERR $o;
    exit(1);
}

sub ProcessOptions {
    $Getopt::Long::bundling = 1;
    $Getopt::Long::getopt_compat = 0;
    local $SIG{'__WARN__'} = sub {
        print STDERR "WMk:Error: $_[0]";
    };
    if (not Getopt::Long::GetOptions(
            "a|all",
            "A|accept=s@",
            "F|forget=s@",
            "x|exec-prolog=s@",
            "X|exec-epilog=s@",
            "f|force",
            "n|nop",
            "r|norcfile",
            "I|include=s@", 
            "i|includefile=s@", 
            "D|define=s@",
            "O|optimize=i",
            "o|outputfile=s@",
            "P|prologue=s@",
            "E|epilogue=s@",
            "t|settime",
            "p|pass=s@",
            "W|passoption=s@",
            "M|depend:s",
            "s|safe",
            "v|verbose:i",
            "q|quiet",
            "z|mp4h",
            "V|version:i",
            "h|help"
    )) {
        print STDERR "Try `$0 --help' for more information.\n";
        exit(0);
    }
    &usage($0) if ($opt_h);
}

sub error {
    my ($str) = @_;
    print STDERR "** WMK:Error: $str\n";
    exit(1);
}

#   save argument line
@ARGVLINE = @ARGV;

#   WMk options
$opt_a = 0;
@opt_A = ('*.wml');
@opt_F = ();
@opt_o = ();
@opt_x = ();
@opt_X = ();
$opt_f = 0;
$opt_r = 0;
$opt_n = 0;

#   WML options are read from the command line
@opt_I = ();
@opt_i = ();
@opt_D = ();
$opt_O = '';
@opt_P = ();
@opt_E = ();
$opt_t = 0;
@opt_p = ();
@opt_W = ();
$opt_M = '-';
$opt_s = 0;
$opt_v = -1;
$opt_q = 0;
$opt_h = 0;
$opt_V = -1;
$opt_z = 0;

&ProcessOptions();

#   fix the version level
if ($opt_V == 0) {
    $opt_V = 1; # Getopt::Long sets 0 if -V only
}
if ($opt_V == -1) {
    $opt_V = 0; # we operate with 0 for not set
}
if ($opt_V) {
    system("$WML -V$opt_V");
    exit(0);
}

#   If the -M was the last option and the user forgot
#   to put `--' to end options, we adjust it.
if ($opt_M !~ m%^(-|[MD]*)$% && $#ARGV == -1) {
    push(@ARGV,$opt_M);
    $opt_M = '';
}

##
##   CREATE WML COMMAND
##

#   escape options if not quoted but
#   when shell metachars exists
sub quotearg {
    my ($arg) = @_;
    if ($arg !~ m|^'.*'$| and $arg !~ m|^".*"$|) {
        if ($arg =~ m|[\[\]()!*?&"']|) {
            $arg =~ s|'|\\'|sg;
            $arg = "'".$arg."'";
        }
    }
    return $arg;
}

sub addquotedarg {
    my ($flag, $arg) = @_;
    return ' -'.$flag.' "'.&quotearg($arg).'"';
}

$Oq = '';
$Oq = ' -q' if ($opt_q);

$Oz = '';
$Oz = ' -z' if ($opt_z);

$Ov = '';
$Ov = ' -v' if ($opt_v == 0);
$Ov = ' -v'.$opt_v if ($opt_v > 0);

$Op = '';
foreach $a (@opt_p) { $Op .= ' -p'.$a; }

$OW = '';
foreach $a (@opt_W) { $OW .= &addquotedarg('W', $a); }

$OD = '';
foreach $a (@opt_D) { $OD .= &addquotedarg('D', $a); }

$OP = '';
foreach $a (@opt_P) { $OP .= &addquotedarg('P', $a); }

$OE = '';
foreach $a (@opt_E) { $OE .= &addquotedarg('E', $a); }

$OM = '';
$OM = " -M$opt_M" if ($opt_M ne '-');

$Ot = '';
$Ot = ' -t' if ($opt_t);

$Or = '';
$Or = ' -r' if ($opt_r);

$Os = '';
$Os = ' -s' if ($opt_s);

$OI = '';
foreach $a (@opt_I) { $OI .= &addquotedarg('I', $a); }

$Oi = '';
foreach $a (@opt_i) { $Oi .= &addquotedarg('i', $a); }

$OO = '';
$OO = ' -O'.$opt_O if ($opt_O ne '');

$wml_cmd = "$WML -n".$Oq.$Oz.$Ov.$Op.$OW.$OD.$OP.$OE.$OM.$Ot.$Os.$Or.$OI.$Oi.$OO;
$wml_ipp = "$WML -n -MM".$Oq.$Oz.$Ov.$Op.$OW.$OD.$OP.$OE.$OM.$Ot.$Os.$Or.$OI.$Oi.$OO;

$Oo = '';
foreach $a (@opt_o) { $Oo .= ' -o'.$a; }

#   store initial working directory
my $cwd = Cwd::cwd;

##  read $HOME/.wmkrc
my @pwinfo = getpwuid($<);
my $home = $pwinfo[7];
$home =~ s|/$||;
if (-f "$home/.wmkrc") {
        chdir ($home);
        &read_rcfile();
        chdir ($cwd);
}

##
##   FILESYSTEM PROCESSING
##

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

#    this variable is defined in read_rcfile
$matchF = '';

#   set the path to act on
if ($#ARGV == -1) {
    @P = ( '.' );
}
else {
    @P = @ARGV;
}
foreach $p (@P) {
    if (-d $p) {
        if ($opt_a) {
            #
            #   path is a directory and we run recursively
            #
            #   first look into .wmkrc in case -F option is found
            chdir($p);
            &read_rcfile();
            chdir($cwd);

            @dirs = ();
            sub wanted {
              -d $_ &&
              ( m#^${matchF}$# && ($File::Find::prune = 1)
                               || push (@dirs, $File::Find::name));
            }
            File::Find::find(\&wanted, $p);
            $dirC = '';
            foreach $dir (@dirs) {
                $dir =~ s|\n$||;
                chdir($dir);
                &read_rcfile() if $dir ne $p;
                @files = &determine_files();
                if ($#files > -1) {
                    #   a little bit verbosity
                    if ($dirC ne $dir) {
                        $dirC = $dir;
                        $dirtxt = &CanonPath($dir);
                        if ($dirtxt ne '.') {
                            print STDERR "${bold}[$dirtxt]${norm}\n";
                        }
                    }
                    foreach $exec (@opt_x_CUR) {
                        $rc = system($exec);
                        error("prolog failed: $exec") if $rc != 0;
                    }
                    foreach $file (@files) {
                        &process_file("$dir/$file", $dir, $file);
                    }
                    foreach $exec (@opt_X_CUR) {
                        $rc = system($exec);
                        error("epilog failed: $exec") if $rc != 0;
                    }
                }
                chdir($cwd);
            }
        }
        else {
            #
            #   path is a directory and we run locally
            #
            chdir($p);
            &read_rcfile();
            next if $p =~ m#^${matchF}$#;
            @files = &determine_files();
            foreach $exec (@opt_x_CUR) {
                $rc = system($exec);
                error("prolog failed: $exec") if $rc != 0;
            }
            foreach $file (@files) {
                &process_file("$p/$file", $p, $file);
            }
            foreach $exec (@opt_X_CUR) {
                $rc = system($exec);
                error("epilog failed: $exec") if $rc != 0;
            }
            chdir($cwd);
        }
    }
    elsif (-f $p) {
        #
        #   path is a file
        #
        next if $p =~ m#^${matchF}$#;

        my ($dir, $file) = ($p =~ m|^(.*?)([^/]+)$|);
        if ($dir) {
            chdir($dir);
            &read_rcfile();
            &process_file($p, $dir, $file);
            chdir($cwd);
        }
        else {
            &read_rcfile();
            &process_file($p, $dir, $file);
        }
    }
    else {
        error("path `$p' neither directory nor plain file");
    }
}

#   read .wmkrc files and command-line options
sub read_rcfile {
    my ($cwd, $dir, @DIR);
    @opt_A_SAV = @opt_A;
    @opt_F_SAV = @opt_F;
    @opt_x_SAV = @opt_x;
    @opt_X_SAV = @opt_X;
    @opt_o_SAV = @opt_o;
    @opt_A_CUR = @opt_A;
    @opt_F_CUR = @opt_F;
    @opt_x_CUR = @opt_x;
    @opt_X_CUR = @opt_X;
    $opt_o_CUR = '';
    if (not $opt_r) {
        ($cwd = Cwd::cwd) =~ s|/$||;
        while ($cwd) {
            push(@DIR, $cwd);
            $cwd =~ s|/[^/]+$||;
        }
        foreach $dir (reverse(@DIR)) {
            if (-f "$dir/.wmkrc") {
                open(FP, "<$dir/.wmkrc")
                        || error("Unable to load $dir/.wmkrc: $!");
                @ARGV = ();
                while (<FP>) {
                    next if (m|^\s*\n$|);
                    next if (m|^\s*#[#\s]*.*$|);
                    s|^\s+||;
                    s|\s+$||;
                    s|\$([A-Za-z_][A-Za-z0-9_]*)|$ENV{$1}|ge;
                    push(@ARGV, &split_argv($_));
                }
                close(FP) || error("Unable to close $dir/.wmkrc: $!");
                @opt_A = ();
                @opt_F = ();
                @opt_x = ();
                @opt_X = ();
                @opt_o = ();
                &ProcessOptions();
                @opt_A_CUR = (@opt_A_CUR, @opt_A);
                @opt_F_CUR = (@opt_F_CUR, @opt_F);
                @opt_x_CUR = (@opt_x_CUR, @opt_x);
                @opt_X_CUR = (@opt_X_CUR, @opt_X);
                if ($#opt_o > -1) {
                    $opt_o_CUR = '-o' . join(' -o', @opt_o);
                }
            }
        }
    }

    #   Add command-line options
    @opt_A = ();
    @opt_F = ();
    @opt_x = ();
    @opt_X = ();
    @opt_o = ();
    @ARGV  = @ARGVLINE;
    &ProcessOptions();
    @opt_A_CUR = (@opt_A_CUR, @opt_A);
    @opt_F_CUR = (@opt_F_CUR, @opt_F);
    @opt_x_CUR = (@opt_x_CUR, @opt_x);
    @opt_X_CUR = (@opt_X_CUR, @opt_X);
    if ($#opt_o > -1) {
        $opt_o_CUR = '-o' . join(' -o', @opt_o);
    }

    #    transforms filename wildcards into extended regexp
    if ($#opt_F_CUR > -1) {
        $matchF = '(' . join ('|', @opt_F_CUR) . ')';
        $matchF =~ s|\.|\\.|g;
        $matchF =~ s|\?|.|g;
        $matchF =~ s|\*|.*|g;
    }
    else {
        $matchF = '';
    }

    #   Restore values
    @opt_A = @opt_A_SAV;
    @opt_F = @opt_F_SAV;
    @opt_x = @opt_x_SAV;
    @opt_X = @opt_X_SAV;
    @opt_o = @opt_o_SAV;
}

#   determine files to act on
sub determine_files {
    my (@files, @filesA, @filesF, $fileA, $fileF, %files);

    #   determine files
    @filesA = glob(join(' ', @opt_A_CUR));
    @filesF = glob(join(' ', @opt_F_CUR));
    %files = ();
    foreach $fileA (@filesA) {
        $ok = 1;
        foreach $fileF (@filesF) {
            if ($fileA eq $fileF) {
                $ok = 0;
                last;
            }
        }
        $files{$fileA} = 1 if $ok;
    }
    @files = sort(keys(%files));

    return @files;
}

#   helper function to split argument line
#   the same way Bourne-Shell does:
#   #1: foo=bar quux   => "foo=bar", "quux"
#   #2: "foo=bar quux" => "foo=bar quux"
#   #3: foo="bar quux" => "foo=bar quux"     <-- !!
sub split_argv {
    my ($str) = @_;
    my (@argv) = ();
    my ($r) = '';

    while (1) {
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
    }
    return @argv;
}

sub process_file {
    my ($path, $dir, $file) = @_;
    my ($shebang, $opts, $out);
    local (*FP);

    #   determine additional options
    $opts = $Oo;
    if ($opts eq '') {
        $opts = $opt_o_CUR;
        open(FP, "<$file") || error("Unable to load $file: $!");
        $shebang = '';
        while (1) {
            $shebang .= <FP>;
            if ($shebang =~ m|^(.*)\\\s*$|s) {
                $shebang = $1;
                next;
            }
            last;
        }
        if ($shebang =~ m|^#!wml\s+(.+\S)\s*$|is) {
           $opts = $1;
        }
        close(FP) || error("Unable to close $file: $!");
    }

    #   expand %DIR and %BASE
    my $base = $file;
    $base =~ s|\.[a-zA-Z0-9]+$||;
    $opts =~ s|%DIR|$dir|sg;
    $opts =~ s|%BASE|$base|sg;

    #   determine default output file
    if ($opts !~ m|-o|) {
        $opts .= " -o ${base}.html";
    }
    $opts =~ s|(\s*)(\S+)|' '.&quotearg($2)|sge;
    $opts =~ s|^\s+||;
    $opts =~ s|\s+$||;

    #   determine if invocation can be skipped
    if (not $opt_f) {
        my @outfiles = ();
        my $s = $opts;
        $s =~ s|-o\s*["']?(?:[^:]+:(?!:))?([^\s\@'"]+)|push(@outfiles, $1), ''|sge;
        $skipable = &skipable($file, @outfiles);
    }
    else {
        $skipable = 0;
    }
    
    if ($skipable) {
        print STDERR "$wml_cmd $opts $file  (${bold}skipped${norm})\n";
    }
    else {
        print STDERR "$wml_cmd $opts $file\n";
        if (not $opt_n) {
            $rc = system("$wml_cmd $opts $file");
            error("Error in WML (rc=$rc)") if $rc != 0;
        }
    }
}

#   is file skipable because not newer than
#   any of its output files
sub skipable {
    my ($file, @outfiles) = @_;
    my ($skipable, $outfile, $t, $dep, $incl);
    my (@IS, @OS);

    $skipable = 1;
    @IS = stat($file);
    local($/) = undef;
    open(DEP, "$wml_ipp -odummy $file |")
        || error("Unable to exec $wml_ipp: $!");
    $dep = <DEP>;
    close(DEP) || error("Unable to close exec $wml_ipp: $!");
    $dep =~ s/\\\s+/ /sg;
    if ($dep =~ m|^(.*):\s+(.*?)\s+(.*)$|) {
        foreach $incl (split(/\s+/,$3)) {
            if (-f $incl) {
                @OS = stat(_);
                if ($IS[9] < $OS[9]) { # 9=mtime
                    $IS[9] = $OS[9];
                }
            }
       } 
    }
    
    foreach $outfile (@outfiles) {
        if (-f $outfile) {
            @OS = stat(_);
            if ($IS[9] >= $OS[9]) { # 9=mtime
                $skipable = 0;
                last;
            }
        }
        else {
            $skipable = 0;
            last;
        }
    }
    return $skipable;
}


#   exit gracefully
exit(0);

##EOF##

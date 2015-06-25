#!/usr/bin/perl
eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if $running_under_some_shell;
##
##  IPP -- Include Pre-Processor
##  Copyright (c) 1997,1998,1999 Ralf S. Engelschall, All Rights Reserved. 
##  Copyright (c) 2000 Denis Barbier, All Rights Reserved. 
##

require 5.003;

BEGIN { $^W = 0; } # get rid of nasty warnings

use lib "/usr/local/lib/wml/perl/lib";
use lib "/usr/local/lib/wml/perl/lib/x86_64-linux";

use Getopt::Long 2.13;
use IO::Handle 1.15;
use IO::File 1.06;

#
#   help functions
#
sub verbose {
    my ($level, $str) = @_;
    if ($opt_v) {
        print STDERR ' ' x ($level*2) . "$str\n";
    }
}
sub error {
    my ($str) = @_;
    print STDERR "** IPP:Error: $str\n";
    exit(1);
}
sub warning {
    my ($str) = @_;
    print STDERR "** IPP:Warning: $str\n";
}


#
#   process command line 
#
sub usage {
    print STDERR "Usage: ipp [options] file ...\n";
    print STDERR "\n";
    print STDERR "Options:\n";
    print STDERR "  -D, --define=<name>=<value>  define a variable\n";
    print STDERR "  -S, --sysincludedir=<dir>    add system include directory\n";
    print STDERR "  -I, --includedir=<dir>       add user include directory\n";
    print STDERR "  -s, --sysincludefile=<file>  pre-include system include file\n";
    print STDERR "  -i, --includefile=<file>     pre-include user include file\n";
    print STDERR "  -M, --depend=<options>       dump dependencies as gcc does\n";
    print STDERR "  -P, --prolog=<path>          specify one or more prolog filters\n";
    print STDERR "  -m, --mapfile=<file>         use include file mapping table\n";
    print STDERR "  -N, --nosynclines            do not output sync lines\n";
    print STDERR "  -n, --inputfile=<file>       set input file name printed by sync lines\n";
    print STDERR "  -o, --outputfile=<file>      set output file instead of stdout\n";
    print STDERR "  -v, --verbose                verbosity\n";
    exit(1);
}
$opt_v = 0;
$opt_M = '-';
@opt_I = ();
@opt_D = ();
@opt_S = ();
@opt_i = ();
@opt_s = ();
@opt_P = (); 
@opt_m = (); 
$opt_N = 0;
$opt_n = '';
$opt_o = '-';
$Getopt::Long::bundling = 1;
$Getopt::Long::getopt_compat = 0;
if (not Getopt::Long::GetOptions(
    "v|verbose", 
    "S|sysincludedir=s@", 
    "D|define=s@", 
    "I|includedir=s@", 
    "s|sysincludefile=s@", 
    "i|includefile=s@", 
    "M|depend:s" ,
    "P|prolog=s@",
    "m|mapfile=s@", 
    "N|nosynclines", 
    "n|inputfile=s", 
    "o|outputfile=s"  )) {
    &usage;
}
#   Adjust the -M flags
if ($opt_M !~ m%^(-|[MD]*)$% && $#ARGV == -1) {
    push(@ARGV,$opt_M);
    $opt_M = '';
}
&usage if ($#ARGV == -1);
push(@opt_I, '.');

#
#   read mapfiles
#
sub read_mapfile {
    my ($MAP, $mapfile) = @_;
    local (*FP);

    open(FP, "<$mapfile") || error("cannot load $mapfile: $!");
    while (<FP>) {
        next if (m|^\s*$|);
        next if (m|^\s*#.*$|);
        if (($given, $replace, $actiontype, $actiontext) =
             m|^(\S+)\s+(\S+)\s+\[\s*([SWE])\s*:\s*(.+?)\s*\].*$|) {
            if ($given =~ m|,|) {
                @given = split(/,/, $given);
            }
            else {
                @given = ($given);
            }
            foreach $given (@given) {
                $MAP->{$given} = {};
                $MAP->{$given}->{REPLACE}    = $replace; 
                $MAP->{$given}->{ACTIONTYPE} = $actiontype;
                $MAP->{$given}->{ACTIONTEXT} = $actiontext;
            }
        }
    }
    close(FP) || error("cannot close $mapfile");
}
$MAP = {};
foreach $file (@opt_m) {
    &read_mapfile($MAP, $file);
}


#
#   iterate over the input files
#

%INCLUDES = ();
$outbuf   = '';

sub setargs {
    my ($arg, $str) = @_;

    return if ($str eq '');
    while ($str) {
        $str =~ s|^\s+||;
        last if ($str eq '');
        if ($str =~ s|^([a-zA-Z][a-zA-Z0-9_]*)="([^"]*)"||) {
            $arg->{$1} = $2;
        }
        elsif ($str =~ s|^([a-zA-Z][a-zA-Z0-9_]*)=(\S+)||) {
            $arg->{$1} = $2;
        }
        elsif ($str =~ s|^([a-zA-Z][a-zA-Z0-9_]*)=\s+||) {
            $arg->{$1} = '';
        }
        elsif ($str =~ s|^([a-zA-Z][a-zA-Z0-9_]*)||) {
            $arg->{$1} = 1;
        }
        else {
            $str = substr($str, 1); # make sure the loop terminates
        }
    }
}

sub mapfile {
    my ($file) = @_;
    my ($replace, $type, $text);

    if ($replace = $MAP->{$file}->{REPLACE}) {
        $type = $MAP->{$file}->{ACTIONTYPE};
        $text = $MAP->{$file}->{ACTIONTEXT};
        if ($type eq 'S') {
            $file = $replace;
        }
        elsif ($type eq 'W') {
            &warning("$file: $text");
            $file = $replace;
        }
        else {
            &error("$file: $text");
        }
    }
    return $file;
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

sub PatternProcess {
    my ($mode, $delimiter, $dirname, $pattern, $ext, $level, $noid, %arg) = @_;
    my ($dir, $found, $out, $test, @ls);

    $out = '';
    if ($ext eq '') {
        $test = '-f "$dir/$dirname/$_"';
    }
    else {
        $test = '-d "$dir/$dirname"';
    }
    if ($delimiter eq '<') {
        $found = 0;
        foreach $dir (reverse @opt_S) {
            opendir(DIR, "$dir/$dirname") || next;
            @ls = grep { /^$pattern$/  && eval $test } readdir(DIR);
            closedir DIR;
            foreach (@ls) {
                next if (m|/\.+$| or m|^\.+$|);
                $out .= &ProcessFile($mode, $delimiter, "$dirname/$_$ext", "", $level, $noid, %arg);
                $found = 1;
            }
            last if $found;
        }
    }
    if ($delimiter eq '<' or $delimiter eq '"') {
        $found = 0;
        foreach $dir (reverse @opt_I) {
            opendir(DIR, "$dir/$dirname") || next;
            @ls = grep { /^$pattern$/  && eval $test } readdir(DIR);
            closedir DIR;
            foreach (@ls) {
                next if (m|/\.+$| or m|^\.+$|);
                $out .= &ProcessFile($mode, $delimiter, "$dirname/$_$ext", "", $level, $noid, %arg);
                $found = 1;
            }
            last if $found;
        }
    }
    if ($delimiter eq '<' or $delimiter eq '"' or $delimiter eq "'") {
        $dir = '.';
        if (-d $dirname) {
            opendir(DIR, "$dirname");
            @ls = grep { /^$pattern$/  && eval $test } readdir(DIR);
            closedir DIR;

            #   Sort list of files
            my $criterion = $arg{'IPP_SORT'} || $arg{'IPP_REVERSE'};
            if ($criterion eq 'date') {
                @ls = sort {-M $a <=> -M $b} @ls;
            }
            elsif ($criterion eq 'numeric') {
                @ls = sort {$a <=> $b} @ls;
            }
            elsif ($criterion) {
                @ls = sort @ls;
            }
            @ls = reverse @ls if ($arg{'IPP_REVERSE'});

            #   and truncate it
            if ($arg{'IPP_MAX'} =~ m/^\d+$/ and $arg{'IPP_MAX'} < $#ls + 1) {
                splice (@ls, $arg{'IPP_MAX'} - $#ls - 1);
            }
            push (@ls, "");

            $arg{'IPP_NEXT'} = '';
            $arg{'IPP_THIS'} = '';
            foreach (@ls) {
                next if (m|/\.+$| or m|^\.+$|);

                #   set IPP_PREV, IPP_THIS, IPP_NEXT
                $arg{'IPP_PREV'} = $arg{'IPP_THIS'};
                $arg{'IPP_THIS'} = $arg{'IPP_NEXT'};
                $arg{'IPP_NEXT'} = ($_ eq '' ? '' : $dirname . "/$_$ext");
                next if $arg{'IPP_THIS'} eq '';

                $out .= &ProcessFile($mode, $delimiter, $arg{'IPP_THIS'}, "", $level, $noid, %arg);
            }
            delete $arg{'IPP_NEXT'};
            delete $arg{'IPP_THIS'};
            delete $arg{'IPP_PREV'};
        }
    }
    return $out;
}

sub ProcessFile {
    my ($mode, $delimiter, $file, $realname, $level, $noid, %arg) = @_;
    my ($in, $found, $line, $incfile, $type, %argO, $out, $store);
    my ($dirname, $pattern, $ext);

    #
    #   first check whether this is a filename pattern in which case
    #   we must expand it
    #
    if (($dirname, $pattern, $ext) = ($file =~ m/^(.*?)(?=[?*\]])([?*]|\[[^\]]*\])(.*)$/)) {
        if ($dirname =~ m|^(.*)/(.*?)$|) {
            $dirname = $1;
            $pattern = $2.$pattern;
        }
        else {
            $pattern = $dirname.$pattern;
            $dirname = '.';
        }
        if ($ext =~ m|^(.*?)(/.*)$|) {
            $pattern .= $1;
            $ext     = $2;
        }
        else {
            $pattern .= $ext;
            $ext     = '';
        }

        #
        #   replace filename patterns by regular expressions
        #
        $pattern =~ s/\./\\./g;
        $pattern =~ s/\*/.*/g;
        $pattern =~ s/\?/./g;
        return &PatternProcess($mode, $delimiter, $dirname, $pattern, $ext, $level, $noid, %arg);
    }

    #
    #    this is a regular file
    #
    $found  = 0;

    if ($delimiter eq '<') {
        foreach $dir (reverse @opt_S) {
            if (-f "$dir/$file") {
                $file = "$dir/$file";
                $found = 1;
                last;
            }
        }
    }
    if ($delimiter eq '<' or $delimiter eq '"') {
        foreach $dir (reverse @opt_I) {
            if (-f "$dir/$file") {
                $file = "$dir/$file";
                $found = 1;
                last;
            }
        }
    }
    if ($delimiter eq '<' or $delimiter eq '"' or $delimiter eq "'") {
        if (-f $file) {
            $found = 1;
        }
    }
    &error("file not found: $file") if not $found;

    #
    #   stop if file was still included some time before
    #
    if (not $noid) {
        $id = &CanonPath($file);
        if ($mode eq 'use') {
            return '' if (exists $INCLUDES{$id});
        }
        if ($delimiter eq '<') {
            $INCLUDES{$id} = 1;
        }
        else {
            $INCLUDES{$id} = 2;
        }
    }
    #
    #   stop if just want to check dependency
    #
    return '' if $mode eq 'depends';

    #
    #   process the file
    #
    $realname = $file if $realname eq '';
    $in = new IO::File;
    &verbose($level, "|");
    &verbose($level, "+-- $file");
    $in->open("<$file") || error("cannot load $file: $!");
    $line   = 0;
    $out    = '';
    $out    = "<__file__ $realname /><__line__ 0 />" .
              "<protect pass=2><:# line $line \"$realname\":></protect>\n"
                        if not $opt_N and not $arg{'IPP_NOSYNCLINES'};
    $store  = '';
    while ($l = <$in>) {
        $line++;

        #   EOL-comments
        next if $l =~ m/^\s*#(?!use|include|depends)/;

        #   Line-Continuation Support
        $l =~ s|^\s+|| if $store ne '';
        next if $l =~ m|^\\\s*\n$|;
        if ($l =~ m|^(.*[^\\])\\\s*\n$|) {
            $store .= $1;
            next;
        }
        if ($l =~ m|^(.*\\)\\(\s*\n)$|) {
            $l = $1.$2;
        }
        $l = $store.$l;
        $store = '';

        #
        #   Variable Interpolation
        #

        #       Substitutions are performed from left to right and from
        #       inner to outer, all operators have same precedence.
        {
            if ($l =~ m/((?!\\).|^)\$\(([a-zA-Z0-9_]+)((=|:[-=?+*])([^()]*))?\)/) {
                my ($name, $op, $str) = ($2, $4, $5);
                if (not defined ($op)) {
                    #   Normal Value
                    $l =~ s/((?!\\).|^)\$\($name\)/exists $arg{$name} ? $1.$arg{$name} : $1/e;
                    redo;
                }
                #   Escape special characters
                $op =~ s/([?+*])/\\$1/;
                my $subst = '((?!\\\\).|^)\\$\\(' . $name . $op . '(?:[^()]*)\\)';

                if ($op eq '=') {
                    #   Assign
                    $l =~ s/$subst/$1/;
                    if ($str eq '') {
                        delete $arg{$name} if exists $arg{$name};
                    }
                    else {
                        $arg{$name} = $str;
                    }
                }
                elsif ($op eq ':\?') {
                    #   Indicate Error if Unset
                    $l =~ s/$subst/exists $arg{$name} ? $1.$arg{$name} : $1.&error($str)/e;
                }
                elsif ($op eq ':-') {
                    #   Use Default Values
                    $l =~ s/$subst/exists $arg{$name} ? $1.$arg{$name} : $1.$str/e;
                }
                elsif ($op eq ':=') {
                    #   Use Default Values And Assign
                    $l =~ s/$subst/exists $arg{$name} ? $1.$arg{$name} : $1.$str/e;
                    if ($str eq '') {
                        delete $arg{$name} if exists $arg{$name};
                    }
                    else {
                        $arg{$name} = $str;
                    }
                }
                elsif ($op eq ':\+') {
                    #   Use Alternative Value
                    $l =~ s/$subst/exists $arg{$name} ? $1.$str : $1/e;
                }
                elsif ($op eq ':\*') {
                    #   Use Negative Alternative Value
                    $l =~ s/$subst/exists $arg{$name} ? $1 : $1.$str/e;
                }
                else {
                    #   There is an error in these statements
                    die "Internal error when expanding variables";
                }
                redo;
            }
        }

        #   EOL-comments again
        next if $l =~ m/^\s*#(?!use|include|depends)/;

        #   Implicit Variables
        $l =~ s|__LINE__|$line|g;
        if ($level == 0 and $arg{'IPP_SRC_REALNAME'} ne '') {
            $arg{'IPP_SRC_REALNAME'} = './' . $arg{'IPP_SRC_REALNAME'}
                if $arg{'IPP_SRC_REALNAME'} !~ m|/|;
            $l =~ s|__FILE__|$arg{'IPP_SRC_REALNAME'}|g;
        }
        else {
            $l =~ s|__FILE__|$file|g;
        }
        #   remove one preceding backslash
        $l =~ s/\\(\$\([a-zA-Z0-9_]+(:[-=?+*][^()]*)?\))/$1/g;

        #
        #   ``#include'', ``#use'' and ``#depends'' directives
        #

        if (($cmd, $incfile, $args) = ($l =~ m/^#(use|include|depends)\s+(\S+)(.*)$/)) {
            #   set arguments
            %argO = %arg;
            &setargs(\%arg, $args);

            #   do possible argument mapping
            $incfile = &mapfile($incfile);

            #   determine raw filename and type
            if ($incfile =~ m|^(\S+?)::(\S+)$|) {
                $type = '<';
                $incfile = "$2.$1";
                $incfile =~ s|::|/|g;
            }
            elsif ($incfile =~ m|^(['"<])([^'">]+)['">]$|) {
                $type = $1;
                $incfile = $2;
            }
            else {
                &error("Unknown file-argument syntax: ``$incfile''");
            }

            #   now recurse down
            $out .= &ProcessFile($cmd, $type, $incfile, "", $level+1, 0, %arg);
            $out .= "<__file__ $realname /><__line__ $line />" .
                    "<protect pass=2><:# line $line \"$realname\":></protect>\n"
                        if not $opt_N and not $arg{'IPP_NOSYNCLINES'};

            #   reset arguments
            %arg = %argO;
        }

        #
        #   ``__END__'' feature
        #
        elsif ($l =~ m|^\s*__END__\s*\n?$|) {
            last;
        }

        #
        #   plain text
        #
        else {
            $out .= $l;
        }
    }
    $out .= $store;
    $in->close() || error("cannot close $file: $!");

    return $out;
}

#
#   create initial argument vector
#
%arg = ();
foreach $str (@opt_D) {
    $str =~ s|^(['"])(.*)\1$|$2|;
    if ($str =~ m|^([a-zA-Z][a-zA-Z0-9_]*)="(.*)"$|) {
        $arg{$1} = $2;
    }
    elsif ($str =~ m|^([a-zA-Z][a-zA-Z0-9_]*)=(['"]['"])?$|) {
        $arg{$1} = '';
    }
    elsif ($str =~ m|^([a-zA-Z][a-zA-Z0-9_]*)=(.+)$|) {
        $arg{$1} = $2;
    }
    elsif ($str =~ m|^([a-zA-Z][a-zA-Z0-9_]*)$|) {
        $arg{$1} = 1;
    }
    else {
        &error("Bad argument to option `D': $str");
    }
}

#
#   process the pre-loaded include files
#
$tmpdir = $ENV{'TMPDIR'} || '/tmp';
$tmpfile = $tmpdir . "/ipp.$$.tmp";
unlink($tmpfile);
$tmp = new IO::File;
$tmp->open(">$tmpfile") || error("cannot write into $tmpfile: $!");
foreach $file (@opt_s) {
    if ($file =~ m|^(\S+?)::(\S+)(.*)\n$|) {
        $file = "$2.$1";
        $file =~ s|::|/|g;
    }
    $tmp->print("#include <$file>\n")
        || error("cannot write into $tmpfile: $!");
}
foreach $file (@opt_i) {
    if ($file =~ m|^(\S+?)::(\S+)(.*)$|) {
        $tmp->print("#use $file\n")
            || error("cannot write into $tmpfile: $!");
    }
    else {
        $tmp->print("#include \"$file\"\n")
            || error("cannot write into $tmpfile: $!");
    }
}
$tmp->close() || error("cannot close $tmpfile: $!");
$outbuf .= &ProcessFile('include', "'", $tmpfile, "", 0, 1, %arg);
unlink($tmpfile);

#
#   process real files
#
foreach $file (@ARGV) {
    #   read input file
    if ($file eq '-') {
        $in = new IO::Handle;
        $in->fdopen(fileno(STDIN), 'r') || error("cannot load STDIN: $!");
        local ($/) = undef;
        $inbuf = <$in>;
        $in->close() || error("cannot close STDIN: $!");
    }
    else {
        $in = new IO::File;
        $in->open($file) || error("cannot load $file: $!");
        local ($/) = undef;
        $inbuf = <$in>;
        $in->close() || error("cannot close $file: $!");
    }

    #   create temporary working file
    $tmp = new IO::File;
    $tmp->open(">$tmpfile") || error("cannot write into $tmpfile: $!");
    $tmp->print($inbuf) || error("cannot write into $tmpfile: $!");
    $tmp->close() || error("cannot close $tmpfile: $!");

    #   apply prolog filters
    foreach $p (@opt_P) {
        $rc = system("$p <$tmpfile >$tmpfile.f && mv $tmpfile.f $tmpfile 2>/dev/null");
        &error("Prolog Filter `$p' failed") if ($rc != 0);
    }

    #   process file via IPP filter
    $outbuf .= &ProcessFile('include', "'", $tmpfile,
        ($opt_n eq '' ? $file : $opt_n), 0, 1, %arg);

    #   cleanup
    unlink($tmpfile);
}

if ($opt_M ne '-' && $opt_o ne '-') {
    #   Write dependencies
    if ($opt_M =~ m|D|) {
        if ($opt_o =~ m|(.*?)\.|) {
            $depfile = $1 . '.d';
        }
        else {
            $depfile = $opt_o . '.d';
        }
        $depout = new IO::File;
        $depout->open(">$depfile") || error("cannot write into $depfile: $!");
    }
    else {
        $depfile = 'STDOUT';
        $depout = new IO::Handle;
        $depout->fdopen(fileno(STDOUT), "w") || error("cannot write into $depfile: $!");
    }

    #    Write the target
    $depout->print($opt_o . ": \\\n")
        || error("cannot write into $depfile: $!");

    @deps = @ARGV;
    foreach (keys(%INCLUDES)) {
        push(@deps,$_) if $INCLUDES{$_} != 1 or $opt_M !~ m|M|;
    }
    #    and its dependencies
    $depout->print("\t" . join(" \\\n\t",@deps) . "\n")
        || error("cannot write into $depfile: $!");
    $depout->close() || error("cannot close $depfile: $!");
}
else {
    #
    #  create output file
    #
    if ($opt_o eq '-') {
        $out = new IO::Handle;
        $out->fdopen(fileno(STDOUT), "w") || error("cannot write into STDOUT: $!");
    }
    else {
        $out = new IO::File;
        $out->open(">$opt_o") || error("cannot write into $opt_o: $!");
    }
    $out->print($outbuf) || error("cannot write into $opt_o: $!");
    $out->close() || error("cannot close $opt_o: $!");
}

#   die gracefully
exit(0);

##EOF##

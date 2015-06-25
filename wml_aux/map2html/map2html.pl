#!/usr/bin/perl
eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if $running_under_some_shell;
##
##  map2html -- convert server-side to client-side imagemap 
##  Copyright (c) 1996-1998,1999 Ralf S. Engelschall, All Rights Reserved. 
##

require 5.003;

use lib "/usr/local/lib/wml/perl/lib";
use lib "/usr/local/lib/wml/perl/lib/x86_64-linux";

use Getopt::Long;

#
#   process command line
#
sub usage {
    print STDERR "Usage: map2html [options] mapfile\n";
    print STDERR "   where options are\n";
    print STDERR "   -t type  map format: 'ncsa' or 'cern' (default)\n";
    print STDERR "   -d shape default area shape: 'def' (default) or 'rect'\n";
    print STDERR "   -n name  produce a map called <name> (default is filename)\n";
    print STDERR "   -o file  output file\n";
    print STDERR "   -h       help (this text)\n";
    print STDERR "   -v       version information\n";
    exit(1);
}
sub version {
    print STDERR "This is MAP2HTML, Version 1.1\n";
    exit(0);
}
$opt_v = 0;
$opt_h = 0;
$opt_o = "-";
$opt_t = "ncsa";
$opt_d = "def";
$opt_n = "";
$Getopt::Long::bundling = 1;
$Getopt::Long::getopt_compat = 0;
$rc = Getopt::Long::GetOptions("v|verbose", 
                               "t|type=s", 
                               "d|defshape=s", 
                               "n|name=s",
                               "o|outputfile=s",
                               "h|help");
if (not $rc or $opt_h or ($#ARGV == -1)) {
    &usage;
}
if ($opt_v) {
    &version;
}

$server    = $opt_t;
$defshape  = $opt_d;
$name      = $opt_n;
$default   = "";
$lastc     = "";
$alt       = "";
  
if ($opt_o eq "-") {
    *OUT = *STDOUT;
}
else {
    open(OUT, ">$opt_o") || die "Cannot open output file ``$opt_o''";
}

for $file (@ARGV) {
    &domap(*OUT, $file, $name);
}

if ($opt_o ne "-") {
    close(OUT);
}

sub domap {
    local(*OUT, $file, $name) = @_;
    local(*IN);
    
    open(IN, "<$file") || warn "Can't open: $file\n", return;
    if ($name eq "") {
        $name = $file;
    }
    print OUT "<MAP NAME=\"$name\">\n"; # header
    while(<IN>) {
        &doline(*OUT, $_);
    }
    print OUT "$default"; # the default URL must be last
    print OUT "</MAP>\n";
    close(IN);
    return;
}

sub doline {
    local(*OUT, $line) = @_;
    local(@coords);
    local($coords, $href, $type);
  
    $type='dodgy'; # make sure that it doesn't print anything unless it's set
    $line =~ s|\n$||;
    $line =~ s|$||;
    if ($server =~ m|cern|i) {
        if ($line =~ m|^\s*default\s+(\S+)\s*$|i) {
            if ($defshape eq "rect") {
                $default = "<AREA SHAPE=RECT COORDS=\"0,0,9999,9999\" HREF=\"$1\" ALT=\"DEFAULT\">\n";
            }
            else {
                $default = "<AREA SHAPE=DEFAULT HREF=\"$1\" ALT=\"DEFAULT\">\n";
            }
            return;
        }
        elsif ($line =~ m/^\s*(circle|poly|rectangle)\s+([^\000]+)\s+(\S+)\s*$/i) {
            $type = $1;
            $href = $3;
            $coords = $2;
            $type =~ s/rectangle/rect/i; # CERN uses rectangle but we want rect
        }
        elsif ($line =~ m/^\s*#\s+(.+)\s*$/i) {
            $lastc = $1;
            print OUT "<!-- $1 -->\n";
        }
        else {
            chop($line);
            print OUT "<!-- Unrecognized line: $line -->\n";
            $lastc = "";
        }
    } elsif ($server =~ m|ncsa|i) {
        if ($line =~ m|^\s*default\s+(\S+)\s*$|i ) {
            if ($defshape eq "rect") {
                $default = "<AREA SHAPE=RECT COORDS=\"0,0,9999,9999\" HREF=\"$1\" ALT=\"DEFAULT\">\n";
            }
            else {
                $default = "<AREA SHAPE=DEFAULT HREF=\"$1\" ALT=\"DEFAULT\">\n";
            }
            return;
        }
        elsif ($line =~ m/^\s*(circle|poly|rect|point)\s+(\S+)\s+([^\000]+)$/i) {
            $type = $1;
            $href = $2;
            $coords = $3;
        }
        elsif ($line =~ m/^\s*#\s+(.+)\s*$/i) {
            $lastc = $1;
            print OUT "<!-- $1 -->\n";
        }
        else {
            chop($line);
            print OUT "<!-- Unrecognized line: $line -->\n";
            $lastc = "";
        }
    }
    else {
        print "Dodgy server set!\n";
        exit;
    }

    if ($type =~ m/(circle|poly|rect)/i) {
        # convert the coords to a comma separated list of numbers
        @coords = ();
        $type =~ tr|a-z|A-Z|;
        while($coords =~ s|^\D*(\d+)||) {
            push(@coords, $1);
        }
        $coords = join(",", @coords);
        if ($lastc ne "") {
            $alt = $lastc;
        }
        print OUT "<AREA SHAPE=$type COORDS=\"$coords\" HREF=\"$href\" ALT=\"$alt\">\n";
        $lastc = "";
        $alt = "";
    }
}
    
##EOF##

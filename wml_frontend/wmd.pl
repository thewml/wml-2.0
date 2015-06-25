#!/usr/bin/perl
eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if $running_under_some_shell;
##
##  WMd -- Website META Language Documentation Browser
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

use Getopt::Long 2.13;


##
##  PROCESS ARGUMENT LINE
##

sub usage {
    my ($progname) = @_;
    my ($o);

    print STDERR "Usage: $progname [options] [path ...]\n";
    print STDERR "\n";
    print STDERR "Giving Feedback:\n";
    print STDERR "  -V, --version[=NUM]    display version and build information\n";
    print STDERR "  -h, --help             display this usage summary\n";
    print STDERR "\n";
    exit(1);
}

sub version {
    system("wml -V$opt_V");
    exit(0);
}

#   options
$opt_V = -1;
$opt_h = 0;

sub ProcessOptions {
    $Getopt::Long::bundling = 1;
    $Getopt::Long::getopt_compat = 0;
    $SIG{'__WARN__'} = sub { 
        print STDERR "WMd:Error: $_[0]";
    };
    if (not Getopt::Long::GetOptions(
            "V|version:i",
            "h|help"
    )) {
        print STDERR "Try `$0 --help' for more information.\n";
        exit(0);
    }
    &usage($0) if ($opt_h);
    $SIG{'__WARN__'} = undef;
}
&ProcessOptions();

#   fix the version level
if ($opt_V == 0) {
    $opt_V = 1; # Getopt::Long sets 0 if -V only
}
if ($opt_V == -1) {
    $opt_V = 0; # we operate with 0 for not set
}
&version if ($opt_V);


##
##  This variable eases port on some OS.  For instance if htmlclean is
##  part of your system, you do not want to include it within WML.
##  When defining
##     %map = ('wml_aux_htmlclean' => 'htmlclean');
##  the `wml_aux_htmlclean' entry in WMd will display the htmlclean
##  manpage.
##  By default there is no mapping
%map = ();
if (-r "/usr/local/lib/wml/data/wmd.map") {
    if (open(MAP, "< /usr/local/lib/wml/data/wmd.map")) {
        while (<MAP>) {
            s/^\s*(.*?)\s*=\s*(.*?)\s*$/$map{$1} = $2/e;
        }
        close(MAP);
    }
}

##
##  Find browser
##

$browser      = '/usr/local/lib/wml/exec/wml_aux_iselect';
$browser_file = '/usr/local/lib/wml/data/wmd.txt';

$reader_man  = 'MANPATH="/usr/local/man:$MANPATH"; export MANPATH; man';

$reader_url  = '';
@reader_progs = qw(w3m lynx);
WWW_PROG: foreach $prog (@reader_progs) {
    foreach $dir (split(/:/, $ENV{'PATH'})) {
        if (-x "$dir/$prog") {
            $reader_url = "$dir/$prog";
            last WWW_PROG;
        }
    }
}

$p = 10;
while (1) {
    $rc = `$browser -n "Website META Language" -t "Documentation Browser" -p$p -P <$browser_file`;
    last if ($rc eq '');
    $rc =~ m|^(\d+):(.*)|;
    ($p, $line) = ($1, $2);
    if ((($page, $sec) = $line =~ m|^\s*(\S+)\((\d)\)\s+|)) {
        if (exists $map{$page}) {
            $page = $map{$page};
        }
        system("$reader_man $page");
        system("$reader_man wmd_missing") if $?;
    }
    elsif (($url) = ($line =~ m/^\s*((?:http|ftp):\/\/\S+)/)) {
        if ($reader_url) {
            system("$reader_url $url");
        }
        else {
            print STDERR "wmd:Error:  cannot access URL $url\n";
            print STDERR "wmd:Reason: require one of the following programs in \$PATH: ".
                         join(' ', @reader_progs)."\n";
            sleep(4);
        }
    }
    elsif (($keyword) = ($line =~ m/^\s*search=(.+)$/)) {
        @L = glob("/usr/local/man/*/wml* /usr/local/man/*/wm[bdku]\.[1-9]*");
        %F = ();
        foreach $f (@L) {
            $n = $f; 
            $n =~ s%^.+?/(wm[bdklu](?:[:_].+?|))\.([1-9])(?:\.Z|\.z|\.gz|)$%$1($2)%;
            $metacat = 'cat';
            $metacat = 'gzip -d -c' if ($f =~ m/\.(?:Z|z|gz)$/);
            @R = `$metacat $f | grep -i '$keyword'`;
            for ($i = 0; $i <= $#R; $i++) {
                $F{$n}++;
            }
        }
        $L = '';
        $L .= "'' 'Keyword Search Result: $keyword' '' ";
        foreach $f (sort {$F{$b} <=> $F{$a}} (keys(%F))) {
            $L .= sprintf("'%-30s (%3d) <s>' ", $f, $F{$f});
        }
        $p2 = 4;
        while (1) {
            $rc = `$browser -n "Website META Language" -t "Documentation Browser (Keyword Search)" -p$p2 -P $L`;
            last if ($rc eq '');
            $rc =~ m|^(\d+):(.*)|;
            ($p2, $line) = ($1, $2);
            if ((($page, $sec) = $line =~ m|^\s*(\S+)\((\d)\)\s+|)) {
                system("$reader_man $page");
            }
        }
    }
}

#   exit gracefully
exit(0);

##EOF##

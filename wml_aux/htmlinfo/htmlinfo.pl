#!/usr/bin/perl
eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if $running_under_some_shell;
##
##  htmlinfo -- HTML markup code information report
##  Copyright (c) 1997 Ralf S. Engelschall, All Rights Reserved. 
##

require 5.003;

use lib "/usr/local/lib/wml/perl/lib";
use lib "/usr/local/lib/wml/perl/lib/x86_64-linux";

use Term::Cap;
use IO::Handle 1.15;
use IO::File 1.06;
use Image::Size;

eval "\$term = Tgetent Term::Cap { TERM => undef, OSPEED => 9600 }";
if ($@) {
    $bold = '';
    $norm = '';
}
else {
    $bold = $term->Tputs('md', 1, undef);
    $norm = $term->Tputs('me', 1, undef);
}


#
#   open input file and read into buffer
#
if (($#ARGV == 0 and $ARGV[0] eq '-') or $#ARGV == -1) {
    $in = new IO::Handle;
    $in->fdopen(fileno(STDIN), "r");
    local ($/) = undef;
    $INPUT = <$in>;
    $in->close;
    $src = "STDIN";
}
elsif ($#ARGV == 0) {
    $in = new IO::File;
    $in->open($ARGV[0]);
    local ($/) = undef;
    $INPUT = <$in>;
    $in->close;
    $src = $ARGV[0];
}
else {
    print STDERR "Usage: htmlinfo file.html\n";
    exit(1);
}


#
#   process HTML tags in general
#
$atags = 0;
$ttags = 0;
$ctags = 0;
$htags = 0;
$ntags = 0;
$jtags = 0;
$mtags = 0;
$plain = $INPUT;
$plain =~ s|<[a-zA-Z]+.+?>|$atags++, ''|sge;
$comment = $INPUT;
$comment =~ s|<!--.+?-->|$ctags++, ''|sge;
$table = $INPUT;
$table =~ s|<table.+?>|$ttags++, ''|sge;
$href = $INPUT;
$href =~ s|<a.+?href.+?>|$htags++, ''|sge;
$href = $INPUT;
$href =~ s|<a.+?name.+?>|$ntags++, ''|sge;
$js = $INPUT;
$js =~ s|<script.+?JavaScript.+?>|$jtags++, ''|isge;
$meta = $INPUT;
$meta =~ s|<meta.+?>|$mtags++, ''|isge;
$abytes = length($INPUT);
$pbytes = length($plain);
$cbytes = $abytes - length($comment);
$hbytes = $abytes - $pbytes;


#
#   process IMG tags
#
$ubytes  = 0;
$bytes   = 0;
$xpixel  = 0;
$ypixel  = 0;
$vxpixel = 0;
$vypixel = 0;
$pixel   = 0;
$vpixel  = 0;
$images  = 0;
$uimages = 0;
$itags   = 0;
$bitags   = 0;
$vitags   = 0;
%IMAGE   = ();

sub ProcessImgTag {
    my ($tag) = @_;
    my ($image, $width, $height, $pwidth, $pheight);

    $itags++;

    if (   $tag =~ m|SRC\s*=\s*"([^"]*)"|is
        or $tag =~ m|SRC\s*=\s*(\S+)|is    ) {
        $image = $1;

        if (-f $image) {
            my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
                $atime,$mtime,$ctime,$blksize,$blocks) = stat(_);

            $vitags++;

            if ($IMAGE{$image} eq '') {
                $IMAGE{$image} = 1;
                $ubytes += $size;
                $uimages++;
            }
            $bytes += $size;
            $images++;

            #   determine specified width/height
            $width  = -1;
            $height = -1;
            if (   $tag =~ m|WIDTH\s*=\s*([0-9]+%?)|is
                or $tag =~ m|WIDTH\s*=\s*"([0-9]+%?)"|is) {
                $width = $1;
            }
            if (   $attr =~ m|HEIGHT\s*=\s*([0-9]+%?)|is
                or $attr =~ m|HEIGHT\s*=\s*"([0-9]+%?)"|is) {
                $height = $1;
            }

            #   determine physical width/height
            ($pwidth, $pheight) = Image::Size::imgsize($image);

            #   adjust physical counter
            $xpixel += $pwidth;
            $ypixel += $pheight;
            $pixel += ($pwidth * $pheight);

            #   adjust visual counter
            if ($width != -1) {
                if ($width =~ m|^(\d+)%$|) {
                    $vxpixel += int(($pwidth / 100) * $1);
                    $x = int(($pwidth / 100) * $1);
                }
                else {
                    $vxpixel += $width;
                    $x = $width;
                }
            }
            else {
                $vxpixel += $pwidth;
                $x = $pwidth;
            }
            if ($height != -1) {
                if ($height =~ m|^(\d+)%$|) {
                    $vypixel += int(($pheight / 100) * $1);
                    $y = int(($pheight / 100) * $1);
                }
                else {
                    $vypixel += $height;
                    $y = $height;
                }
            }
            else {
                $vypixel += $pheight;
                $y = $pheight;
            }
            $vpixel += ($x * $y);
        }
        else {
            $bitags++;
        }
    }
}

$buf = $INPUT;
$buf =~ s|(<IMG\s+[^>]+>)|&ProcessImgTag($1), ''|isge;
$spixel = int(sqrt($pixel));
$svpixel = int(sqrt($vpixel));

#
#  give information to user
#

print  STDERR "   \n"; # some spaces to erase the WML prop !!
print  STDERR "  ${bold}WEBPAGE SUMMARY$norm\n";
print  STDERR "  Source: $src\n";
print  STDERR "\n";

print  STDERR "  ${bold}NETWORK TRANSFER AMOUNT$norm              Bytes  Reqs\n";
print  STDERR "                                   --------- -----\n";
printf STDERR "    Plain ASCII Text             + %9d  }\n", $pbytes;
printf STDERR "    HTML Markup Code             + %9d  }  1\n", $hbytes;
print  STDERR "    ------------------------------ --------- -----\n";
printf STDERR "    Markup File                  = %9d %5d\n", $abytes, 1;
printf STDERR "    Embedded Image Objects       + %9d %5d\n", $ubytes, $itags;
print  STDERR "    ------------------------------ --------- -----\n";
printf STDERR "    Page Total                   = $bold%9d %5d$norm\n", $abytes + $ubytes, 1 + $itags;

print  STDERR "\n";
print  STDERR "  ${bold}IMAGE VISUAL DISPLAY AMOUNT$norm     Pixels Dimension\n";
print  STDERR "                                -------- ---------\n";
printf STDERR "    Physical Image Size:        %8d %9s\n", $pixel, "${spixel}x${spixel}";
printf STDERR "    Visual   Image Size:        $bold%8d %9s$norm\n", $vpixel, "${svpixel}x${svpixel}";
print  STDERR "\n";

print  STDERR "  ${bold}MARKUP DETAILS$norm           Tags Additional Info\n";
print  STDERR "                           ---- -----------------------\n";
printf STDERR "    Images     (<img>):    %4d unique: %d, broken: %d\n", $itags, $uimages, $bitags;
printf STDERR "    Comments   (<!-->):    %4d bytes: %d\n", $ctags, $cbytes;
printf STDERR "    Anchors    (<a>):      %4d href: %d, name: %d\n", $htags + $ntags, $htags, $ntags;
printf STDERR "    Tables     (<table>):  %4d\n", $ttags;
printf STDERR "    JavaScript (<script>): %4d\n", $jtags;
printf STDERR "    Meta Tags  (<meta>):   %4d\n", $mtags;
print  STDERR "\n";

exit(0);

##EOF##
__END__

=head1 NAME

htmlinfo - HTML markup code information report

=head1 SYNOPSIS

B<htmlinfo>
[I<inputfile>]

=head1 DESCRIPTION

The F<htmlinfo> program reads I<inputfile> or from C<stdin> and displays
a webpage contents report on B<STDERR>. 

=head1 AUTHOR

 Ralf S. Engelschall
 rse@engelschall.com
 www.engelschall.com

=cut


package WML::GD;

# Copyright 1995 Lincoln D. Stein.  See accompanying README file for
# usage information

require 5.004;
require FileHandle;
require Exporter;
require DynaLoader;
require AutoLoader;
use Carp 'croak','carp';
use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $AUTOLOAD);
$VERSION = "1.23";

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	gdMaxColors
);

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.  If a constant is not found then control is passed
    # to the AUTOLOAD in AutoLoader.

    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
	if ($! =~ /Invalid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
	    my($pack,$file,$line) = caller;
	    die "Your vendor has not defined GD macro $pack\:\:$constname, used at $file line $line.\n";
	}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

bootstrap WML::GD;

# Autoload methods go after __END__, and are processed by the autosplit program.
1;
__END__

=head1 NAME

GD.pm - Interface to Gd Graphics Library

=head1 SYNOPSIS

    use GD;
        
    # create a new image
    $im = new GD::Image(100,100);

    # allocate some colors
    $white = $im->colorAllocate(255,255,255);
    $black = $im->colorAllocate(0,0,0);       
    $red = $im->colorAllocate(255,0,0);      
    $blue = $im->colorAllocate(0,0,255);

    # make the background transparent and interlaced
    $im->transparent($white);
    $im->interlaced('true');

    # Put a black frame around the picture
    $im->rectangle(0,0,99,99,$black);

    # Draw a blue oval
    $im->arc(50,50,95,75,0,360,$blue);

    # And fill it with red
    $im->fill(50,50,$red);

    # make sure we are writing to a binary stream
    binmode STDOUT;

    # Convert the image to PNG and print it on standard output
    print $im->png;

=head1 DESCRIPTION

B<GD.pm> is a port of Thomas Boutell's gd graphics library (see
below).  GD allows you to create color drawings using a large number of
graphics primitives, and emit the drawings as PNG files.

GD defines the following three classes:

=over 5

=item C<GD::Image>

An image class, which holds the image data and accepts graphic
primitive method calls.

=item C<GD::Font>

A font class, which holds static font information and used for text
rendering.

=item C<GD::Polygon>

A simple polygon object, used for storing lists of vertices prior to
rendering a polygon into an image.

=back

A Simple Example:

	#!/usr/local/bin/perl

	use GD;
	
	# create a new image
	$im = new GD::Image(100,100);

	# allocate some colors
	$white = $im->colorAllocate(255,255,255);
	$black = $im->colorAllocate(0,0,0);       
	$red = $im->colorAllocate(255,0,0);      
	$blue = $im->colorAllocate(0,0,255);

	# make the background transparent and interlaced
	$im->transparent($white);
	$im->interlaced('true');

	# Put a black frame around the picture
	$im->rectangle(0,0,99,99,$black);

	# Draw a blue oval
	$im->arc(50,50,95,75,0,360,$blue);

	# And fill it with red
	$im->fill(50,50,$red);

	# make sure we are writing to a binary stream
	binmode STDOUT;

	# Convert the image to PNG and print it on standard output
	print $im->png;

Notes:

=over 5

=item 1.
To create a new, empty image, send a new() message to GD::Image, passing
it the width and height of the image you want to create.  An image
object will be returned.  Other class methods allow you to initialize
an image from a preexisting PNG, GD or XBM file.

=item 2.
Next you will ordinarily add colors to the image's color table.
colors are added using a colorAllocate() method call.  The three
parameters in each call are the red, green and blue (rgb) triples for
the desired color.  The method returns the index of that color in the
image's color table.  You should store these indexes for later use.

=item 3.
Now you can do some drawing!  The various graphics primitives are
described below.  In this example, we do some text drawing, create an
oval, and create and draw a polygon.

=item 4.
Polygons are created with a new() message to GD::Polygon.  You can add
points to the returned polygon one at a time using the addPt() method.
The polygon can then be passed to an image for rendering.

=item 5.
When you're done drawing, you can convert the image into PNG format by
sending it a png() message.  It will return a (potentially large)
scalar value containing the binary data for the image.  Ordinarily you
will print it out at this point or write it to a file.  To ensure
portability to platforms that differentiate between text and binary
files, be sure to call C<binmode()> on the file you are writing
the image to.

=back

=head1 Method Calls


=head2 Creating and Saving Images

=over 5

=item C<new>

C<GD::Image-E<gt>new(width,height)> I<class method>

To create a new, blank image, send a new() message to the GD::Image
class.  For example:

	$myImage = new GD::Image(100,100) || die;

This will create an image that is 100 x 100 pixels wide.  If you don't
specify the dimensions, a default of 64 x 64 will be chosen. If
something goes wrong (e.g. insufficient memory), this call will
return undef.


=item C<newFromPng>

C<GD::Image-E<gt>newFromPng(FILEHANDLE)> I<class method>

This will create an image from a PNG file read in through the provided
filehandle.  The filehandle must previously have been opened on a
valid PNG file or pipe.  If successful, this call will return an
initialized image which you can then manipulate as you please.  If it
fails, which usually happens if the thing at the other end of the
filehandle is not a valid PNG file, the call returns undef.  Notice
that the call doesn't automatically close the filehandle for you.
But it does call C<binmode(FILEHANDLE)> for you, on platforms where
this matters.

To get information about the size and color usage of the information,
you can call the image query methods described below.

	Example usage:

	open (PNG,"barnswallow.png") || die;
	$myImage = newFromPng GD::Image(PNG) || die;
	close PNG;


=item C<newFromXbm>

C<GD::Image-E<gt>newFromXbm(FILEHANDLE)> I<class method>

This works in exactly the same way as C<newFromPng>, but reads the
contents of an X Bitmap (black & white) file:

	open (XBM,"coredump.xbm") || die;
	$myImage = newFromXbm GD::Image(XBM) || die;
	close XBM;

Note that this function also calls C<binmode(FILEHANDLE)> before
reading from the filehandle.


=item C<newFromXpm>

C<GD::Image-E<gt>newFromXpm($filename)> I<class method>

This creates a new GD::Image object starting from a B<filename>.  This
is unlike the other newFrom() functions because it does not take a
filehandle.  This difference comes from an inconsistency in the
underlying gd library.

	$myImage = newFromXpm GD::Image('earth.xpm') || die;

This function is only available if libgd was compiled with XPM
support.  

NOTE: As of version 1.7.3 of the libgd library, I can't get the
underlying createFromXpm() function to return a valid image -- I just
get black.

=item C<newFromGd2>

C<GD::Image-E<gt>newFromGd2(FILEHANDLE)> I<class method>

This works in exactly the same way as C<newFromgd()>, but uses the new
compressed GD2 image format.

=item C<newFromGd>

C<GD::Image-E<gt>newFromGd(FILEHANDLE)> I<class method>

This works in exactly the same way as C<newFromPng>, but reads the
contents of a GD file.  GD is Tom Boutell's disk-based storage format,
intended for the rare case when you need to read and write the image
to disk quickly.  It's not intended for regular use, because, unlike
PNG or JPEG, no image compression is performed and these files can
become B<BIG>.

	open (GDF,"godzilla.gd") || die;
	$myImage = newFromGd GD::Image(GDF) || die;
	close GDF;

Note that this function also calls C<binmode(FILEHANDLE)> before
reading from the supplied filehandle.


=item C<newFromGd2>

C<GD::Image-E<gt>newFromGd2(FILEHANDLE)> I<class method>

This works in exactly the same way as C<newFromgd()>, but uses the new
compressed GD2 image format.

=item C<newFromGd2Part>

C<GD::Image-E<gt>newFromGd2Part(FILEHANDLE,srcX,srcY,width,height)> I<class method>

This class method allows you to read in just a portion of a GD version
2 image file.  In additionto a filehandle, it accepts the top-left
corner and dimensions (width,height) of the region of the image to
read.  For example:

	open (GDF,"godzilla.gd2") || die;
	$myImage = GD::Image->newFromGd2Part(GDF,10,20,100,100) || die;
	close GDF;

This reads a 100x100 square portion of the image starting from
position (10,20).

=item C<png>

C<$image-E<gt>png> I<object method>

This returns the image data in PNG format.  You can then print it,
pipe it to a display program, or write it to a file.  Example:

	$png_data = $myImage->png;
	open (DISPLAY,"| display -") || die;
	binmode DISPLAY;
	print DISPLAY $png_data;
	close DISPLAY;

Note the use of C<binmode()>.  This is crucial for portability to
DOSish platforms.


=item C<gd>

C<$image-E<gt>gd> I<object method>

This returns the image data in GD format.  You can then print it,
pipe it to a display program, or write it to a file.  Example:

	binmode MYOUTFILE;
	print MYOUTFILE $myImage->gd;



=item C<gd2>

C<$image-E<gt>gd2> I<object method>

Same as gd(), except that it returns the data in compressed GD2
format.

=back

=head2 Color Control

=over 5

=item C<colorAllocate>

C<$image-E<gt>colorAllocate(red,green,blue)> I<object method>

This allocates a color with the specified red, green and blue
components and returns its index in the color table, if specified.
The first color allocated in this way becomes the image's background
color.  (255,255,255) is white (all pixels on).  (0,0,0) is black (all
pixels off).  (255,0,0) is fully saturated red.  (127,127,127) is 50%
gray.  You can find plenty of examples in /usr/X11/lib/X11/rgb.txt.

If no colors are allocated, then this function returns -1.

Example:

	$white = $myImage->colorAllocate(0,0,0); #background color
	$black = $myImage->colorAllocate(255,255,255);
	$peachpuff = $myImage->colorAllocate(255,218,185);

=item C<colorDeallocate>

C<$image-E<gt>colorDeallocate(colorIndex)> I<object method> 

This marks the color at the specified index as being ripe for
reallocation.  The next time colorAllocate is used, this entry will be
replaced.  You can call this method several times to deallocate
multiple colors.  There's no function result from this call.

Example:

	$myImage->colorDeallocate($peachpuff);
	$peachy = $myImage->colorAllocate(255,210,185);

=item C<colorClosest>

C<$image-E<gt>colorClosest(red,green,blue)> I<object method>

This returns the index of the color closest in the color table to the
red green and blue components specified.  If no colors have yet been
allocated, then this call returns -1.

Example:

	$apricot = $myImage->colorClosest(255,200,180);

=item C<colorExact>

C<$image-E<gt>colorExact(red,green,blue)> I<object method>

This returns the index of a color that exactly matches the specified
red green and blue components.  If such a color is not in the color
table, this call returns -1.

	$rosey = $myImage->colorExact(255,100,80);
	warn "Everything's coming up roses.\n" if $rosey >= 0;

=item C<colorResolve>

C<$image-E<gt>colorResolve(red,green,blue)> I<object method>

This returns the index of a color that exactly matches the specified
red green and blue components.  If such a color is not in the color
table and there is room, then this method allocates the color in the
color table and returns its index.

	$rosey = $myImage->colorResolve(255,100,80);
	warn "Everything's coming up roses.\n" if $rosey >= 0;

=item C<colorsTotal>

C<$image-E<gt>colorsTotal)> I<object method>

This returns the total number of colors allocated in the object.

	$maxColors = $myImage->colorsTotal;

=item C<getPixel>

C<$image-E<gt>getPixel(x,y)> I<object method>

This returns the color table index underneath the specified
point.  It can be combined with rgb()
to obtain the rgb color underneath the pixel.

Example:

        $index = $myImage->getPixel(20,100);
        ($r,$g,$b) = $myImage->rgb($index);

=item C<rgb>

C<$image-E<gt>rgb(colorIndex)> I<object method>

This returns a list containing the red, green and blue components of
the specified color index.

Example:

	@RGB = $myImage->rgb($peachy);

=item C<transparent>

C<$image-E<gt>transparent(colorIndex)> I<object method>

This marks the color at the specified index as being transparent.
Portions of the image drawn in this color will be invisible.  This is
useful for creating paintbrushes of odd shapes, as well as for
making PNG backgrounds transparent for displaying on the Web.  Only
one color can be transparent at any time. To disable transparency, 
specify -1 for the index.  

If you call this method without any parameters, it will return the
current index of the transparent color, or -1 if none.

Example:

	open(PNG,"test.png");
	$im = newFromPng GD::Image(PNG);
	$white = $im->colorClosest(255,255,255); # find white
	$im->transparent($white);
	binmode STDOUT;
	print $im->png;

=back

=head2 Special Colors

GD implements a number of special colors that can be used to achieve
special effects.  They are constants defined in the GD::
namespace, but automatically exported into your namespace when the GD
module is loaded.

=over 5

=item C<setBrush>

=item C<gdBrushed>

C<$image-E<gt>setBrush( )> and C<GD::gdBrushed>

You can draw lines and shapes using a brush pattern.  Brushes are 
just images that you can create and manipulate in the usual way. When
you draw with them, their contents are used for the color and shape of
the lines.

To make a brushed line, you must create or load the brush first, then
assign it to the image using C<setBrush>.  You can then draw in that
with that brush using the C<gdBrushed> special color.  It's often 
useful to set the background of the brush to transparent so that 
the non-colored parts don't overwrite other parts of your image.

Example:

	# Create a brush at an angle
	$diagonal_brush = new GD::Image(5,5);
	$white = $diagonal_brush->allocateColor(255,255,255);
	$black = $diagonal_brush->allocateColor(0,0,0);
	$diagonal_brush->transparent($white);
	$diagonal_brush->line(0,4,4,0,$black); # NE diagonal

	# Set the brush
	$myImage->setBrush($diagonal_brush);
	
	# Draw a circle using the brush
	$myImage->arc(50,50,25,25,0,360,gdBrushed);

=item C<setStyle>

=item C<gdStyled>

C<$image-E<gt>setStyle(@colors)> and C<GD::gdStyled>

Styled lines consist of an arbitrary series of repeated colors and are
useful for generating dotted and dashed lines.  To create a styled
line, use C<setStyle> to specify a repeating series of colors.  It
accepts an array consisting of one or more color indexes.  Then
draw using the C<gdStyled> special color.  Another special color,
C<gdTransparent> can be used to introduce holes in the line, as the
example shows.

Example:

	# Set a style consisting of 4 pixels of yellow,
	# 4 pixels of blue, and a 2 pixel gap
	$myImage->setStyle($yellow,$yellow,$yellow,$yellow,
			   $blue,$blue,$blue,$blue,
			   gdTransparent,gdTransparent);
	$myImage->arc(50,50,25,25,0,360,gdStyled);

To combine the C<gdStyled> and C<gdBrushed> behaviors, you can specify
C<gdStyledBrushed>.  In this case, a pixel from the current brush
pattern is rendered wherever the color specified in setStyle() is
neither gdTransparent nor 0.

=item C<gdTiled>

Draw filled shapes and flood fills using a pattern.  The pattern is
just another image.  The image will be tiled multiple times in order
to fill the required space, creating wallpaper effects.  You must call
C<setTile> in order to define the particular tile pattern you'll use
for drawing when you specify the gdTiled color.
details.

=item C<gdStyled>

The gdStyled color is used for creating dashed and dotted lines.  A
styled line can contain any series of colors and is created using the
C<setStyled> command.

=back

=head2 Drawing Commands

=over 5

=item C<setPixel>

C<$image-E<gt>setPixel(x,y,color)> I<object method> 

This sets the pixel at (x,y) to the specified color index.  No value
is returned from this method.  The coordinate system starts at the
upper left at (0,0) and gets larger as you go down and to the right.
You can use a real color, or one of the special colors gdBrushed, 
gdStyled and gdStyledBrushed can be specified.

Example:

	# This assumes $peach already allocated
	$myImage->setPixel(50,50,$peach);

=item C<line>

C<$image-E<gt>line(x1,y1,x2,y2,color)> I<object method>

This draws a line from (x1,y1) to (x2,y2) of the specified color.  You
can use a real color, or one of the special colors gdBrushed, 
gdStyled and gdStyledBrushed.

Example:

	# Draw a diagonal line using the currently defind
	# paintbrush pattern.
	$myImage->line(0,0,150,150,gdBrushed);

=item C<dashedLine>

C<$image-E<gt>dashedLine(x1,y1,x2,y2,color)> I<object method>

This draws a dashed line from (x1,y1) to (x2,y2) in the specified
color.  A more powerful way to generate arbitrary dashed and dotted
lines is to use the setStyle() method described below and to draw with
the special color gdStyled.

Example:

	$myImage->dashedLine(0,0,150,150,$blue);

=item C<rectangle>

C<GD::Image::rectangle(x1,y1,x2,y2,color)> I<object method>

This draws a rectangle with the specified color.  (x1,y1) and (x2,y2)
are the upper left and lower right corners respectively.  Both real 
color indexes and the special colors gdBrushed, gdStyled and 
gdStyledBrushed are accepted.

Example:

	$myImage->rectangle(10,10,100,100,$rose);

=item C<filledRectangle>

C<$image-E<gt>filledRectangle(x1,y1,x2,y2,color)> I<object method>

This draws a rectangle filed with the specified color.  You can use a
real color, or the special fill color gdTiled to fill the polygon
with a pattern.

Example:

	# read in a fill pattern and set it
	open(PNG,"happyface.png") || die;
	$tile = newFromPng GD::Image(PNG);
	$myImage->setTile($tile); 

	# draw the rectangle, filling it with the pattern
	$myImage->filledRectangle(10,10,150,200,gdTiled);

=item C<polygon>

C<$image-E<gt>polygon(polygon,color)> I<object method> 

This draws a polygon with the specified color.  The polygon must be
created first (see below).  The polygon must have at least three
vertices.  If the last vertex doesn't close the polygon, the method
will close it for you.  Both real color indexes and the special 
colors gdBrushed, gdStyled and gdStyledBrushed can be specified.

Example:

	$poly = new GD::Polygon;
	$poly->addPt(50,0);
	$poly->addPt(99,99);
	$poly->addPt(0,99);
	$myImage->polygon($poly,$blue);

=item C<filledPolygon>

C<$image-E<gt>filledPolygon(poly,color)> I<object method>

This draws a polygon filled with the specified color.  You can use a
real color, or the special fill color gdTiled to fill the polygon
with a pattern.

Example:

	# make a polygon
	$poly = new GD::Polygon;
	$poly->addPt(50,0);
	$poly->addPt(99,99);
	$poly->addPt(0,99);

	# draw the polygon, filling it with a color
	$myImage->filledPolygon($poly,$peachpuff);

=item C<arc>

C<$image-E<gt>arc(cx,cy,width,height,start,end,color)> I<object method>

This draws arcs and ellipses.  (cx,cy) are the center of the arc, and
(width,height) specify the width and height, respectively.  The
portion of the ellipse covered by the arc are controlled by start and
end, both of which are given in degrees from 0 to 360.  Zero is at the
top of the ellipse, and angles increase clockwise.  To specify a
complete ellipse, use 0 and 360 as the starting and ending angles.  To
draw a circle, use the same value for width and height.

You can specify a normal color or one of the special colors gdBrushed,
gdStyled, or gdStyledBrushed.

Example:

	# draw a semicircle centered at 100,100
	$myImage->arc(100,100,50,50,0,180,$blue);

=item C<fill>

C<$image-E<gt>fill(x,y,color)> I<object method>

This method flood-fills regions with the specified color.  The color
will spread through the image, starting at point (x,y), until it is
stopped by a pixel of a different color from the starting pixel (this
is similar to the "paintbucket" in many popular drawing toys).  You
can specify a normal color, or the special color gdTiled, to flood-fill
with patterns.

Example:

	# Draw a rectangle, and then make its interior blue
	$myImage->rectangle(10,10,100,100,$black);
	$myImage->fill(50,50,$blue);

=item C<$image-E<gt>fillToBorder(x,y,bordercolor,color)> I<object method>

Like C<fill>, this method flood-fills regions with the specified color,
starting at position (x,y).
However, instead of stopping when it hits a pixel of a different color
than the starting pixel, flooding will only stop when it hits the
color specified by bordercolor.  You must specify a normal indexed
color for the bordercolor.  However, you are free to use the gdTiled
color for the fill.

Example:

	# This has the same effect as the previous example
	$myImage->rectangle(10,10,100,100,$black);
	$myImage->fillToBorder(50,50,$black,$blue);

=back

=head2 Image Copying Commands

Two methods are provided for copying a rectangular region from one
image to another.  One method copies a region without resizing it.
The other allows you to stretch the region during the copy operation.

With either of these methods it is important to know that the routines
will attempt to flesh out the destination image's color table to match
the colors that are being copied from the source.  If the
destination's color table is already full, then the routines will
attempt to find the best match, with varying results.

=over 5

=item C<copy>

C<$image-E<gt>copy(sourceImage,dstX,dstY,srcX,srcY,width,height)> I<object method>

This is the simplest of the several copy operations, copying the
specified region from the source image to the destination image (the
one performing the method call).  (srcX,srcY) specify the upper left
corner of a rectangle in the source image, and (width,height) give the
width and height of the region to copy.  (dstX,dstY) control where in
the destination image to stamp the copy.  You can use the same image
for both the source and the destination, but the source and
destination regions must not overlap or strange things will happen.

Example:

	$myImage = new GD::Image(100,100);
	... various drawing stuff ...
	$srcImage = new GD::Image(50,50);
	... more drawing stuff ...
	# copy a 25x25 pixel region from $srcImage to
	# the rectangle starting at (10,10) in $myImage
	$myImage->copy($srcImage,10,10,0,0,25,25);

=item C<clone>

C<$image-E<gt>clone()> I<object method>

Make a copy of the image and return it as a new object.  The new image
will look identical.  However, it may differ in the size of the color
palette and other nonessential details.

Example:

	$myImage = new GD::Image(100,100);
	... various drawing stuff ...
        $copy = $myImage->clone;

C<$image-E<gt>copyMerge(sourceImage,dstX,dstY,srcX,srcY,width,height,percent)> I<object method>

This copies the indicated rectangle from the source image to the
destination image, merging the colors to the extent specified by
percent (an integer between 0 and 100).  Specifying 100% has the same
effect as copy() -- replacing the destination pixels with the source
image.  This is most useful for highlighting an area by merging in a
solid rectangle.

Example:

	$myImage = new GD::Image(100,100);
	... various drawing stuff ...
	$redImage = new GD::Image(50,50);
	... more drawing stuff ...
	# copy a 25x25 pixel region from $srcImage to
	# the rectangle starting at (10,10) in $myImage, merging 50%
	$myImage->copyMerge($srcImage,10,10,0,0,25,25,50);

C<$image-E<gt>copyMergeGray(sourceImage,dstX,dstY,srcX,srcY,width,height,percent)> I<object method>

This is identical to copyMerge() except that it preserves the hue of
the source by converting all the pixels of the destination rectangle
to grayscale before merging.

=item C<copyResized>

C<$image-E<gt>copyResized(sourceImage,dstX,dstY,srcX,srcY,destW,destH,srcW,srcH)> I<object method>

This method is similar to copy() but allows you to choose different
sizes for the source and destination rectangles.  The source and
destination rectangle's are specified independently by (srcW,srcH) and
(destW,destH) respectively.  copyResized() will stretch or shrink the
image to accomodate the size requirements.

Example:

	$myImage = new GD::Image(100,100);
	... various drawing stuff ...
	$srcImage = new GD::Image(50,50);
	... more drawing stuff ...
	# copy a 25x25 pixel region from $srcImage to
	# a larger rectangle starting at (10,10) in $myImage
	$myImage->copyResized($srcImage,10,10,0,0,50,50,25,25);

=back

=head2 Character and String Drawing

Gd allows you to draw characters and strings, either in normal
horizontal orientation or rotated 90 degrees.  These routines use a
GD::Font object, described in more detail below.  There are four
built-in fonts, available in global variables gdGiantFont, gdLargeFont,
gdMediumBoldFont, gdSmallFont and gdTinyFont.  Currently there is no
way of dynamically creating your own fonts.

=over 5

=item C<string>

C<$image-E<gt>string(font,x,y,string,color)> I<Object Method>

This method draws a string startin at position (x,y) in the specified
font and color.  Your choices of fonts are gdSmallFont, gdMediumBoldFont,
gdTinyFont, gdLargeFont and gdGiantFont.

Example:

	$myImage->string(gdSmallFont,2,10,"Peachy Keen",$peach);

=item C<stringUp>

C<$image-E<gt>stringUp(font,x,y,string,color)> I<Object Method>

Just like the previous call, but draws the text rotated
counterclockwise 90 degrees.

=item C<char>

=item C<charUp>

C<$image-E<gt>char(font,x,y,char,color)> I<Object Method>
C<$image-E<gt>charUp(font,x,y,char,color)> I<Object Method>

These methods draw single characters at position (x,y) in the
specified font and color.  They're carry-overs from the C interface,
where there is a distinction between characters and strings.  Perl is
insensible to such subtle distinctions.

=item C<stringTTF>

C<@bounds = $image-E<gt>stringTTF(fgcolor,fontname,ptsize,angle,x,y,string)> I<Object Method> 
C<@bounds = GD::Image-E<gt>stringTTF(fgcolor,fontname,ptsize,angle,x,y,string)> I<Class Method>

This method uses TrueType to draw a scaled, antialiased string using
the TrueType vector font of your choice.  It requires that libgd to
have been compiled with TrueType support, and for the appropriate
TrueType font to be installed on your system.  

The arguments are as follows:

  fgcolor    Color index to draw the string in
  fontname   An absolute or relative path to the TrueType (.ttf) font file
  ptsize     The desired point size (may be fractional)
  angle      The rotation angle, in radians
  x,y        X and Y coordinates to start drawing the string
  string     The string itself

If successful, the method returns an eight-element list giving the
boundaries of the rendered string:

 @bounds[0,1]  Lower left corner (x,y)
 @bounds[2,3]  Lower right corner (x,y)
 @bounds[4,5]  Upper right corner (x,y)
 @bounds[6,7]  Upper left corner (x,y)

In case of an error (such as the font not being available, or TTF
support not being available), the method returns an empty list and
sets $@ to the error message.

You may also call this method from the GD::Image class name, in which
case it doesn't do any actual drawing, but returns the bounding box
using an inexpensive operation.  You can use this to perform layout
operations prior to drawing.

=back

=head2 Miscellaneous Image Methods

=over 5

=item C<interlaced>

C<$image-E<gt>interlaced( )> C<$image-E<gt>interlaced(1)> I<Object method>

This method sets or queries the image's interlaced setting.  Interlace
produces a cool venetian blinds effect on certain viewers.  Provide a
true parameter to set the interlace attribute.  Provide undef to
disable it.  Call the method without parameters to find out the
current setting.

=item C<getBounds>

C<$image-E<gt>getBounds( )> I<Object method>

This method will return a two-member list containing the width and
height of the image.  You query but not not change the size of the
image once it's created.

=item C<compare>

C<$image1-E<gt>compare($image2)>

Compare two images and return a bitmap describing the differenes
found, if any.  The return value must be logically ANDed with one or
more constants in order to determine the differences.  The following
constants are available:

  GD_CMP_IMAGE             The two images look different
  GD_CMP_NUM_COLORS        The two images have different numbers of colors
  GD_CMP_COLOR             The two images' palettes differ
  GD_CMP_SIZE_X            The two images differ in the horizontal dimension
  GD_CMP_SIZE_Y            The two images differ in the vertical dimension
  GD_CMP_TRANSPARENT       The two images have different transparency
  GD_CMP_BACKGROUND        The two images have different background colors
  GD_CMP_INTERLACE         The two images differ in their interlace

The most important of these is GD_CMP_IMAGE, which will tell you
whether the two images will look different, ignoring differences in the
order of colors in the color palette and other invisible changes.  The
constants are not imported by default, but must be imported individually
or by importing the :cmp tag.  Example:

  use GD qw(:DEFAULT :cmp);
  # get $image1 from somewhere
  # get $image2 from somewhere
  if ($image1->compare($image2) & GD_CMP_IMAGE) {
     warn "images differ!";
  }

=back

=head2 Polygon Methods

A few primitive polygon creation and manipulation methods are
provided.  They aren't part of the Gd library, but I thought they
might be handy to have around (they're borrowed from my qd.pl
Quickdraw library).

=over 5

=item C<new>

C<GD::Polygon-E<gt>new> I<class method>

Create an empty polygon with no vertices.

	$poly = new GD::Polygon;

=item C<addPt>

C<$poly-E<gt>addPt(x,y)> I<object method>

Add point (x,y) to the polygon.

	$poly->addPt(0,0);
	$poly->addPt(0,50);
	$poly->addPt(25,25);
	$myImage->fillPoly($poly,$blue);

=item C<getPt>

C<$poly-E<gt>getPt(index)> I<object method>

Retrieve the point at the specified vertex.

	($x,$y) = $poly->getPt(2);

=item C<setPt>

C<$poly-E<gt>setPt(index,x,y)> I<object method>

Change the value of an already existing vertex.  It is an error to set
a vertex that isn't already defined.

	$poly->setPt(2,100,100);

=item C<deletePt>

C<$poly-E<gt>deletePt(index)> I<object method>

Delete the specified vertex, returning its value.

	($x,$y) = $poly->deletePt(1); 

=item C<toPt>

C<$poly-E<gt>toPt(dx,dy)> I<object method>

Draw from current vertex to a new vertex, using relative 
(dx,dy) coordinates.  If this is the first point, act like
addPt().

	$poly->addPt(0,0);
	$poly->toPt(0,50);
	$poly->toPt(25,-25);
	$myImage->fillPoly($poly,$blue);


=item C<length>

C<$poly-E<gt>length> I<object method>

Return the number of vertices in the polygon.

	$points = $poly->length;

=item C<vertices>

C<$poly-E<gt>vertices> I<object method>

Return a list of all the verticies in the polygon object.  Each
membver of the list is a reference to an (x,y) array.

	@vertices = $poly->vertices;
	foreach $v (@vertices)
	   print join(",",@$v),"\n";
	}

=item C<bounds>

C<$poly-E<gt>bounds> I<object method>

Return the smallest rectangle that completely encloses the polygon.
The return value is an array containing the (left,top,right,bottom) of
the rectangle.

	($left,$top,$right,$bottom) = $poly->bounds;

=item C<offset>

C<$poly-E<gt>offset(dx,dy)> I<object method>

Offset all the vertices of the polygon by the specified horizontal
(dh) and vertical (dy) amounts.  Positive numbers move the polygon
down and to the right.

	$poly->offset(10,30);

=item C<map>

C<$poly-E<gt>map(srcL,srcT,srcR,srcB,destL,dstT,dstR,dstB)> I<object method>

Map the polygon from a source rectangle to an equivalent position in a
destination rectangle, moving it and resizing it as necessary.  See
polys.pl for an example of how this works.  Both the source and
destination rectangles are given in (left,top,right,bottom)
coordinates.  For convenience, you can use the polygon's own bounding
box as the source rectangle.

	# Make the polygon really tall
	$poly->map($poly->bounds,0,0,50,200);

=item C<scale>

C<$poly-E<gt>scale(sx,sy)> I<object method>

Scale each vertex of the polygon by the X and Y factors indicated by
sx and sy.  For example scale(2,2) will make the polygon twice as
large.  For best results, move the center of the polygon to position
(0,0) before you scale, then move it back to its previous position.

=item C<transform>

C<$poly-E<gt>transform(sx,rx,sy,ry,tx,ty)> I<object method>

Run each vertex of the polygon through a transformation matrix, where
sx and sy are the X and Y scaling factors, rx and ry are the X and Y
rotation factors, and tx and ty are X and Y offsets.  See the Adobe
PostScript Reference, page 154 for a full explanation, or experiment.

=back

=head2 Font Utilities

The libgd library (used by the Perl GD library) has built-in support
for about half a dozen fonts, which were converted from public-domain
X Windows fonts.  For more fonts, compile libgd with TrueType support
and use the stringTTF() call.

If you wish to add more built-in fonts, the directory bdf_scripts
contains two contributed utilities that may help you convert X-Windows
BDF-format fonts into the format that libgd uses internally.  However
these scripts were written for earlier versions of GD which included
its own mini-gd library.  These scripts will have to be adapted for
use with libgd, and the libgd library itself will have to be
recompiled and linked!  Please do not contact me for help with these
scripts: they are unsupported.

=over 5

=item C<gdSmallFont>

C<GD::Font-E<gt>Small> I<constant>

This is the basic small font, "borrowed" from a well known public
domain 6x12 font.

=item C<gdLargeFont>

C<GD::Font-E<gt>Large> I<constant>

This is the basic large font, "borrowed" from a well known public
domain 8x16 font.

=item C<gdMediumBoldFont>

C<GD::Font-E<gt>MediumBold> I<constant>

This is a bold font intermediate in size between the small and large
fonts, borrowed from a public domain 7x13 font;

=item C<gdTinyFont>

C<GD::Font-E<gt>Tiny> I<constant>

This is a tiny, almost unreadable font, 5x8 pixels wide.

=item C<gdGiantFont>

C<GD::Font-E<gt>Giant> I<constant>

This is a 9x15 bold font converted by Jan Pazdziora from a sans serif
X11 font.

=item C<nchars>

C<$font-E<gt>nchars>	I<object method>

This returns the number of characters in the font.

	print "The large font contains ",gdLargeFont->nchars," characters\n";

=item C<offset>

C<$font-E<gt>offset> 	I<object method>

This returns the ASCII value of the first character in the font

=item C<width>

=item C<height>

C<$font-E<gt>width> C<GD::Font::height>	I<object methods>

These return the width and height of the font.

	($w,$h) = (gdLargeFont->width,gdLargeFont->height);

=back

=head1 Obtaining the C-language version of gd

libgd, the C-language version of gd, can be obtained at URL
http://www.boutell.com/gd/.  Directions for installing and using it
can be found at that site.  Please do not contact me for help with
libgd.

=head1 Copyright Information

The GD.pm interface is copyright 1995-1999, Lincoln D. Stein.  It is
distributed under the same terms as Perl itself.  See the "Artistic
License" in the Perl source code distribution for licensing terms.

The latest versions of GD.pm are available at

  http://stein.cshl.org/WWW/software/GD


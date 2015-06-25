                    =====================================
                      Package "Bit::Vector" Version 6.0
                    =====================================


This package is available for download either from my web site at

                  http://www.engelschall.com/u/sb/download/

or from any CPAN (= "Comprehensive Perl Archive Network") mirror server:

               http://www.perl.com/CPAN/authors/id/S/ST/STBEY/


Abstract:
---------

Bit::Vector is an efficient C library which allows you to handle
bit vectors, sets (of integers), "big integer arithmetic" and
boolean matrices, all of arbitrary sizes.

The library is efficient (in terms of algorithmical complexity)
and therefore fast (in terms of execution speed) for instance
through the widespread use of divide-and-conquer algorithms.

The package also includes an object-oriented Perl module for
accessing the C library from Perl, and optionally features
overloaded operators for maximum ease of use.

The C library can nevertheless be used stand-alone, without Perl.


Legal issues:
-------------

This package with all its parts is

Copyright (c) 1995 - 2000 by Steffen Beyer.
All rights reserved.

This package is free software; you can use, modify and redistribute
it under the same terms as Perl itself, i.e., under the terms of
the "Artistic License" or the "GNU General Public License".

The C library at the core of this Perl module can additionally
be used, modified and redistributed under the terms of the
"GNU Library General Public License".

Please refer to the files "Artistic.txt", "GNU_GPL.txt" and
"GNU_LGPL.txt" in this distribution, respectively, for details!


Prerequisites:
--------------

Perl version 5.000 or higher, and an ANSI C compiler (!)
                                     ^^^^^^

If you compile under Windows, note that you will need
exactly the same compiler your Perl itself was compiled
with! (This is also true for Unix, but rarely a problem.)

Moreover, you usually cannot build any modules under
Windows 95/98, the Win 95/98 command shell is too dumb.
You will need the Windows NT command shell ("command.com")
or the "4DOS" shell.

Note that ActiveState provides precompiled binaries of
this module for their Win32 port of Perl ("ActivePerl")
on their web site, which you should be able to install
simply by typing "ppm install Bit-Vector" in your MS-DOS
command shell. This also works under Windows 95/98.

If your firewall prevents "ppm" from downloading this
package, you can also download it manually from
http://www.activestate.com/ppmpackages/5.005/zips/ or
http://www.activestate.com/ppmpackages/5.6/zips/.
Follow the installation instructions included in
the "zip" archive.


Installation:
-------------

Please see the file "INSTALL.txt" in this distribution for instructions
on how to install this package.

It is essential that you read this file since one of the special cases
described in it might apply to you, especially if you are running Perl
under Windows.


Changes over previous versions:
-------------------------------

Please refer to the file "CHANGES.txt" in this distribution for a detailed
version history.


Documentation:
--------------

The documentation of this package is included in POD format (= "Plain
Old Documentation") in the files "Vector.pod" and "Overload.pod" in
this distribution, the human-readable markup-language standard for
Perl documentation.

By building this package, this documentation will automatically be
converted into a man page, which will automatically be installed in
your Perl tree through the installation process for further reference,
where it can be accessed by the commands "man Bit::Vector" (UNIX) and
"perldoc Bit::Vector" (UNIX and Win32), or "man Bit::Vector::Overload"
(UNIX) and "perldoc Bit::Vector::Overload" (UNIX and Win32).

If Perl is not available on your system, you can also read these files
directly.


What does it do:
----------------

This module implements bit vectors of arbitrary size and provides efficient
methods for handling them.

This goes far beyond the built-in capabilities of Perl for handling bit
vectors (compare with the method list below!).

Moreover, the C core of this module can be used "stand-alone" in other
C applications; Perl is not necessarily required.

The module is intended to serve as a base class for other applications
or application classes, such as implementing sets or performing big
integer arithmetic.

All methods are implemented in C internally for maximum performance.

An add-on module (named "Bit::Vector::Overload") provides overloaded
arithmetic and relational operators for maximum ease of use (Perl only).

Note that there is (of course) a little speed penalty to pay for
overloaded operators. If speed is crucial, use the "Bit::Vector"
module alone!

This module is useful for a large range of different tasks:

  -  For example for implementing sets and performing set operations
     (like union, difference, intersection, complement, check for subset
     relationship etc.),

  -  as a basis for many efficient algorithms, for instance the
     "Sieve of Erathostenes" (for calculating prime numbers),

     (The complexities of the methods in this module are usually either
      O(1) or O(n/b), where "b" is the number of bits in a machine word
      on your system.)

  -  for shift registers of arbitrary length (for example for cyclic
     redundancy checksums),

  -  to calculate "look-ahead", "first" and "follow" character sets
     for parsers and compiler-compilers,

  -  for graph algorithms,

  -  for efficient storage and retrieval of status information,

  -  for performing text synthesis ruled by boolean expressions,

  -  for "big integer" arithmetic with arbitrarily large integers,

  -  for manipulations of chunks of bits of arbitrary size,

  -  for bitwise processing of audio CD wave files,

  -  to convert formats of data files,

and more.

(A number of example applications is available from my web site at
http://www.engelschall.com/u/sb/download/.)

A large number of import/export methods allow you to access individual
bits, contiguous ranges of bits, machine words, arbitrary chunks of
bits, lists (arrays) of chunks of bits or machine words and a whole
bit vector at once (for instance for blockwrite/-read to and from
a file).

You can also import and export the contents of a bit vector in binary,
hexadecimal and decimal representation as well as ".newsrc" style
enumerations.

Note that this module is specifically designed for efficiency, which is
also the reason why its methods are implemented in C.

To further increase execution speed, the module doesn't use bytes as its
basic storage unit, but rather uses machine words, assuming that a machine
word is the most efficiently handled size of all scalar types on all
machines (that's what the ANSI C standard proposes and assumes anyway).

In order to achieve this, it automatically determines the number of bits
in a machine word on your system and then adjusts its internal configuration
constants accordingly.

The greater the size of this basic storage unit, the better the complexity
(= execution speed) of the methods in this module, but also the greater the
average waste of unused bits in the last word.

The range of available methods is exceptionally large for this kind of library;
in detail:

Version()                Word_Bits()              Long_Bits()
new()                    new_Hex()                new_Bin()
new_Dec()                new_Enum()               Shadow()
Clone()                  Concat()                 Concat_List()
Size()                   Resize()                 Copy()
Empty()                  Fill()                   Flip()
Primes()                 Reverse()                Interval_Empty()
Interval_Fill()          Interval_Flip()          Interval_Reverse()
Interval_Scan_inc()      Interval_Scan_dec()      Interval_Copy()
Interval_Substitute()    is_empty()               is_full()
equal()                  Lexicompare()            Compare()
to_Hex()                 from_Hex()               to_Bin()
from_Bin()               to_Dec()                 from_Dec()
to_Enum()                from_Enum()              Bit_Off()
Bit_On()                 bit_flip()               bit_test()
Bit_Copy()               LSB()                    MSB()
lsb()                    msb()                    rotate_left()
rotate_right()           shift_left()             shift_right()
Move_Left()              Move_Right()             Insert()
Delete()                 increment()              decrement()
inc()                    dec()                    add()
subtract()               Negate()                 Absolute()
Sign()                   Multiply()               Divide()
GCD()                    Power()                  Block_Store()
Block_Read()             Word_Size()              Word_Store()
Word_Read()              Word_List_Store()        Word_List_Read()
Word_Insert()            Word_Delete()            Chunk_Store()
Chunk_Read()             Chunk_List_Store()       Chunk_List_Read()
Index_List_Remove()      Index_List_Store()       Index_List_Read()
Union()                  Intersection()           Difference()
ExclusiveOr()            Complement()             subset()
Norm()                   Min()                    Max()
Multiplication()         Product()                Closure()
Transpose()


Note to C developers:
---------------------

Note again that the C library at the core of this module can also be
used stand-alone (i.e., it contains no inter-dependencies whatsoever
with Perl).

The library itself consists of three files: "BitVector.c", "BitVector.h"
and "ToolBox.h".

Just compile "BitVector.c" (which automatically includes "ToolBox.h")
and link the resulting output file "BitVector.o" with your application,
which in turn should include "ToolBox.h" and "BitVector.h" (in this order).


Example applications:
---------------------

See the module "Set::IntRange" for an easy-to-use module for sets
of integers within arbitrary ranges.

See the module "Math::MatrixBool" for an efficient implementation
of boolean matrices and boolean matrix operations.

(Both modules are also available from my web site at
http://www.engelschall.com/u/sb/download/ or any CPAN server.)

See the file "SetObject.pl" in the "examples" subdirectory of this
distribution for a way to emulate the "Set::Object" module from CPAN
using "Bit::Vector" - this is a way to perform set operations on sets
of arbitrary objects (any Perl objects or Perl data structures you want!).

An application relying crucially on this "Bit::Vector" module is "Slice",
a tool for generating different document versions out of a single
master file, ruled by boolean expressions ("include english version
of text plus examples but not ...").

(See also http://www.engelschall.com/sw/slice/.)

This tool is itself part of another tool, "Website META Language" ("WML"),
which allows you to generate and maintain large web sites.

Among many other features, it allows you to define your own HTML tags which
will be expanded either at generation or at run time, depending on your
choice.

(See also http://www.engelschall.com/sw/wml/.)

Both tools are written by Ralf S. Engelschall.


Credits:
--------

Please refer to the file "CREDITS.txt" in this distribution for a list
of contributors.


Author's note:
--------------

If you have any questions, suggestions or need any assistance, please
let me know!

Please do send feedback, this is essential for improving this module
according to your needs!

I hope you will find this module beneficial.

Yours,
--
  Steffen Beyer <sb@engelschall.com> http://www.engelschall.com/u/sb/
  "There is enough for the need of everyone in this world, but not
   for the greed of everyone." - Mohandas Karamchand "Mahatma" Gandhi

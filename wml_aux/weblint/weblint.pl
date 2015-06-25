#!/usr/bin/perl
eval 'exec /usr/bin/perl -S $0 ${1+"$@"}'
    if $running_under_some_shell;

#
# weblint - pick fluff off WWW pages (html).
#
# Copyright (C) 1994, 1995, 1996, 1997 Neil Bowers.  All rights reserved.
#
# See README for additional blurb.
# Bugs, comments, suggestions welcome: neilb@cre.canon.co.uk
#
# Latest version is available as:
#	ftp://ftp.cre.canon.co.uk/pub/weblint/weblint.tar.gz
#

#   Added for WML, to replace newgetopt.pl by Getopt::Long
use lib "/usr/local/lib/wml/perl/lib";
use lib "/usr/local/lib/wml/perl/lib/x86_64-linux";
use Getopt::Long 2.13;

$VERSION        = '1.020';
($PROGRAM       = $0) =~ s@.*/@@;
@TMPDIR_OPTIONS	= ('/usr/tmp', '/tmp', '/var/tmp', '/temp');
$TMPDIR         = &PickTmpdir(@TMPDIR_OPTIONS);
$SITE_DIR       = '/usr/local/lib/wml/data';
$USER_RCFILE    = $ENV{'WEBLINTRC'} || "$ENV{'HOME'}/.weblintrc";
$SITE_RCFILE	= $SITE_DIR.'/weblintrc' if $SITE_DIR;


#------------------------------------------------------------------------
# $version - the string which is displayed with -v or -version
#------------------------------------------------------------------------
$versionString=<<EofVersion;
	This is weblint, version $VERSION

	Copyright 1994,1995,1996,1997 Neil Bowers

	Weblint may be used and copied only under the terms of the Artistic
	License, which may be found in the Weblint source kit, or at:
        	http://www.cre.canon.co.uk/~neilb/weblint/artistic.html
EofVersion


#------------------------------------------------------------------------
# $usage - usage string displayed with the -U command-line switch
#------------------------------------------------------------------------
$usage=<<EofUsage;
  $PROGRAM v$VERSION - pick fluff off web pages (HTML)
      -d            : disable specified warnings (warnings separated by commas)
      -e            : enable specified warnings (warnings separated by commas)
      -f filename   : alternate configuration file
      -stderr       : print warnings to STDERR rather than STDOUT
      -i            : ignore case in element tags
      -l            : ignore symlinks when recursing in a directory
      -pedantic     : turn on all warnings, except for case of element tags
      -s            : give short warning messages (filename not printed)
      -t            : terse warning mode, useful mainly for testsuite
      -todo         : print the todo list for $PROGRAM
      -help | -U    : display this usage message
      -urlget       : specify the command used to get a URL
      -version | -v : display version
      -warnings     : list supported warnings
      -x <extn>     : HTML extension to use (supported: Microsoft, Netscape)

  To check one or more HTML files, run weblint thusly:
      weblint file1.html [... fileN.html]
  If a file is in fact a directory, weblint will recurse, checking all files.

  To include the Netscape extensions: weblint -x Netscape file.html
EofUsage

#------------------------------------------------------------------------
# $todo - string displayed with the -todo switch
#------------------------------------------------------------------------
$todo=<<EofToDo;
The Weblint toDo list can be seen at:
	http://www.cre.canon.co.uk/~neilb/weblint/todo/
EofToDo

*WARNING = *STDOUT;

# obsolete tags
$obsoleteTags = 'PLAINTEXT|XMP|LISTING';

$maybePaired  = 'LI|DT|DD|P|TD|TH|TR|OPTION';

$pairElements = 'A|ADDRESS|APPLET|HTML|HEAD|BIG|BLOCKQUOTE|BODY|CAPTION|DIV|'.
                'H1|H2|H3|H4|H5|H6|CENTER|FONT|MAP|FONT|'.
		'B|I|U|TT|STRONG|EM|CODE|KBD|VAR|DFN|CITE|SAMP|'.
		'UL|OL|DL|'.
                'MENU|DIR|FORM|SCRIPT|'.
                'SELECT|SMALL|STRIKE|STYLE|'.
                'SUB|SUP|TABLE|TEXT|TEXTAREA|TITLE|CODE|PRE|'.
                $maybePaired.'|'.
                $obsoleteTags;

# container elements which shouldn't have leading or trailing whitespace
$cuddleContainers = 'A|H1|H2|H3|H4|H5|H6|TITLE|LI';

# expect to see these tags only once
%onceOnly = ('HTML', 1, 'HEAD', 1, 'BODY', 1, 'TITLE', 1);

@fontElements = ('TT', 'I', 'B', 'U', 'STRIKE', 'BIG', 'SMALL', 'SUB', 'SUP',
		 'EM', 'STRONG', 'DFN', 'CODE', 'SAMP', 'KBD', 'VAR', 'CITE');

%physicalFontElements =
(
 'B',  'STRONG',
 'I',  'EM',
 'TT', 'CODE, SAMP, KBD, or VAR'
 );

# expect these tags to have attributes
# these are elements which have no required attributes, but we expect to
# see at least one of the attributes
$expectArgsRE = 'A|FONT';

# these tags can only appear in the head element
$headTagsRE = 'TITLE|NEXTID|LINK|BASE|META';

%requiredContext =
(
 'CAPTION',   'TABLE',
 'DD',        'DL',
 'DT',        'DL',
 'INPUT',     'FORM',
 'LI',        'DIR|MENU|OL|UL',
 'OPTION',    'SELECT',
 'SELECT',    'FORM',
 'TD',        'TR',
 'TEXTAREA',  'FORM',
 'TH',        'TR',
 'TR',        'TABLE',
 'PARAM',    'APPLET',
 );

# these tags are allowed to appear in the head element
%okInHead = ('ISINDEX', 1, 'TITLE', 1, 'NEXTID', 1, 'LINK', 1,
	     'BASE', 1, 'META', 1, 'RANGE', 1, 'STYLE', 1, '!--', 1);

# expect to see these at least once.
# html-outer covers the HTML element
@expectedTags = ('HEAD', 'TITLE', 'BODY');

# elements which cannot be nested
$nonNest = 'A|FORM';

# This table holds the valid attributes for elements
# Where an element does not have an entry, this implies that the element
# does not take any attributes
%validAttributes =
   (
   'A',          'HREF|NAME|TITLE|REL|REV',
   'ADDRESS',    0,
   'APPLET',     'CODEBASE|CODE|ALT|NAME|WIDTH|HEIGHT|ALIGN|HSPACE|VSPACE',
   'AREA',       'SHAPE|COORDS|HREF|NOHREF|ALT',
   'BASE',       'HREF',
   'BASEFONT',   'SIZE',
   'BLOCKQUOTE', 0,
   'BODY',       'BACKGROUND|BGCOLOR|TEXT|LINK|VLINK|ALINK',
   'BR',         'CLEAR',
   'CAPTION',    'ALIGN',
   'CENTER',     0,
   'DIV',        'ALIGN',
   'DIR',        'COMPACT',
   'DD',         0,
   'DL',         'COMPACT',
   'DT',         0,
   'FONT',       'SIZE|COLOR',
   'FORM',       'ACTION|METHOD|ENCTYPE',
   'H1',         'ALIGN',
   'H2',         'ALIGN',
   'H3',         'ALIGN',
   'H4',         'ALIGN',
   'H5',         'ALIGN',
   'H6',         'ALIGN',
   'HEAD',       0,
   'HR',         'ALIGN|NOSHADE|SIZE|WIDTH',
   'HTML',       'VERSION',
   'IMG',       'SRC|ALT|ALIGN|HEIGHT|WIDTH|BORDER|HSPACE|VSPACE|USEMAP|ISMAP',
   'INPUT',      'TYPE|NAME|VALUE|CHECKED|SIZE|MAXLENGTH|SRC|ALIGN',
   'ISINDEX',    'PROMPT',
   'LI',         'TYPE|VALUE',
   'LINK',       'HREF|REL|REV|TITLE',
   'LISTING',    0,
   'MAP',        'NAME',
   'MENU',       'COMPACT',
   'META',       'HTTP-EQUIV|NAME|CONTENT',
   'OL',         'TYPE|START|COMPACT',
   'OPTION',     'SELECTED|VALUE',
   'P',          'ALIGN',
   'PARAM',      'NAME|VALUE',
   'PLAINTEXT',  0,
   'PRE',        'WIDTH',
   'SCRIPT',     'LANGUAGE|SRC',
   'SELECT',     'NAME|SIZE|MULTIPLE',
   'STYLE',      0,
   'TABLE',      'ALIGN|WIDTH|BORDER|CELLSPACING|CELLPADDING',
   'TD',         'NOWRAP|ROWSPAN|COLSPAN|ALIGN|VALIGN|WIDTH|HEIGHT',
   'TEXTAREA',   'NAME|ROWS|COLS',
   'TH',         'NOWRAP|ROWSPAN|COLSPAN|ALIGN|VALIGN|WIDTH|HEIGHT',
   'TITLE',      0,
   'TR',         'ALIGN|VALIGN',
   'TT',         0,
   'UL',         'TYPE|COMPACT',
   'XMP',        0,
   );

foreach $elt (@fontElements)
{
   $validAttributes{$elt} = '';
}

%requiredAttributes =
   (
    'BASE',      'HREF',
    'BASEFONT',  'SIZE',
    'FORM',      'ACTION',
    'IMG',       'SRC',
    'LINK',      'HREF',
    'NEXTID',    'N',
    'SELECT',    'NAME',
    'TEXTAREA',  'NAME|ROWS|COLS'
   );

$ColorNames = 'Black|White|Green|Maroon|Olive|Navy|Purple|Gray|'.
            'Red|Yellow|Blue|Teal|Lime|Aqua|Fuchsia|Silver';

$colorRE = '#[0-9a-fA-F]{6}'.'|'.$ColorNames;
%attributeFormat =
(
 'ALIGN',     'BOTTOM|MIDDLE|TOP|LEFT|CENTER|RIGHT|JUSTIFY|'.
              'BLEEDLEFT|BLEEDRIGHT|DECIMAL',
 'CLEAR',    'LEFT|RIGHT|ALL|NONE',
 'COLS',      '\d+',
 'COLSPAN',   '\d+',
 'HEIGHT',    '\d+',
 'INDENT',    '\d+',
 'MAXLENGTH', '\d+',
 'METHOD',    'GET|POST',
 'ROWS',      '\d+',
 'ROWSPAN',   '\d+',
 'SEQNUM',    '\d+',
 'SIZE',      '[-+]?\d+|\d+,\d+',
 'SKIP',      '\d+',
 'TYPE',     'CHECKBOX|HIDDEN|IMAGE|PASSWORD|RADIO|RESET|SUBMIT|TEXT|'.
             '[AaIi1]|disc|square|circle|FILE',
 'UNITS',     'PIXELS|EN',
 'VALIGN',    'TOP|MIDDLE|BOTTOM|BASELINE',
 'WIDTH',     '\d+%?',
 'WRAP',      'OFF|VIRTUAL|PHYSICAL',
 'X',         '\d+',
 'Y',         '\d+'
);
$attributeFormat{'ALINK'} = $attributeFormat{'VLINK'} =
      $attributeFormat{'LINK'} = $attributeFormat{'TEXT'} =
      $attributeFormat{'BGCOLOR'} = $attributeFormat{'COLOR'} = $colorRE;

#-----------------------------------------------------------------------
# Where an element appears in this hash, the value replaces that in
# the validAttributes hash.
#-----------------------------------------------------------------------
%netscapeAttributes =
(
 'A',        'HREF|NAME|TITLE|REL|REV|TARGET|ONCLICK|ONMOUSEOUT|ONMOUSEOVER',
 'APPLET',   'ALIGN|ALT|ARCHIVE|CODE|CODEBASE|HEIGHT|HSPACE|MAYSCRIPT|NAME|'.
             'VSPACE|WIDTH',
 'AREA',     'COORDS|HREF|NAME|NOHREF|ONMOUSEOUT|ONMOUSEOVER|SHAPE|TARGET',
 'BASE',     'HREF|TARGET',
 'BODY',     'ALINK|BACKGROUND|BGCOLOR|LINK|TEXT|ONBLUR|ONFOCUS|ONLOAD|'.
             'ONUNLOAD|VLINK',
 'BLINK',    '',
 'EMBED',    'ALIGN|BORDER|FRAMEBORDER|HEIGHT|HIDDEN|HSPACE|NAME|PALETTE|'.
             'PLUGINSPAGE|SRC|TYPE|VSPACE|WIDTH|.+',
 'FONT',     'COLOR|SIZE|FACE',
 'FORM',     'ACTION|ENCTYPE|METHOD|NAME|ONRESET|ONSUBMIT|TARGET',
 'FRAME',    'BORDERCOLOR|FRAMEBORDER|MARGINHEIGHT|MARGINWIDTH|NAME|NORESIZE|'.
             'SCROLLING|SRC',
 'FRAMESET', 'BORDER|BORDERCOLOR|COLS|FRAMEBORDER|ONBLUR|ONFOCUS|ONLOAD|'.
             'ONUNLOAD|ROWS',
 'ILAYER',   'ID',
 'IMG',      'ALIGN|ALT|BORDER|HEIGHT|HSPACE|ISMAP|LOWSRC|NAME|ONABORT|'.
             'ONERROR|ONLOAD|SRC|USEMAP|VSPACE|WIDTH',
 'INPUT',    'ALIGN|CHECKED|MAXLENGTH|NAME|ONBLUR|ONCHANGE|ONCLICK|ONFOCUS|'.
             'ONSELECT|SIZE|SRC|TYPE|VALUE',
 'KEYGEN',   'NAME|CHALLENGE',
 'LAYER',    'ID|LEFT|TOP|PAGEX|PAGEY|SRC|Z-INDEX|ABOVE|BELOW|WIDTH|HEIGHT|'.
             'CLIP|VISIBILITY|BGCOLOR|BACKGROUND|ONMOUSEOVER|ONFOCUS|ONLOAD',
 'LINK',     'HREF|REL|REV|TITLE|TYPE',
 'MULTICOL', 'COLS|GUTTER|WIDTH',
 'NOBR',     0,
 'NOEMBED',  0,
 'NOFRAMES', 0,
 'NOLAYER',  0,
 'NOSCRIPT', 0,
 'OL',       'TYPE|START|COMPACT',
 'S',        0,
 'SELECT',   'NAME|MULTIPLE|ONBLUR|ONCHANGE|ONCLICK|ONFOCUS|SIZE',
 'SERVER',   0,
 'SPACER',   'ALIGN|HEIGHT|SIZE|TYPE|WIDTH',
 'SPAN',     'STYLE|CLASS',
 'STYLE',    'TYPE',
 'TABLE',    'ALIGN|BGCOLOR|BORDER|CELLPADDING|CELLSPACING|COLS|HEIGHT|'.
             'HSPACE|WIDTH|VSPACE',
 'TD',       'ALIGN|BGCOLOR|COLSPAN|NOWRAP|ROWSPAN|VALIGN|WIDTH|HEIGHT',
 'TEXTAREA', 'COLS|NAME|ONBLUR|ONCHANGE|ONFOCUS|ONSELECT|ROWS|WRAP',
 'TH',       'ALIGN|BGCOLOR|COLSPAN|NOWRAP|ROWSPAN|VALIGN|WIDTH|HEIGHT',
 'TR',       'ALIGN|VALIGN|BGCOLOR',
 'WBR',      0,
);
$netscapePaired = 'BLINK|FRAMESET|LAYER|MULTICOL|NOEMBED|NOFRAMES|NOLAYER|'.
                  'NOBR|NOSCRIPT|S|SERVER|SPAN|STYLE';

$msStdAttrs   = 'CLASS|ID|LANG|LANGUAGE|STYLE|TITLE';
$msEvents     = 'ONCLICK|ONHELP|ONKEYPRESS|ONMOUSEMOVE|ONMOUSEOVER|'.
                'ONSELECTSTART|ONDBLCLICK|ONKEYDOWN|ONKEYUP|ONMOUSEDOWN|'.
                'ONMOUSEOUT|ONMOUSEUP';
$msFullEvents = 'ONAFTERUPDATE|ONBEFOREUPDATE|ONBLUR|ONFOCUS|ONDRAGSTART|'.
                'ONRESIZE|ONROWENTER|ONROWEXIT|'.$msEvents,
$msTextAttrs  = $msStdAttrs.'|'.$msEvents;
%msAttributes =
(
 'A',          'ACCESSKEY|CLASS|DATAFLD|DATASRC|HREF|ID|LANG|LANGUAGE|'.
               'METHODS|NAME|REL|REV|STYLE|TARGET|TITLE|URN|ONBLUR|'.
               'ONFOCUS|'.$msEvents,
 'ADDRESS',    'CLASS|ID|LANG|LANGUAGE|STYLE|TITLE|'.$msEvents,
 'APPLET',     'ALIGN|ALT|CLASS|CODE|CODEBASE|DATAFLD|DATASRC|HEIGHT|HSPACE|'.
               'ID|NAME|SRC|STYLE|TITLE|VSPACE|WIDTH',
 'AREA',       'ALT|CLASS|COORDS|HREF|ID|LANG|LANGUAGE|NOHREF|SHAPE|STYLE|'.
               'TARGET|TITLE|ONBLUR|ONFOCUS|'.$msEvents,
 'B',          $msTextAttrs,
 'BASE',       'CLASS|HREF|ID|LANG|TARGET|TITLE',
 'BASEFONT',   'CLASS|COLOR|FACE|ID|LANG|SIZE|TITLE',
 'BGSOUND',    'BALANCE|CLASS|ID|LANG|LOOP|SRC|TITLE|VOLUME',
 'BIG',        $msTextAttrs,
 'BLOCKQUOTE', $msTextAttrs,
 'BODY',       'ACCESSKEY|ALINK|BACKGROUND|BGCOLOR|BGPROPERTIES|BOTTOMMARGIN|'.
               'CLASS|ID|LANG|LANGUAGE|LEFTMARGIN|LINK|RIGHTMARGIN|SCROLL|'.
               'STYLE|TEXT|TITLE|TOPMARGIN|VLINK|ONAFTERUPDATE|'.
               'ONBEFOREUPDATE|ONBLUR|ONCLICK|ONDBLCLICK|ONDRAGSTART|'.
               'ONFOCUS|ONHELP|ONKEYDOWN|ONKEYPRESS|ONKEYUP|ONMOUSEDOWN|'.
               'ONMOUSEMOVE|ONMOUSEOUT|ONMOUSEOVER|ONMOUSEUP|ONRESIZE|'.
               'ONROWENTER|ONROWEXIT|ONSCROLL|ONSELECTSTART',
 'BR',         'CLASS|CLEAR|ID|LANG|LANGUAGE|STYLE|TITLE',
 'BUTTON',     'ACCESSKEY|CLASS|DATAFLD|DATAFORMATAS|DATASRC|DISABLED|'.
               'ID|LANG|LANGUAGE|STYLE|TITLE|TYPE|ONAFTERUPDATE|'.
               'ONBEFOREUPDATE|ONBLUR|ONFOCUS|ONDRAGSTART|ONRESIZE|'.
               'ONROWENTER|ONROWEXIT|'.$msEvents,
 'CAPTION',    'ALIGN|CLASS|ID|LANG|LANGUAGE|STYLE|TITLE|VALIGN|'.
               'ONAFTERUPDATE|ONBEFOREUPDATE|ONBLUR|ONFOCUS|'.
               'ONDRAGSTART|ONRESIZE|ONROWENTER|ONROWEXIT|'.$msEvents,
 'CENTER',     $msTextAttrs,
 'CITE',       $msTextAttrs,
 'CODE',       $msTextAttrs,
 'COL',        'ALIGN|CLASS|ID|SPAN|STYLE|TITLE|VALIGN|WIDTH',
 'COLGROUP',   'ALIGN|CLASS|ID|SPAN|STYLE|TITLE|VALIGN|WIDTH',
 'COMMENT',    'ID|LANG|TITLE',
 'DD',         $msTextAttrs,
 'DFN',        $msTextAttrs,
 'DIR',        $msTextAttrs,
 'DIV',        'ALIGN|CLASS|DATAFLD|DATAFORMATAS|DATASRC|ID|LANG|'.
               'LANGUAGE|STYLE|TITLE|'.$msFullEvents,
 'DL',         $msTextAttrs,
 'DT',         $msTextAttrs,
 'EM',         $msTextAttrs,
 'EMBED',      'ALIGN|ALT|CLASS|CODE|CODEBASE|HEIGHT|HSPACE|ID|NAME|SRC|'.
               'STYLE|TITLE|VSPACE|WIDTH',
 'FIELDSET',   $msTextAttrs,
 'FONT',       'CLASS|COLOR|FACE|ID|LANG|LANGUAGE|SIZE|STYLE|TITLE|'.
               $msEvents,
 'FORM',       'ACTION|CLASS|ENCTYPE|ID|LANG|LANGUAGE|METHOD|NAME|STYLE|'.
               'TARGET|TITLE|ONSUBMIT|'.$msEvents,
 'FRAME',      'BORDERCOLOR|CLASS|DATAFLD|DATASRC|FRAMEBORDER|HEIGHT|ID|'.
               'LANG|LANGUAGE|MARGINHEIGHT|MARGINWIDTH|NAME|NORESIZE|'.
               'SCROLLING|SRC|TITLE|WIDTH|ONREADYSTATECHANGE',
 'FRAMESET',   'BORDER|BORDERCOLOR|CLASS|COLS|FRAMEBORDER|FRAMESPACING|'.
               'ID|LANG|LANGUAGE|ROWS|TITLE',
 'HEAD',       'CLASS|ID|TITLE',
 'H1',         'ALIGN|'.$msTextAttrs,
 'H2',         'ALIGN|'.$msTextAttrs,
 'H3',         'ALIGN|'.$msTextAttrs,
 'H4',         'ALIGN|'.$msTextAttrs,
 'H5',         'ALIGN|'.$msTextAttrs,
 'H6',         'ALIGN|'.$msTextAttrs,
 'HR',         'ALIGN|CLASS|COLOR|ID|LANG|LANGUAGE|NOSHADE|SIZE|SRC|STYLE|'.
               'TITLE|WIDTH|'.$msFullEvents,
 'HTML',       'TITLE',
 'I',          $msTextAttrs,
 'IFRAME',     'ALIGN|BORDER|BORDERCOLOR|CLASS|DATAFLD|DATASRC|FRAMEBORDER|'.
               'FRAMESPACING|HEIGHT|HSPACE|ID|LANG|LANGUAGE|MARGINHEIGHT|'.
               'MARGINWIDTH|NAME|NORESIZE|SCROLLING|SRC|STYLE|TITLE|VSPACE|'.
               'WIDTH|ONREADYSTATECHANGE',
 'IMG',        'ALIGN|ALT|BORDER|CLASS|DATAFLD|DATASRC|DYNSRC|HEIGHT|HSPACE|'.
               'ID|ISMAP|LANG|LANGUAGE|LOOP|LOWSRC|NAME|SRC|STYLE|TITLE|'.
               'USEMAP|VSPACE|WIDTH|ONABORT|'.$msFullEvents,
 'INPUT',      'ACCESSKEY|CHECKED|CLASS|DISABLED|ID|LANG|LANGUAGE|MAXLENGTH|'.
               'NAME|READONLY|SIZE|SRC|STYLE|TABINDEX|TITLE|TYPE|VALUE|'.
               $msFullEvents,
 'ISINDEX',    'ACTION|PROMPT|HREF',
 'KBD',        $msTextAttrs,
 'LABEL',      'ACCESSKEY|CLASS|DATAFLD|DATAFORMATAS|DATASRC|FOR|ID|LANG|'.
               'LANGUAGE|STYLE|TITLE|'.$msEvents,
 'LI',         'CLASS|ID|LANG|LANGUAGE|STYLE|TITLE|TYPE|VALUE|'.$msEvents,
 'LINK',       'DISABLED|HREF|ID|REL|TITLE|TYPE',
 'LISTING',    $msTextAttrs,
 'MAP',        'CLASS|ID|LANG|NAME|STYLE|TITLE'.$msEvents,
 'MARQUEE',    'BEHAVIOR|BGCOLOR|CLASS|DATAFLD|DATAFORMATAS|DATASRC|'.
               'DIRECTION|HEIGHT|HSPACE|ID|LANG|LANGUAGE|LOOP|'.
               'SCROLLAMOUNT|SCROLLDELAY|STYLE|TITLE|TRUESPEED|VSPACE|WIDTH|'.
               $msFullEvents,
 'MENU',       'CLASS|ID|LANG|STYLE|TITLE|'.$msEvents,
 'META',       'CONTENT|HTTP-EQUIV|NAME|TITLE|URL',
 'NEXTID',     'TITLE',
 'NOBR',       'ID|STYLE|TITLE',
 'NOFRAMES',   'ID|STYLE|TITLE',
 'NOSCRIPT',   '',
 'OBJECT',     'ACCESSKEY|ALIGN|CLASS|CLASSID|CODE|CODEBASE|CODETYPE|DATA|'.
               'DATAFLD|DATASRC|HEIGHT|ID|LANG|LANGUAGE|NAME|STYLE|TABINDEX|'.
               'TITLE|TYPE|WIDTH|'.$msFullEvents,
 'OL',         'CLASS|ID|LANG|LANGUAGE|START|STYLE|TITLE|TYPE|'.$msEvents,
 'OPTION',     'CLASS|ID|LANG|LANGUAGE|SELECTED|TITLE|VALUE|ONSELECTSTART',
 'P',          'ALIGN|'.$msTextAttrs,
 'PARAM',      'DATAFLD|DATAFORMATAS|DATASRC|NAME|VALUE',
 'PLAINTEXT',  $msTextAttrs,
 'PRE',        $msTextAttrs,
 'S',          $msTextAttrs,
 'SAMP',       $msTextAttrs,
 'SCRIPT',     'CLASS|EVENT|FOR|ID|LANGUAGE|SRC|TITLE',
 'SELECT',     'ACCESSKEY|ALIGN|CLASS|DATAFLD|DATASRC|DISABLED|ID|LANG|'.
               'LANGUAGE|MULTIPLE|NAME|SIZE|STYLE|TABINDEX|TITLE|'.
               $msFullEvents,
 'SMALL',      $msTextAttrs,
 'SPAN',       'CLASS|DATAFLD|DATAFORMATAS|DATASRC|ID|LANG|LANGUAGE|STYLE|'.
               'TITLE|'.$msEvents,
 'STRIKE',     $msTextAttrs,
 'STRONG',     $msTextAttrs,
 'STYLE',      'DISABLED|TITLE|TYPE',
 'SUB',        $msTextAttrs,
 'SUP',        $msTextAttrs,
 'TABLE',      'ALIGN|BACKGROUND|BGCOLOR|BORDER|BORDERCOLOR|BORDERCOLORDARK|'.
               'BORDERCOLORLIGHT|CELLPADDING|CELLSPACING|CLASS|COLS|'.
               'DATAPAGESIZE|DATASRC|FRAME|HEIGHT|ID|LANG|LANGUAGE|RULES|'.
               'STYLE|TITLE|WIDTH|'.$msFullEvents,
 'TBODY',      'ALIGN|BGCOLOR|CLASS|ID|LANG|LANGUAGE|STYLE|TITLE|VALIGN'.
               $msEvents,
 'TD',         'ALIGN|BACKGROUND|BGCOLOR|BORDERCOLOR|BORDERCOLORDARK|'.
               'BORDERCOLORLIGHT|CLASS|COLSPAN|ID|LANG|LANGUAGE|NOWRAP|'.
               'ROWSPAN|STYLE|TITLE|VALIGN|'.$msFullEvents,
 'TEXTAREA',   'ACCESSKEY|ALIGN|CLASS|COLS|DATAFLD|DATASRC|DISABLED|'.
               'ID|LANG|LANGUAGE|NAME|READONLY|ROWS|STYLE|TABINDEX|TITLE|'.
               'WRAP|'.$msFullEvents,
 'TFOOT',      'ALIGN|BGCOLOR|CLASS|ID|LANG|LANGUAGE|STYLE|TITLE|VALIGN'.
               $msEvents,
 'TH',         'ALIGN|BACKGROUND|BGCOLOR|BORDERCOLOR|BORDERCOLORDARK|'.
               'BORDERCOLORLIGHT|CLASS|COLSPAN|ID|LANG|LANGUAGE|NOWRAP|'.
               'ROWSPAN|STYLE|TITLE|VALIGN|'.$msFullEvents,
 'THEAD',      'ALIGN|BGCOLOR|CLASS|ID|LANG|LANGUAGE|STYLE|TITLE|VALIGN'.
               $msEvents,
 'TITLE',      'ID|TITLE',
 'TR',         'ALIGN|BGCOLOR|BORDERCOLOR|BORDERCOLORLIGHT|'.
               'BORDERCOLORDARK|CLASS|ID|LANG|LANGUAGE|STYLE|TITLE|VALIGN|'.
               $msFullEvents,
 'TT',         $msTextAttrs,
 'U',          $msTextAttrs,
 'UL',         'CLASS|ID|LANG|LANGUAGE|STYLE|TITLE|TYPE|'.$msEvents,
 'VAR',        $msTextAttrs,
 'WBR',        'CLASS|ID|LANG|LANGUAGE|STYLE|TITLE',
 'XMP',        $msTextAttrs,
);
$msPaired   = 'BUTTON|COMMENT|COL|COLGROUP|FRAMESET|IFRAME|LABEL|LEGEND|'.
	      'MARQUEE|NOBR|NOFRAMES|NOSCRIPT|OBJECT|SPAN|TBODY|'.
	      'TFOOT|THEAD';

%mustFollow =
(
 'LH',         'UL|OL|DL',
 'OVERLAY',    'FIG',
 'HEAD',       'HTML',
 'BODY',       '/HEAD|NOFRAMES|/FRAMESET',
 'FRAMESET',   '/HEAD|/FRAME|/FRAMESET|/NOFRAMES|HTML',
 '/HTML',      '/BODY|/FRAMESET|/NOFRAMES',
 '/NOFRAMES',  '/BODY'
 );

%badTextContext =
(
 'HEAD',  'BODY, or TITLE perhaps',
 'UL',    'LI or LH',
 'OL',    'LI or LH',
 'DL',    'DT or DD',
 'TABLE', 'TD or TH',
 'TR',    'TD or TH'
);

%variable =
(
 'directory-index',		'index.html',
 'file-extensions',		'html, htm',
 'url-get',			'',
 'message-style',		'lint'
);

@options = ('d=s', 'e=s', 'f=s', 'stderr', 'help', 'i', 'l', 's', 't',
	    'todo', 'U',
	    'noglobals', 'pedantic', 'urlget=s', 'v', 'version', 'warnings',
	    'x=s');
# to suppress warnings with -w
$opt_warnings = $opt_pedantic = $opt_help = $opt_todo = $opt_version =
   $opt_i = $opt_t = $opt_u = $opt_v = $opt_noglobals = $opt_stderr = 0;
$name = '';

$exit_status = 0;

require 'find.pl';

die "$usage" unless @ARGV > 0;

# escape the `-' command-line switch (for stdin), so NGetOpt don't mess wi' it
grep(s/^-$/\tstdin\t/, @ARGV);

Getopt::Long::GetOptions(@options) || die "use -help switch to display usage statement\n";

# put back the `-' command-line switch, if it was there
grep(s/^\tstdin\t$/-/, @ARGV);

die "$versionString\n"	if $opt_v || $opt_version;
die "$usage"		if $opt_U || $opt_help;

&ReadDefaults();

# Read configuration
if ($opt_f)
{
   &ReadConfigFile($opt_f);
}
elsif (-f $USER_RCFILE)
{
   &ReadConfigFile($USER_RCFILE);
}
elsif (! $opt_noglobals && defined $SITE_RCFILE && -f $SITE_RCFILE)
{
   &ReadConfigFile($SITE_RCFILE);
}

# must do this after reading their config file to see a valid url-get
&PrintToDo()		if $opt_todo;

# pedantic command-line switch turns on all warnings except case checking
if ($opt_pedantic)
{
   foreach $warning (keys %enabled)
   {
      &enableWarning($warning, 1);
   }
   &enableWarning('lower-case', 0);
   &enableWarning('upper-case', 0);
   &enableWarning('bad-link', 0);
   &enableWarning('require-doctype', 0);
}

&AddExtension("\L$opt_x")             if $opt_x;
$variable{'message-style'} = 'short'  if $opt_s;
$variable{'message-style'} = 'terse'  if $opt_t;
$variable{'url-get'} = $opt_urlget    if $opt_urlget;
*WARNING = *STDERR                    if $opt_stderr;
&ListWarnings()		              if $opt_warnings;

($fileExtensions = $variable{'file-extensions'}) =~ s/,\s*/\|/g;

# WARNING file handle is default
select(WARNING);

$opt_l = 1                 if $ignore{'SYMLINKS'};

# -d to disable warnings
if ($opt_d)
{
   for (split(/,/,$opt_d))
   {
      &enableWarning($_, 0);
   }
}

# -e to enable warnings
if ($opt_e)
{
   for (split(/,/,$opt_e))
   {
      &enableWarning($_, 1) || next;
   }
}

# -i option to ignore case in element tags
if ($opt_i)
{
   $enabled{'lower-case'} = $enabled{'upper-case'} = 0;
}

if (defined $variable{'directory-index'})
{
   @dirIndices = split(/\s*,\s*/, $variable{'directory-index'});
}

$argc = int(@ARGV);
while (@ARGV > 0)
{
   $arg = shift(@ARGV);

   &CheckURL($arg), next if $arg =~ m!^(http|gopher|ftp)://!;

   &find($arg), next if -d $arg;

   if ($opt_l && -l $arg && $argc == 1)
   {
      warn "$PROGRAM: $arg is a symlink, but I'll check it anyway\n";
   }

   &WebLint($arg), next if (-f $arg && -r $arg) || $arg eq '-';

   print "$PROGRAM: could not read $arg: $!\n";
}

exit $exit_status;

#========================================================================
# Function:	WebLint
# Purpose:	This is the high-level interface to the checker.  It takes
#		a file and checks for fluff.
#========================================================================
sub WebLint
{
   local($filename,$relpath) = @_;
   local(@tags) = ();
   local($tagRE) = ('');
   local(@taglines) = ();
   local(@orphans) = ();
   local(@orphanlines) = ();
   local(%seenPage);
   local(%seenTag);
   local($lastTAG) = '';
   local(%whined);
   local(*PAGE);
   local($line) = ('');
   local($id, $ID);
   local($tag, $tagNum);
   local($closing);
   local($tail);
   local(%args);
   local($arg);
   local($rest);
   local($lastNonTag);
   local(@notSeen);
   local($seenMailtoLink) = (0);
   local($matched);
   local($matchedLine);
   local($novalue);
   local($heading);
   local($headingLine);
   local($commentline);
   local($_);


   if ($filename eq '-')
   {
      *PAGE = *STDIN;
      $filename = 'stdin';
   }
   else
   {
      return if defined $seenPage{$filename};
      if (-d $filename)
      {
	 print "$PROGRAM: $filename is a directory.\n";
	 $exit_status = 0;
	 return;
      }
      $seenPage{$filename}++;
      open(PAGE,"<$filename") || do
      {
	 print "$PROGRAM: could not read file $filename: $!\n";
	 $exit_status = 0;
	 return;
      };
      $filename = $relpath if defined $relpath;
   }

   undef $heading;
   $tagNum = 0;

 READLINE:
   while (<PAGE>)
   {
      $line .= $_;
      # $line =~ s/\n/ /g;

      while ($line =~ /</o)
      {
	 $tail = $'; #'
	 $lastNonTag = '';
	 if ($` !~ /^\s*$/o)
	 {
	    $lastNonTag = $`;

	    # check for illegal text context
	    if (defined $badTextContext{$tags[$#tags]})
	    {
	       &whine($., 'bad-text-context',$tags[$#tags],
		      $badTextContext{$tags[$#tags]});
	    }

	    $lnt = $lastNonTag;
	    while ($lnt =~ />/o)
	    {
	       $nl = $lnt = $';
	       $nl =~ s/[^\n]//go;
	       if ('PRE' =~ /^($tagRE)$/)
	       {
		  &whine($. - length($nl), 'meta-in-pre', '&gt;', '>');
	       }
	       else
	       {
		  &whine($. - length($nl), 'literal-metacharacter', '>', '&gt;');
	       }
	    }
	 }

	 #--------------------------------------------------------
	 #== SGML comment: <!-- ... blah blah ... -->
	 #--------------------------------------------------------
	 if ($tail =~ /^!--/o)
	 {

	    $commentline = $. unless defined $commentline;

	    # push lastNonTag onto word list for spell checking

	    $ct = $';
	    next READLINE unless $ct =~ /--\s*>/o;

	    undef $commentline;

	    $comment = $`;
	    $line = $';

	    # markup embedded in comment can confuse some (most? :-) browsers
	    &whine($., 'markup-in-comment') if $comment =~ /<\s*[^>]+>/o;
	    next;
	 }
	 undef $commentline;

	 next READLINE unless $tail =~ /^(\s*)([^>]*)>/o;


	 &whine($., 'leading-whitespace', $2) if $1 ne '';

         $line = $';
         ($tag = $2) =~ s/\n/ /go;
	 $id = $tag;

         &whine($., 'unknown-element', $id),next if $id =~ /^\s*$/o;

	 # push lastNonTag onto word list for spell checking

         undef $tail;
         undef $closing;

         #-- <!DOCTYPE ... > is ignored for now.
         $seenTag{'DOCTYPE'}=1,next if $id =~ /^!doctype/io;

         if (!$whined{'require-doctype'} && !$seenTag{'DOCTYPE'})
	 {
            &whine($., 'require-doctype');
            $whined{'require-doctype'} = 1;
	 }

	 $closing = 0;
         if ($id =~ m@^/@o)
         {
            $id =~ s@^/@@o;
	    $ID = "\U$id";
            $closing = 1;
         }

	 &CheckAttributes();

	 $TAG = ($closing ? '/' : '').$ID;
	 if (defined $mustFollow{$TAG})
	 {
	    $ok = 0;
	    foreach $pre (split(/\|/, $mustFollow{$TAG}))
	    {
	       ($ok=1),last if $pre eq $lastTAG;
	    }
	    if (!$ok || $lastNonTag !~ /^\s*$/o)
	    {
	       &whine($., 'must-follow', $TAG, $mustFollow{$TAG});
	    }
	 }

	 #-- catch empty container elements
	 if ($closing && $ID eq $lastTAG && $lastNonTag =~ /^\s*$/o
	     && $tagNums[$#tagNums] == ($tagNum - 1)
	     && $ID ne 'TEXTAREA' && $ID ne 'TD')
	 {
	    &whine($., 'empty-container', $ID);
	 }

	 #-- special case for empty optional container elements
	 if (!$closing && @tags > 0 && $ID eq $tags[$#tags] && $lastTAG eq $ID
	     && $ID =~ /^($maybePaired)$/
	     && $tagNums[$#tagNums] == ($tagNum - 1)
	     && $lastNonTag =~ /^\s*$/o
	     && $ID ne 'COL' && $ID ne 'COLGROUP')
	 {
	    pop @tags; # pop off the tag, don't care what it is
	    $tline = pop @taglines;
	    pop @tagNums;
	    &whine($tline, 'empty-container', $ID);
	    $tagRE = join('|',@tags);
	 }

         #-- whine about unrecognized element, and do no more checks ----
         if (!defined $validAttributes{$ID})
	 {
             if (defined $netscapeAttributes{$ID}
                 || defined $msAttributes{$ID})
             {
                 &whine($., 'extension-markup', ($closing ? "/$id" : "$id"));
             }
             else
             {
                 &whine($., 'unknown-element', ($closing ? "/$id" : "$id"));
             }
             next;
	 }

         if ($closing == 0 && defined $requiredAttributes{$ID})
         {
	    foreach $attr (split(/\|/,$requiredAttributes{$ID}))
	    {
	       unless (defined $args{$attr})
	       {
		  &whine($., 'required-attribute', $attr, $id);
	       }
	    }
         }
         elsif ($closing == 0 && $id =~ /^($expectArgsRE)$/io)
         {
            &whine($., 'expected-attribute', $id) unless defined %args;
         }

         #--------------------------------------------------------
         #== check case of tags
         #--------------------------------------------------------
         &whine($., 'upper-case', $id) if $id ne $ID;
         &whine($., 'lower-case', $id) if $id ne "\L$id";


         #--------------------------------------------------------
         #== if tag id is /foo, then strip slash, and mark as a closer
         #--------------------------------------------------------
         if ($closing)
         {
	    if ($ID !~ /^($pairElements)$/o)
	    {
	       &whine($., 'illegal-closing', $id);
	    }

            if ($ID eq 'A' && $lastNonTag =~ /^\s*here\s*$/io)
            {
               &whine($., 'here-anchor');
            }

	    if ($ID eq 'TITLE' && length($lastNonTag) > 64)
	    {
	       &whine($., 'title-length');
	    }

	    #-- end of HEAD, did we see a TITLE in the HEAD element? ----
	    &whine($., 'require-head') if $ID eq 'HEAD' && !$seenTag{'TITLE'};

	    #-- was there a <LINK REV=MADE HREF="mailto:.."> element in HEAD?
	    &whine($., 'mailto-link') if $ID eq 'HEAD' && $seenMailtoLink == 0;
         }
         else
         {
            #--------------------------------------------------------
            # do context checks.  Should really be a state machine.
            #--------------------------------------------------------

	    if (defined $physicalFontElements{$ID})
	    {
	       &whine($., 'physical-font', $ID, $physicalFontElements{$ID});
	    }

	    if ($ID =~ /^H[1-6]$/o && 'A' =~ /^($tagRE)$/)
	    {
	       &whine($., 'heading-in-anchor', $ID);
	    }

            if ($ID eq 'A' && defined $args{'HREF'})
            {
	       $target = $args{'HREF'};
               if ($target =~ /([^:]+):\/\/([^\/]+)(.*)$/o
		   || $target =~ /^(news|mailto):/o
		   || $target =~ /^\//o)
               {
               }
               else
               {
		  $target =~ s/#.*$//o;
		  if ($target !~ /^\s*$/o && ! -f $target && ! -d $target)
		  {
		     &whine($., 'bad-link', $target);
		  }
               }
            }

            if ($ID =~ /^H(\d)$/o)
	    {
               if (defined $heading && $1 - $heading > 1)
               {
	          &whine($., 'heading-order', $ID, $heading, $headingLine);
               }
               $heading     = $1;
               $headingLine = $.;
	    }

	    #-- check for mailto: LINK ------------------------------
	    if ($ID eq 'LINK' && defined $args{'REV'}
                && defined $args{'HREF'}
                && $args{'REV'} =~ /^made$/io
		&& $args{'HREF'} =~ /^mailto:/io)
	    {
	       $seenMailtoLink = 1;
	    }

	    if (defined $onceOnly{$ID})
	    {
	       &whine($., 'once-only', $ID, $seenTag{$ID}) if $seenTag{$ID};
	    }
            $seenTag{$ID} = $.;

            &whine($., 'body-no-head') if $ID eq 'BODY' && !$seenTag{'HEAD'};

            if ($ID ne 'HTML' && $ID ne '!DOCTYPE' && !$seenTag{'HTML'}
                && !$whined{'outer-html'})
            {
               &whine($., 'html-outer');
               $whined{'outer-html'} = 1;
            }

	    #-- check for illegally nested elements ---------------------
	    if ($ID =~ /^($nonNest)$/o && $ID =~ /^($tagRE)$/)
	    {
	       for ($i=$#tags; $tags[$i] ne $ID; --$i)
	       {
	       }
	       &whine($., 'nested-element', $ID, $taglines[$i]);
	    }

            unless (defined $validAttributes{$ID})
	    {
	       &whine($., 'unknown-element', $ID);
	    }

	    #--------------------------------------------------------
	    # check for tags which have a required context
	    #--------------------------------------------------------
	    if (defined $requiredContext{$ID})
	    {
	       $ok = 0;
	       foreach $context (split(/\|/, $requiredContext{$ID}))
	       {
		  ($ok=1),last if $context =~ /^($tagRE)$/;
	       }
	       unless ($ok)
	       {
                  &whine($., 'required-context', $ID, $requiredContext{$ID});
	       }
	    }

	    #--------------------------------------------------------
	    # check for tags which can only appear in the HEAD element
	    #--------------------------------------------------------
	    if ($ID =~ /^($headTagsRE)$/o && 'HEAD' !~ /^($tagRE)$/)
	    {
               &whine($., 'head-element', $ID);
	    }

	    if (! defined $okInHead{$ID} && 'HEAD' =~ /^($tagRE)$/)
	    {
               &whine($., 'non-head-element', $ID);
	    }

	    #--------------------------------------------------------
	    # check for tags which have been deprecated (now obsolete)
	    #--------------------------------------------------------
	    &whine($., 'obsolete', $ID) if $ID =~ /^($obsoleteTags)$/o;
         }

         #--------------------------------------------------------
         #== was tag of type <TAG> ... </TAG>?
         #== welcome to kludgeville, population seems to be on the increase!
         #--------------------------------------------------------
         if ($ID =~ /^($pairElements)$/o)
         {
	    if (!$closing && @tags > 0 && $ID eq $tags[$#tags] &&
		$ID =~ /^($maybePaired)$/o)
	    {
	       pop @tags;
	       pop @tagNums;
	       pop @taglines;
	       $tagRE = join('|',@tags);
	    }
	    if ($closing)
	    {
	       # trailing whitespace in content of container element
	       if ($lastNonTag =~ /\S\s+$/o && $ID =~ /^($cuddleContainers)$/o)
	       {
		  &whine($., 'container-whitespace', 'trailing', $ID);
	       }

	       #-- if we have a closing tag, and the tag(s) on top of the stack
	       #-- are optional closing tag elements, pop tag off the stack,
	       #-- unless it matches the current closing tag
	       if (@tags > 0 && $tags[$#tags] ne $ID
		   && $tags[$#tags] =~ /^($maybePaired)$/o
		   && $lastNonTag =~ /^\s*$/o
		   && $tagNums[$#tagNums] == ($tagNum - 1)
		   && $ID ne 'TD')
	       {
		  $tline = $taglines[$#taglines];
		  &whine($tline, 'empty-container', $tags[$#tags]);
	       }

	       while (@tags > 0 && $tags[$#tags] ne $ID
		      && $tags[$#tags] =~ /^($maybePaired)$/o)
	       {
		  pop @tags;
		  pop @tagNums;
		  pop @taglines;
	       }
	       $tagRE = join('|',@tags);
	    }
	    else
	    {
	       # leading whitespace in content of container element
	       if ($line =~ /^\s+/o && $ID =~ /^($cuddleContainers)$/o)
	       {
		  &whine($., 'container-whitespace', 'leading', $ID);
	       }
	    }

            if ($closing && $tags[$#tags] eq $ID)
            {
               &PopEndTag();
            }
            elsif ($closing && $tags[$#tags] ne $ID)
            {
	       #-- closing tag does not match opening tag on top of stack
	       if ($ID =~ /^($tagRE)$/)
	       {
		  # If we saw </HTML>, </HEAD>, or </BODY>, then we try
		  # and resolve anything inbetween on the tag stack
		  if ($ID =~ /^(HTML|HEAD|BODY)$/o)
		  {
		     while ($tags[$#tags] ne $ID)
		     {
			$ttag = pop @tags;
			pop @tagNums;
			$ttagline = pop @taglines;
			if ($ttag !~ /^($maybePaired)$/o)
			{
			   &whine($., 'unclosed-element', $ttag, $ttagline);
			}

			#-- does top of stack match top of orphans stack? --
			while (@orphans > 0 && @tags > 0
			       && $orphans[$#orphans] eq $tags[$#tags])
			{
			   pop @orphans;
			   pop @orphanlines;
			   pop @tags;
			   pop @tagNums;
			   pop @taglines;
			}
		     }

		     #-- pop off the HTML, HEAD, or BODY tag ------------
		     pop @tags;
		     pop @tagNums;
		     pop @taglines;
		     $tagRE = join('|',@tags);
		  }
		  else
		  {
		     #-- matched opening tag lower down on stack
		     push(@orphans, $ID);
		     push(@orphanlines, $.);
		  }
	       }
	       else
	       {
                  if ($ID =~ /^H[1-6]$/o && $tags[$#tags] =~ /^H[1-6]$/o)
                  {
		     &whine($., 'heading-mismatch', $tags[$#tags], $ID);
                     &PopEndTag();
                  }
		  else
		  {
		     &whine($., 'mis-match', $ID);
                  }
	       }
            }
            else
            {
               push(@tags,$ID);
               $tagRE = join('|',@tags);
               push(@tagNums,$tagNum);
               push(@taglines,$.);
            }
         }

         #--------------------------------------------------------
         #== inline images (IMG) should have an ALT argument :-)
         #--------------------------------------------------------
         &whine($., 'img-alt') if ($ID eq 'IMG'
				   && !defined $args{'ALT'}
				   && !$closing);

         #--------------------------------------------------------
         #== WIDTH & HEIGHT on inline images (IMG) can help browsers
         #--------------------------------------------------------
         &whine($., 'img-size') if ($ID eq 'IMG'
				   && !defined $args{'WIDTH'}
				   && !defined $args{'HEIGHT'}
				   && !$closing);

      } continue {
	 ++$tagNum;
         $lastTAG = $TAG;
      }
      $lastNonTag = $line;
   }
   close PAGE;

   if (defined $commentline)
   {
      &whine($commentline, 'unclosed-comment');
      return;
   }

   while (@tags > 0)
   {
      $tag = shift(@tags);
      shift(@tagNums);
      $line = shift(@taglines);
      if ($tag !~ /^($maybePaired)$/o)
      {
	 &whine($., 'unclosed-element', $tag, $line);
      }
   }

   for (@expectedTags)
   {
      # if we haven't seen TITLE but have seen HEAD
      # then we'll have already whined about the lack of a TITLE element
      next if $_ eq 'TITLE' && !$seenTag{$_} && $seenTag{'HEAD'};
      next if $_ eq 'BODY' && $seenTag{'FRAMESET'};
      push(@notSeen,$_) unless $seenTag{$_};
   }
   if (@notSeen > 0)
   {
      printf "%sexpected tag(s) not seen: @notSeen\n",
		      ($opt_s ? "" : "$filename(-): ");
      $exit_status = 1;
   }
}

#========================================================================
# Function:	CheckAttributes
# Purpose:	If the tag has attributes, check them for validity.
#========================================================================
sub CheckAttributes
{
   undef %args;

   if ($closing == 0 && $tag =~ m|^(\S+)\s+(.*)|)
   {
      ($id,$tail) = ($1,$2);
      $ID = "\U$id";

      # don't worry, or warn, about attributes of unknown elements
      return unless defined $validAttributes{$ID};

      $tail =~ s/\n/ /go;

      # check for odd number of quote characters
      ($quotes = $tail) =~ s/[^""]//go;
      &whine($., 'odd-quotes', $tag) if length($quotes) % 2 == 1;

      $novalue = 0;
      $valid = $validAttributes{$ID};
      while ($tail =~ /^\s*([^=\s]+)\s*=\s*(.*)$/o
	     # catch attributes like ISMAP for IMG, with no arg
	     || ($tail =~ /^\s*(\S+)(.*)/o && ($novalue = 1)))
      {
	 $arg = "\U$1";
	 $rest = $2;

	 &whine($., 'unexpected-open', $tag) if $arg =~ /</o;

	 if (defined $validAttributes{$ID}
             && $arg !~ /^($valid)$/i)
	 {
	    if (   (defined $netscapeAttributes{$ID}
                    && $arg =~ /^($netscapeAttributes{$ID})$/i)
                || (defined $msAttributes{$ID}
                    && $arg =~ /^($msAttributes{$ID})$/i))
	    {
	       &whine($., 'extension-attribute', $arg, $id);
	    }
	    else
	    {
	       &whine($., 'unknown-attribute', $id, $arg);
	    }
	 }

	 #-- catch repeated attributes.  for example:
	 #--     <IMG SRC="foo.gif" SRC="bar.gif">
	 if (defined $args{$arg})
	 {
	    &whine($., 'repeated-attribute', $arg, $id);
	 }

	 if ($novalue)
	 {
	    $args{$arg} = '';
	    $tail = $rest;
	 }
	 elsif ($rest =~ /^'([^'']+)'(.*)$/o)
         {
	    &whine($., 'attribute-delimiter', $arg, $ID);
            $args{$arg} = $1;
            $tail = $2;
         }
	 elsif ($rest =~ /^"([^""]*)"(.*)$/o
		|| $rest =~ /^'([^'']*)'(.*)$/o)
         {
            $args{$arg} = $1;
            $tail = $2;
         }
	 elsif ($rest =~ /^(\S+)(.*)$/o)
         {
            $attrValue = $1;
            $args{$arg} = $attrValue;
            $tail = $2;
            if ($attrValue =~ /[^-.A-Za-z0-9]/o)
            {
               &whine($., 'quote-attribute-value', $arg, $attrValue, $ID);
            }
         }
         else
         {
	    $args{$arg} = $rest;
	    $tail = '';
         }
	 $novalue = 0;
      }
      foreach $attr (keys %args)
      {
         if (defined $attributeFormat{$attr} &&
             $args{$attr} !~ /^($attributeFormat{$attr})$/i)
         {
            &whine($., 'attribute-format', $attr, $id, $args{$attr});
         }
      }
      &whine($., 'unexpected-open', $tag) if $tail =~ /</o;
   }
   else
   {
      if ($closing && $id =~ m|^(\S+)\s+(.*)|)
      {
	 &whine($., 'closing-attribute', $tag);
	 $id = $1;
      }
      $ID = "\U$id";
   }
}

#========================================================================
# Function:	whine
# Purpose:	Give a standard format whine:
#			filename(line #): <message>
#               The associative array `enabled' is used as a gating
#               function, to suppress or enable each warning.  Every
#               warning has an associated identifier, which is used to
#               refer to the warning, and as the index into the hash.
#========================================================================
sub whine
{
   local($line, $id, @argv) = @_;
   local($mstyle)	    = $variable{'message-style'};


   return unless $enabled{$id};
   @argv = @argv;
   $exit_status = 1;
   (print "$filename:$line:$id\n"), return             if $mstyle eq 'terse';
   (eval "print \"\$filename($line): $message{$id}\n\""), return if $mstyle eq 'lint';
   (eval "print \"line $line: $message{$id}\n\""), return if $mstyle eq 'short';

   die "Unknown message style `$mstyle'\n";
}

#========================================================================
# Function:	ReadConfigFile
# Purpose:	Read the specified configuration file. This is used to
#		the user's .weblintrc file, or the global system config
#		file, if the user doesn't have one.
#========================================================================
sub ReadConfigFile
{
   local($filename) = @_;
   local(*CONFIG);
   local($arglist);
   local($keyword, $value);
   local($_);


   open(CONFIG,"< $filename") || do
   {
      print WARNING "Unable to read config file `$filename': $!\n";
      return;
   };

   while (<CONFIG>)
   {
      chop;
      s/#.*$//;
      next if /^\s*$/o;

      #-- match keyword: process one or more argument -------------------
      if (/^\s*(enable|disable|extension|ignore)\s+(.*)$/io)
      {
	 $keyword = "\U$1";
	 $arglist = $2;
	 while ($arglist =~ /^\s*(\S+)/o)
	 {
	    $value = "\L$1";

	    &enableWarning($1, 1) if $keyword eq 'ENABLE';

	    &enableWarning($1, 0) if $keyword eq 'DISABLE';

	    $ignore{"\U$1"} = 1 if $keyword eq 'IGNORE';

	    &AddExtension("\L$1") if $keyword eq 'EXTENSION';

	    $arglist = $';
	 }
      }
      elsif (/^\s*set\s+(\S+)\s*=\s*(.*)/o)
      {
         # setting a weblint variable
         if (defined $variable{$1})
         {
            $variable{$1} = $2;
         }
         else
         {
            print WARNING "Unknown variable `$1' in configuration file\n";
         }
      }
      elsif (/^\s*use\s*global\s*weblintrc/o)
      {
	 if (-f $SITE_RCFILE)
	 {
	    &ReadConfigFile($SITE_RCFILE);
	 }
	 else
	 {
	    print WARNING "$PROGRAM: unable to read global config file\n";
	    next;
	 }
      }
      else
      {
	 print WARNING ("$PROGRAM: ignoring unknown sequence (\"$_\") ".
                       "in config file $filename\n");
      }
   }

   close CONFIG;
}

#========================================================================
# Function:	enableWarning
# Purpose:	Takes a warning identifier and an integer (boolean)
#		flag which specifies whether the warning should be
#		enabled.
#========================================================================
sub enableWarning
{
   local($id, $enabled) = @_;


   if (! defined $enabled{$id})
   {
      print WARNING "$PROGRAM: unknown warning identifier \"$id\"\n";
      return 0;
   }

   $enabled{$id} = $enabled;

   #
   # ensure consistency: if you just enabled upper-case,
   # then we should make sure that lower-case is disabled
   #
   $enabled{'lower-case'} = 0 if $id eq 'upper-case';
   $enabled{'upper-case'} = 0 if $id eq 'lower-case';
   $enabled{'upper-case'} = $enabled{'lower-case'} = 0 if $id eq 'mixed-case';

   return 1;
}

#========================================================================
# Function:	AddExtension
# Purpose:	Extend the HTML understood.  Currently supported extensions:
#			Netscape  - the netscape extensions proposed by
#                                   Netscape Communications, Inc.  See:
#			Microsoft - the extensions for Microsoft Internet
#				    Explorer
#               http://www.netscape.com/home/services_docs/html-extensions.html
#========================================================================
sub AddExtension
{
   local($extension) = @_;
   local(@extlist);
   local($element);

   if ($extension =~ /,/o)
   {
      @extlist = split(/\s*,\s*/, $extension);
      &AddExtension(shift @extlist) while @extlist > 0;
      return;
   }

   if (   $extension ne 'netscape'
       && $extension ne 'microsoft')
   {
      warn "$PROGRAM: unknown extension `$extension' -- ignoring.\n";
      return;
   }

   #---------------------------------------------------------------------
   # Microsoft extensions
   #---------------------------------------------------------------------
   if ($extension eq 'microsoft')
   {      
      #-- new element attributes for existing elements ---------------------
      foreach $element (keys %msAttributes)
      {
          $validAttributes{$element} = $msAttributes{$element};
      }

      $pairElements  .= '|'.$msPaired;
      $maybePaired   .= '|COL|COLGROUP';

      $attributeFormat{'LOOP'} = '\d+|INFINITE';
      $okInHead{'BGSOUND'} = 1;
      $requiredAttributes{'BGSOUND'} = 'SRC';
      $attributeFormat{'LEFTMARGIN'} = '\d+';
      $attributeFormat{'TOPMARGIN'} = '\d+';

      $requiredContext{'AREA'}  = 'MAP';
      $requiredAttributes{'MAP'}   = 'NAME';
      $requiredAttributes{'AREA'}  = 'COORDS';

      #-- MARQUEE attributes
      $attributeFormat{'BEHAVIOR'} = 'SCROLL|SLIDE|ALTERNATE';
      $attributeFormat{'DIRECTION'} = 'LEFT|RIGHT';
      $attributeFormat{'WIDTH'} = '\d+%?';
      $attributeFormat{'HEIGHT'} = '\d+%?';

      # attribute format check for attributes which take colors
      $attributeFormat{'ALINK'} = $attributeFormat{'VLINK'} =
      $attributeFormat{'LINK'} = $attributeFormat{'TEXT'} =
      $attributeFormat{'BGCOLOR'} =
      $attributeFormat{'COLOR'} = $attributeFormat{'BORDERCOLOR'} =
      $attributeFormat{'BORDERCOLORLIGHT'} = $colorRE;

      # LI TYPE= can take A, a, I, i, or 1
      $attributeFormat{'TYPE'} .= '|[AaIi1]';

      # the FRAME and RULES attributes for TABLE element
      $attributeFormat{'FRAME'} = 'VOID|ABOVE|BELOW|HSIDES|LHS|RHS|VSIDES|'.
	                           'BOX|BORDER';
      $attributeFormat{'RULES'} = 'NONE|GROUPS|ROWS|COLS|ALL';

      # START attribute for IMG element
      $attributeFormat{'START'} = 'FILEOPEN|MOUSEOVER';

      # VALUETYPE attribute for PARAM element (in an OBJECT)
      $attributeFormat{'VALUETYPE'} = 'DATA|REF|OBJECT';

      $requiredContext{'THEAD'} = 'TABLE';
      $requiredContext{'TBODY'} = 'TABLE';
      $requiredContext{'TFOOT'} = 'TABLE';
      $requiredContext{'COLGROUP'} = 'TABLE';
      $requiredContext{'COL'} = 'COLGROUP';
      $requiredContext{'PARAM'} = 'APPLET|OBJECT';

      # COMMENT, LISTING, PLAINTEXT, and XMP are valid elements for Microsoft
      $obsoleteTags = '';
   }

   #---------------------------------------------------------------------
   # Netscape extensions
   #---------------------------------------------------------------------

   if ($extension eq 'netscape')
   {
      #-- new element attributes for existing elements ---------------------
      foreach $element (keys %netscapeAttributes)
      {
          $validAttributes{$element} = $netscapeAttributes{$element};
      }

      #-- formats for new attributes ---------------------------------------

      $attributeFormat{'SIZE'} = '[-+]?\d+';
      $attributeFormat{'MARGINWIDTH'} = '\d+';
      $attributeFormat{'MARGINHEIGHT'} = '\d+';
      $attributeFormat{'SCROLLING'} = 'NO|YES|AUTO';
      $attributeFormat{'TYPE'} .= '|[AaIi1]|disc|square|circle';

      #-- attributes for EMBED element
      $attributeFormat{'TYPE'} .= '|.+';
      $attributeFormat{'PALETTE'} = 'FOREGROUND|BACKGROUND';

      #-- new elements -----------------------------------------------------

      $pairElements  .= '|'.$netscapePaired;
      $requiredContext{'AREA'}    = 'MAP';
      $requiredContext{'FRAME'}   = 'FRAMESET';
      $requiredContext{'KEYGEN'}  = 'FORM';
      $requiredAttributes{'MAP'}  = 'NAME';
      $requiredAttributes{'AREA'} = 'COORDS';

      # this should really be specific to ROWS and COLS in FRAMESET element<
      $attributeFormat{'ROWS'} =
	 $attributeFormat{'COLS'} = '\d+|(\d*[*%]?,)*\s*\d*[*%]?';

      # this is for TEXTAREA
      $attributeFormat{'WRAP'} .= '|SOFT|HARD';

      # attribute format check for attributes which take colors
      $attributeFormat{'ALIGN'} .= '|TEXTTOP|ABSMIDDLE|BASELINE|ABSBOTTOM';

      # BASE can take just a TARGET attribute, HREF not required therefore
      delete $requiredAttributes{'BASE'};

      $expectArgsRE .= '|FONT|BASE';

      $okInHead{'SCRIPT'} = 1;
   }
}

sub AddAttributes
{
   local($element,@attributes) = @_;
   local($attr);


   $attr = join('|', @attributes);
   if (defined $validAttributes{$element})
   {
      $validAttributes{$element} .= "|$attr";
   }
   else
   {
      $validAttributes{$element} = "$attr";
   }
}

#========================================================================
# Function:	ListWarnings()
# Purpose:	List all supported warnings, with identifier, and
#		whether the warning is enabled.
#========================================================================
sub ListWarnings
{
   local($id);
   local($message);


   foreach $id (sort keys %enabled)
   {
      ($message = $message{$id}) =~ s/\$argv\[\d+\]/.../g;
      $message =~ s/\\"/"/g;
      print WARNING "$id (", ($enabled{$id} ? "enabled" : "disabled"), ")\n";
      print WARNING "    $message\n\n";
   }
}

sub CheckURL
{
   local($url)		= @_;
   local($workfile)	= "$TMPDIR/$PROGRAM.$$";
   local($urlget)	= $variable{'url-get'};


   die "$PROGRAM: url-get variable is not defined -- ".
       "don't know how to get $url\n" unless defined $urlget;

   system("$urlget $url > $workfile");
   &WebLint($workfile, $url);
   unlink $workfile;
}

sub PrintToDo
{
   print STDERR "$todo";
   exit 0;
}

#========================================================================
# Function:	wanted
# Purpose:	This is called by &find() to determine whether a file
#               is wanted.  We're looking for files, with the filename
#               extension .html or .htm.
#========================================================================
sub wanted
{
   local($foundIndex);

   if (-d $_)
   {
      $foundIndex = 0;
      foreach $legalIndex (@dirIndices)
      {
         $foundIndex=1,last if -f "$_/$legalIndex";
      }
      if (! $foundIndex)
      {
         &whine("$arg/$_", 'directory-index', "@dirIndices");
      }
   }

   /\.($fileExtensions)$/o &&   # valid filename extensions: .html .htm
      -f $_ &&			# only looking for files
      (!$opt_l || !-l $_) &&	# ignore symlinks if -l given
      &WebLint($_,$name);	# check the file
}

sub PopEndTag
{
   $matched     = pop @tags;
   pop @tagNums;
   $matchedLine = pop @taglines;

   #-- does top of stack match top of orphans stack? --------
   while (@orphans > 0 && @tags > 0
	  && $orphans[$#orphans] eq $tags[$#tags])
   {
      &whine($., 'element-overlap', $orphans[$#orphans],
	     $orphanlines[$#orphanlines], $matched, $matchedLine);
      pop @orphans;
      pop @orphanlines;
      pop @tags;
      pop @tagNums;
      pop @taglines;
   }
   $tagRE = join('|',@tags);
}

#========================================================================
# Function:	PickTmpdir
# Purpose:	Pick a temporary working directory. If TMPDIR environment
#		variable is set, then we try that first.
#========================================================================
sub PickTmpdir
{
   local(@options) = @_;
   local($tmpdir);

   @options = ($ENV{'TMPDIR'}, @options) if defined $ENV{'TMPDIR'};
   foreach $tmpdir (@options)
   {
      return $tmpdir if -d $tmpdir && -w $tmpdir;
   }
   die "$PROGRAM: unable to find a temporary directory.\n",
       ' ' x (length($PROGRAM)+2), "tried: ",join(' ',@options),"\n";
}

#========================================================================
# Function:	ReadDefaults
# Purpose:	Read the built-in defaults.  These are stored at the end
#               of the script, after the __END__, and read from the
#               DATA filehandle.
#========================================================================
sub ReadDefaults
{
   local(@elements);


   while (<DATA>)
   {
      chop;
      s/^\s*//;
      next if /^$/;

      push(@elements, $_);

      next unless @elements == 3;

      ($id, $default, $message) = @elements;
      $enabled{$id} = ($default eq 'ENABLE');
      ($message{$id} = $message) =~ s/"/\\"/g;
      undef @elements;
   }
}

__END__
upper-case
	DISABLE
	tag <$argv[0]> is not in upper case.
lower-case
	DISABLE
	tag <$argv[0]> is not in lower case.
mixed-case
	ENABLE
	tag case is ignored
here-anchor
	ENABLE
	bad form to use `here' as an anchor!
require-head
	ENABLE
	no <TITLE> in HEAD element.
once-only
	ENABLE
	tag <$argv[0]> should only appear once.  I saw one on line $argv[1]!
body-no-head
	ENABLE
	<BODY> but no <HEAD>.
html-outer
	ENABLE
	outer tags should be <HTML> .. </HTML>.
head-element
	ENABLE
	<$argv[0]> can only appear in the HEAD element.
non-head-element
	ENABLE
	<$argv[0]> cannot appear in the HEAD element.
obsolete
	ENABLE
	<$argv[0]> is obsolete.
mis-match
	ENABLE
	unmatched </$argv[0]> (no matching <$argv[0]> seen).
img-alt
	ENABLE
	IMG does not have ALT text defined.
nested-element
	ENABLE
	<$argv[0]> cannot be nested -- </$argv[0]> not yet seen for <$argv[0]> on line $argv[1].
mailto-link
	DISABLE
	did not see <LINK REV=MADE HREF="mailto..."> in HEAD.
element-overlap
	ENABLE
	</$argv[0]> on line $argv[1] seems to overlap <$argv[2]>, opened on line $argv[3].
unclosed-element
	ENABLE
	no closing </$argv[0]> seen for <$argv[0]> on line $argv[1].
markup-in-comment
	ENABLE
	markup embedded in a comment can confuse some browsers.
unknown-attribute
	ENABLE
	unknown attribute "$argv[1]" for element <$argv[0]>.
leading-whitespace
	ENABLE
	should not have whitespace between "<" and "$argv[0]>".
required-attribute
	ENABLE
	the $argv[0] attribute is required for the <$argv[1]> element.
unknown-element
	ENABLE
	unknown element <$argv[0]>.
odd-quotes
	ENABLE
	odd number of quotes in element <$argv[0]>.
heading-order
	ENABLE
	bad style - heading <$argv[0]> follows <H$argv[1]> on line $argv[2].
bad-link
	DISABLE
	target for anchor "$argv[0]" not found.
expected-attribute
	ENABLE
	expected an attribute for <$argv[0]>.
unexpected-open
	ENABLE
	unexpected < in <$argv[0]> -- potentially unclosed element.
required-context
	ENABLE
	illegal context for <$argv[0]> - must appear in <$argv[1]> element.
unclosed-comment
	ENABLE
	unclosed comment (comment should be: <!-- ... -->).
illegal-closing
	ENABLE
	element <$argv[0]> is not a container -- </$argv[0]> not legal.
extension-markup
	ENABLE
	<$argv[0]> is extended markup (use "-x <extension>" to allow this).
extension-attribute
	ENABLE
	attribute `$argv[0]' for <$argv[1]> is extended markup (use "-x <extension>" to allow this).
physical-font
	DISABLE
	<$argv[0]> is physical font markup -- use logical (such as $argv[1]).
repeated-attribute
	ENABLE
	attribute $argv[0] is repeated in element <$argv[1]>
must-follow
	ENABLE
	<$argv[0]> must immediately follow <$argv[1]>
empty-container
	ENABLE
	empty container element <$argv[0]>.
directory-index
	ENABLE
	directory does not have an index file ($argv[0])
closing-attribute
	ENABLE
	closing tag <$argv[0]> should not have any attributes specified.
attribute-delimiter
	ENABLE
	use of ' for attribute value delimiter is not supported by all browsers (attribute $argv[0] of tag $argv[1])
img-size
	DISABLE
	setting WIDTH and HEIGHT attributes on IMG tag can improve rendering performance on some browsers.
container-whitespace
	DISABLE
	$argv[0] whitespace in content of container element $argv[1]
require-doctype
	DISABLE
	first element was not DOCTYPE specification
literal-metacharacter
	ENABLE
	metacharacter '$argv[0]' should be represented as '$argv[1]'
heading-mismatch
	ENABLE
	malformed heading - open tag is <$argv[0]>, but closing is </$argv[1]>
bad-text-context
	ENABLE
	illegal context, <$argv[0]>, for text; should be in $argv[1].
attribute-format
	ENABLE
	illegal value for $argv[0] attribute of $argv[1] ($argv[2])
quote-attribute-value
	ENABLE
	value for attribute $argv[0] ($argv[1]) of element $argv[2] should be quoted (i.e. $argv[0]="$argv[1]")
meta-in-pre
	ENABLE
	you should use '$argv[0]' in place of '$argv[1]', even in a PRE element.
heading-in-anchor
	ENABLE
	<A> should be inside <$argv[0]>, not <$argv[0]> inside <A>.
title-length
	ENABLE
	The HTML spec. recommends the TITLE be no longer than 64 characters.

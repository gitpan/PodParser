#############################################################################
# Pod/Parser.pm -- package which defines a base class for parsing POD docs.
#
# Based on Tom Christiansen's Pod::Text module
# (with extensive modifications).
#
# Copyright (C) 1996-1998 Tom Christiansen. All rights reserved.
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.
#############################################################################

package Pod::Parser;

$VERSION = 1.05;   ## Current version of this package
require  5.003;    ## requires this Perl version or later

#############################################################################

=head1 NAME

Pod::Parser - base class for creating POD filters and translators

=head1 SYNOPSIS

    use Pod::Parser;

    package MyParser;
    @ISA = qw(Pod::Parser);

    sub command { 
        my ($parser, $command, $paragraph) = @_;
        ## Interpret the command and its text; sample actions might be:
        if ($command eq 'head1') { ... }
        elsif ($command eq 'head2') { ... }
        ## ... other commands and their actions
        my $out_fh = $parser->output_handle();
        my $expansion = $parser->interpolate($paragraph);
        print $out_fh $expansion;
    }

    sub verbatim { 
        my ($parser, $paragraph) = @_;
        ## Format verbatim paragraph; sample actions might be:
        my $out_fh = $parser->output_handle();
        print $out_fh $paragraph;
    }

    sub textblock { 
        my ($parser, $paragraph) = @_;
        ## Translate/Format this block of text; sample actions might be:
        my $out_fh = $parser->output_handle();
        my $expansion = $parser->interpolate($paragraph);
        print $out_fh $expansion;
    }

    sub interior_sequence { 
        my ($parser, $seq_command, $seq_argument) = @_;
        ## Expand an interior sequence; sample actions might be:
        return "*$seq_argument*"     if ($seq_command = 'B');
        return "`$seq_argument'"     if ($seq_command = 'C');
        return "_${seq_argument}_'"  if ($seq_command = 'I');
        ## ... other sequence commands and their resulting text
    }

    package main;

    ## Create a parser object and have it parse file whose name was
    ## given on the command-line (use STDIN if no files were given).
    $parser = new MyParser();
    $parser->parse_from_filehandle(\*STDIN)  if (@ARGV == 0);
    for (@ARGV) { $parser->parse_from_file($_); }

=head1 REQUIRES

perl5.003, Pod::InputObjects, Exporter, FileHandle, Carp

=head1 EXPORTS

Nothing.

=head1 DESCRIPTION

B<Pod::Parser> is a base class for creating POD filters and translators.
It handles most of the effort involved with parsing the POD sections
from an input stream, leaving subclasses free to be concerned only with
performing the actual translation of text.

B<Pod::Parser> parses PODs, and makes method calls to handle the various
components of the POD. Subclasses of B<Pod::Parser> override these methods
to translate the POD into whatever output format they desire.

=head1 QUICK OVERVIEW

To create a POD filter for translating POD documentation into some other
format, you create a subclass of B<Pod::Parser> which typically overrides
just the base class implementation for the following methods:

=over 2

=item *

B<command()>

=item *

B<verbatim()>

=item *

B<textblock()>

=item *

B<interior_sequence()>

=back

You may also want to override the B<begin_input()> and B<end_input()>
methods for your subclass (to perform any needed per-file and/or
per-document initialization or cleanup).

If you need to perform any preprocesssing of input before it is parsed
you may want to override one or more of B<preprocess_line()> and/or
B<preprocess_paragraph()>.

Sometimes it may be necessary to make more than one pass over the input
files. If this is the case you have several options. You can make the
first pass using B<Pod::Parser> and override your methods to store the
intermediate results in memory somewhere for the B<end_pod()> method to
process. You could use B<Pod::Parser> for several passes with an
appropriate state variable to control the operation for each pass. If
your input source can't be reset to start at the beginning, you can
store it in some other structure as a string or an array and have that
structure implement a B<getline()> method (which is all that
B<parse_from_filehandle()> uses to read input).

Feel free to add any member data fields you need to keep track of things
like current font, indentation, horizontal or vertical position, or
whatever else you like. Be sure to read L<"PRIVATE METHODS AND DATA">
to avoid name collisions.

For the most part, the B<Pod::Parser> base class should be able to
do most of the input parsing for you and leave you free to worry about
how to intepret the commands and translate the result.

=cut

#############################################################################

use vars qw($VERSION @ISA);
use strict;
#use diagnostics;
use Pod::InputObjects;
use Carp;
use Exporter;
use FileHandle;
@ISA = qw(Exporter);

#############################################################################

=head1 RECOMMENDED SUBROUTINE/METHOD OVERRIDES

B<Pod::Parser> provides several methods which most subclasses will probably
want to override. These methods are as follows:

=cut

##---------------------------------------------------------------------------

=head1 B<command()>

            $parser->command($cmd,$text,$pod_para);

This method should be overridden by subclasses to take the appropriate
action when a POD command paragraph (denoted by a line beginning with
"=") is encountered. When such a POD directive is seen in the input,
this method is called and is passed the command name C<$cmd>, and the
remainder of the text paragraph C<$text>, which appears immediately after
the command name. The C<$pod_para> argument is a reference to a 
C<Pod::Paragraph> object which contains further information about the
paragraph command. Please see L<Pod::InputObjects> for details if
you need to access this additional information.

B<Note> that this method I<is> called for C<=pod> paragraphs.

The base class implementation of this method simply treats the raw POD
command as normal block of paragraph text (invoking the B<textblock()>
method with the command paragraph).

=cut

sub command {
    my ($self, $cmd, $text, $pod_para)  = @_;
    ## Just treat this like a textblock
    $self->textblock($pod_para->raw_text());
}

##---------------------------------------------------------------------------

=head1 B<verbatim()>

            $parser->verbatim($text);


This method may be overridden by subclasses to take the appropriate
action when a block of verbatim text is encountered. It is passed the
text block C<$text> as a parameter.

The base class implementation of this method simply prints the textblock
(unmodified) to the output filehandle.

=cut

sub verbatim {
    my ($self, $text) = @_;
    my $out_fh = $self->{_OUTPUT};
    print $out_fh $text;
}

##---------------------------------------------------------------------------

=head1 B<textblock()>

            $parser->textblock($text);


This method may be overridden by subclasses to take the appropriate
action when a normal block of POD text is encountered (although the base
class method will usually do what you want). It is passed the text block
C<$text> as a parameter.

In order to process interior sequences, subclasses implementations of
this method will probably want invoke the B<interpolate()> method,
passing it the text block C<$text> as a parameter and then perform any
desired processing upon the returned result.

The base class implementation of this method simply prints the text block
as it occurred in the input stream).

=cut

sub textblock {
    my ($self, $text) = @_;
    my $out_fh = $self->{_OUTPUT};
    print $out_fh $self->interpolate($text);
}

##---------------------------------------------------------------------------

=head1 B<interior_sequence()>

            $parser->interior_sequence($seq_cmd,$seq_arg,$pod_seq);


This method should be overridden by subclasses to take the appropriate
action when an interior sequence is encountered. An interior sequence is
an embedded command within a block of text which appears as a command
name (usually a single uppercase character) followed immediately by a
string of text which is enclosed in angle brackets. This method is
passed the sequence command C<$seq_cmd> and the corresponding text
C<$seq_arg>. It is invoked by the B<interpolate()> method for each interior
sequence that occurs in the string that it is passed. It should return
the desired text string to be used in place of the interior sequence.
The C<$pod_seq> argument is a reference to a C<Pod::InteriorSequence>
object which contains further information about the interior sequence.
Please see L<Pod::InputObjects> for details if you need to access this
additional information.

Subclass implementations of this method may wish to invoke the the
B<sequence_commands()> method to examine the set of interior sequence
commands that are in the middle of being processed (there might be
several such sequence commands if nested interior sequences appear in
the input). See L<"sequence_commands()">.

The base class implementation of the B<interior_sequence()> method simply
returns the raw text of the of the interior sequence (as it occurred in
the input) to the caller.

=cut

sub interior_sequence {
    my ($self, $seq_cmd, $seq_arg, $pod_seq) = @_;
    ## Just return the raw text of the interior sequence
    return  $pod_seq->raw_text();
}

#############################################################################

=head1 OPTIONAL SUBROUTINE/METHOD OVERRIDES

B<Pod::Parser> provides several methods which subclasses may want to override
to perform any special pre/post-processing. These methods do I<not> have to
be overridden, but it may be useful for subclasses to take advantage of them.

=cut

##---------------------------------------------------------------------------

=head1 B<new()>

            my $parser = Pod::Parser->new();

This is the constructor for B<Pod::Parser> and its subclasses. You
I<do not> need to override this method! It is capable of constructing
subclass objects as well as base class objects, provided you use
any of the following constructor invocation styles:

    my $parser1 = MyParser->new();
    my $parser2 = new MyParser();
    my $parser3 = $parser2->new();

where C<MyParser> is some subclass of B<Pod::Parser>.

Using the syntax C<MyParser::new()> to invoke the constructor is I<not>
recommended, but if you insist on being able to do this, then the
subclass I<will> need to override the B<new()> constructor method. If
you do override the constructor, you I<must> be sure to invoke the
B<initialize()> method of the newly blessed object.

Using any of the above invocations, the first argument to the
constructor is always the corresponding package name (or object
reference). No other arguments are required, but if desired, an
associative array (or hash-table) my be passed to the B<new()>
constructor, as in:

    my $parser1 = MyParser->new( MYDATA => $value1, MOREDATA => $value2 );
    my $parser2 = new MyParser( -myflag => 1 );

All arguments passed to the B<new()> constructor will be treated as
key/value pairs in a hash-table. The newly constructed object will be
initialized by copying the contents of the given hash-table (which may
have been empty). The B<new()> constructor for this class and all of its
subclasses returns a blessed reference to the initialized object (hash-table).

=cut

sub new {
    ## Determine if we were called via an object-ref or a classname
    my $this = shift;
    my $class = ref($this) || $this;
    ## Any remaining arguments are treated as initial values for the
    ## hash that is used to represent this object.
    my %params = @_;
    my $self = { %params };
    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    $self->initialize();
    return $self;
}

##---------------------------------------------------------------------------

=head1 B<initialize()>

            $parser->initialize();


This method performs any necessary object initialization. It takes no
arguments (other than the object instance of course, which is typically
copied to a local variable named C<$self>). If subclasses override this
method then they I<must> be sure to invoke C<$self-E<gt>SUPER::initialize()>.

=cut

sub initialize {
    #my $self = shift;
    #return;
}

##---------------------------------------------------------------------------

=head1 B<begin_pod()>

            $parser->begin_pod();


This method is invoked at the beginning of processing for each POD
document that is encountered in the input. Subclasses should override
this method to perform any per-document initialization.

=cut

sub begin_pod {
    #my $self = shift;
    #return;
}

##---------------------------------------------------------------------------

=head1 B<begin_input()>

            $parser->begin_input();


This method is invoked by B<parse_from_filehandle()> immediately I<before>
processing input from a filehandle. The base class implementation does
nothing, however, subclasses may override it to perform any per-file
initializations.

Note that if multiple files are parsed for a single POD document
(perhaps the result of some future C<=include> directive) this method
is invoked for every file that is parsed. If you wish to perform certain
initializations once per document, then you should use B<begin_pod()>.

=cut

sub begin_input {
    #my $self = shift;
    #return;
}

##---------------------------------------------------------------------------

=head1 B<end_input()>

            $parser->end_input();


This method is invoked by B<parse_from_filehandle()> immediately I<after>
processing input from a filehandle. The base class implementation does
nothing, however, subclasses may override it to perform any per-file
cleanup actions.

Please note that if multiple files are parsed for a single POD document
(perhaps the result of some kind of C<=include> directive) this method
is invoked for every file that is parsed. If you wish to perform certain
cleanup actions once per document, then you should use B<end_pod()>.

=cut

sub end_input {
    #my $self = shift;
    #return;
}

##---------------------------------------------------------------------------

=head1 B<end_pod()>

            $parser->end_pod();


This method is invoked at the end of processing for each POD document
that is encountered in the input. Subclasses should override this method
to perform any per-document finalization.

=cut

sub end_pod {
    #my $self = shift;
    #return;
}

##---------------------------------------------------------------------------

=head1 B<preprocess_line()>

          $textline = $parser->preprocess_line($text);


This methods should be overridden by subclasses that wish to perform any
kind of preprocessing for each I<line> of input (I<before> it has been
determined whether or not it is part of a POD paragraph). The parameter
C<$text> is the input line and the value returned should correspond to
the new text to use in its place. If the empty string or an undefined
value is returned then no further process will be performed for this
line. If desired, this method can call the B<parse_paragraph()> method
directly with any preprocessed text and return an empty string (to
indicate that no further processing is needed).

Please note that the B<preprocess_line()> method is invoked I<before>
the B<preprocess_paragraph()> method. After all (possibly preprocessed)
lines in a paragraph have been assembled together and it has been
determined that the paragraph is part of the POD documentation from one
of the selected sections, then B<preprocess_paragraph()> is invoked.

The base class implementation of this method returns the given text.

=cut

sub preprocess_line {
    my ($self, $text) = @_;
    return  $text;
}

##---------------------------------------------------------------------------

=head1 B<preprocess_paragraph()>

            $textblock = $parser->preprocess_paragraph($text);


This method should be overridden by subclasses that wish to perform any
kind of preprocessing for each block (paragraph) of POD documentation
that appears in the input stream. The parameter C<$text> is the POD
paragraph from the input file and the value returned should correspond
to the new text to use in its place. If the empty string is returned or
an undefined value is returned, then the given C<$text> is ignored (not
processed).

This method is invoked by B<parse_paragraph()>. After it returns,
B<parse_paragraph()> examines the current cutting state (which is
returned by C<$self-E<gt>cutting()>). If it evaluates to false then
input text (including the given C<$text>) is cut (not processed) until
the next POD directive is encountered.

Please note that the B<preprocess_line()> method is invoked I<before>
the B<preprocess_paragraph()> method. After all (possibly preprocessed)
lines in a paragraph have been assembled together and it has been
determined that the paragraph is part of the POD documentation from one
of the selected sections, then B<preprocess_paragraph()> is invoked.

The base class implementation of this method returns the given text.

=cut

sub preprocess_paragraph {
    my ($self, $text) = @_;
    return  $text;
}

#############################################################################

=head1 METHODS FOR PARSING AND PROCESSING

B<Pod::Parser> provides several methods to process input text. These
methods typically won't need to be overridden, but subclasses may want
to invoke them to exploit their functionality.

=cut

##---------------------------------------------------------------------------

=head1 B<interpolate()>

            $textblock = $parser->interpolate($text,$end_re);


This method translates all text (including any embedded interior sequences)
in the given text string C<$text> and returns the interpolated result. If
a second argument is given, then it is must be a regular expression which,
when matched in the text, indicates when to quit interpolating the string.

B<interpolate()> merely invokes a private method to recursively expand
nested interior sequences in bottom-up order (innermost sequences are
expanded first). Unless there is a need to expand nested sequences in
some alternate order, this method should probably I<not> be overridden by
subclasses.

=cut

sub interpolate {
    my($self, $text, $end_re) = @_;
    return  $self->_interpolate_bottom_up($text, $end_re);
}

##---------------------------------------------------------------------------

=head1 B<parse_paragraph()>

            $parser->parse_paragraph($text);


This method takes the text of a POD paragraph to be processed and
invokes the appropriate method (one of B<command()>, B<verbatim()>,
or B<textblock()>).

This method does I<not> usually need to be overridden by subclasses.

=cut

sub parse_paragraph {
    my ($self, $text) = @_;
    my $input_top = $self->{_TOP_STREAM};
    local $_;

    ## This is the end of a non-empty paragraph
    ## Ignore up until next POD directive if we are cutting
    if ($self->{_CUTTING}) {
       return  unless ($text =~ /^=/);
       $self->{_CUTTING} = 0;
    }

    ## Now we know this is block of text in a POD section!

    ##-----------------------------------------------------------------
    ## This is a hook (hack ;-) for Pod::Select to do its thing without
    ## having to override methods, but also without Pod::Parser assuming
    ## $self is an instance of Pod::Select (if the _SELECTED_SECTIONS
    ## field exists then we assume there is an is_selected() method for
    ## us to invoke (calling $self->can('is_selected') could verify this
    ## but that is more overhead than I want to incur)
    ##-----------------------------------------------------------------

    ## Ignore this block if it isnt in one of the selected sections
    if (exists $self->{_SELECTED_SECTIONS}) {
        $self->is_selected($text)  or  return ($self->{_CUTTING} = 1);
    }

    ## Perform any desired preprocessing and re-check the "cutting" state
    $text = $self->preprocess_paragraph($text);
    return 1  if ((! defined $text) || ($text eq "") || ($self->{_CUTTING}));

    ## Look for one of the three types of paragraphs
    my ($pfx, $cmd, $arg, $sep) = ('', '', '', '');
    my $pod_para = undef;
    if ($text =~ /^(={1,2})(?=\S)/) {
        ## Looks like a command paragraph. Capture the command prefix used
        ## ("=" or "=="), as well as the command-name, its paragraph text,
        ## and whatever sequence of characters was used to separate them
        $pfx = $1;
        $_ = substr($text, length $pfx);
        $sep = /(\s+)(?=\S)/ ? $1 : '';
        ($cmd, $text) = split(" ", $_, 2);
        ## If this is a "cut" directive then we dont need to do anything
        ## except return to "cutting" mode.
        if ($cmd eq 'cut') {
           $self->{_CUTTING} = 1;
           return;
        }
        ## Save the attributes indicating how the command was specified.
        $pod_para = new Pod::Paragraph(
              -name      => $cmd,
              -text      => $text,
              -prefix    => $pfx,
              -separator => $sep
        );
    }
    $pod_para = new Pod::Paragraph(-text => $text)  unless (defined $pod_para);
    # ## Invoke appropriate callbacks
    # if (exists $self->{_CALLBACKS}) {
    #    ## Look through the callback list, invoke callbacks,
    #    ## then see if we need to do the default actions
    #    ## (invoke_callbacks will return true if we do).
    #    return  1  unless $self->invoke_callbacks($cmd, $text, $pod_para);
    # }
    if ($cmd ne '') {
        ## A command paragraph
        $self->command($cmd, $text, $pod_para);
    }
    elsif ($text =~ /^\s+/) {
        ## Indented text - must be a verbatim paragraph
        $self->verbatim($text);
    }
    else {
        ## Looks like an ordinary block of text
        $self->textblock($text);
    }
    return  1;
}

##---------------------------------------------------------------------------

=head1 B<parse_from_filehandle()>

            $parser->parse_from_filehandle($in_fh,$out_fh);


This method takes an input filehandle (which is assumed to already be
opened for reading) and reads the entire input stream looking for blocks
(paragraphs) of POD documentation to be processed. If no first argument
is given the default input filehandle C<STDIN> is used.

The C<$in_fh> parameter may be any object that provides a B<getline()>
method to retrieve a single line of input text (hence, an appropriate
wrapper object could be used to parse PODs from a single string or an
array of strings).

Using C<$in_fh-E<gt>getline()>, input is read line-by-line and assembled
into paragraphs or "blocks" (which are separated by lines containing
nothing but whitespace). For each block of POD documentation
encountered it will call the B<parse_paragraph()> method.

If a second argument is given then it should correspond to a filehandle where
output should be sent (otherwise the default output filehandle is
C<STDOUT> if no output filehandle is currently in use).

B<NOTE:> For performance reasons, this method caches the input stream at
the top of the stack in a local variable. Any attempts by clients to
change the stack contents during processing when in the midst executing
of this method I<will not affect> the input stream used by the current
invocation of this method.

This method does I<not> usually need to be overridden by subclasses.

=cut

sub parse_from_filehandle {
    my ($self, $in_fh, $out_fh) = @_;
    local $_;

    ## Put this stream at the top of the stack and do beginning-of-input
    ## processing. NOTE that $in_fh might be reset during this process.
    my $input_top = $self->_push_input_stream($in_fh, $out_fh);

    my $textline  = '';
    my $paragraph = '';
    while ($textline = $input_top->getline()) {
        $textline = $self->preprocess_line($textline);
        next  unless ((defined $textline)  &&  ($textline ne ''));

        if (($paragraph eq '') && ($textline =~ /^==/)) {
            ## '==' denotes a one-line command paragraph
            $paragraph = $textline;
            $textline  = '';
        } else {
            ## Append this line to the current paragraph
            $paragraph .= $textline;
        }

        ## See of this line is blank and ends the current paragraph.
        ## If it isnt, then keep iterating until it is.
        next unless (($textline =~ /^\s*$/) && ($paragraph ne ''));

        ## Now process the paragraph
        $self->parse_paragraph($paragraph);
        $paragraph = '';
    }
    ## Dont forget about the last paragraph in the file
    $self->parse_paragraph($paragraph)  unless ($paragraph eq '');

    ## Now pop the input stream off the top of the input stack.
    $input_top = $self->_pop_input_stream();
}

##---------------------------------------------------------------------------

=head1 B<parse_from_file()>

            $parser->parse_from_file($filename,$outfile);


This method takes a filename and does the following:

=over 2

=item *

opens the input and output files for reading
(creating the appropriate filehandles)

=item *

invokes the B<parse_from_filehandle()> method passing it the
corresponding input and output filehandles.

=item *

closes the input and output files.

=back

If the special input filename "-" or "<&STDIN" is given then the STDIN
filehandle is used for input (and no open or close is performed). If no
input filename is specified then "-" is implied.

If a second argument is given then it should be the name of the desired
output file. If the special output filename "-" or ">&STDOUT" is given
then the STDOUT filehandle is used for output (and no open or close is
performed). If the special output filename ">&STDERR" is given then the
STDERR filehandle is used for output (and no open or close is
performed). If no output filehandle is currently in use and no output
filename is specified, then "-" is implied.

This method does I<not> usually need to be overridden by subclasses.

=cut

sub parse_from_file {
    my ($self, $infile, $outfile) = @_;
    my ($in_fh,  $out_fh)  = (undef, undef);
    my ($close_input, $close_output) = (0, 0);
    local $_;

    ## Is $infile a filename or a (possibly implied) filehandle
    $infile  = '-'  unless ((defined $infile)  && ($infile ne ''));
    if (($infile  eq '-') || ($infile =~ /^<&(STDIN|0)$/i)) {
        ## Not a filename, just a string implying STDIN
        $self->{_INFILE} = "<standard input>";
        $in_fh = \*STDIN;
    }
    elsif (ref $infile) {
        ## Must be a filehandle-ref (or else assume its a ref to an object
        ## that supports the common IO read operations).
        $self->{_INFILE} = ${$infile};
        $in_fh = $infile;
    }
    else {
        ## We have a filename, open it for reading
        $self->{_INFILE} = $infile;
        $in_fh = FileHandle->new("< $infile")  or
             croak "Can't open $infile for reading: $!\n";
        $close_input = 1;
    }

    ## NOTE: we need to be *very* careful when "defaulting" the output
    ## file. We only want to use a default if this is the beginning of
    ## the entire document (but *not* if this is an included file). We
    ## determine this by seeing the input stream stack has been set-up
    ## already
    ## 
    unless ((defined $outfile) && ($outfile ne '')) {
        (defined $self->{_TOP_STREAM}) && ($out_fh  = $self->{_OUTPUT})
                                       || ($outfile = '-');
    }
    ## Is $outfile a filename or a (possibly implied) filehandle
    if ((defined $outfile) && ($outfile ne '')) {
        if (($outfile  eq '-') || ($outfile =~ /^>&?(?:STDOUT|1)$/i)) {
            ## Not a filename, just a string implying STDOUT
            $self->{_OUTFILE} = "<standard output>";
            $out_fh  = \*STDOUT;
        }
        elsif ($outfile =~ /^>&(STDERR|2)$/i) {
            ## Not a filename, just a string implying STDERR
            $self->{_OUTFILE} = "<standard error>";
            $out_fh  = \*STDERR;
        }
        elsif (ref $outfile) {
            ## Must be a filehandle-ref (or else assume its a ref to an
            ## object that supports the common IO write operations).
            $self->{_OUTFILE} = ${$outfile};;
            $out_fh = $outfile;
        }
        else {
            ## We have a filename, open it for writing
            $self->{_OUTFILE} = $outfile;
            $out_fh = FileHandle->new("> $outfile")  or
                 croak "Can't open $outfile for writing: $!\n";
            $close_output = 1;
        }
    }

    ## Whew! That was a lot of work to set up reasonably/robust behavior
    ## in the case of a non-filename for reading and writing. Now we just
    ## have to parse the input and close the handles when we're finished.
    $self->parse_from_filehandle($in_fh, $out_fh);

    $close_input  and 
        close($in_fh) || croak "Can't close $infile after reading: $!\n";
    $close_output  and
        close($out_fh) || croak "Can't close $outfile after writing: $!\n";
}

#############################################################################

=head1 ACCESSOR METHODS

Clients of B<Pod::Parser> should use the following methods to access
instance data fields:

=cut

##---------------------------------------------------------------------------

=head1 B<cutting()>

            $boolean = $parser->cutting();


Returns the current C<cutting> state: a boolean-valued scalar which
evaluates to true if text from the input file is currently being "cut"
(meaning it is I<not> considered part of the POD document).

            $parser->cutting($boolean);


Sets the current C<cutting> state to the given value and returns the
result.

=cut

sub cutting {
   return (@_ > 1) ? ($_[0]->{_CUTTING} = $_[1]) : $_[0]->{_CUTTING};
}

##---------------------------------------------------------------------------

=head1 B<output_file()>

            $fname = $parser->output_file();


Returns the name of the output file being written.

=cut

sub output_file {
   return $_[0]->{_OUTFILE};
}

##---------------------------------------------------------------------------

=head1 B<output_handle()>

            $fhandle = $parser->output_handle();


Returns the output filehandle object.

=cut

sub output_handle {
   return $_[0]->{_OUTPUT};
}

##---------------------------------------------------------------------------

=head1 B<input_file()>

            $fname = $parser->input_file();


Returns the name of the input file being read.

=cut

sub input_file {
   return $_[0]->{_INFILE};
}

##---------------------------------------------------------------------------

=head1 B<input_handle()>

            $fhandle = $parser->input_handle();


Returns the current input filehandle object.

=cut

sub input_handle {
   return $_[0]->{_INPUT};
}

##---------------------------------------------------------------------------

=head1 B<total_lines()>

            $numlines = $parser->total_lines();


The total number of input lines read thus far. This includes I<all> lines,
regardless of whether or not they were part of the POD documentation.

=cut

sub total_lines {
   return $_[0]->{_LINES};
}

##---------------------------------------------------------------------------

=head1 B<input_streams()>

            $listref = $parser->input_streams();


Returns a reference to an array which corresponds to the stack of all
the input streams that are currently in the middle of being parsed.

While parsing an input stream, it is possible to invoke
B<parse_from_file()> or B<parse_from_filehandle()> to parse a new input
stream and then return to parsing the previous input stream. Each input
stream to be parsed is pushed onto the end of this input stack
before any of its input is read. The input stream that is currently
being parsed is always at the end (or top) of the input stack. When an
input stream has been exhausted, it is popped off the end of the
input stack.

Each element on this input stack is a reference to C<Pod::InputSource>
object. Please see L<Pod::InputObjects> for more details.

This method might be invoked when printing diagnostic messages, for example,
to obtain the name and line number of the all input files that are currently
being processed.

=cut

sub input_streams {
   return $_[0]->{_INPUT_STREAMS};
}

##---------------------------------------------------------------------------

=head1 B<top_stream()>

            $hashref = $parser->top_stream();


Returns a reference to the hash-table that represents the element
that is currently at the top (end) of the input stream stack
(see L<"input_streams()">). The return value will be the C<undef>
if the input stack is empty.

This method might be used when printing diagnostic messages, for example,
to obtain the name and line number of the current input file.

=cut

sub top_stream {
   return $_[0]->{_TOP_STREAM} || undef;
}

##---------------------------------------------------------------------------

=head1 B<sequence_commands()>

            $listref = $parser->sequence_commands();


Returns a reference to an array that corresponds to the list of interior
sequence commands that are currently in the middle of being processed.
The array will have multiple elements I<only> when in the middle of
processing nested interior sequences.

The current interior sequence command (the one currently being processes)
should always be at the top of this stack. Each element on this stack
is a reference to a C<Pod::InteriorSequence> object. Please see
L<Pod::InputObjects> for more details.

=cut

sub sequence_commands {
   return $_[0]->{_SEQUENCE_CMDS} || undef;
}

#############################################################################

=head1 PRIVATE METHODS AND DATA

B<Pod::Parser> makes use of several internal methods and data fields
which clients should not need to see or use. For the sake of avoiding
name collisions for client data and methods, these methods and fields
are briefly discussed here. Determned hackers may obtain further
information about them by reading the B<Pod::Parser> source code.

Private data fields are stored in the hash-object whose reference is
returned by the B<new()> constructor for this class. The names of all
private methods and data-fields used by B<Pod::Parser> begin with a
prefix of "_" and match the regular expression C</^_\w+$/>.

=cut


##---------------------------------------------------------------------------

=begin _PRIVATE_

=head1 B<_interpolate_bottom_up()>

            $textblock = $parser->_interpolate_bottom_up($text,$end_re);


This method implements the guts of B<interpolate()> and takes the same set
of arguments. Upon return, the C<$text> parameter I<will have been modified>
to contain only the un-processed portion of the given string (which will
I<not> contain any text matched by C<$end_re>). This method should probably
I<not> be overridden by subclasses.

=end _PRIVATE_

=cut

sub _interpolate_bottom_up {
    my $self = shift;
    my($text, $end_re) = @_;
    ## Set defaults for unspecified arguments
    $text   = ''   unless (defined $text);
    $end_re = '$'  unless ((defined $end_re) && ($end_re ne ''));
    local $_;
    my $result = '';
    ## Keep track of a stack of sequences currently "in progress"
    my $seq_stack = $self->{_SEQUENCE_CMDS};
    my ($seq_cmd, $seq_arg, $end) = ('', '', undef);
    my $pod_sequence = undef;
    ## Parse all sequences until end-of-string or we match the end-regex
    while (($text ne '')  &&  ($text =~ /^(.*?)(([A-Z])<|($end_re))/)) {
        ## Append text before the match to the result
        $result .= $1;
        ## See if we matched an interior sequence or an end-expression
        ($seq_cmd, $end) = ($3, $4);
        ## Only text after the match remains to be processed
        $text = substr($text, length($1) + length($2));
        ## Was this the end of the sequence
        if (! defined $seq_cmd) {
            last  if ($end_re eq '$');
            (! defined $end)  and  $end = "";
            ## If the sequence stack is empty, this cant be the end because
            ## we havent yet seen a proper beginning. Keep looking.
            next if ((@{$seq_stack} == 0) && ($result .= $end));
           
            ## The following is a *hack* to allow '->' and '=>' inside of
            ## C<...> sequences (but not '==>' or '-->')
            if (($end eq '>') && (@{$seq_stack} > 0)) {
                my $top_cmd = $seq_stack->[-1]->cmd_name();
                ## Exit the loop if this was the end of the sequence.
                last unless (($top_cmd eq 'C') && ($result =~ /[^-=][-=]$/));
                ## This was a "false-end" that was really '->' or '=>'
                ## so we need to keep looking.
                $result .= $end  and  next;
            }
        }
        ## At this point we have found an interior sequence,
        ## we need to obtain its argument
        $pod_sequence = new Pod::InteriorSequence(
                          -name => $seq_cmd,
                    );
        push(@{$seq_stack}, $pod_sequence);
        $seq_arg = $pod_sequence->text(
                         $self->_interpolate_bottom_up($text, '>')
                   );
        ## Now process the interior sequence
        $result .= $self->interior_sequence($seq_cmd, $seq_arg, $pod_sequence);
        pop(@{$seq_stack});
    }
    ## Handle whatever is left if we didnt match the ending regexp
    unless ((defined $end) && ($end_re ne '$')) {
        $result .= $text;
        $result .= "\n"  if (($end_re eq '$') && (chop($text) ne "\n"));
        $text = '';
    }
    ## Modify the input parameter to consume the text that was
    ## processed so far.
    $_[0] = $text;
    ## Return the processed-text
    return  $result;
}

##---------------------------------------------------------------------------

=begin _PRIVATE_

=head1 B<_push_input_stream()>

            $hashref = $parser->_push_input_stream($in_fh,$out_fh);


This method will push the given input stream on the input stack and
perform any necessary beginning-of-document or beginning-of-file
processing. The argument C<$in_fh> is the input stream filehandle to
push, and C<$out_fh> is the corresponding output filehandle to use (if
it is not given or is undefined, then the current output stream is used,
which defaults to standard output if it doesnt exist yet).

The value returned will be reference to the hash-table that represents
the new top of the input stream stack. I<Please Note> that it is
possible for this method to use default values for the input and output
file handles. If this happens, you will need to look at the C<INPUT>
and C<OUTPUT> instance data members to determine their new values.

=end _PRIVATE_

=cut

sub _push_input_stream {
    my ($self, $in_fh, $out_fh) = @_;

    ## Initialize stuff for the entire document if this is *not*
    ## an included file.
    ##
    ## NOTE: we need to be *very* careful when "defaulting" the output
    ## filehandle. We only want to use a default value if this is the
    ## beginning of the entire document (but *not* if this is an included
    ## file).
    unless (defined  $self->{_TOP_STREAM}) {
        $out_fh  = \*STDOUT  unless (defined $out_fh);
        $self->{_LINES}         = 0;   ## total lines read
        $self->{_CUTTING}       = 1;   ## current "cutting" state
        $self->{_SEQUENCE_CMDS} = [];  ## list of nested interior sequences
        $self->{_INPUT_STREAMS} = [];  ## stack of all input streams
    }

    ## Initialize input indicators
    $self->{_OUTFILE} = '<unknown>'  unless (defined  $self->{_OUTFILE});
    $self->{_OUTPUT}  = $out_fh      if (defined  $out_fh);
    $in_fh            = \*STDIN      unless (defined  $in_fh);
    $self->{_INFILE}  = '<unknown>'  unless (defined  $self->{_INFILE});
    $self->{_INPUT}   = $in_fh;
    my $input_stack   = $self->{_INPUT_STREAMS};
    my $input_top     = $self->{_TOP_STREAM}
                      = new Pod::InputSource(
                            -name        => $self->{_INFILE},
                            -handle      => $in_fh,
                            -lines       => 0,
                            -was_cutting => $self->{_CUTTING}
                        );
    push(@{$input_stack}, $input_top);

    ## Perform beginning-of-document and/or beginning-of-input processing
    $self->begin_pod()  if (@{$input_stack} == 1);
    $self->begin_input();

    return  $input_top;
}

##---------------------------------------------------------------------------

=begin _PRIVATE_

=head1 B<_pop_input_stream()>

            $hashref = $parser->_pop_input_stream();


This takes no arguments. It will perform any necessary end-of-file or
end-of-document processing and then pop the current input stream from
the top of the input stack.

The value returned will be reference to the hash-table that represents
the new top of the input stream stack.

=end _PRIVATE_

=cut

sub _pop_input_stream {
    my ($self) = @_;
    my $input_stack = $self->{_INPUT_STREAMS};

    ## Perform end-of-input and/or end-of-document processing
    $self->end_input()  if (@{$input_stack} > 0);
    $self->end_pod()    if (@{$input_stack} == 1);

    ## Restore cutting state to whatever it was before we started
    ## parsing this file.
    my $old_top = pop(@{$input_stack});
    $self->{_CUTTING} = $old_top->was_cutting();

    ## Dont to reset the input indicators
    my $input_top = undef;
    if (@{$input_stack} > 0) {
       $input_top = $self->{_TOP_STREAM} = $input_stack->[-1];
       $self->{_INFILE}  = $input_top->name();
       $self->{_INPUT}   = $input_top->handle();
    } else {
       delete $self->{_TOP_STREAM};
       delete $self->{_INPUT_STREAMS};
    }

    return  $input_top;
}

#############################################################################

=head1 SEE ALSO

See L<Pod::Select> and L<Pod::Callbacks>.

B<Pod::Select> is a subclass of B<Pod::Parser> which provides the ability
to selectively include and/or exclude sections of a POD document from being
translated based upon the current heading, subheading, subsubheading, etc.

B<Pod::Callbacks> is a subclass of B<Pod::Parser> which gives
its users the ability the employ I<callback functions> instead of, or in
addition to, overriding methods of the base class.

B<Pod::Select> and B<Pod::Callbacks> do not override any
methods nor do they define any new methods with the same name. Because
of this, they may I<both> be used (in combination) as a base class of
the same subclass in order to combine their functionality without
causing any namespace clashes due to multiple inheritance.

=head1 AUTHOR

Brad Appleton E<lt>bradapp@enteract.mot.comE<gt>

Based on code for B<Pod::Text> written by
Tom Christiansen E<lt>tchrist@mox.perl.comE<gt>

=cut

1;

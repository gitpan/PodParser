#############################################################################
# Pod/InputObjects.pm -- package which defines objects for input streams
# and paragraphs and commands when parsing POD docs.
#
# Copyright (C) 1996-1998 Tom Christiansen. All rights reserved.
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.
#############################################################################

package Pod::InputObjects;

$VERSION = 1.05;   ## Current version of this package
require  5.003;    ## requires this Perl version or later

#############################################################################

=head1 NAME

Pod::InputObjects - objects representing POD input streams, paragraphs, etc.

=head1 SYNOPSIS

    use Pod::InputObjects;

=head1 REQUIRES

perl5.003, Exporter, Carp

=head1 EXPORTS

Nothing.

=head1 DESCRIPTION

This module defines some basic input objects used by B<Pod::Parser> when
reading and parsing POD text from an input source. The following objects
are defined:

=over 4

=item B<Pod::InputSource>

An object corresponding to a source of POD input text. It is mostly a
wrapper around a filehandle or C<IO::Handle>-type object (or anything
that implements the C<getline()> method) which keeps track of some
additional information relevant to the parsing of PODs.

=item B<Pod::Paragraph>

An object corresponding to a paragraph of POD input text. It may be a
plain paragraph, a verbatim paragraph, or a command paragraph (see
L<perlpod>).

=item B<Pod::InteriorSequence>

An object corresponding to an interior sequence command from the POD
input text (see L<perlpod>).

=back

Each of these input objects are described in further detail in the
sections which follow.

=cut

#############################################################################

use vars qw($VERSION);
use strict;
#use diagnostics;
use Carp;

#############################################################################

package Pod::InputSource;

##---------------------------------------------------------------------------

=head1 B<Pod::InputSource>

This object corresponds to an input source or stream of POD
documentation. When parsing PODs, it is necessary to associate and store
certain context information with each input source. All of this
information is kept together with the stream itself in one of these
C<Pod::InputSource> objects. Each such object is merely a wrapper around
an C<IO::Handle> object of some kind (or at least something that
implements the C<getline()> method). They have the following
methods/attributes:

=over 4

=cut

##---------------------------------------------------------------------------

=item B<new()>

        my $pod_input1 = Pod::InputSource->new(-handle => $filehandle);
        my $pod_input2 = new Pod::InputSource(-handle => $filehandle,
                                              -name   => $name);
        my $pod_input3 = new Pod::InputSource(-handle => \*STDIN);
        my $pod_input4 = Pod::InputSource->new(-handle => \*STDIN,
                                               -name => "(STDIN)");

This is a class method that constructs a C<Pod::InputSource> object and
returns a reference to the new input source object. It takes one or more
keyword arguments in the form of a hash. The keyword C<-handle> is
required and designates the corresponding input handle. The keyword
C<-name> is optional and specifies the name associated with the input
handle (typically a file name).

=cut

sub new {
    ## Determine if we were called via an object-ref or a classname
    my $this = shift;
    my $class = ref($this) || $this;

    ## Any remaining arguments are treated as initial values for the
    ## hash that is used to represent this object. Note that we default
    ## certain values by specifying them *before* the arguments passed.
    ## If they are in the argument list, they will override the defaults.
    my $self = { -name => '(UNKNOWN)', -was_cutting => 0, -lines => 0, @_ };

    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    return $self;
}

##---------------------------------------------------------------------------

=item B<getline()>

        my $textline = $pod_input->getline();

This method behaves exactly like the C<getline()> function for
an C<IO::Handle> or C<FileHandle> object. See L<IO::Handle>
and L<FileHandle> for more details.

=cut

sub getline {
   if (wantarray) {
      my @lines = $_[0]->{'-handle'}->getline();
      $_[0]->{'-lines'} += scalar(@lines)  if (@lines > 0);
      return (@lines > 0) ? @lines : undef;
   } else {
      my $textline = $_[0]->{'-handle'}->getline();
      ++$_[0]->{'-lines'}  if (defined $textline);
      return $textline;
   }
}

##---------------------------------------------------------------------------

=item B<name()>

        my $filename = $pod_input->name();
        $pod_input->name($new_filename_to_use);

This method gets/sets the name of the input source (usually a filename).
If no argument is given, it returns a string containing the name of
the input source; otherwise it sets the name of the input source to the
contents of the given argument.

=cut

sub name {
   $_[0]->{'-name'} = $_[1]  if (@_ > 1);
   return $_[0]->{'-name'};
}

##---------------------------------------------------------------------------

=item B<handle()>

        my $handle = $pod_input->handle();

Returns a reference to the handle object from which input is read (the
one used to contructed this input source object).

=cut

sub handle {
   return $_[0]->{'-handle'};
}

##---------------------------------------------------------------------------

=item B<num_lines()>

        my $line_number = $pod_input->num_lines();

Returns the number of input lines read from input source object
(since the time it was contructed).

=cut

sub num_lines {
   return $_[0]->{'-lines'};
}

##---------------------------------------------------------------------------

=item B<was_cutting()>

        print "Yes.\n" if ($pod_input->was_cutting());

The value of the C<cutting> state (that the B<cutting()> method would
have returned) immediately before any input was read from this input
stream. After all input from this stream has been read, the C<cutting>
state is restored to this value.

=cut

sub was_cutting {
   $_[0]->{-was_cutting} = $_[1]  if (@_ > 1);
   return $_[0]->{-was_cutting};
}

##---------------------------------------------------------------------------

=back

=cut

#############################################################################

package Pod::Paragraph;

##---------------------------------------------------------------------------

=head1 B<Pod::Paragraph>

An object representing a paragraph of POD input text.
It has the following methods/attributes:

=over 4

=cut

##---------------------------------------------------------------------------

=item B<new()>

        my $pod_para1 = Pod::Paragraph->new(-text => $text);
        my $pod_para2 = Pod::Paragraph->new(-name => $cmd,
                                            -text => $text);
        my $pod_para3 = new Pod::Paragraph(-text => $text);
        my $pod_para2 = new Pod::Paragraph(-name => $cmd,
                                           -text => $text);

This is a class method that constructs a C<Pod::Paragraph> object and
returns a reference to the new paragraph object. It may be given one or
two keyword arguments. The C<-text> keyword indicates the corresponding
text of the POD paragraph. The C<-name> keyword indicates the name of
the corresponding POD command, such as C<head1> or C<item> (it should
I<not> contain the C<=> prefix); this is needed only if the POD
paragraph corresponds to a command paragraph.

=cut

sub new {
    ## Determine if we were called via an object-ref or a classname
    my $this = shift;
    my $class = ref($this) || $this;

    ## Any remaining arguments are treated as initial values for the
    ## hash that is used to represent this object. Note that we default
    ## certain values by specifying them *before* the arguments passed.
    ## If they are in the argument list, they will override the defaults.
    my $self = {
          -name      => undef,
          -text      => (@_ == 1) ? $_[0] : undef,
          -prefix    => '=',
          -separator => ' ',
          @_
    };

    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    return $self;
}

##---------------------------------------------------------------------------

=item B<cmd_name()>

        my $para_cmd = $pod_para->cmd_name();

If this paragraph is a command paragraph, then this method will return 
the name of the command (I<without> any leading C<=> prefix).

=cut

sub cmd_name {
   $_[0]->{'-name'} = $_[1]  if (@_ > 1);
   return $_[0]->{'-name'};
}

##---------------------------------------------------------------------------

=item B<text()>

        my $para_text = $pod_para->text();

This method will return the corresponding text of the paragraph.

=cut

sub text {
   $_[0]->{'-text'} = $_[1]  if (@_ > 1);
   return $_[0]->{'-text'};
}

##---------------------------------------------------------------------------

=item B<raw_text()>

        my $raw_pod_para = $pod_para->raw_text();

This method will return the I<raw> text of the POD paragraph, exactly
as it appeared in the input.

=cut

sub raw_text {
   return $_[0]->{'-text'}  unless (defined $_[0]->{'-name'});
   return $_[0]->{'-prefix'} . $_[0]->{'-name'} . 
          $_[0]->{'-separator'} . $_[0]->{'-text'};
}

##---------------------------------------------------------------------------

=item B<cmd_prefix()>

        my $prefix = $pod_para->cmd_prefix();

If this paragraph is a command paragraph, then this method will return 
the prefix used to denote the command (which should be the string "=").

=cut

sub cmd_prefix {
   return $_[0]->{'-prefix'};
}

##---------------------------------------------------------------------------

=item B<cmd_separator()>

        my $separator = $pod_para->cmd_separator();

If this paragraph is a command paragraph, then this method will return
the text used to separate the command name from the rest of the
paragraph (if any).

=cut

sub cmd_separator {
   return $_[0]->{'-separator'};
}

##---------------------------------------------------------------------------

=back

=cut

#############################################################################

package Pod::InteriorSequence;

##---------------------------------------------------------------------------

=head1 B<Pod::InteriorSequence>

An object representing a POD interior sequence command.
It has the following methods/attributes:

=over 4

=cut

##---------------------------------------------------------------------------

=item B<new()>

        my $pod_seq1 = Pod::InteriorSequence->new(-name => $cmd,
                                                  -text => $text);
        my $pod_seq2 = new Pod::InteriorSequence(-name => $cmd,
                                                 -text => $text);

This is a class method that constructs a C<Pod::InteriorSequence> object
and returns a reference to the new interior sequence object. It should
be given two keyword arguments.  The C<-text> keyword indicates the
corresponding text of the POD paragraph, The C<-name> keyword indicates
the name of the corresponding interior sequence command, such as C<I> or
C<B> or C<C>.

=cut

sub new {
    ## Determine if we were called via an object-ref or a classname
    my $this = shift;
    my $class = ref($this) || $this;

    ## Any remaining arguments are treated as initial values for the
    ## hash that is used to represent this object. Note that we default
    ## certain values by specifying them *before* the arguments passed.
    ## If they are in the argument list, they will override the defaults.
    my $self = {
          -name      => (@_ == 2) ? $_[0] : undef,
          -text      => (@_ == 2) ? $_[1] : undef,
          -ldelim    => '<',
          -rdelim    => '>',
          @_
    };

    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    return $self;
}

##---------------------------------------------------------------------------

=item B<cmd_name()>

        my $seq_cmd = $pod_seq->cmd_name();

The name of the interior sequence command.

=cut

sub cmd_name {
   $_[0]->{'-name'} = $_[1]  if (@_ > 1);
   return $_[0]->{'-name'};
}

##---------------------------------------------------------------------------

=item B<text()>

        my $seq_text = $pod_seq->text();

The text of the interior sequence (this is what the command will modify
or massage in some manner).

=cut

sub text {
   $_[0]->{'-text'} = $_[1]  if (@_ > 1);
   return $_[0]->{'-text'};
}       

=item B<list()>

        my $seq_ref  = $pod_seq->list();
      or
        my @seq_list = $pod_seq->list();

The list of things in the interior sequence (this is what the command will modify
or massage in some manner).

=cut

sub list
{
 my $o = shift;
 if (@_)
  {
   $o->{'-list'} = [@_];
  }
 return (wantarray) ? (@{$o->{'-list'}}) : $o->{'-list'};
}


##---------------------------------------------------------------------------

=item B<raw_text()>

        my $seq_raw_text = $pod_seq->raw_text();

This method will return the I<raw> text of the POD interior sequence,
exactly as it appeared in the input.

=cut

sub raw_text {
   return $_[0]->{'-name'} . $_[0]->{'-ldelim'} .
          $_[0]->{'-text'} . $_[0]->{'-rdelim'} ;
}

##---------------------------------------------------------------------------

=item B<left_delimiter()>

        my $ldelim = $pod_seq->left_delimiter();

The leftmost delimiter beginning the argument text to the interior
sequence (should be "<").

=cut

sub left_delimiter {
   return $_[0]->{'-ldelim'};
}

##---------------------------------------------------------------------------

=item B<right_delimiter()>

The rightmost delimiter beginning the argument text to the interior
sequence (should be ">").

=cut

sub right_delimiter {
   return $_[0]->{'-rdelim'};
}

##---------------------------------------------------------------------------

=back

=cut

#############################################################################

=head1 SEE ALSO

See L<Pod::Parser>, L<Pod::Select>, and L<Pod::Callbacks>.

=head1 AUTHOR

Brad Appleton E<lt>bradapp@enteract.mot.comE<gt>

=cut

1;

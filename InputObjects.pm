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

$VERSION = 1.06;   ## Current version of this package
require  5.004;    ## requires this Perl version or later

#############################################################################

=head1 NAME

Pod::InputObjects - objects representing POD input streams, paragraphs, etc.

=head1 SYNOPSIS

    use Pod::InputObjects;

=head1 REQUIRES

perl5.004, Exporter, Carp

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

=item B<Pod::ParseTree>

An object corresponding to a tree of parsed POD text. Each "node" in
a parse-tree (or I<ptree>) is either a text-string or a reference to
a B<Pod::InteriorSequence> object. The nodes appear in the parse-tree
in they order in which they were parsed from  left-to-right.

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
    my $self = { -name        => '(unknown)',
                 -handle      => undef,
                 -was_cutting => 0,
                 @_ };

    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    return $self;
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
   (@_ > 1)  and  $_[0]->{'-name'} = $_[1];
   return $_[0]->{'-name'};
}

## allow 'filename' as an alias for 'name'
*filename = \&name;

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

=item B<was_cutting()>

        print "Yes.\n" if ($pod_input->was_cutting());

The value of the C<cutting> state (that the B<cutting()> method would
have returned) immediately before any input was read from this input
stream. After all input from this stream has been read, the C<cutting>
state is restored to this value.

=cut

sub was_cutting {
   (@_ > 1)  and  $_[0]->{-was_cutting} = $_[1];
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
        my $pod_para4 = new Pod::Paragraph(-name => $cmd,
                                           -text => $text);
        my $pod_para5 = Pod::Paragraph->new(-name => $cmd,
                                            -text => $text,
                                            -file => $filename,
                                            -line => $line_number);

This is a class method that constructs a C<Pod::Paragraph> object and
returns a reference to the new paragraph object. It may be given one or
two keyword arguments. The C<-text> keyword indicates the corresponding
text of the POD paragraph. The C<-name> keyword indicates the name of
the corresponding POD command, such as C<head1> or C<item> (it should
I<not> contain the C<=> prefix); this is needed only if the POD
paragraph corresponds to a command paragraph. The C<-file> and C<-line>
keywords indicate the filename and line number corresponding to the
beginning of the paragraph 

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
          -name       => undef,
          -text       => (@_ == 1) ? $_[0] : undef,
          -file       => '<unknown-file>',
          -line       => 0,
          -prefix     => '=',
          -separator  => ' ',
          -ptree => [],
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
   (@_ > 1)  and  $_[0]->{'-name'} = $_[1];
   return $_[0]->{'-name'};
}

## let name() be an alias for cmd_name()
*name = \&cmd_name;

##---------------------------------------------------------------------------

=item B<text()>

        my $para_text = $pod_para->text();

This method will return the corresponding text of the paragraph.

=cut

sub text {
   (@_ > 1)  and  $_[0]->{'-text'} = $_[1];
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

=item B<parse_tree()>

        my $ptree = $pod_parser->parse_text( $pod_para->text() );
        $pod_para->parse_tree( $ptree );
        $ptree = $pod_para->parse_tree();

This method will get/set the corresponding parse-tree of the paragraph's text.

=cut

sub parse_tree {
   (@_ > 1)  and  $_[0]->{'-ptree'} = $_[1];
   return $_[0]->{'-ptree'};
}       

## let ptree() be an alias for parse_tree()
*ptree = \&parse_tree;

##---------------------------------------------------------------------------

=item B<file_line()>

        my ($filename, $line_number) = $pod_para->file_line();
        my $position = $pod_para->file_line();

Returns the current filename and line number for the paragraph
object.  If called in an array context, it returns a list of two
elements: first the filename, then the line number. If called in
a scalar context, it returns a string containing the filename, followed
by a colon (':'), followed by the line number.

=cut

sub file_line {
   my @loc = ($_[0]->{'-file'} || '<unknown-file>',
              $_[0]->{'-line'} || 0);
   return (wantarray) ? @loc : join(':', @loc);
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

        my $pod_seq1 = Pod::InteriorSequence->new(-name => $cmd
                                                  -ldelim => $delimiter);
        my $pod_seq2 = new Pod::InteriorSequence(-name => $cmd,
                                                 -ldelim => $delimiter);
        my $pod_seq3 = new Pod::InteriorSequence(-name => $cmd,
                                                 -ldelim => $delimiter,
                                                 -file => $filename,
                                                 -line => $line_number);

This is a class method that constructs a C<Pod::InteriorSequence> object
and returns a reference to the new interior sequence object. It should
be given two keyword arguments.  The C<-ldelim> keyword indicates the
corresponding left-delimiter of the interior sequence (e.g. 'E<lt>').
The C<-name> keyword indicates the name of the corresponding interior
sequence command, such as C<I> or C<B> or C<C>. The C<-file> and
C<-line> keywords indicate the filename and line number corresponding
to the beginning of the interior sequence.

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
          -name       => (@_ == 1) ? $_[0] : undef,
          -file       => '<unknown-file>',
          -line       => 0,
          -ldelim     => '<',
          -rdelim     => '>',
          -ptree => new Pod::ParseTree(),
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
   (@_ > 1)  and  $_[0]->{'-name'} = $_[1];
   return $_[0]->{'-name'};
}

## let name() be an alias for cmd_name()
*name = \&cmd_name;

##---------------------------------------------------------------------------

## Private subroutine to set the parent pointer of all the given
## children that are interior-sequences to be $self

sub _set_child2parent_links {
   my ($self, @children) = @_;
   ## Make sure any sequences know who their parent is
   for (@children) {
      next unless ref $_;
      if ($_->isa('Pod::InteriorSequence') or $_->can('nested')) {
          $_->{'-parent_sequence'} = $self;
      }
   }
}

## Private subroutine to unset child->parent links

sub _unset_child2parent_links {
   my $self = shift;
   $self->{'-parent_sequence'} = undef;
   my $ptree = $self->{'-ptree'};
   for (@$ptree) {
      next  unless ($_ and ref $_);
      $_->_unset_child2parent_links();
   }
}

##---------------------------------------------------------------------------

=item B<prepend()>

        $pod_seq->prepend($text);
        $pod_seq1->prepend($pod_seq2);

Prepends the given string or parse-tree or sequence object to the parse-tree
of this interior sequence.

=cut

sub prepend {
   my $self  = shift;
   $self->{'-ptree'}->prepend(@_);
   _set_child2parent_links($self, @_);
   return $self;
}       

##---------------------------------------------------------------------------

=item B<append()>

        $pod_seq->append($text);
        $pod_seq1->append($pod_seq2);

Appends the given string or parse-tree or sequence object to the parse-tree
of this interior sequence.

=cut

sub append {
   my $self = shift;
   $self->{'-ptree'}->append(@_);
   _set_child2parent_links($self, @_);
   return $self;
}       

##---------------------------------------------------------------------------

=item B<nested()>

        $outer_seq = $pod_seq->nested || print "not nested";

If this interior sequence is nested inside of another interior
sequence, then the outer/parent sequence that contains it is
returned. Otherwise C<undef> is returned.

sub nested {
   my $self = shift;
   return  $self->{'-parent_sequence'} || undef;
}

##---------------------------------------------------------------------------

=item B<raw_text()>

        my $seq_raw_text = $pod_seq->raw_text();

This method will return the I<raw> text of the POD interior sequence,
exactly as it appeared in the input.

=cut

sub raw_text {
   my $self = shift;
   my $text = $self->{'-name'} . $self->{'-ldelim'};
   for ( $self->{'-ptree'}->children ) {
      $text .= (ref $_) ? $_->raw_text : $_;
   }
   $text .= $self->{'-rdelim'};
   return $text;
}

##---------------------------------------------------------------------------

=item B<left_delimiter()>

        my $ldelim = $pod_seq->left_delimiter();

The leftmost delimiter beginning the argument text to the interior
sequence (should be "<").

=cut

sub left_delimiter {
   (@_ > 1)  and  $_[0]->{'-ldelim'} = $_[1];
   return $_[0]->{'-ldelim'};
}

## let ldelim() be an alias for left_delimiter()
*ldelim = \&left_delimiter;

##---------------------------------------------------------------------------

=item B<right_delimiter()>

The rightmost delimiter beginning the argument text to the interior
sequence (should be ">").

=cut

sub right_delimiter {
   (@_ > 1)  and  $_[0]->{'-rdelim'} = $_[1];
   return $_[0]->{'-rdelim'};
}

## let rdelim() be an alias for right_delimiter()
*rdelim = \&right_delimiter;

##---------------------------------------------------------------------------

=item B<parse_tree()>

        my $ptree = $pod_parser->parse_text($paragraph_text);
        $pod_seq->parse_tree( $ptree );
        $ptree = $pod_seq->parse_tree();

This method will get/set the corresponding parse-tree of the interior
sequence's text.

=cut

sub parse_tree {
   (@_ > 1)  and  $_[0]->{'-ptree'} = $_[1];
   return $_[0]->{'-ptree'};
}       

## let ptree() be an alias for parse_tree()
*ptree = \&parse_tree;

##---------------------------------------------------------------------------

=item B<file_line()>

        my ($filename, $line_number) = $pod_seq->file_line();
        my $position = $pod_seq->file_line();

Returns the current filename and line number for the interior sequence
object.  If called in an array context, it returns a list of two
elements: first the filename, then the line number. If called in
a scalar context, it returns a string containing the filename, followed
by a colon (':'), followed by the line number.

=cut

sub file_line {
   my @loc = ($_[0]->{'-file'}  || '<unknown-file>',
              $_[0]->{'-line'}  || 0);
   return (wantarray) ? @loc : join(':', @loc);
}

##---------------------------------------------------------------------------

=item B<DESTROY()>

This method performs any necessary cleanup for the interior-sequence.
If you override this method then it is B<imperative> that you invoke
the parent method from within your own method, otherwise
I<interior-sequence storage will not be reclaimed upon destruction!>

=cut

sub DESTROY {
   ## We need to get rid of all child->parent pointers throughout the
   ## tree so their reference counts will go to zero and they can be
   ## garbage-collected
   _unset_child2parent_links(@_);
}

##---------------------------------------------------------------------------

=back

=cut

#############################################################################

package Pod::ParseTree;

##---------------------------------------------------------------------------

=head1 B<Pod::ParseTree>

This object corresponds to a tree of parsed POD text. As POD text is
scanned from left to right, it is parsed into an ordered list of
text-strings and B<Pod::InteriorSequence> objects (in order of
appearance). A B<Pod::ParseTree> object corresponds to this list of
strings and sequences. Each interior sequence in the parse-tree may
itself contain a parse-tree (since interior sequences may be nested).

=over 4

=cut

##---------------------------------------------------------------------------

=item B<new()>

        my $ptree1 = Pod::ParseTree->new;
        my $ptree2 = new Pod::ParseTree;
        my $ptree4 = Pod::ParseTree->new($array_ref);
        my $ptree3 = new Pod::ParseTree($array_ref);

This is a class method that constructs a C<Pod::Parse_tree> object and
returns a reference to the new parse-tree. If a single-argument is given,
it mist be a reference to an array, and is used to initialize the root
(top) of the parse tree.

=cut

sub new {
    ## Determine if we were called via an object-ref or a classname
    my $this = shift;
    my $class = ref($this) || $this;

    my $self = (@_ == 1  and  ref $_[0]) ? $_[0] : [];

    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    return $self;
}

##---------------------------------------------------------------------------

=item B<top()>

        my $top_node = $ptree->top();
        $ptree->top( $top_node );
        $ptree->top( @children );

This method gets/sets the top node of the parse-tree. If no arguments are
given, it returns the topmost node in the tree (the root), which is also
a B<Pod::ParseTree>. If it is given a single argument that is a reference,
then the reference is assumed to a parse-tree and becomes the new top node.
Otherwise, if arguments are given, they are treated as the new list of
children for the top node.

=cut

sub top {
   my $self = shift;
   if (@_ > 0) {
      @{ $self } = (@_ == 1  and  ref $_[0]) ? ${ @_ } : @_;
   }
   return $self;
}

## let parse_tree() & ptree() be aliases for the 'top' method
*parse_tree = *ptree = \&top;

##---------------------------------------------------------------------------

=item B<children()>

This method gets/sets the children of the top node in the parse-tree.
If no arguments are given, it returns the list (array) of children
(each of which should be either a string or a B<Pod::InteriorSequence>.
Otherwise, if arguments are given, they are treated as the new list of
children for the top node.

=cut

sub children {
   my $self = shift;
   if (@_ > 0) {
      @{ $self } = (@_ == 1  and  ref $_[0]) ? ${ @_ } : @_;
   }
   return @{ $self };
}

##---------------------------------------------------------------------------

=item B<prepend()>

This method prepends the given text or parse-tree to the current parse-tree.
If the first item on the parse-tree is text and the argument is also text,
then the text is prepended to the first item (not added as a separate string).
Otherwise the argument is added as a new string or parse-tree I<before>
the current one.

=cut

use vars qw(@ptree);  ## an alias used for performance reasons

sub prepend {
   my $self = shift;
   local *ptree = $self;
   for (@_) {
      next  unless $_;
      if (@ptree  and  !(ref $ptree[0])  and  !(ref $_)) {
         $ptree[0] = $_ . $ptree[0];
      }
      else {
         unshift @ptree, $_;
      }
   }
}

##---------------------------------------------------------------------------

=item B<append()>

This method appends the given text or parse-tree to the current parse-tree.
If the last item on the parse-tree is text and the argument is also text,
then the text is appended to the last item (not added as a separate string).
Otherwise the argument is added as a new string or parse-tree I<after>
the current one.

=cut

sub append {
   my $self = shift;
   local *ptree = $self;
   for (@_) {
      next  unless $_;
      if (@ptree  and  !(ref $ptree[-1])  and  !(ref $_)) {
         $ptree[-1] .= $_;
      }
      else {
         push @ptree, $_;
      }
   }
}

##---------------------------------------------------------------------------

## Private routines to set/unset child->parent links

sub _unset_child2parent_links {
   my $self = shift;
   local *ptree = $self;
   for (@_) {
      next  unless ($_ and ref $_);
      $_->_unset_child2parent_links();
   }
}

sub _set_child2parent_links {
    ## nothing to do, Pod::ParseTrees cant have parent pointers
}

=item B<DESTROY()>

This method performs any necessary cleanup for the parse-tree.
If you override this method then it is B<imperative>
that you invoke the parent method from within your own method,
otherwise I<parse-tree storage will not be reclaimed upon destruction!>

=cut

sub DESTROY {
   ## We need to get rid of all child->parent pointers throughout the
   ## tree so their reference counts will go to zero and they can be
   ## garbage-collected
   _unset_child2parent_links(@_);
}

#############################################################################

=head1 SEE ALSO

See L<Pod::Parser>, L<Pod::Select>, and L<Pod::Callbacks>.

=head1 AUTHOR

Brad Appleton E<lt>bradapp@enteract.comE<gt>

=cut

1;

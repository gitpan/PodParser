#############################################################################
# Pod/ParseUtils.pm -- helpers for POD parsing and conversion
#
# Copyright (C) 1999 by Marek Rouchal. All rights reserved.
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.
#############################################################################

package Pod::ParseUtils;

use vars qw($VERSION);
$VERSION = 0.1;    ## Current version of this package
require  5.004;    ## requires this Perl version or later

=head1 NAME

Pod::ParseUtils - helpers for POD parsing and conversion

=head1 SYNOPSIS

  use Pod::ParseUtils;

  my $list = new Pod::List;
  my $link = Pod::Hyperlink->new('Pod::Parser');

=head1 DESCRIPTION

B<Pod::ParseUtils> contains currently two object-oriented helper
packages.

=cut

#-----------------------------------------------------------------------------
# Pod::List
#
# class to hold POD list info (=over, =item, =back)
#-----------------------------------------------------------------------------

package Pod::List;

use Carp;

=head2 Pod::List

B<Pod::List> can be used to hold information about POD lists
(written as =over ... =item ... =back) for further processing.
The following methods are available:

=over 4

=item new()

Create a new list object. Properties may be specified through a hash
reference like this:

  my $list = Pod::List->new({ -start => $., -indent => 4 });

See the individual methods/properties for details.

=cut

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my %params = @_;
    my $self = {%params};
    bless $self, $class;
    $self->initialize();
    return $self;
}

sub initialize {
    my $self = shift;
    $self->{-file} ||= 'unknown';
    $self->{-start} ||= 'unknown';
    $self->{-indent} ||= 4; # perlpod: "should be the default"
    $self->{_items} = [];
    $self->{-type} ||= '';
}

=item file()

Without argument, retrieves the file name the list is in. This must
have been set before by either specifying B<-file> in the B<new()>
method or by calling the B<file()> method with a scalar argument.

=cut

# The POD file name the list appears in
sub file {
   return (@_ > 1) ? ($_[0]->{-file} = $_[1]) : $_[0]->{-file};
}

=item start()

Without argument, retrieves the line number where the list started.
This must have been set before by either specifying B<-start> in the
B<new()> method or by calling the B<start()> method with a scalar
argument.

=cut

# The line in the file the node appears
sub start {
   return (@_ > 1) ? ($_[0]->{-start} = $_[1]) : $_[0]->{-start};
}

=item indent()

Without argument, retrieves the indent level of the list as specified
in C<=over n>. This must have been set before by either specifying
B<-indent> in the B<new()> method or by calling the B<indent()> method
with a scalar argument.

=cut

# indent level
sub indent {
   return (@_ > 1) ? ($_[0]->{-indent} = $_[1]) : $_[0]->{-indent};
}

=item type()

Without argument, retrieves the list type, which can be an arbitrary value,
e.g. C<OL>, C<UL>, ... when thinking the HTML way.
This must have been set before by either specifying
B<-type> in the B<new()> method or by calling the B<type()> method
with a scalar argument.

=cut

# The type of the list (UL, OL, ...)
sub type {
   return (@_ > 1) ? ($_[0]->{-type} = $_[1]) : $_[0]->{-type};
}

=item rx()

Without argument, retrieves a regular expression for simplifying the 
individual item strings once the list type has been determined. Usage:
E.g. when converting to HTML, one might strip the leading number in
an ordered list as C<E<lt>OLE<gt>> already prints numbers itself.
This must have been set before by either specifying
B<-rx> in the B<new()> method or by calling the B<rx()> method
with a scalar argument.

=cut

# The regular expression to simplify the items
sub rx {
   return (@_ > 1) ? ($_[0]->{-rx} = $_[1]) : $_[0]->{-rx};
}

=item item()

Without argument, retrieves the array of the items in this list.
The items may be represented by any scalar.
If an argument has been given, it is pushed on the list of items.

=cut

# The individual =items of this list
sub item {
    my ($self,$item) = @_;
    if(defined $item) {
        push(@{$self->{_items}}, $item);
        return $item;
    }
    else {
        return @{$self->{_items}};
    }
}

=item parent()

Without argument, retrieves information about the parent holding this
list, which is represented as an arbitrary scalar.
This must have been set before by either specifying
B<-parent> in the B<new()> method or by calling the B<parent()> method
with a scalar argument.

=cut

# possibility for parsers/translators to store information about the
# lists's parent object
sub parent {
   return (@_ > 1) ? ($_[0]->{-parent} = $_[1]) : $_[0]->{-parent};
}

=item tag()

Without argument, retrieves information about the list tag, which can be
any scalar.
This must have been set before by either specifying
B<-tag> in the B<new()> method or by calling the B<tag()> method
with a scalar argument.

=back

=cut

# possibility for parsers/translators to store information about the
# list's object
sub tag {
   return (@_ > 1) ? ($_[0]->{-tag} = $_[1]) : $_[0]->{-tag};
}

#-----------------------------------------------------------------------------
# Pod::Hyperlink
#
# class to manipulate POD hyperlinks (L<>)
#-----------------------------------------------------------------------------

package Pod::Hyperlink;

=head2 Pod::Hyperlink

B<Pod::Hyperlink> is a class for manipulation of POD hyperlinks. Usage:

  my $link = Pod::Hyperlink->new('alternative text|page/"section in page"');

The B<Pod::Hyperlink> class is mainly designed to parse the contents of the
C<LE<lt>...E<gt>> sequence, providing a simple interface for accessing the
different parts of a POD hyperlink for further processing. It can also be
used to construct hyperlinks.

=over 4

=item new()

The B<new()> method can either be passed a set of key/value pairs or a single
scalar value, namely the contents of a C<LE<lt>...E<gt>> sequence. An object
of the class C<Pod::Hyperlink> is returned. The value C<undef> indicates a
failure, the error message is stored in C<$@>.

=cut

use Carp;

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = +{};
    bless $self, $class;
    $self->initialize();
    if(defined $_[0]) {
        if(ref($_[0])) {
            # called with a list of parameters
            %$self = %{$_[0]};
            $self->_construct_text();
        }
        else {
            # called with L<> contents
            return undef unless($self->parse($_[0]));
        }
    }
    return $self;
}

sub initialize {
    my $self = shift;
    $self->{-line} ||= 'undef';
    $self->{-file} ||= 'undef';
    $self->{-page} ||= '';
    $self->{-node} ||= '';
    $self->{-alttext} ||= '';
    $self->{-type} ||= 'undef';
    $self->{_warnings} = [];
}

=item parse($string)

This method can be used to (re)parse a (new) hyperlink, i.e. the contents
of a C<LE<lt>...E<gt>> sequence. The result is stored in the current object.

=cut

sub parse {
    my $self = shift;
    local($_) = $_[0];
    # syntax check the link and extract destination
    my ($alttext,$page,$node,$type) = ('','','','');

    $self->{_warnings} = [];

    # collapse newlines with whitespace
    if(s/\s*\n+\s*/ /g) {
        $self->warning("collapsing newlines to blanks");
    }
    # strip leading/trailing whitespace
    if(s/^[\s\n]+//) {
        $self->warning("ignoring leading whitespace in link");
    }
    if(s/[\s\n]+$//) {
        $self->warning("ignoring trailing whitespace in link");
    }
    unless(length($_)) {
        _invalid_link("empty link");
        return undef;
    }

    ## Check for different possibilities. This is tedious and error-prone
    # we match all possibilities (alttext, page, section/item)
    #warn "DEBUG: link=$_\n";

    # only page
    if(m!^(\w+(?:::\w+)*)\s*(\(\w*\)|)$!) {
        $page = $1 . $2;
        $type = 'page';
    }
    # alttext, page and section
    elsif(m!^(.+?)\s*[|]\s*(\w+(?:::\w+)*)\s*(\(\w*\)|)\s*/\s*"(.+)"$!) {
        ($alttext, $page, $node) = ($1, $2 . $3, $4);
        $type = 'section';
    }
    # page and section
    elsif(m!^(\w+(?:::\w+)*)\s*(\(\w*\)|)\s*/\s*"(.+)"$!) {
        ($page, $node) = ($1 . $2, $3);
        $type = 'section';
    }
    # page and item
    elsif(m!^(\w+(?:::\w+)*)\s*(\(\w*\)|)\s*/\s*(.+)$!) {
        ($page, $node) = ($1 . $2, $3);
        $type = 'item';
    }
    # only section
    elsif(m!^(?:/\s*|)"(.+)"$!) {
        $node = $1;
        $type = 'section';
    }
    # only item
    elsif(m!^/(.+)$!) {
        $node = $1;
        $type = 'item';
    }
    # non-standard: Hyperlink
    elsif(m!^((?:http|ftp|mailto|news):.+)$!i) {
        $node = $1;
        $type = 'hyperlink';
    }
    # alttext, page and item
    elsif(m!^(.+?)\s*[|]\s*(\w+(?:::\w+)*)\s*(\(\w*\)|)\s*/\s*(.+)$!) {
        ($alttext, $page, $node) = ($1, $2 . $3, $4);
        $type = 'item';
    }
    # alttext and page
    elsif(m!^(.+?)\s*[|]\s*(\w+(?:::\w+)*)\s*(\(\w*\)|)$!) {
        ($alttext, $page) = ($1, $2 . $3);
        $type = 'page';
    }
    # alttext and section
    elsif(m!^(.+?)\s*[|]\s*(?:/\s*|)"(.+)"$!) {
        ($alttext, $node) = ($1,$2);
        $type = 'section';
    }
    # alttext and item
    elsif(m!^(.+?)\s*[|]\s*/(.+)$!) {
        ($alttext, $node) = ($1,$2);
    }
    # nonstandard: alttext and hyperlink
    elsif(m!^(.+?)\s*[|]\s*((?:http|ftp|mailto|news):.+)$!) {
        ($alttext, $node) = ($1,$2);
        $type = 'hyperlink';
    }
    # must be an item or a "malformed" section (without "")
    else {
        $node = $_;
        $type = 'item';
    }

    if($page =~ /[(]\w*[)]$/) {
        $self->warning("section in `$page' deprecated");
    }
    $self->{-page} = $page;
    $self->{-node} = $node;
    $self->{-alttext} = $alttext;
    #warn "DEBUG: page=$page section=$section item=$item alttext=$alttext\n";
    $self->{-type} = $type;
    $self->_construct_text();
    1;
}

sub _construct_text {
    my $self = shift;
    my $alttext = $self->alttext();
    my $type = $self->type();
    my $section = $self->node();
    my $page = $self->page();
    my $page_ext = '';
    $page =~ s/([(]\w*[)])$// && ($page_ext = $1);
    if($alttext) {
        $self->{_text} = $alttext;
    }
    elsif($type eq 'hyperlink') {
        $self->{_text} = $section;
    }
    else {
        $self->{_text} = (!$section ? '' : 
            $type eq 'item' ? "the $section entry" :
                "the section on $section" ) .
            ($page ? ($section ? ' in ':'') . "the $page$page_ext manpage" :
                ' elsewhere in this document');
    }
    # for being marked up later
    # use the non-standard markers P<> and Q<>, so that the resulting
    # text can be parsed by the translators. It's their job to put
    # the correct hypertext around the linktext
    if($alttext) {
        $self->{_markup} = "Q<$alttext>";
    }
    elsif($type eq 'hyperlink') {
        $self->{_markup} = "Q<$section>";
    }
    else {
        $self->{_markup} = (!$section ? '' : 
            $type eq 'item' ? "the Q<$section> entry" :
                "the section on Q<$section>" ) .
            ($page ? ($section ? ' in ':'') . "the P<$page>$page_ext manpage" :
                ' elsewhere in this document');
    }
}

=item markup($string)

Set/retrieve the textual value of the link. This string contains special
markers C<PE<lt>E<gt>> and C<QE<lt>E<gt>> that should be expanded by the
translator's interior sequence expansion engine to the
formatter-specific code to highlight/activate the hyperlink. The details
have to be implemented in the translator.

=cut

#' retrieve/set markuped text
sub markup {
    return (@_ > 1) ? ($_[0]->{_markup} = $_[1]) : $_[0]->{_markup};
}

=item text()

This method returns the textual representation of the hyperlink as above,
but without markers (read only). Depending on the link type this is one of
the following alternatives (the + and * denote the portions of the text
that are marked up):

  the +perl+ manpage
  the *$|* entry in the +perlvar+ manpage
  the section on *OPTIONS* in the +perldoc+ manpage
  the section on *DESCRIPTION* elsewhere in this document

=cut

# The complete link's text
sub text {
    $_[0]->{_text};
}

=item warning()

After parsing, this method returns any warnings encountered during the
parsing process.

=cut

# Set/retrieve warnings
sub warning {
    my $self = shift;
    if(@_) {
        push(@{$self->{_warnings}}, @_);
        return @_;
    }
    return @{$self->{_warnings}};
}

=item line(), file()

Just simple slots for storing information about the line and the file
the link was encountered in. Has to be filled in manually.

=cut

# The line in the file the link appears
sub line {
    return (@_ > 1) ? ($_[0]->{-line} = $_[1]) : $_[0]->{-line};
}

# The POD file name the link appears in
sub file {
    return (@_ > 1) ? ($_[0]->{-file} = $_[1]) : $_[0]->{-file};
}

=item page()

This method sets or returns the POD page this link points to.

=cut

# The POD page the link appears on
sub page {
    if (@_ > 1) {
        $_[0]->{-page} = $_[1];
        $_[0]->_construct_text();
    }
    $_[0]->{-page};
}

=item node()

As above, but the destination node text of the link.

=cut

# The link destination
sub node {
    if (@_ > 1) {
        $_[0]->{-node} = $_[1];
        $_[0]->_construct_text();
    }
    $_[0]->{-node};
}

=item alttext()

Sets or returns an alternative text specified in the link.

=cut

# Potential alternative text
sub alttext {
    if (@_ > 1) {
        $_[0]->{-alttext} = $_[1];
        $_[0]->_construct_text();
    }
    $_[0]->{-alttext};
}

=item type()

The node type, either C<section> or C<item>. As an unofficial type,
there is also C<hyperlink>, derived from e.g. C<LE<lt>http://perl.comE<gt>>

=cut

# The type: item or headn
sub type {
    return (@_ > 1) ? ($_[0]->{-type} = $_[1]) : $_[0]->{-type};
}

=item link()

Returns the link as contents of C<LE<lt>E<gt>>. Reciprocal to B<parse()>.

=cut

# The link itself
sub link {
    my $self = shift;
    my $link = $self->page() || '';
    if($self->node()) {
        if($self->type() eq 'section') {
            $link .= ($link ? '/' : '') . '"' . $self->node() . '"';
        }
        elsif($self->type() eq 'hyperlink') {
            $link = $self->node();
        }
        else { # item
            $link .= '/' . $self->node();
        }
    }
    if($self->alttext()) {
        $link = $self->alttext() . '|' . $link;
    }
    $link;
}

sub _invalid_link {
    my ($msg) = @_;
    # this sets @_
    #eval { die "$msg\n" };
    #chomp $@;
    $@ = $msg; # this seems to work, too!
    undef;
}

=head1 AUTHOR

Marek Rouchal E<lt>marek@saftsack.fs.uni-bayreuth.deE<gt>, borrowing
a lot of things from L<pod2man> and L<pod2roff> as well as other POD
processing tools by Tom Christiansen, Brad Appleton and Russ Allbery.

=head1 SEE ALSO

L<pod2man>, L<pod2roff>, L<Pod::Parser>, L<Pod::Checker>,
L<pod2html>

=cut

1;

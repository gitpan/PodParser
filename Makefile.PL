# Makefile.PL -- Makefile template for PodParser.
#
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.

require 5.004;
use ExtUtils::MakeMaker;

$DISTNAME  = "PodParser";    ## The "product" name for this distribution
$DISTMOD   = 'Pod::Parser';  ## The "title" module of this distribution
@MODULES   = ( $DISTMOD,     ## Other modules in this distribution
               qw( Pod::Checker
                   Pod::InputObjects
                   Pod::PlainText
                   Pod::Select
                   Pod::Usage
                 )
             );

## The executable scripts to be installed
@SCRIPTS   = qw( podchecker
                 podselect
                 pod2usage
               );

##-----------------------------------------------------------------------
## Instructions to write the Makefile (see Ext::MakeMaker)

WriteMakefile(
    NAME         => $DISTMOD,
    DISTNAME     => $DISTNAME,
    VERSION_FROM => 'lib/Pod/Parser.pm',  ## Finds distribution $VERSION
    realclean    => { FILES => "@SCRIPTS" },
    ($] < 5.005 ?     ## Need File::Spec if this is 5.004 or earlier
       (PREREQ_PM  => {'File::Spec' => 0}) : ()),
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
       (ABSTRACT   => 'Modules for parsing/translating POD format documents',
        AUTHOR     => 'Brad Appleton <bradapp@enteract.com>') : ()),
);

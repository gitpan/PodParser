# Makefile.PL -- Makefile template for PodParser.
#
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.

require 5.004;
use ExtUtils::MakeMaker;
use File::Spec;

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

## The test-script to execute regression tests (note that the
## 'xtra' directory might not exist for some installations)
@TESTPODS = ();
my $testdir  = File::Spec->catfile('t', 'pod');
my $test2dir = File::Spec->catfile($testdir, 'xtra');
my @testdirs = ($testdir);
push @testdirs, $test2dir if (-d $testdir);
@TESTPODS = map { File::Spec->catfile($_, '*.t') } @testdirs;

## If WriteMakefile had a TEST_FILES attribute we could just use that,
## but since it doesnt we have to resort to this below to override
## using t/*.t as the suite of test-scripts!
sub MY::test {
    package MY; # so that "SUPER" works right
    my $inherited  = shift->SUPER::test(@_);
    my $test_files = "@main::TESTPODS";
    $inherited =~ s/^(\s*TEST_FILES\s*=\s*)(.*)$/$1$test_files/m;
    $inherited;
}


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



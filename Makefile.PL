# Makefile.PL -- Makefile template for PodParser.
#
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => "Pod::Parser",
    DISTNAME     => "PodParser",
    VERSION_FROM => "Parser.pm",
    SKIP         => [qw(static dynamic)],
    linkext      => {LINKTYPE => ''},
    INSTALLDIRS  => 'perl',
    EXE_FILES    => [qw(podselect pod2usage)],
);

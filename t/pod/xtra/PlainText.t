BEGIN {
   use File::Basename;
   use Cwd qw(abs_path);
   my $THISDIR = abs_path(dirname $0);
   unshift @INC, $THISDIR, dirname($THISDIR);
   require "testp2pt.pl";
   import TestPodIncPlainText;
}

my %options = map { $_ => 1 } @ARGV;  ## convert cmdline to options-hash
my $passed  = testpodplaintext \%options, $0;
exit( ($passed == 1) ? 0 : -1 )  unless $ENV{HARNESS_ACTIVE};


__END__

=include PlainText.pm



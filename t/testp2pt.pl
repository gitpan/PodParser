package TestPodIncPlainText;

BEGIN { push @INC, '..' };
use Pod::PlainText;
use vars qw(@ISA @EXPORT $MYPKG);
#use strict;
#use diagnostics;
use Carp;
use Exporter;
use File::Basename;
use File::Spec;
use File::Compare;

@ISA = qw(Pod::PlainText);
@EXPORT = qw(testpodplaintext);
$MYPKG = eval { (caller)[0] };

## Hardcode settings for TERMCAP and COLUMNS so we can try to get
## reproducible results between environments
@ENV{qw(TERMCAP COLUMNS)} = ('co=72:do=^J', 72);

## Find the path to the file to =include
sub findinclude {
    my $self    = shift;
    my $incname = shift;

    ## See if its already found w/out any "searching;
    return  $incname if (-r $incname);

    ## Need to search for it. Look in the following directories ...
    ##   1. the directory containing this pod file
    my $thispoddir  = dirname $self->input_file;
    ##   2. the parent directory of the above
    my $parentdir   = ($thispoddir eq '.') ? '..' : dirname $thispoddir;
    ##   3. the 'Pod' subdirectory of the above (sibling of $thispoddir)
    my $podsibdir   = File::Spec->catfile($parentdir, 'Pod');
    ##   4. the 'Pod' subdirectory of this pod's directory
    my $podsubdir   = File::Spec->catfile($thispoddir, 'Pod');

    my @podincdirs  = ($thispoddir, $parentdir, $podsibdir, $podsubdir);
    for (@podincdirs) {
       my $incfile = File::Spec->catfile($_, $incname);
       return $incfile  if (-r $incfile);
    }
    warn("*** Can't find =include file $incname in @podincdirs\n");
    return "";
}

sub command {
    my $self = shift;
    my ($cmd, $text, $line_num, $pod_para)  = @_;
    $cmd     = ''  unless (defined $cmd);
    local $_ = $text || '';
    my $out_fh  = $self->output_handle;

    ## Defer to the superclass for everything except '=include'
    return  $self->SUPER::command(@_) unless ($cmd eq "include");

    ## We have an '=include' command
    my $incdebug = 1; ## debugging
    my @incargs = split;
    if (@incargs == 0) {
        warn("*** No filename given for '=include'\n");
        return;
    }
    my $incfile  = $self->findinclude(shift @incargs)  or  return;
    print $out_fh "###### begin =include $incfile #####\n"  if ($incdebug);
    $self->parse_from_file( {-cutting => 1}, $incfile );
    print $out_fh "###### end =include $incfile #####\n"    if ($incdebug);
}

sub podinc2plaintext( $ $ ) {
    my ($infile, $outfile) = @_;
    local $_;
    my $text_parser = $MYPKG->new;
    $text_parser->parse_from_file($infile, $outfile);
}

sub testpodinc2plaintext( @ ) {
   my %args = @_;
   my $infile  = $args{'-In'}  || croak "No input file given!";
   my $outfile = $args{'-Out'} || croak "No output file given!";
   my $cmpfile = $args{'-Cmp'} || croak "No compare-result file given!";

   my $different = '';
   my $testname = basename $cmpfile, '.t', '.xr';

   unless (-e $cmpfile) {
      my $msg = "*** Can't find comparison file $cmpfile for testing $infile";
      warn  "$msg\n";
      return  $msg;
   }

   print "+ Running testpodinc2plaintext for '$testname'...\n";
   ## Compare the output against the expected result
   podinc2plaintext($infile, $outfile);
   if ( File::Compare::cmp($outfile, $cmpfile) ) {
       $different = "$outfile is different from $cmpfile";
   }
   else {
       unlink($outfile);
   }
   return  $different;
}

sub testpodplaintext( @ ) {
   my %opts = (ref $_[0] eq 'HASH') ? %{shift()} : ();
   my @testpods = @_;
   my ($testname, $testdir) = ("", "");
   my ($podfile, $cmpfile) = ("", "");
   my ($outfile, $errfile) = ("", "");
   my $passes = 0;
   my $failed = 0;
   local $_;

   print "1..", scalar @testpods, "\n"  unless ($opts{'-xrgen'});

   for $podfile (@testpods) {
      ($testname, $_) = fileparse($podfile);
      $testdir ||=  $_;
      $testname  =~ s/\.t$//;
      $cmpfile   =  $testdir . $testname . '.xr';
      $outfile   =  $testdir . $testname . '.OUT';

      if ($opts{'-xrgen'}) {
          if ($opts{'-force'} or ! -e $cmpfile) {
             ## Create the comparison file
             print "+ Creating expected result for \"$testname\"" .
                   " pod2plaintext test ...\n";
             podinc2plaintext($podfile, $cmpfile);
          }
          else {
             print "+ File $cmpfile already exists" .
                   " (use '-force' to regenerate it).\n";
          }
          next;
      }

      my $failmsg = testpodinc2plaintext
                        -In  => $podfile,
                        -Out => $outfile,
                        -Cmp => $cmpfile;
      if ($failmsg) {
          ++$failed;
          print "+\tFAILED. ($failmsg)\n";
	  print "not ok ", $failed+$passes, "\n";
      }
      else {
          ++$passes;
          unlink($outfile);
          print "+\tPASSED.\n";
	  print "ok ", $failed+$passes, "\n";
      }
   }
   return  $passes;
}

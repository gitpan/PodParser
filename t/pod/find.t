# Testing of Pod::Find
# Author: Marek Rouchal <marek@saftsack.fs.uni-bayreuth.de>

$| = 1;

use Test;

BEGIN { plan tests => 2 }

use Pod::Find qw(pod_find);

# load successful
ok(1);

require Cwd;
my $THISDIR = Cwd::cwd();

print "*** searching $THISDIR/lib\n";
my %pods = pod_find("$THISDIR/lib");
my $result = join(',', sort values %pods);
print "*** found $result\n";
my $compare = join(',', qw(
    Pod::Checker
    Pod::Find
    Pod::InputObjects
    Pod::ParseUtils
    Pod::Parser
    Pod::PlainText
    Pod::Select
    Pod::Usage
));
ok($result,$compare);


use Test;
BEGIN { plan tests => 8 };

$len = 50000;
$num = 5;
$wd = './wd';
sub echo { printf("%-45s ... ", $_[0]) }


use Bio::Tools::Prepeat qw(random_sequence);

echo "Initiating object";
my $p = Bio::Tools::Prepeat->new( wd => $wd );
ok(1);

echo "Feeding sequences";
$p->feed(random_sequence($len)) for 1..$num;
ok(1);

echo "Building index";
$p->buildidx();
ok(1);

echo "Resetting object";
$p->reset();
ok(1);

echo "Loading index";
$p->loadidx();
ok(1);

echo "Querying";
$p->query(4);
ok(1);

echo "Checking sequence file";
ok(-s "$wd/seqs");

echo "Checking repeats file";
ok(-s "$wd/result");

map{unlink $_} glob("$wd/*");
rmdir $wd;

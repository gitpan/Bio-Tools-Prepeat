use Prepeat qw(random_sequence);
my $p= new Bio::Tools::Prepeat(wd=>"wd");
$p->loadidx();
open F, $ARGV[0];
while(chomp($_=<F>)){
    print "$_ => ";
    print join q/ /, $p->relpos( $_), ' ';
    @r = $p->relpos( $_);
    print substr($p->{seqarr}->[$r[0]], $r[1]);
    print $/;
}
close F;

package Bio::Tools::Prepeat;
use 5.006;
use strict;
our $VERSION = '0.03';
use XSLoader;
XSLoader::load 'Bio::Tools::Prepeat';
use Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(random_sequence);
use Cwd qw(abs_path);
use String::Random qw(random_string);
use IO::File;

our @amino = 'A'..'Z';
sub random_sequence { ref($_[0]) ? shift : undef;random_string('0'x(shift), \@amino) }

sub new {
    my $pkg = shift;
    my $arg = ref($_[0]) ? $_[0] : {@_};
    die "It exists as a non-directory\n" if -e $arg->{wd} && !-d $arg->{wd};
    mkdir abs_path($arg->{wd});
    bless {
	wd => abs_path($arg->{wd}),
	seqarr => undef,
    }, $pkg;
}

sub reset {
    my $pkg = shift;
    @{$pkg->{seqarr}} = ();
    @{$pkg->{acclen}} = ();
    $pkg->{built} = 0;
}

sub feed { push @{(shift)->{seqarr}}, map{uc$_}@_ }

# cartesian product over @amino X @amino
sub bigram_set {
    my @ret;
    foreach my $f (@amino){
	foreach my $s (@amino){
	    push @ret, $f.$s;
	}
    }
    @ret;
}

sub loadseq {
    my $pkg = shift;
    open F, $pkg->{wd}."/seqs" or die "Cannot load sequence file\n";
    while(chomp($_=<F>)){
	push @{$pkg->{seqarr}}, $_;
    }
    close F;
}

# accumulating lengths
sub acclen {
    my $pkg = shift;
    my $sum;
    push @{$pkg->{acclen}}, 0;
    for (1..$#{$pkg->{seqarr}}){
	$sum += length $pkg->{seqarr}->[$_-1];
	push @{$pkg->{acclen}}, $sum;
    }
}

sub loadidx {
    my $pkg = shift;
    $pkg->{seqarr} = $pkg->{acclen} = undef;
    $pkg->loadseq;
    $pkg->acclen;
    $pkg->{built} = 1;
}

sub buildidx {
    my $pkg = shift;
    my %fh;

    $pkg->acclen;

    foreach (bigram_set){
	$fh{$_} = new IO::File $pkg->{wd}."/idx.$_", O_CREAT|O_WRONLY|O_TRUNC;
	die "Cannot open index file $_ for writing\n" unless defined $fh{$_};
    }

    open F, '>', $pkg->{wd}."/seqs";
    my $cnt = 0;
    foreach my $seq (@{$pkg->{seqarr}}){
	print F "$seq\n";
	for(my $i = 0; $i < length($seq)-1; $i++){
	    my $bigram = substr($seq, $i, 2);
	    my $h = $fh{$bigram};
	    print $h ($pkg->{acclen}->[$cnt] + $i)."\n";
	}
	$cnt++;
    }
    close F;

    $_->close foreach (values %fh);
    $pkg->{built} = 1;
}

# relative position
sub relpos {
    my ($pkg, $abspos) = @_;
    my ($seqid, $pos) = (0, 0);
    for( my $i=$#{$pkg->{acclen}} ; $i>=0 ; $i--){
	if( $abspos >= $pkg->{acclen}->[$i] ){
	    $pos = $abspos - $pkg->{acclen}->[$i];
	    $seqid = $i;
	    last;
	}
    }
    return ($seqid, $pos);
}

sub coincidence_length {
    my ($pkg, $prev, $this) = @_;
    my @prevrel = $pkg->relpos($prev);
    my @thisrel = $pkg->relpos($this);
    my $str_a = substr($pkg->{seqarr}->[$prevrel[0]], $prevrel[1], $pkg->{length});
    my $str_b = substr($pkg->{seqarr}->[$thisrel[0]], $thisrel[1], $pkg->{length});

    return undef if length $str_a != $pkg->{length} && $str_b != $pkg->{length};
    return undef if $str_a ne $str_b;
#    print "$prev, $this => ", substr($pkg->{seqarr}->[$prevrel[0]], $prevrel[1], $pkg->{length}), '/', substr($pkg->{seqarr}->[$thisrel[0]], $thisrel[1], $pkg->{length}), $/;



    return [ \@prevrel, \@thisrel ];
}

sub query {
    my ($pkg, $length) = @_;
    die "Index files are not built or loaded. Please use 'buildidx' or 'loadidx' first\n" unless $pkg->{built};
    die "Length of a repeat sequence must exceed 3\n" unless $length >= 3;
    $pkg->{length} = $length;
    open R, '>', $pkg->{wd}."/result";
    my ($prev, $this);
    foreach (bigram_set){
	next unless -s $pkg->{wd}."/idx.$_";
	open F, $pkg->{wd}."/idx.$_" or die "Cannot open index file $_ for query\n";
	my @posarr;
	while ( chomp ($_ = <F>) ){ push @posarr, $_; }

	my %checked;
	foreach $prev (@posarr){
	    next if $checked{$prev};
	    foreach $this (@posarr){
		if($this - $prev > $pkg->{length}){
		    my $occ = $pkg->coincidence_length($prev, $this);
		    if(ref $occ){
			$checked{$this} = 1;
			print R
			    join ' ',
			    substr($pkg->{seqarr}->[$occ->[0]->[0]],
				   $occ->[0]->[1], $pkg->{length}),
			    "@{$occ->[0]} @{$occ->[1]}\n";

		    }
		}
	    }
	}
	close F;
    }
    close R;

    open R, $pkg->{wd}."/result" or die "Cannot open result file\n";
    my $prep; # previous repeat
    my $ret;
    while(chomp($_=<R>)){
	my @e = split /\s/, $_;
	next unless length $e[0]  == $length;
	push @{$ret->{$e[0]}}, ($e[0] ne $prep ? ([ @e[1..2] ], [ @e[3..4] ]) : [ @e[3..4] ]);
	$prep = $e[0];
    }
    close R;
    $ret;
}


sub cleanidx {
    map{unlink $_} glob($_[0]->{wd}."/*");
    rmdir $_[0]->{wd};
}



1;
__END__
# Below is stub documentation for your module. You better edit it!

=head1 NAME

Bio::Tools::Prepeat - Finding repeats in protein sequences

=head1 SYNOPSIS

    use Bio::Tools::Prepeat;
    my $p = Bio::Tools::Prepeat->new( wd => './working_directory' );
    $p->feed(@seq);
    $p->buildidx();
    $result = $p->query();

=head1 DESCRIPTION

This is a module for locating repeats in protein sequences. Usage is as follows: feed the sequences, build index files, perform queries, and then it will return a reference to the repeat data.

=head1 INTERFACE

=head2 new

  my $p = Bio::Tools::Prepeat->new( wd => './working_directory' );

Contructor. You need to specify a directory's name for storing index files and other information.

=head2 feed

  $p->feed($seq1, $seq2);

Use this to feed protein sequences into the object. NOTE, the module does not do character checking for your input data.

=head2 reset

  $p->reset();

It resets the object. Sequences will be freed from memory, and you may need to use 'loadidx' to load index files that are previously built before you perform another query.

=head2 buildidx

  $p->buildidx();

It builds bigram index for sequences. Bigram index is used to pick up possible candidates.

=head2 loadidx

  $p->loadidx();

It loads previously built bigram index files.

=head2 query

    $p->query(10);

It returns a reference to repeat sequences of length 10 with sequence ids they belong to and their positions in sequences.

=head2 random_sequence


   $p->random_sequence(100000);

or you may use it as a plain function.

    use Bio::Tools::Prepeat qw(random_sequence);
    print random_sequence(100000);

It generates a random protein sequence, and you may use this for testing.

=head1 NOTE

It is all written in Perl for now, and parts of the code will be translated into XS for better performance in next versions.

=head1 COPRYRIGHT

xern E<lt>xern@cpan.orgE<gt>

This module is free software; you can redistribute it or modify it under the same terms as Perl itself.

=cut

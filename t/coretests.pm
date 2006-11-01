#!/usr/bin/perl 
use Test::More qw(no_plan);
use YAML qw/LoadFile Load Dump/;
use SVN::Notify;
use Cwd;
my $PWD = getcwd;
my $USER = $ENV{USER};
my $SVNLOOK = SVN::Notify->find_exe('svnlook');

my $repos_path = "$PWD/t/test-repos";

my @results = ();

sub reset_all_tests {
    create_test_repos();
}

sub initialize_results {
    @results = LoadFile("$PWD/t/".shift);
    foreach my $result ( @results ) {
	next if $result =~ /empty/;
	$result = [$result] unless ref($result) eq 'ARRAY';
	for ( @$result ) {
	    foreach my $key ( keys %{ $_ } ) {
		if ( $_->{$key} and $_->{$key} =~ /^\$/ ) {
		    # only one of these will match
		    $_->{$key} =~ s/\$USER/$USER/;
		    $_->{$key} =~ s/\$PWD/$PWD/;
		    $_->{$key} =~ s/\$SVNLOOK/$SVNLOOK/;
		}
	    }
	}
    }
}

# Create a repository fill it with sample values the first time through
sub create_test_repos {
    require SVN::Notify;
    my $svnadmin = $ENV{SVNADMIN} || SVN::Notify->find_exe('svnadmin');
    die (<<"") unless defined($svnadmin);
Can't locate svnadmin binary!
Start test files with e.g.:
    \$ SVNADMIN=/path/to/svnadmin ./Build test

    unless ( -d $repos_path ) {
	system(<<"") == 0 or die "system failed: $?";
$svnadmin create $repos_path

	system(<<"") == 0 or die "system failed: $?";
$svnadmin load --quiet $repos_path < ${repos_path}.dump

    }
}

sub run_tests {
    my $command = shift;
    my $TESTER;
    my $rsync_test = 0;

    for (my $rev = 1; $rev <= $#results; $rev++) {
	my %args = @_;
	# Common to all tests
	$args{'repos-path'} = $repos_path;
	$args{'revision'} = $rev;

	my $change = $results[$rev];
	next unless $change;
	
	_test(
	    $change, 
	    $command, 
	    %args
	);
    }

}

sub _test {
    my ($expected, $command, %args) = @_;
    my $test;

    $ENV{'TZ'} = 'EST5EDT'; # fix for RT#22704
    open $TESTER, '-|', _build_command($command, %args);
    while (<$TESTER>) {
	next if /--- YAML/;
	$test .= $_;
    }
    close $TESTER;

    my @test = Load($test);

    if ( @test ) {
	is_deeply(\@test, $expected, 
	    "All object properties match at rev: " . $args{revision});
    } 
    elsif ( $expected =~ /empty/ ) {
	pass "No changes at rev: " . $args{revision};
    }
    else { # failure path
	fail "Failed to produce expected results at rev: " .
	$args{revision};
    }
}

sub _build_command {
    my ($command, %args) = @_;
    my @commandline = split " ", $command;

    push @commandline, $args{'repos-path'}, $args{'revision'};
    return @commandline;
}

1; # magic return

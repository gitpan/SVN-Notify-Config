package SVN::Notify::Config;
$SVN::Notify::Config::VERSION = '0.01';

use strict;
use YAML;
use SVN::Notify;

=head1 NAME

SVN::Notify::Config - Config-driven Subversion notification

=head1 VERSION

This document describes version 0.01 of SVN::Notify::Config,
released October 17, 2004.

=head1 SYNOPSIS

Set this as your Subversion repository's F<hooks/post-commit>:

 #!/usr/bin/perl -MSVN::Notify::Config=$0
 --- #YAML:1.0
 '':
   with-diff: 1
 path:
   handler: HTML::ColorDiff
   to: root@localhost
 path/ignored:
   handler: ~
 path/snapshot:
   handler: Snapshot
   to: '/tmp/tarball-${revision}.tgz'
   pattern: '*.xml'
 path/multitarget:
   - to: alice@localhost
   - to: bob@localhost
   - to: root@localhost

=head1 DESCRIPTION

This module is a is a YAML-based configuration wrapper on L<SVN::Notify>.

(More documentations later.  Sorry.)

=cut

sub import {
    my $class = shift;
    my $config = shift or return;

    $config =~ s/\$0/$0/g;
    $config =~ s/\$(\d+)/$ARGV[$1-1]/eg;

    my $self = bless( YAML::LoadFile( $config ), $class );
    $self->run(
        repos_path  => $ARGV[0],
        revision    => $ARGV[1],
    );
}

sub run {
    my ($self, %args) = @_;
    $self->fixup;

    my @actions = ({});
    my $path = $args{repos_path};
    foreach my $key (sort keys %$self) {
        print "Matching $path against $key\n";
        $path =~ m{^/$key\b} or next;
        my $values = $self->{$key};
        # multiply @actions by @$values
        @actions = map {
            my $orig = $_;
            map { +{ %$orig, %$_ } } @$values
        } @actions;
    }

    foreach my $value (@actions) {
        %$value = (%$value, %args);
        $value->{handler} or next;

        my $notify = SVN::Notify->new(%$value);
        $notify->prepare;
        $notify->execute;
    }

    exit;
}

sub fixup {
    my $self = shift;

    # Heuristic: if none of our values are refs, cast it into ''.
    $self = { '' => { %$self } } unless grep ref, values %$self;

    my @keys = sort keys %$self;
    foreach my $key (@keys) {
        next if UNIVERSAL::isa( $self->{$key} => 'ARRAY' );
        $self->{$key} = [ { %{ $self->{$key} } } ];
    }

    foreach my $key (@keys) {
        foreach my $value (@{ $self->{$key} }) {
            my @vkeys = sort keys %$value;
            foreach my $vkey (@vkeys) {
                $vkey =~ /-/ or next;
                my $nkey = $vkey;
                $nkey =~ s/-/_/g;
                $value->{$nkey} = delete $value->{$vkey};
            }
        }
    }
}

1;

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 SEE ALSO

L<SVN::Notify>

=head1 COPYRIGHT

Copyright 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

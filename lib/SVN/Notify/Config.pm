package SVN::Notify::Config;
$SVN::Notify::Config::VERSION = '0.04';

use strict;
use YAML;
use SVN::Notify;

=head1 NAME

SVN::Notify::Config - Config-driven Subversion notification

=head1 VERSION

This document describes version 0.04 of SVN::Notify::Config,
released October 18, 2004.

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
 path/multitarget:
   - to: alice@localhost
   - to: bob@localhost
   - to: root@localhost

Alternatively, use a config file inside the repository:

 #!/usr/bin/perl -MSVN::Notify::Config=file://$1/svnnotify.yml

=head1 DESCRIPTION

This module is a YAML-based configuration wrapper on L<SVN::Notify>.

(More documentations later.  Sorry.)

=cut

sub import {
    my $class = shift;
    my @config = @_ or return;

    foreach my $config (@config) {
        $config =~ s/\$0/$0/g;
        $config =~ s/\$(\d+)/$ARGV[$1-1]/eg;

        my $self = $class->new($config);

        $self->prepare;
        $self->execute(
            repos_path  => $ARGV[0],
            revision    => $ARGV[1],
        );
    }

    exit;
}

sub new {
    my ($class, $config) = @_;
    bless(
        ($config =~ m{^[A-Za-z][-+.A-Za-z0-9]*://}
            ? YAML::Load(scalar `svn cat $config`)
            : YAML::LoadFile( $config )),
        $class,
    );
}


sub prepare {
    my ($self) = @_;

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
                $value->{$self->_normalize_key($vkey)} = delete $value->{$vkey};
            }
        }
    }
}
sub execute {
    my ($self, %args) = @_;

    my @actions = ({});
    my $path = $args{repos_path};

    my @keys = sort keys %$self or return;

    my $filter = SVN::Notify->new(
        %args,
        to_regex_map => {
            map { +( $_ => $keys[$_] ) } (0 .. $#keys)
        },
    );
    $filter->prepare_recipients;

    foreach my $key (sort @keys[$filter->{to} =~ /(\d+)/g]) {
        my $values = $self->{$key};
        # multiply @actions by @$values
        @actions = map {
            my $orig = $_;
            map {
                +{
                    %$orig,
                    %$_,
                    (exists $_->{handler})
                        ? ( handle_path => $key ) : (),
                }
            } @$values
        } @actions;
    }

    foreach my $value (@actions) {
        %$value = (%$value, %args);
        $value->{handler} or next;

        foreach my $key (sort keys %$value) {
            my $vval = $value->{$key};
            $vval =~ s{\$\{([-\w]+)\}}
                      {$value->{$self->_normalize_key($1)}}eg or next;
            $value->{$key} = $vval;
        }

        my $notify = SVN::Notify->new(%$value);
        $notify->prepare;
        $notify->execute;
    }
}

sub _normalize_key {
    my ($self, $key) = @_;
    $key =~ s/-/_/g;
    return $key;
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

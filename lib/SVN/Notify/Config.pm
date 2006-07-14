package SVN::Notify::Config;
$SVN::Notify::Config::VERSION = '0.08';

use strict;
use YAML;
use SVN::Notify;

=head1 NAME

SVN::Notify::Config - Config-driven Subversion notification

=head1 VERSION

This document describes version 0.08 of SVN::Notify::Config,
released July 13, 2006.

=head1 SYNOPSIS

Set this as your Subversion repository's F<hooks/post-commit>:

 #!/usr/bin/perl -MSVN::Notify::Config=$0
 --- #YAML:1.0
 '':
   PATH: "/usr/bin:/usr/local/bin"
 '/path':
   handler: HTML::ColorDiff
   to: root@localhost
 '/path/ignored':
   handler: ~
 '/path/snapshot':
   fork: 1
   handler: Snapshot
   to: "/tmp/tarball-%{%Y%m%d}-${revision}.tar.gz"
 '/path/multitarget':
   - to: alice@localhost
   - to: bob@localhost
   - to: root@localhost
 '/path/tags':
   handler: Mirror
   to: '/path/to/another/dir'
   tag-regex: "RELEASE_"

Alternatively, use a config file inside the repository:

 #!/usr/bin/perl -MSVN::Notify::Config=file://$1/svnnotify.yml

=head1 DESCRIPTION

This module is a YAML-based configuration wrapper on L<SVN::Notify>.  Any
option of the base L<SVN::Notify> or any of its subclasses can be rendered
in YAML and will be used to perform the appropriate task.  In essence, your
hook script B<is> your configuration file, so it can be a very compact way
to use L<SVN::Notify>.

=cut

sub import {
    my $class = shift;
    my @config = @_ or return;

    local $ENV{PATH} = $ENV{PATH} || do {
        require Config;
        require File::Basename;
        join(
            $Config::Config{pathsep},
            ($Config::Config{bin}, File::Basename::dirname($^X)),
        );
    };

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

    bless( (
	( ref($config) eq 'HASH' )
	    ? $config :
        ($config =~ m{^(?:file|svn(?:\+ssh)?)://})
            ? YAML::Load(scalar `svn cat $config`) :
        ($config =~ m{^[A-Za-z][-+.A-Za-z0-9]*://})
            ? do { require LWP::Simple; LWP::Simple::get($config) } 
            : YAML::LoadFile( $config ),
    ), $class);
}


sub prepare {
    my ($self) = @_;

    # Heuristic: if none of our values are refs, cast it into ''.
    $self = { '' => { %$self } } unless grep ref, values %$self;

    my @keys = sort keys %$self;
    foreach my $key (@keys) {
        next if ref($self->{$key}) eq 'ARRAY';
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
            map { +( $_ => map "$_(?:)", ($keys[$_] =~ m!^/?(.*)!g) ) } (0 .. $#keys)
        },
    );
    $filter->prepare_recipients;

    # maintain backwards compatibility with SVN::Notify < 2.61
    my $to = $filter->{to};
    unless ( ref($to) eq 'ARRAY' ) {
	$to = [$to =~ m!(\d+)!g];
    }

    foreach my $key ( sort map {$keys[$_]} @{$to} ) {
        my $values = $self->{$key};
        # multiply @actions by @$values
        @actions = map {
            my $orig = $_;
            map {
                +{
                    %$orig,
                    %$_,
                    (exists $_->{handler})
                        ? ( handle_path => ($key =~ m!^/?(.*)!g) ) : (),
                }
            } @$values
        } @actions;
    }

    foreach my $value (@actions) {
        %$value = (%$value, %args);

        $value->{handler} or next;

        foreach my $key (sort keys %$value) {
            my $vval = $value->{$key};
            next if ref($vval);
            $vval =~ s{\$\{([-\w]+)\}}
                      {$value->{$self->_normalize_key($1)}}eg;
            $vval =~ s{\%\{(.+?)\}}
                      {require POSIX; POSIX::strftime($1, localtime(time))}eg;
            $value->{$key} = $vval;
        }

        fork and exit if $value->{fork};

        local %ENV = %ENV;
        $ENV{$_} = $value->{$_} for grep !/\p{IsLower}/, keys %$value;

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

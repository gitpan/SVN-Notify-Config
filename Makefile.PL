#!/usr/bin/env perl

use inc::Module::Install;
license 'perl';

include( 'ExtUtils::AutoInstall' );
auto_install();

WriteMakefile(
    NAME                => 'SVN::Notify::Config',
    AUTHOR              => 'John Peacock <jpeacock@cpan.org>',
    VERSION_FROM        => 'lib/SVN/Notify/Config.pm',
    ABSTRACT            => 'Config-driven Subversion notification',
    PL_FILES            => {},
    PREREQ_PM => {
        'SVN::Notify'   => 2.62,
        'Test::More'    => 0,
        'YAML'          => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'SVN-Notify-Config-* t/test-repos' },
    (MM->can('signature_target') ? (SIGN => 1) : ()),
);

#!/usr/bin/env perl

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'SVN::Notify::Config',
    AUTHOR              => 'John Peacock <jpeacock@cpan.org>',
    VERSION_FROM        => 'lib/SVN/Notify/Config.pm',
    ABSTRACT            => 'Config-driven Subversion notification',
    LICENSE             => 'perl',  
    PL_FILES            => {},
    PREREQ_PM => {
        'SVN::Notify'   => 2.62,
        'Test::More'    => 0,
        'YAML'          => 0,
    },
    dist            => {
        COMPRESS => 'gzip -9f', 
        SUFFIX => 'gz',
	PREOP => 'my-changelog.pl > Changes',
    },
    clean               => { FILES => 'SVN-Notify-Config-* t/test-repos' },
    (MM->can('signature_target') ? (SIGN => 1) : ()),
);

#!/usr/bin/env perl

use inc::Module::Install;

name		('SVN-Notify-Config');
author		('Autrijus Tang <autrijus@autrijus.org>');
abstract	('Config-driven Subversion notification');
license		('perl');
version_from	('lib/SVN/Notify/Config.pm');

requires (
    'SVN::Notify'   => 2.62,
    'YAML'          => 0,
);

include( 'ExtUtils::AutoInstall' );
auto_install();

WriteAll( sign => 1 );

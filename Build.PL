use Module::Build;
# See perldoc Module::Build for details of how this works

my $class = Module::Build->subclass
(
    class => 'JPEACOCK::Builder',
    code => q{
	sub ACTION_dist {
	    my $self = shift;
	    $self->do_system('my-changelog.pl > Changes');
	    $self->SUPER::ACTION_dist();
	}
    }
);

my $mb = $class->new
    ( module_name     => 'SVN::Notify::Config',
      license         => 'perl',
      dist_author     => 'John Peacock <jpeacock@cpan.org>',
      requires        => {
	  'Module::Build' => 0.2805,
	  'SVN::Notify'   => 2.70,
	  'YAML'          => 0.62,
      },
      sign            => 1,
      add_to_cleanup =>
	  ['t/test-repos', ],
    );

$mb->create_build_script;

use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Firepear::Catechesis',
    license             => 'perl',
    dist_author         => 'Firepear Informatics <firepear@cpan.org>',
    dist_version_from   => 'lib/Firepear/Catechesis.pm',
    requires       => {
                       JSON => 0,
                      },
    build_requires => {
        'Test::More' => 0,
    },
    add_to_cleanup      => [ 'Firepear-Catechesis-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();

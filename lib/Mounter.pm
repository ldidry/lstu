package Mounter;
use Mojo::Base 'Mojolicious';
use Mojo::File;
use FindBin qw($Bin);
use File::Spec qw(catfile);
use Lstu::DefaultConfig qw($default_config);

# This method will run once at server start
sub startup {
    my $self = shift;

    push @{$self->commands->namespaces}, 'Lstu::Command';

    my $cfile = Mojo::File->new($Bin, '..' , 'lstu.conf');
    if (defined $ENV{MOJO_CONFIG}) {
        $cfile = Mojo::File->new($ENV{MOJO_CONFIG});
        unless (-e $cfile->to_abs) {
            $cfile = Mojo::File->new($Bin, '..', $ENV{MOJO_CONFIG});
        }
    }
    my $config = $self->plugin('Config' =>
        {
            file    => $cfile,
            default => $default_config
        }
    );

    # Themes handling
    $self->plugin('FiatTux::Themes');

    # Static assets gzipping
    $self->plugin('GzipStatic');

    # Headers
    $self->plugin('Lstu::Plugin::Headers');

    # Helpers
    $self->plugin('Lstu::Plugin::Helpers');

    # URL cache
    if (scalar(@{$config->{memcached_servers}})) {
        $self->plugin(CHI => {
            lstu_urls_cache => {
                driver             => 'Memcached',
                servers            => $config->{memcached_servers},
                expires_in         => '1 day',
                expires_on_backend => 1,
            }
        });
    }

    $self->plugin('Mount' => {$config->{prefix} => File::Spec->catfile($Bin, '..', 'script', 'application')});
}

1;

package Mounter;
use Mojo::Base 'Mojolicious';
use Mojo::File;
use FindBin qw($Bin);
use File::Spec qw(catfile);

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
            default =>  {
                prefix           => '/',
                provisioning     => 100,
                provis_step      => 5,
                length           => 8,
                secret           => ['hfudsifdsih'],
                page_offset      => 10,
                theme            => 'default',
                ban_min_strike   => 3,
                ban_whitelist    => [],
                minion           => {
                    enabled => 0,
                    db_path => 'minion.db'
                },
                session_duration => 3600,
                dbtype           => 'sqlite',
                max_redir        => 2,
                skip_spamhaus    => 0,
                cache_max_size   => 2,
                csp              => "default-src 'none' ; script-src 'self' ; style-src 'self' ; img-src 'self' data: ; font-src 'self'",
            }
        }
    );

    # Themes handling
    shift @{$self->static->paths};
    if ($config->{theme} ne 'default') {
        my $theme = $self->home->rel_file('themes/'.$config->{theme});
        push @{$self->static->paths}, $theme.'/public' if -d $theme.'/public';
    }
    push @{$self->static->paths}, $self->home->rel_file('themes/default/public');

    # Cache
    $self->plugin('StaticCache' => { even_in_dev => 1, max_age => 2592000 });

    # Static assets gzipping
    $self->plugin('GzipStatic');

    # Add CSP Header
    $self->plugin('CSPHeader', csp => $config->{'csp'}) if $config->{'csp'};

    # Helpers
    $self->plugin('Lstu::Plugin::Helpers');

    $self->plugin('Mount' => {$config->{prefix} => File::Spec->catfile($Bin, '..', 'script', 'application')});
}

1;

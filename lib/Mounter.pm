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
                prefix                 => '/',
                provisioning           => 100,
                provis_step            => 5,
                length                 => 8,
                secret                 => ['hfudsifdsih'],
                page_offset            => 10,
                theme                  => 'default',
                ban_min_strike         => 3,
                ban_whitelist          => [],
                ban_blacklist          => [],
                minion                 => {
                    enabled => 0,
                    db_path => 'minion.db'
                },
                session_duration       => 3600,
                dbtype                 => 'sqlite',
                db_path                => 'lstu.db',
                max_redir              => 2,
                skip_spamhaus          => 0,
                memcached_servers      => [],
                x_frame_options        => 'DENY',
                x_content_type_options => 'nosniff',
                x_xss_protection       => '1; mode=block',
                log_creator_ip         => 0,
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

    # Static assets gzipping
    $self->plugin('GzipStatic');

    # Headers
    $self->plugin('Lstu::Plugin::Headers');

    # Helpers
    $self->plugin('Lstu::Plugin::Helpers');

    $self->plugin('Mount' => {$config->{prefix} => File::Spec->catfile($Bin, '..', 'script', 'application')});
}

1;

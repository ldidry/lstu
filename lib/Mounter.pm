package Mounter;
use Mojo::Base 'Mojolicious';
use FindBin qw($Bin);
use File::Spec qw(catfile);

# This method will run once at server start
sub startup {
    my $self = shift;

    push @{$self->commands->namespaces}, 'Lstu::Command';

    my $config = $self->plugin('Config' =>
        {
            file    => File::Spec->catfile($Bin, '..' ,'lstu.conf'),
            default => {
                prefix => '/',
                theme  => 'default',
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

    $self->hook(after_static => sub {
        my $c = shift;
        $c->res->headers->cache_control('max-age=2592000, must-revalidate');
    });
    $self->plugin('Mount' => {$config->{prefix} => File::Spec->catfile($Bin, '..', 'script', 'application')});
}

1;

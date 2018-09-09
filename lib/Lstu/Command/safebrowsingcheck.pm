# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Command::safebrowsingcheck;
use Mojo::Base 'Mojolicious::Command';
use FindBin qw($Bin);
use File::Spec qw(catfile);
use Term::ProgressBar::Quiet;

has description => 'Checks all URLs in database against Google Safe Browsing database (local copy)';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;
    my @args = @_;

    my $cfile = Mojo::File->new($Bin, '..' , 'lstu.conf');
    if (defined $ENV{MOJO_CONFIG}) {
        $cfile = Mojo::File->new($ENV{MOJO_CONFIG});
        unless (-e $cfile->to_abs) {
            $cfile = Mojo::File->new($Bin, '..', $ENV{MOJO_CONFIG});
        }
    }
    my $config = $c->app->plugin('Config', {
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
            safebrowsing_api_key   => '',
            memcached_servers      => [],
            x_frame_options        => 'DENY',
            x_content_type_options => 'nosniff',
            x_xss_protection       => '1; mode=block',
            log_creator_ip         => 0,
        }
    });

    $c->app->plugin('Lstu::Plugin::Helpers');

    if ($c->app->gsb) {
        my $urls = Lstu::DB::URL->new(app => $c->app)->get_all_urls;

        my $progress = Term::ProgressBar::Quiet->new(
            { name => 'Scanning '.$urls->size.' URLs', count => $urls->size, ETA => 'linear' }
        );
        my (@bad, %bad_ips, @bad_from_ips);
        my $gsb = $c->app->gsb;
        $urls->each(sub {
            my ($e, $num) = @_;

            $progress->update($num);

            my @matches = $gsb->lookup(url => $e->{url});

            if (@matches) {
                push @bad, $e->{short};
                $bad_ips{$e->{created_by}} = 1 if $e->{created_by};
            }
        });

        say sprintf('All URLs (%d) have been scanned.', $urls->size);
        say sprintf('%d bad URLs detected.', scalar(@bad));

        say sprintf("If you want to delete the detected bad URLs, please do:\n  carton exec script/lstu url --remove %s", join(' ', @bad)) if @bad;

        for my $ip (keys %bad_ips) {
            my $u = Lstu::DB::URL->new(app => $c->app)->search_creator($ip);
            $u->each(sub {
                my ($e, $num) = @_;
                push @bad_from_ips, $e->{short};
            });
        }
        say sprintf("Bad URLs creators' IP addresses: \n  %s", join(", ", keys %bad_ips)) if (keys %bad_ips);
        say sprintf("If you want to delete the URLs created by the same IPs than the detected bad URLs, please do:\n  carton exec script/lstu url --remove %s", join(' ', @bad_from_ips)) if @bad_from_ips;
    } else {
        say 'It seems that safebrowsing_api_key isn\'t set. Please, check your configuration';
    }
}

=encoding utf8

=head1 NAME

Lstu::Command::safebrowsing - Checks all URLs in database against Google Safe Browsing database (local copy)

=head1 SYNOPSIS

  Usage:
      carton exec script/lstu safebrowsingcheck

=cut

1;

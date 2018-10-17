# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Command::ban;
use Mojo::Base 'Mojolicious::Command';
use FindBin qw($Bin);
use File::Spec qw(catfile);
use Mojo::Util qw(getopt);
use Lstu::DB::Ban;

has description => 'Ban IPs addresses for ten years, or unban them';
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

    getopt \@args,
      'b|ban=s{1,}'   => \my @ban_ips,
      'u|unban=s{1,}' => \my @unban_ips;

    for my $ip (@ban_ips) {
        Lstu::DB::Ban->new(
            app    => $c->app,
            ip     => $ip
        )->ban_ten_years;
    }
    say sprintf("%d banned IP addresses", scalar(@ban_ips)) if (@ban_ips);

    for my $ip (@unban_ips) {
        Lstu::DB::Ban->new(
            app    => $c->app,
            ip     => $ip
        )->unban;
    }
    say sprintf("%d unbanned IP addresses", scalar(@unban_ips)) if (@unban_ips);

    say $c->extract_usage unless (scalar(@ban_ips) || scalar(@unban_ips));
}

=encoding utf8

=head1 NAME

Lstu::Command::ban - Ban IPs addresses for ten years, or unban them

=head1 SYNOPSIS

  Usage:
      carton exec script/lstu ban -b|--ban <ip> <ip>    Ban the space separated IP addresses for ten years
      carton exec script/lstu ban -u|--unban <ip> <ip>  Unban the space separated IP addresses

  Please note that you can pass the --ban and --unban options at the same time.

=cut

1;

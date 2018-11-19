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

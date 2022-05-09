# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Command::url;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(getopt);
use Mojo::Collection 'c';
use Lstu::DB::URL;
use FindBin qw($Bin);
use File::Spec qw(catfile);

has description => 'Manage stored URL';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;
    my @args = @_;

    getopt \@args,
      'info=s{1,}'         => \my @info,
      'r|remove=s{1,}'     => \my @remove,
      's|search=s'         => \my $search,
      'ip=s{1,}'           => \my @ips,
      'y|yes'              => \my $yes,
      'e|even-if-disabled' => \my $even_disabled;

    if (scalar @info) {
        c(@info)->each(
            sub {
                my ($e, $num) = @_;
                my $u = get_short($c, $e, $even_disabled);
                print_infos($u->to_hash) if $u;
            }
        );
    }
    if (scalar @remove) {
        my @r_ips;
        c(@remove)->each(
            sub {
                my ($e, $num) = @_;
                my $u = get_short($c, $e, 1);
                if ($u) {
                    push @r_ips, $u->created_by if $u->created_by;
                    print_infos($u->to_hash);
                    if ($u->disabled) {
                        say sprintf('%s URL is already disabled', $e);
                    } else {
                        my $confirm = ($yes) ? 'yes' : undef;
                        unless (defined $confirm) {
                            printf('Are you sure you want to remove this URL (%s)? [N/y] ', $e);
                            $confirm = <STDIN>;
                            chomp $confirm;
                        }
                        if ($confirm =~ m/^y(es)?$/i) {
                            if ($u->remove) {
                                say sprintf('Success: %s URL has been removed', $e);
                            } else {
                                say sprintf('Failure: %s URL has not been removed', $e);
                            }
                        } else {
                            say 'Answer was not "y" or "yes". Aborting deletion.';
                        }
                    }
                }
            }
        );
        say sprintf("If you want to ban the uploaders' IPs, please do:\n  carton exec script/lstu ban --ban %s", join(' ', @r_ips)) if @r_ips;
    }
    if ($search) {
        my $u = Lstu::DB::URL->new(app => $c->app)->search_url($search);
        my @shorts;
        my @s_ips;
        $u->each(sub {
            my ($e, $num) = @_;
            push @shorts, $e->{short};
            push @s_ips, $e->{created_by} if $e->{created_by};
            print_infos($e);
        });
        say sprintf('%d matching URLs', $u->size);
        say sprintf("If you want to delete those URLs, please do:\n  carton exec script/lstu url --yes --remove %s", join(' ', @shorts)) if @shorts;
        say sprintf("If you want to ban those IPs, please do:\n  carton exec script/lstu ban --ban %s", join(' ', @s_ips)) if @s_ips;
    }
    if (scalar(@ips)) {
        my @recap;
        c(@ips)->each(sub {
            my ($ip, $num) = @_;
            my $u = Lstu::DB::URL->new(app => $c->app)->search_creator($ip);
            my @shorts;
            $u->each(sub {
                my ($e, $num) = @_;
                push @shorts, $e->{short};
                print_infos($e);
            });
            say sprintf('[%s] %d matching URLs', $ip, $u->size);
            if (@shorts) {
                say sprintf("[%s] If you want to delete those URLs, please do:\n  carton exec script/lstu url --yes --remove %s", $ip, join(' ', @shorts));
                push @recap, @shorts;
            }
        });
        say sprintf("If you want to delete all those URLs, please do:\n  carton exec script/lstu url --yes --remove %s", join(' ', @recap)) if @recap;
        say sprintf("If you want to ban those IPs, please do:\n  carton exec script/lstu ban --ban %s", join(' ', @ips)) if @ips;
    }
}

sub get_short {
    my $c                = shift;
    my $short            = shift;
    my $even_if_disabled = shift;

    my $u = Lstu::DB::URL->new(app => $c->app, short => $short);
    if ($u->url) {
        return $u if !$u->disabled;
        return $u if $even_if_disabled;
    }
    say sprintf('Sorry, unable to find an URL with short = %s', $short);
    return undef;
}

sub print_infos {
    my $u = shift;

    if ($u) {
        my $msg = <<EOF;
%s
    url        : %s
    disabled   : %d
    counter    : %d
    created at : %s
    timestamp  : %d
EOF
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($u->{timestamp});
        my $timestamp = sprintf('%d-%d-%d %d:%d:%d GMT', $year + 1900, ++$mon, $mday, $hour, $min, $sec);
        if ($u->{created_by}) {
            $msg .= '    created_by : %s';
            say sprintf($msg, $u->{short}, $u->{url}, $u->{disabled}, $u->{counter}, $timestamp, $u->{timestamp}, $u->{created_by});
        } else {
            say sprintf($msg, $u->{short}, $u->{url}, $u->{disabled}, $u->{counter}, $timestamp, $u->{timestamp});
        }
    }
}

=encoding utf8

=head1 NAME

Lstu::Command::url - Manage URL in Lstu's database

=head1 SYNOPSIS

  Usage:
      carton exec script/lstu url --info <short> <short>           Print infos about the space-separated URLs
      carton exec script/lstu url --remove <short> <short> [--yes] Remove the space-separated URLs (ask for confirmation unless --yes is given)
                                                                   Will print infos about URL before confirmation
      carton exec script/lstu url --search <url>                   Search URLs by its true URL (LIKE match)
      carton exec script/lstu url --ip <ip address> <ip address>   Search URLs by the IP address of its creator (exact match)

=cut

1;

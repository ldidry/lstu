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
            memcached_servers      => [],
            x_frame_options        => 'DENY',
            x_content_type_options => 'nosniff',
            x_xss_protection       => '1; mode=block',
            log_creator_ip         => 0,
        }
    });

    getopt \@args,
      'info=s{1,}'   => \my @info,
      'r|remove=s{1,}' => \my @remove,
      's|search=s'     => \my $search,
      'ip=s'           => \my $ip,
      'y|yes'          => \my $yes;

    if (scalar @info) {
        c(@info)->each(
            sub {
                my ($e, $num) = @_;
                my $u = get_short($c, $e);
                print_infos($u->to_hash) if $u;
            }
        );
    }
    if (scalar @remove) {
        c(@remove)->each(
            sub {
                my ($e, $num) = @_;
                my $u = get_short($c, $e);
                if ($u) {
                    print_infos($u->to_hash);
                    my $confirm = ($yes) ? 'yes' : undef;
                    unless (defined $confirm) {
                        printf('Are you sure you want to remove this URL (%s)? [N/y] ', $e);
                        $confirm = <STDIN>;
                        chomp $confirm;
                    }
                    if ($confirm =~ m/^y(es)?$/i) {
                        if ($u->delete) {
                            say sprintf('Success: %s URL has been removed', $e);
                        } else {
                            say sprintf('Failure: %s URL has not been removed', $e);
                        }
                    } else {
                        say 'Answer was not "y" or "yes". Aborting deletion.';
                    }
                }
            }
        );
    }
    if ($search) {
        my $u = Lstu::DB::URL->new(app => $c->app)->search_url($search);
        my @shorts;
        $u->each(sub {
            my ($e, $num) = @_;
            push @shorts, $e->{short};
            print_infos($e);
        });
        say sprintf('%d matching URLs', $u->size);
        say sprintf("If you want to delete those URLs, please do:\n  carton exec script/lstu url --remove %s", join(' ', @shorts)) if @shorts;
    }
    if ($ip) {
        my $u = Lstu::DB::URL->new(app => $c->app)->search_creator($ip);
        my @shorts;
        $u->each(sub {
            my ($e, $num) = @_;
            push @shorts, $e->{short};
            print_infos($e);
        });
        say sprintf('%d matching URLs', $u->size);
        say sprintf("If you want to delete those URLs, please do:\n  carton exec script/lstu url --remove %s", join(' ', @shorts)) if @shorts;
    }
}

sub get_short {
    my $c     = shift;
    my $short = shift;

    my $u = Lstu::DB::URL->new(app => $c->app, short => $short);
    if ($u->url) {
        return $u;
    } else {
        say sprintf('Sorry, unable to find an URL with short = %s', $short);
        return undef;
    }
}

sub print_infos {
    my $u = shift;

    if ($u) {
        my $msg = <<EOF;
%s
    url        : %s
    counter    : %d
    created at : %s
    timestamp  : %d
EOF
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($u->{timestamp});
        my $timestamp = sprintf('%d-%d-%d %d:%d:%d GMT', $year + 1900, ++$mon, $mday, $hour, $min, $sec);
        if ($u->{created_by}) {
            $msg .= '    created_by : %s';
            say sprintf($msg, $u->{short}, $u->{url}, $u->{counter}, $timestamp, $u->{timestamp}, $u->{created_by});
        } else {
            say sprintf($msg, $u->{short}, $u->{url}, $u->{counter}, $timestamp, $u->{timestamp});
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
      carton exec script/lstu url --ip <ip address>                Search URLs by the IP address of its creator (exact match)

=cut

1;

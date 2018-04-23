# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Command::url;
use Mojo::Base 'Mojolicious::Command';
use Mojo::Util qw(getopt);
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
        }
    });

    my $cache_max_size = ($config->{cache_max_size} > 0) ? 8 * 1024 * 1024 * $config->{cache_max_size} : 1;
    $c->app->plugin(CHI => {
        lstu_urls_cache => {
            driver        => 'SharedMem',
            global        => 1,
            is_size_aware => 1,
            max_size      => $cache_max_size,
            expires_in    => '1 day',
            shmkey        => 1782340321,
        }
    });

    getopt \@args,
      'i|info=s'   => \my $info,
      'r|remove=s' => \my $remove,
      's|search=s' => \my $search,
      'y|yes'      => \my $yes;

    if ($info) {
        my $u = get_short($c, $info);
        print_infos($u->to_hash) if $u;
    }
    if ($remove) {
        my $u = get_short($c, $remove);
        if ($u) {
            print_infos($u->to_hash);
            my $confirm = ($yes) ? 'yes' : undef;
            unless (defined $confirm) {
                say 'Are you sure you want to remove this URL? [N/y]';
                $confirm = <STDIN>;
                chomp $confirm;
            }
            if ($confirm =~ m/^y(es)?$/i) {
                if ($u->delete) {
                    $c->app->chi('lstu_urls_cache')->remove($remove);
                    say sprintf('Success: %s URL has been removed', $remove);
                } else {
                    say sprintf('Failure: %s URL has not been removed', $remove);
                }
            } else {
                say 'Answer was not "y" or "yes". Aborting deletion.';
            }
        }
    }
    if ($search) {
        my $u = Lstu::DB::URL->new(app => $c->app)->search_url($search);
        $u->each(sub {
            my ($e, $num) = @_;
            print_infos($e);
        });
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
        say sprintf($msg, $u->{short}, $u->{url}, $u->{counter}, $timestamp, $u->{timestamp});
    }
}

=encoding utf8

=head1 NAME

Lstu::Command::url - Manage URL in Lstu's database

=head1 SYNOPSIS

  Usage:
      script/lstu url --info <short>           Print infos about the URL
      script/lstu url --remove <short> [--yes] Remove URL (ask for confirmation unless --yes is given)
                                               Will print infos about URL before confirmation
      script/lstu url --url <url>              Search URL by its true URL (like match)

=cut

1;

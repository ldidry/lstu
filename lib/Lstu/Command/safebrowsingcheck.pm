# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Command::safebrowsingcheck;
use Mojo::Base 'Mojolicious::Command';
use FindBin qw($Bin);
use File::Spec qw(catfile);
use Term::ProgressBar::Quiet;
use Mojo::Util qw(getopt);
use Mojo::Collection 'c';
use Lstu::DB::URL;
use Lstu::DB::Ban;

has description => 'Checks all URLs in database against Google Safe Browsing database (local copy)';
has usage => sub { shift->extract_usage };

sub run {
    my $c = shift;
    my @args = @_;

    getopt \@args,
      'u|url=s{1,}' => \my @urls_to_check,
      's|seconds=i' => \my $delay,
      'r|remove'    => \my $remove,
      'a|all'       => \my $all,
      'b|ban'       => \my $ban;

    if ($c->app->gsb) {
        my $urls;
        if (@urls_to_check) {
            $urls = c(get_shorts($c, @urls_to_check));
        } elsif ($delay) {
            $urls = Lstu::DB::URL->new(app => $c->app)->get_all_urls_created_ago($delay);
        } else {
            $urls = Lstu::DB::URL->new(app => $c->app)->get_all_urls;
        }

        unless ($urls->size) {
            say 'No URLs to check.';
            exit;
        }

        my $progress = Term::ProgressBar::Quiet->new(
            { name => 'Scanning '.$urls->size.' URLs', count => $urls->size, ETA => 'linear' }
        );
        my (@bad, %bad_ips, @bad_from_ips);
        my $gsb     = $c->app->gsb;
        my $deleted = 0;
        $urls->each(sub {
            my ($e, $num) = @_;

            $progress->update($num);

            my @matches = $gsb->lookup(url => $e->{url});

            if (@matches) {
                push @bad, $e->{short};
                $bad_ips{$e->{created_by}} = 1 if $e->{created_by};
                $deleted += Lstu::DB::URL->new(
                    app => $c->app,
                    short => $e->{short}
                )->remove if $remove;
            }
        });

        say sprintf('All URLs (%d) have been scanned.', $urls->size);
        say sprintf('%d bad URLs detected.', scalar(@bad));

        if ($remove) {
            say sprintf('%d bad URLs deleted.', $deleted) if $deleted;
        } else {
            say sprintf("If you want to delete the detected bad URLs, please do:\n  carton exec script/lstu url --remove %s", join(' ', @bad)) if @bad;
        }

        $deleted = 0;
        for my $ip (keys %bad_ips) {
            my $u = Lstu::DB::URL->new(app => $c->app)->search_creator($ip);
            $u->each(sub {
                my ($e, $num) = @_;
                push @bad_from_ips, $e->{short};
                $deleted += Lstu::DB::URL->new(
                    app => $c->app,
                    short => $e->{short}
                )->remove if ($remove && $all);
            });
        }
        my @ips = keys %bad_ips;
        say sprintf("Bad URLs creators' IP addresses: \n  %s", join(", ", @ips)) if (@ips);

        if ($ban) {
            for my $ip (@ips) {
                Lstu::DB::Ban->new(
                    app    => $c->app,
                    ip     => $ip
                )->ban_ten_years;
            }
            say sprintf("%d banned IP addresses", scalar(@ips)) if (@ips);
        }

        if ($remove && $all) {
            say sprintf('%d URLs from same IPs deleted.', $deleted) if $deleted;
        } else {
            say sprintf("If you want to delete the URLs created by the same IPs than the detected bad URLs, please do:\n  carton exec script/lstu url --remove %s", join(' ', @bad_from_ips)) if @bad_from_ips;
        }
    } else {
        say 'It seems that safebrowsing_api_key isn\'t set. Please, check your configuration';
    }
}

sub get_shorts {
    my $c      = shift;
    my @shorts = @_;

    my @results;

    for my $short (@shorts) {
        my $u = Lstu::DB::URL->new(app => $c->app, short => $short);
        if ($u->url) {
            push @results, $u->to_hash;
        } else {
            say sprintf('Sorry, unable to find an URL with short = %s', $short);
        }
    }
    return @results;
}

=encoding utf8

=head1 NAME

Lstu::Command::safebrowsing - Checks all URLs in database against Google Safe Browsing database (local copy)

=head1 SYNOPSIS

  Usage:
      carton exec script/lstu safebrowsingcheck                           Checks all URLs in database against Google Safe Browsing database
      carton exec script/lstu safebrowsingcheck -u|--url <short> <short>  Checks the space-separated URLs against Google Safe Browsing database
      carton exec script/lstu safebrowsingcheck -s|--seconds <xxx>        Checks URLs created the last xxx seconds against Google Safe Browsing database

  Options (available with all commands):
      -r|--remove  Remove bad URLs that have been found
      -a|--all     Remove all URLs created by the same IP addresses that created bad URLs (only in combination with the `-r|--remove` option)
      -b|--ban     Ban IP addresses that created bad URLs

=cut

1;

# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Controller::URL;
use Mojo::Base 'Mojolicious::Controller';
use Lstu::DB::URL;
use Lstu::DB::Ban;
use Data::Validate::URI qw(is_http_uri is_https_uri);
use Mojo::JSON qw(to_json decode_json);
use Mojo::URL;
use Mojo::Util qw(b64_encode slugify);
use Image::PNG::QRCode 'qrpng';

sub add {
    my $c = shift;

    $c->cleaning;

    # Is the user allowed to create a short URL?
    if ((!defined($c->config('ldap')) && !defined($c->config('htpasswd'))) || $c->is_user_authenticated) {
        my $ip = $c->ip;

        # Check banning
        my $banned = Lstu::DB::Ban->new(
            app    => $c,
            ip     => $ip
        )->is_banned($c->config('ban_min_strike'));

        my $disabled_api = 0;
        if ($c->config('disable_api')) {
            $disabled_api = 1 if $c->validation->csrf_protect->has_error('csrf_token');
            $disabled_api = 1 if (!defined($c->req->headers->referrer) || Mojo::URL->new($c->req->headers->referrer)->host ne Mojo::URL->new('https://'.$c->req->headers->host)->host)
        }

        if (defined $banned) {
            # Increase ban delay if necessary
            my $penalty = 3600;
            if ($banned->strike >= 2 * $c->config('ban_min_strike')) {
                $penalty = 3600 * 24 * 30; # 30 days of banishing
            }
            $banned->increment_ban_delay($penalty);

            my $msg = $c->l('You asked to shorten too many URLs too quickly. You\'re banned for %1 hour(s).', $penalty/3600);
            $c->respond_to(
                json => { json => { success => Mojo::JSON->false, msg => $msg } },
                any  => sub {
                    shift->render(
                        template => 'index',
                        msg      => $msg,
                        banned   => 1
                    );
                }
            );
        } elsif ($disabled_api) {
            my $msg = $c->l('Sorry, the API is disabled.');
            $c->app->log->info('Blocked API call for '.$ip);
            $c->respond_to(
                json => { json => { success => Mojo::JSON->false, msg => $msg } },
                any  => sub {
                    shift->render(
                        template => 'index',
                        msg      => $msg,
                    );
                }
            );
        } else {
            my $lsturl     = $c->param('lsturl');
            $lsturl        =~ s/^\s+|\s+$//g;
            my $url        = Mojo::URL->new($lsturl);
            my $custom_url = $c->param('lsturl-custom');
            my $format     = $c->param('format');

            $custom_url = undef if (defined($custom_url) && $custom_url eq '');

            my ($msg, $short);
            if (defined($custom_url) &&
                       ($custom_url =~ m#^(a|d|cookie|stats|fullstats|login|logout|api)$# || $custom_url =~ m/\.json$/)
                ) {
                $msg = $c->l('The shortened text can\'t be "a", "api", "d", "cookie", "stats", "fullstats", "login" or "logout" or end with ".json". Your URL to shorten: %1', $url);
            } elsif (is_http_uri($url->to_string) || is_https_uri($url->to_string) || (defined($url->host) && $url->host =~ m/\.onion$/)) {
                my $res = ($url->host =~ m/\.onion$/) ? {} : $c->is_spam($url, 0);

                # Check if spam
                if ($res->{is_spam}) {
                    $msg = $res->{msg};
                } else {
                    # Not spam, let's go

                    Lstu::DB::Ban->new(
                        app    => $c,
                        ip     => $ip
                    )->increment_ban_delay(1);

                    my $db_url = Lstu::DB::URL->new(
                        app    => $c,
                        url    => $url
                    );

                    if ($db_url->short && !defined($custom_url)) {
                        # Already got this URL
                        $short = $db_url->short;
                    } else {
                        if (defined($custom_url)) {
                            $custom_url             = slugify $custom_url;
                            my $suffix              = 2;
                            my $original_custom_url = $custom_url;
                            while (Lstu::DB::URL->new(app => $c)->exist($custom_url) > 0) {
                                $custom_url = $original_custom_url.'-'.$suffix;
                                $suffix++;
                            }
                            Lstu::DB::URL->new(
                                app        => $c,
                                short      => $custom_url,
                                url        => $url,
                                timestamp  => time(),
                                created_by => ($c->config('log_creator_ip')) ? $ip : undef
                            )->write;

                            $short = $custom_url;
                        } else {
                            $db_url = Lstu::DB::URL->new(app => $c)->choose_empty;
                            if (defined $db_url) {
                                $db_url->url($url)->timestamp(time);

                                $db_url->created_by($ip) if $c->config('log_creator_ip');

                                $db_url->write;

                                $short = $db_url->short;
                            } else {
                                # Houston, we have a problem
                                $msg = $c->l('No shortened URL available. Please retry or contact the administrator at %1. Your URL to shorten: [_2]', $c->config('contact'), $url);
                            }
                        }
                    }
                }
            } else {
                $msg = $c->l('%1 is not a valid URL.', $url);
            }
            if ($msg) {
                $c->respond_to(
                    json => { json => { success => Mojo::JSON->false, msg => $msg } },
                    any  => sub {
                        shift->render(
                            template => 'index',
                            msg      => $msg
                        );
                    }
                );
            } else {
                # Get URLs from cookie
                my $u = (defined($c->cookie('url'))) ? decode_json $c->cookie('url') : [];

                # Add the new URL
                push @{$u}, $short;

                # Make the array contain only unique URLs
                my %k = map { $_, 1 } @{$u};
                @{$u} = keys %k;

                # And set the cookie
                my $cookie = to_json($u);
                $c->cookie(
                    'url' => $cookie,
                    {
                        path => $c->config('prefix'),
                        expires => time + 142560000
                    }
                ); # expires in 10 years

                my $prefix = $c->prefix;

                my $qrcode = b64_encode(qrpng(text => $prefix.$short, scale => $c->config('qrcode_size')));

                $c->respond_to(
                    json => { json => { success => Mojo::JSON->true, url => $url, short => $prefix.$short, qrcode => $qrcode } },
                    any  => sub {
                        shift->render(
                            template => 'index',
                            url      => $url,
                            short    => $prefix.$short,
                            qrcode   => $qrcode
                        );
                    }
                );
            }
        }
    } else {
        # Not authorized
        $c->redirect_to('login');
    }
}

sub get {
    my $c = shift;
    my $short = $c->param('short');

    if (defined($c->stash('format')) && $short eq 'robots' && $c->stash('format') eq 'txt') {
        if ($c->app->static->file('robots.txt')) {
            $c->res->headers->content_type('text/plain');
            return $c->reply->static('robots.txt');
        } else {
            return $c->reply->not_found;
        }
    }

    my $url;
    my $disabled_url = 0;
    if (scalar(@{$c->config('memcached_servers')})) {
        $url = $c->chi('lstu_urls_cache')->compute($short, undef, sub {
            my $db_url = Lstu::DB::URL->new(app => $c, short => $short);
            if ($db_url->disabled) {
                $disabled_url++;
                return undef
            } else {
                return $db_url->url;
            }
        });
    } else {
        my $db_url = Lstu::DB::URL->new(app => $c, short => $short);
        if ($db_url->disabled) {
            $disabled_url++;
        } else {
            $url = $db_url->url;
        }
    }

    if ($url) {
        $c->respond_to(
            json => { json => { success => Mojo::JSON->true, url => $url } },
            any  => sub {
                my $c = shift;
                $c->res->code(301);
                $c->redirect_to($url);
            }
        );
        # Update counter
        $c->on(finish => sub {
            if ($c->config('minion')->{enabled} && $c->config('minion')->{db_path}) {
                $c->app->minion->enqueue(increase_counter => [$short, $c->{url}]);
            } else {
                Lstu::DB::URL->new(app => $c, short => $short)->increment_counter;

                my $piwik = $c->config('piwik');
                if (defined($piwik) && $piwik->{idsite} && $piwik->{url}) {
                    $c->piwik_api(
                        'Track' => {
                            idSite     => $piwik->{idsite},
                            action_url => $c->{url},
                            url        => $piwik->{url}
                        }
                    );
                }

            }
        });
    } else {
        my $msg;
        if ($disabled_url) {
            $msg = $c->l('The shortened URL %1 no longer exists.', $c->url_for('/')->to_abs.$short);
        } else {
            $msg = $c->l('The shortened URL %1 doesn\'t exist.', $c->url_for('/')->to_abs.$short);
        }
        $c->res->code(404);
        $c->respond_to(
            json => { json => { success => Mojo::JSON->false, msg => $msg } },
            any  => sub {
                my $c = shift;

                $c->render(
                    template => 'index',
                    msg      => $msg
                );
            }
        );
    }
}

1;

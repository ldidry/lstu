# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Controller::Lstu;
use Mojo::Base 'Mojolicious::Controller';
use Lstu::DB::URL;
use Lstu::DB::Ban;
use Lstu::DB::Session;
use Data::Validate::URI qw(is_http_uri is_https_uri);
use Mojo::JSON qw(to_json decode_json);
use Mojo::URL;
use Mojo::File qw(tempfile);
use Mojo::Util qw(b64_encode);
use Image::PNG::QRCode 'qrpng';
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);

sub add {
    my $c = shift;

    $c->cleaning;

    if ((!defined($c->config('ldap')) && !defined($c->config('htpasswd'))) || $c->is_user_authenticated) {
        my $ip = $c->ip;

        my $banned = Lstu::DB::Ban->new(
            app    => $c,
            ip     => $c->ip
        )->is_banned($c->config('ban_min_strike'));
        if (defined $banned) {
            my $penalty = 3600;
            if ($banned->strike >= 2 * $c->config('ban_min_strike')) {
                $penalty = 3600 * 24 * 30; # 30 days of banishing
            }
            $banned->increment_ban_delay($penalty);

            my $msg = $c->l('You asked to shorten too many URLs too quickly. You\'re banned for %1 hour(s).', $penalty/3600);
            $c->respond_to(
                json => { json => { success => Mojo::JSON->false, msg => $msg } },
                any  => sub {
                    my $c = shift;

                    $c->flash('msg' => $msg);
                    $c->flash('banned' => 1);
                    $c->redirect_to('index');
                }
            );
        } else {
            my $lsturl     = $c->param('lsturl');
            $lsturl        =~ s/^\s+|\s+$//g;
            my $url        = Mojo::URL->new($lsturl);
            my $custom_url = $c->param('lsturl-custom');
            my $format     = $c->param('format');

            my $prefix  = $c->prefix;

            $custom_url = undef if (defined($custom_url) && $custom_url eq '');

            my ($msg, $short);
            if (defined($custom_url) && ($custom_url =~ m/^a(pi)?$|^stats$/ || $custom_url =~ m/^d$/ ||
                $custom_url =~ m/\.json$/ || $custom_url !~ m/^[-a-zA-Z0-9_]+$/))
            {
                $msg = $c->l('The shortened text can contain only numbers, letters and the - and _ character, can\'t be "a", "api", "d" or "stats" or end with ".json". Your URL to shorten: %1', $url);
            } elsif (defined($custom_url) && Lstu::DB::URL->new(app => $c)->exist($custom_url) > 0) {
                $msg = $c->l('The shortened text (%1) is already used. Please choose another one.', $custom_url);
            } elsif (is_http_uri($url->to_string) || is_https_uri($url->to_string)) {
                my $res = $c->is_spam($url, 0);
                if ($res->{is_spam}) {
                    $msg = $res->{msg};
                } else {
                    my $db_url = Lstu::DB::URL->new(
                        app    => $c,
                        url    => $url
                    );

                    Lstu::DB::Ban->new(
                        app    => $c,
                        ip     => $ip
                    )->increment_ban_delay(1);

                    if ($db_url->short && !defined($custom_url) && !$c->config('allow_multiple')) {
                        # Already got this URL
                        $short = $db_url->short;
                    } else {
                        if (defined($custom_url)) {
                            Lstu::DB::URL->new(
                                app       => $c,
                                short     => $custom_url,
                                url       => $url,
                                timestamp => time()
                            )->write;

                            $short = $custom_url;
                        } else {
                            my $hmany = $c->param('lsturl-how-many');
                            my $hlong = $c->param('lsturl-how-long');
                            if (!$c->config('allow_multiple') || !defined($hmany) || $hmany == 1) {
                                $db_url = Lstu::DB::URL->new(app => $c)->choose_empty;
                                if (defined $db_url) {
                                    if (defined($hlong) && $hlong ne '' && $hlong >= 0) {
                                        $db_url->url($url)->timestamp(time)->expires_after($hlong)->write;
                                    } else {
                                        $db_url->url($url)->timestamp(time)->write;
                                    }

                                    $short = $db_url->short;
                                } else {
                                    # Houston, we have a problem
                                    $msg = $c->l('No shortened URL available. Please retry or contact the administrator at %1. Your URL to shorten: [_2]', $c->config('contact'), $url);
                                }
                            } else {
                                if ($hmany > 1) {
                                    my $zip = Archive::Zip->new();

                                    my $links = "$url\n\n";
                                    my $qrcodes = Mojo::Collection->new();
                                    my @shorts;
                                    for my $i (1..$hmany) {
                                        $db_url = Lstu::DB::URL->new(app => $c)->choose_empty;
                                        if (defined $db_url) {
                                            if (defined($hlong) && $hlong ne '' && $hlong >= 0) {
                                                $db_url->url($url)->timestamp(time)->expires_after($hlong)->write;
                                            } else {
                                                $db_url->url($url)->timestamp(time)->write;
                                            }

                                            # For the cookie
                                            push @shorts, $db_url->short;

                                            # For the text file
                                            $links .= $prefix.$db_url->short."\n";

                                            # For the QRCode
                                            my $svg = $c->param('svg-file');
                                            my $path;
                                            if (defined($svg) && $svg->slurp()) {
                                                $path = Mojo::File->new('tmp/'.$db_url->short.'.svg');

                                                my $text = $svg->slurp();

                                                my $link = $prefix.$db_url->short;

                                                my $png  = b64_encode(qrpng(text => $link));
                                                $text    =~ s#QRCODEHERE#data:image/png;base64,$png#g;

                                                $text    =~ s#LINKHERE#$link#g;

                                                $path->spurt($text);

                                                $zip->addFile($path->to_string, 'svg/'.$db_url->short.'.svg');
                                            } else {
                                                $path = Mojo::File->new('tmp/'.$db_url->short.'.png');

                                                $path->spurt(qrpng(text => $prefix.$db_url->short));
                                                $zip->addFile($path->to_string, 'qrcodes/'.$db_url->short.'.png');
                                            }
                                            push @{$qrcodes}, $path->to_string;
                                        } else {
                                            # Houston, we have a problem
                                            $msg = $c->l('No shortened URL available. Please retry or contact the administrator at %1. Your URL to shorten: [_2]', $c->config('contact'), $url);
                                        }
                                    }

                                    my $string_member = $zip->addString($links, 'links.txt');
                                    my ($fh, $zipfile) = Archive::Zip::tempFile();
                                    unless ($zip->writeToFileNamed($zipfile) == AZ_OK) {
                                        $msg = $c->l('Something went wrong when creating the zip file. Try again later or contact the administrator (%1).', $c->config('contact'));
                                    } else {
                                        # Get URLs from cookie
                                        my $u = (defined($c->cookie('url'))) ? decode_json $c->cookie('url') : [];
                                        # Add the new URL
                                        push @{$u}, @shorts;
                                        # Make the array contain only unique URLs
                                        my %k = map { $_, 1 } @{$u};
                                        @{$u} = keys %k;
                                        # And set the cookie
                                        my $cookie = to_json($u);
                                        $c->cookie('url' => $cookie, {expires => time + 142560000}); # expires in 10 years

                                        # Send the zip file
                                        $c->res->content->headers->content_type('application/zip;name=links.zip');
                                        $c->res->content->headers->content_disposition('attachment;filename=links.zip');

                                        my $asset = Mojo::Asset::File->new(path => $zipfile);

                                        $c->res->content->asset($asset);
                                        $c->res->content->headers->content_length($asset->size);

                                        unlink $zipfile;
                                        $qrcodes->each(
                                            sub {
                                                my ($e, $num) = @_;
                                                unlink $e;
                                            }
                                        );

                                        return $c->rendered(200);
                                    }
                                } else {
                                    $msg = $c->l('You asked for a non-valid number of shortening.');
                                }
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
                        my $c = shift;

                        $c->flash('msg' => $msg);
                        $c->redirect_to('index');
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
                $c->cookie('url' => $cookie, {expires => time + 142560000}); # expires in 10 years

                my $qrcode = b64_encode(qrpng(text => $prefix.$short));

                $c->respond_to(
                    json => { json => { success => Mojo::JSON->true, url => $url, short => $prefix.$short, qrcode => $qrcode } },
                    any  => sub {
                        my $c = shift;

                        $c->flash('url'    => $url);
                        $c->flash('short'  => $prefix.$short);
                        $c->flash('qrcode' => $qrcode);
                        $c->redirect_to('index');
                    }
                );
            }
        }
    } else {
        $c->redirect_to('login');
    }
}

sub stats {
    my $c = shift;
    if ((!defined($c->config('ldap')) && !defined($c->config('htpasswd'))) || $c->is_user_authenticated) {
        my $db_session = Lstu::DB::Session->new(
            app    => $c,
            token  => $c->session('token')
        );
        if (defined($c->session('token')) && $db_session->is_valid) {
            my $total = Lstu::DB::URL->new(app => $c)->total;
            my $page  = $c->param('page') || 0;
               $page  = 0 if ($page < 0);
               $page  = $page - 1 if ($page * $c->config('page_offset') > $total);

            my ($first, $last) = (!$page, ($page * $c->config('page_offset') <= $total && $total < ($page + 1) * $c->config('page_offset')));

            my @urls  = Lstu::DB::URL->new(
                app    => $c,
            )->paginate($page, $c->config('page_offset'));
            $c->respond_to(
                json => sub {
                    my $c = shift;
                    $c->render(
                        json => {
                            prefix   => $c->prefix,
                            urls     => \@urls,
                            first    => $first,
                            last     => $last,
                            page     => $page,
                            admin    => 1,
                            total    => $total
                        }
                    );
                },
                any => sub {
                    my $c = shift;
                    $c->render(
                        template => 'stats',
                        prefix   => $c->prefix,
                        urls     => \@urls,
                        first    => $first,
                        last     => $last,
                        page     => $page,
                        admin    => 1,
                        total    => $total
                    )
                }
            );
        } else {
            my $u = (defined($c->cookie('url'))) ? decode_json $c->cookie('url') : [];

            my @urls  = Lstu::DB::URL->new(
                app    => $c
            )->get_a_lot($u);

            my $prefix = $c->prefix;

            $c->respond_to(
                json => sub {
                    my @struct;
                    for my $url (@urls) {
                        push @struct, {
                            short      => $prefix.$url->{short},
                            url        => $url->{url},
                            counter    => $url->{counter},
                            created_at => $url->{timestamp},
                            qrcode     => b64_encode(qrpng(text => $prefix.$url->{short}))
                        };
                    }
                    $c->render( json => \@struct );
                },
                any  => sub {
                    my @struct;
                    for my $url (@urls) {
                        push @struct, {
                            short     => $url->{short},
                            url       => $url->{url},
                            counter   => $url->{counter},
                            timestamp => $url->{timestamp},
                            qrcode    => b64_encode(qrpng(text => $prefix.$url->{short}))
                        };
                    }
                    $c->render(
                        template => 'stats',
                        prefix   => $prefix,
                        urls     => \@struct
                    )
                }
            )
        }
    } else {
        $c->redirect_to('login');
    }
}

sub get {
    my $c = shift;
    my $short = $c->param('short');

    my ($url, $db_url, $expires_at, $expires_after);
    if (defined $c->cache->{$short}) {
        $url           = $c->cache->{$short}->{url};
        $expires_at    = $c->cache->{$short}->{expires_at};
        $expires_after = $c->cache->{$short}->{expires_after};
    } else {
        $db_url = Lstu::DB::URL->new(
            app    => $c,
            short  => $short
        );
        $url           = $db_url->url;
        $expires_at    = $db_url->expires_at;
        $expires_after = $db_url->expires_after;
    }
    my $expired = ($expires_at && $expires_at < time);
    if ($url && !$expired) {
        $c->respond_to(
            json => { json => { success => Mojo::JSON->true, url => $url } },
            any  => sub {
                my $c = shift;
                $c->res->code((defined($expires_after)) ? 302 : 301);
                $c->redirect_to($url);
            }
        );
        # Update counter
        $c->on(finish => sub {
            my $nexpires_at = $expires_at;
            if (!defined($nexpires_at)) {
                $nexpires_at = (defined($expires_after)) ? (time + $expires_after * 86400) : undef;
            }
            $c->cache->{$short} = {
                last_used     => time,
                url           => $url,
                expires_at    => $nexpires_at,
                expires_after => $expires_after
            };

            if ($c->config('minion')->{enabled} && $c->config('minion')->{db_path}) {
                $c->app->minion->enqueue(increase_counter => [$short, $c->{url}, $nexpires_at]);
            } else {
                $db_url = Lstu::DB::URL->new(
                    app    => $c,
                    short  => $short
                ) if (defined $c->cache->{$short});

                $db_url->increment_counter;
                $db_url->expires_at($nexpires_at)->write;

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
            $c->clear_cache;
        });
    } else {
        my $msg = $c->l('The shortened URL %1 doesn\'t exist.', $c->url_for('/')->to_abs.$short);
           $msg = $c->l('The shortened URL %1 has been deactivated.', $c->url_for('/')->to_abs.$short) if $expired;
        $c->respond_to(
            json => { json => { success => Mojo::JSON->false, msg => $msg } },
            any  => sub {
                my $c = shift;

                $c->flash('msg' => $msg);
                $c->redirect_to('index');
            }
        );
    }
}

1;

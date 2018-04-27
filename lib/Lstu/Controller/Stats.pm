# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::Controller::Stats;
use Mojo::Base 'Mojolicious::Controller';
use Lstu::DB::URL;
use Lstu::DB::Ban;
use Lstu::DB::Session;
use Data::Validate::URI qw(is_http_uri is_https_uri);
use Mojo::JSON qw(to_json decode_json);
use Mojo::URL;
use Mojo::Util qw(b64_encode);
use Image::PNG::QRCode 'qrpng';

sub export_cookie {
    my $c = shift;

    my $u = (defined($c->cookie('url'))) ? decode_json $c->cookie('url') : [];

    $c->res->headers->add('Content-Disposition' => 'attachment;filename=lstu_export.json');
    return $c->render(json => $u);
}

sub import_cookie {
    my $c    = shift;
    my $file = $c->param('file');

    my $json = decode_json($file->slurp);

    if (ref($json) eq 'ARRAY') {
        # Get URLs from cookie
        my $u = (defined($c->cookie('url'))) ? decode_json $c->cookie('url') : [];
        # Add the new URL
        push @{$u}, @{$json};
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

        $c->flash(success_msg => $c->l('File imported'));
    } else {
        $c->flash(msg => $c->l('Sorry, unable to parse the provided file'));
    }
    return $c->redirect_to('stats');
}

sub fullstats {
    my $c = shift;

    my $url = Lstu::DB::URL->new(app => $c);
    return $c->render(
        json => {
            empty     => $url->count_empty,
            urls      => $url->total,
            timestamp => time,
        }
    );
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


sub stat_for_one_short {
    my $c = shift;
    my $short = $c->param('short');

    my $url  = Lstu::DB::URL->new(
        app    => $c,
        short  => $short
    );

    if ($url->{url}) {
        my $prefix = $c->prefix;

        $c->render(
            json => {
                success    => Mojo::JSON->true,
                short      => $prefix.$url->{short},
                url        => $url->{url},
                counter    => $url->{counter},
                created_at => $url->{timestamp},
                timestamp  => time
            }
        );
    } else {
        $c->render(
            json => {
                success => Mojo::JSON->false,
                msg     => $c->l('The shortened URL %1 doesn\'t exist.', $c->url_for('/')->to_abs.$short)
            }
        );
    }
}

1;

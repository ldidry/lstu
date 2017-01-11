# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
use Mojo::Base -strict;
use Mojo::JSON qw(true false);
use Mojo::File qw(slurp spurt);
use Mojolicious;

use Test::More;
use Test::Mojo;

use lib 'lib';
use Lstu::DB::URL;
use Lstu::DB::Ban;
use Lstu::DB::Session;
use FindBin qw($Bin);
use File::Spec::Functions;

my $config;

BEGIN {
    my $m = Mojolicious->new;
    $config = $m->plugin('Config' =>
        {
            file    => catfile($Bin, '..' ,'lstu.conf'),
            default => {
                dbtype => 'sqlite'
            }
        }
    );
}

Lstu::DB::URL->new(dbtype => $config->{dbtype})->delete_all;
Lstu::DB::Ban->new(dbtype => $config->{dbtype})->delete_all;

my $t = Test::Mojo->new('Lstu');
$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr/Lstu/i);

$t->post_ok('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success')
    ->json_is('/success' => true, '/url' => 'https://lstu.fr')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

$t->post_ok('/a' => form => { lsturl => 'truc', format => 'json' })
    ->status_is(200)
    ->json_has('msg', 'success')
    ->json_is({success => false, msg => 'truc is not a valid URL.'});

Lstu::DB::Ban->new(dbtype => $config->{dbtype})->delete_all; # prevents banishing
my $a = $t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })->res->json('/short');

$t->get_ok($a)
    ->status_is(301);

$t->get_ok($a.'.json')
    ->status_is(200)
    ->json_is({success => true, url => 'https://lstu.fr'});

$t->get_ok($a.'i.json')
    ->status_is(200)
    ->json_is({success => false, msg => 'The shortened URL '.$a.'i doesn\'t exist.'});

# Needed if we use Minion for increasing counters
sleep 2;

$t->get_ok('/stats.json')
    ->status_is(200)
    ->json_has('/0/created_at', '/0/counter', '/0/short', '/0/url')
    ->json_is('/0/url' => 'https://lstu.fr', '/0/short' => $a)
    ->json_is('/0/counter' => 2)
    ->json_like('/0/created_at' => qr#\d+#);

my $b = $a;
$b =~ s#http://127\.0\.0\.1:\d+/##;

$t->ua->max_redirects(1);
$t->get_ok('/d/'.$b)
    ->status_is(200)
    ->content_like(qr/Bad password/);

$t->post_ok('/stats' => form => { adminpwd => 'toto', page => 0 })
    ->status_is(200)
    ->content_like(qr/$a/);

$t->get_ok('/d/'.$b)
    ->status_is(200);

$t->get_ok($a.'i.json')
    ->status_is(200)
    ->json_is({success => false, msg => 'The shortened URL '.$a.'i doesn\'t exist.'});

$a = $t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })->res->json('/short');
$a =~ s#http://127\.0\.0\.1:\d+/##;

$t->get_ok('/d/'.$a.'?format=json')
    ->status_is(200)
    ->json_is({success => true, deleted => 1});

$t->post_ok('/stats' => form => { adminpwd => 'toto', action => 'logout' })
    ->status_is(200);

# Test admin banishing
for my $i (1..3) {
    $t->post_ok('/stats' => form => { adminpwd => 'totoi' })
        ->status_is(200)
        ->content_like(qr/Bad password/);
}

$t->post_ok('/stats' => form => { adminpwd => 'totoi' })
    ->status_is(200)
    ->content_like(qr/Too many bad passwords\./);

# Test user banishing
Lstu::DB::Ban->new(dbtype => $config->{dbtype})->delete_all; # reset banishing
Lstu::DB::URL->new(dbtype => $config->{dbtype})->delete_all;
$t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' });
$t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' });
$t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' });
$t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' });
$t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' });

$t->post_ok('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })
    ->status_is(200)
    ->json_has('msg', 'success')
    ->json_is('/success' => false)
    ->json_like('/msg' => qr#You asked to shorten too many URLs too quickly\. You're banned for \d+ hour\(s\)\.#);

Lstu::DB::Ban->new(dbtype => $config->{dbtype})->delete_all; # reset banishing
$t->post_ok('/a' => form => { lsturl => ' https://fiat-tux.fr', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success')
    ->json_is('/success' => true, '/url' => 'https://fiat-tux.fr')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

# Test htpasswd
my $config_content = slurp 'lstu.conf';
my $config_orig    = $config_content;
   $config_content =~ s/#?htpasswd.*/htpasswd => 't\/lstu.passwd'/gm;
spurt $config_content, 'lstu.conf';

Lstu::DB::Ban->new(dbtype => $config->{dbtype})->delete_all; # reset banishing
Lstu::DB::URL->new(dbtype => $config->{dbtype})->delete_all;

$t = Test::Mojo->new('Lstu');
$t->get_ok('/')
    ->status_is(302);

$t->get_ok('/login')
    ->status_is(200)
    ->content_like(qr/Login/);

$t->post_ok('/login' => form => { login => 'luc', password => 'titi' })
    ->status_is(200)
    ->content_like(qr/Please, check your credentials: unable to authenticate\./);

$t->post_ok('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })
    ->status_is(302);

$t->post_ok('/login' => form => { login => 'luc', password => 'toto' })
    ->status_is(302);

$t->post_ok('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success')
    ->json_is('/success' => true, '/url' => 'https://lstu.fr')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

$t->get_ok('/logout')
  ->status_is(200)
  ->content_like(qr/You have been successfully logged out\./);

spurt $config_orig, 'lstu.conf';

done_testing();

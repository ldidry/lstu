# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
use Mojo::Base -strict;
use Mojo::JSON qw(true false);

use Test::More;
use Test::Mojo;

use lib 'lib';
use LstuModel;

# Rotten syntax, but prevents "Static LstuModel->delete has been deprecated"
LstuModel::Lstu->delete_where('1 = 1');
LstuModel::Ban->delete_where('1 = 1');

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

LstuModel::Ban->delete_where('1 = 1'); # Prevents banishing
my $a = $t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })->res->json('/short');

$t->get_ok($a)
    ->status_is(301);

$t->get_ok($a.'.json')
    ->status_is(200)
    ->json_is({success => true, url => 'https://lstu.fr'});

$t->get_ok($a.'i.json')
    ->status_is(200)
    ->json_is({success => false, msg => 'The shortened URL '.$a.'i doesn\'t exist.'});

$t->get_ok('/stats.json')
    ->status_is(200)
    ->json_has('/0/created_at', '/0/counter', '/0/short', '/0/url')
    ->json_is('/0/url' => 'https://lstu.fr', '/0/short' => $a)
    ->json_like('/0/created_at' => qr#\d+#, '/0/counter' => qr#\d+#);

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

LstuModel::Ban->delete_where('1 = 1');
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
LstuModel::Ban->delete_where('1 = 1'); # Reset banishing
LstuModel::Lstu->delete_where('1 = 1');
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

LstuModel::Ban->delete_where('1 = 1'); # Reset banishing
$t->post_ok('/a' => form => { lsturl => ' https://fiat-tux.fr', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success')
    ->json_is('/success' => true, '/url' => 'https://fiat-tux.fr')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

done_testing();

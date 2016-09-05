# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
use Mojo::Base -strict;
use Mojo::JSON qw(true false);

use Test::More;
use Test::Mojo;

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

done_testing();

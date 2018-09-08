# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
use Mojo::Base -strict;
use Mojo::JSON qw(true false);
use Mojo::File;
use Mojo::URL;
use Mojolicious;

use Test::More;
use Test::Mojo;

use Lstu::DB::URL;
use Lstu::DB::Ban;
use Lstu::DB::Session;
use FindBin qw($Bin);
use File::Spec::Functions;

my ($m, $cfile);

BEGIN {
    use lib 'lib';
    $m = Mojolicious->new;
    $cfile = Mojo::File->new($Bin, '..' , 'lstu.conf');
    if (defined $ENV{MOJO_CONFIG}) {
        $cfile = Mojo::File->new($ENV{MOJO_CONFIG});
        unless (-e $cfile->to_abs) {
            $cfile = Mojo::File->new($Bin, '..', $ENV{MOJO_CONFIG});
        }
    }
    my $config = $m->plugin('Config' =>
        {
            file    => $cfile->to_abs->to_string,
            default => {
                dbtype           => 'sqlite',
                max_redir        => 2,
                skip_spamhaus    => 0,
            }
        }
    );
    $m->plugin('Lstu::Plugin::Helpers');
    $m->plugin('DebugDumperHelper');
}

Lstu::DB::URL->new(app => $m)->delete_all;
Lstu::DB::Ban->new(app => $m)->delete_all;

my $t = Test::Mojo->new('Lstu');

# Give time to provision some short URLs
sleep 3;

# Home page
$t->get_ok('/')
    ->status_is(200)
    ->header_is('X-Frame-Options' => 'DENY')
    ->header_is('X-XSS-Protection' => '1; mode=block')
    ->header_is('X-Content-Type-Options' => 'nosniff')
    ->header_is('Content-Security-Policy' => "base-uri 'self'; default-src 'none'; font-src 'self'; form-action 'self'; frame-ancestors 'none'; img-src 'self' data:; script-src 'self'; style-src 'self'")
    ->content_like(qr/Lstu/i);

# Test robots.txt
$t->get_ok('/robots.txt')
    ->status_is(404);
$t->get_ok('/robots')
    ->status_is(404);


# Create short URL
$t->post_ok('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success', 'qrcode')
    ->json_is('/success' => true, '/url' => 'https://lstu.fr')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

# Create short URL with a .onion URL
$t->post_ok('/a' => form => { lsturl => 'http://lstupiioqgxmq66f.onion', 'lsturl-custom' => 'onion', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success', 'qrcode')
    ->json_is('/success' => true, '/url' => 'https://lstupiioqgxmq66f.onion', '/short' => 'http://127.0.0.1/onion');

Lstu::DB::Ban->new(app => $m)->delete_all; # prevents ban

# Create short URL with robots custom short
$t->post_ok('/a' => form => { lsturl => 'http://robots-txt.com/', 'lsturl-custom' => 'robots', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success', 'qrcode')
    ->json_is('/success' => true, '/url' => 'https://lstu.fr', '/short' => 'http://127.0.0.1/robots');

# Test robots.txt even after creating a robots short URL
$t->get_ok('/robots.txt')
    ->status_is(404);
$t->get_ok('/robots')
    ->status_is(301);

# Create short URL, with invalid argument
# Create short URL, with invalid argument
$t->post_ok('/a' => form => { lsturl => 'truc', format => 'json' })
    ->status_is(200)
    ->json_has('msg', 'success')
    ->json_is({success => false, msg => 'truc is not a valid URL.'});

Lstu::DB::Ban->new(app => $m)->delete_all; # prevents ban

# Give time to provision some short URLs
sleep 5;

# Create short URL
my $a = $t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })->res->json('/short');

# Test redirection
$t->get_ok($a)
    ->status_is(301);

# Test JSON answer
$t->get_ok($a.'.json')
    ->status_is(200)
    ->json_is({success => true, url => 'https://lstu.fr'});

# Extract the path of the short URL
my $short = Mojo::URL->new($a)->path();

# Get stats about the short URL
$t->get_ok('/stats'.$short)
    ->status_is(200)
    ->json_has('success', 'short', 'url', 'counter', 'created_at', 'timestamp')
    ->json_is('/success' => true, '/url' => 'https://lstu.fr', '/short' => $a, '/counter' => 1)
    ->json_like('/created_at' => qr#[0-9]{10}#, '/timestamp' => qr#[0-9]{10}#);

# Test JSON answer on invalid short URL
$t->get_ok($a.'i.json')
    ->status_is(404)
    ->json_is({success => false, msg => 'The shortened URL '.$a.'i doesn\'t exist.'});

# Get stats about an invalid short URL
$t->get_ok('/stats'.$short.'i')
    ->status_is(200)
    ->json_is({success => false, msg => 'The shortened URL '.$a.'i doesn\'t exist.'});

# Test full stats
$t->get_ok('/fullstats')
    ->status_is(200)
    ->json_has('urls', 'empty', 'timestamp')
    ->json_is('/urls' => 3)
    ->json_like('/empty' => qr#\d+#, '/timestamp' => qr#[0-9]{10}#);

# Needed if we use Minion for increasing counters
sleep 4;

# Get stats in JSON format
$t->get_ok('/stats.json')
    ->status_is(200)
    ->json_has('/0/created_at', '/0/counter', '/0/short', '/0/url', '/0/qrcode')
    ->json_is('/0/url' => 'https://lstu.fr', '/0/short' => $a)
    ->json_is('/0/counter' => 2)
    ->json_like('/0/created_at' => qr#\d+#);

# Extract the path of the short URL
my $b = $a;
$b = Mojo::URL->new($a)->path();

$t->ua->max_redirects(1);

# Try to delete short URL while not admin
$t->get_ok('/d'.$b)
    ->status_is(200)
    ->content_like(qr/You&#39;re not authenticated as the admin/);

# Login as admin
$t->post_ok('/stats' => form => { adminpwd => 'toto', page => 0 })
    ->status_is(200)
    ->content_like(qr/$a/);

# Delete short URL while admin
$t->get_ok('/d'.$b)
    ->status_is(200)
    ->content_like(qr/WTFPL/);

# Verify that short URL does not exists anymore
$t->get_ok($a.'.json')
    ->status_is(404)
    ->json_is({success => false, msg => 'The shortened URL '.$a.' doesn\'t exist.'});

# Create short URL
$a = $t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })->res->json('/short');

# Extract the path of the short URL
$a = Mojo::URL->new($a)->path();

# Delete short URL while admin, JSON format
$t->get_ok('/d'.$a.'?format=json')
    ->status_is(200)
    ->json_is({success => true, deleted => 1});

# Logout
$t->post_ok('/stats' => form => { adminpwd => 'toto', action => 'logout' })
    ->status_is(200);

# Test admin ban
Lstu::DB::Ban->new(app => $m)->delete_all;
for my $i (1..3) {
    # Login three times with a bad password
    $t->post_ok('/stats' => form => { adminpwd => 'totoi' })
        ->status_is(200)
        ->content_like(qr/Bad password/);
}

# Login with a bad password, should be banned now
$t->post_ok('/stats' => form => { adminpwd => 'totoi' })
    ->status_is(200)
    ->content_like(qr/Too many bad passwords\./);

# Test user ban
Lstu::DB::Ban->new(app => $m)->delete_all; # reset ban
Lstu::DB::URL->new(app => $m)->delete_all;
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

Lstu::DB::Ban->new(app => $m)->delete_all; # reset ban

# Give time to provision some short URLs
sleep 3;

# Create short URL, JSON format
$t->post_ok('/a' => form => { lsturl => ' https://fiat-tux.fr', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success', 'qrcode')
    ->json_is('/success' => true, '/url' => 'https://fiat-tux.fr')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

# Test htpasswd
my $config_file    = Mojo::File->new($cfile->to_abs->to_string);
my $config_content = $config_file->slurp;
my $config_orig    = $config_content;
   $config_content =~ s/#?htpasswd.*/htpasswd => 't\/lstu.passwd',/gm;
$config_file->spurt($config_content);

Lstu::DB::Ban->new(app => $m)->delete_all; # reset ban
Lstu::DB::URL->new(app => $m)->delete_all;

$t = Test::Mojo->new('Lstu');

# Give time to provision some short URLs
sleep 3;

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
    ->json_has('url', 'short', 'success', 'qrcode')
    ->json_is('/success' => true, '/url' => 'https://lstu.fr')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

$t->get_ok('/logout')
    ->status_is(200)
    ->content_like(qr/You have been successfully logged out\./);

# Test IP whitelisting
$config_content = $config_orig;
$config_content =~ s/^( +)#?ban_whitelist.*/$1ban_whitelist => ['::1', '127.0.0.1'],/gm;
$config_file->spurt($config_content);

$t = Test::Mojo->new('Lstu');

# Give time to provision some short URLs
sleep 3;

$t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' });
$t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' });
$t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' });
$t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' });
$t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' });

$t->post_ok('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success', 'qrcode')
    ->json_is('/success' => true, '/url' => 'https://lstu.fr')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

$config_file->spurt($config_orig);

# Test IP blacklisting
$config_content = $config_orig;
$config_content =~ s/^( +)#?ban_blacklist.*/$1ban_blacklist => ['::1', '127.0.0.1'],/gm;
$config_file->spurt($config_content);

$t = Test::Mojo->new('Lstu');

# Give time to provision some short URLs
sleep 3;

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

$config_file->spurt($config_orig);

# Test domain blacklisting
Lstu::DB::Ban->new(app => $m)->delete_all;
$config_content = $config_orig;
$config_content =~ s/^( +)#?spam_blacklist_regex.*/$1spam_blacklist_regex => 'google\\.(fr|com)',/gm;
$config_file->spurt($config_content);

$t = Test::Mojo->new('Lstu');

# Give time to provision some short URLs
sleep 3;

$t->post_ok('/a' => form => { lsturl => 'https://google.fr', format => 'json' })
    ->status_is(200)
    ->json_has('msg', 'success')
    ->json_is({success => false, msg => 'The URL you want to shorten comes from a domain (google.fr) that is blacklisted on this server (usually because of spammers that use this domain).'});

$t->post_ok('/a' => form => { lsturl => 'https://google.com', format => 'json' })
    ->status_is(200)
    ->json_has('msg', 'success')
    ->json_is({success => false, msg => 'The URL you want to shorten comes from a domain (google.com) that is blacklisted on this server (usually because of spammers that use this domain).'});

$t->post_ok('/a' => form => { lsturl => 'https://google.de', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success', 'qrcode')
    ->json_is('/success' => true, '/url' => 'https://google.de')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

# Test domain whitelisting
Lstu::DB::Ban->new(app => $m)->delete_all;
$config_content =~ s/^( +)#?spam_whitelist_regex.*/$1spam_whitelist_regex => 'google\.fr',/gm;
$config_file->spurt($config_content);

$t = Test::Mojo->new('Lstu');

# Give time to provision some short URLs
sleep 3;

$t->post_ok('/a' => form => { lsturl => 'https://google.fr', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success', 'qrcode')
    ->json_is('/success' => true, '/url' => 'https://google.fr')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

$t->post_ok('/a' => form => { lsturl => 'https://google.com', format => 'json' })
    ->status_is(200)
    ->json_has('msg', 'success')
    ->json_is({success => false, msg => 'The URL you want to shorten comes from a domain (google.com) that is blacklisted on this server (usually because of spammers that use this domain).'});

# Test Cache system
$config_content =~ s/^( +)#?memcached_servers => \[\],/memcached_servers => ['127.0.0.1:11211'],/gm;
$config_file->spurt($config_content);

$t = Test::Mojo->new('Lstu');

# Give time to provision some short URLs
sleep 3;

$a = $t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })->res->json('/short');
$t->get_ok($a)
    ->status_is(301);

# Test command
my $help = `carton exec script/lstu help url`;
like($help, qr/Print infos about the space-separated URLs/m, 'Test help url command');

# Create short URL
$a = $t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })->res->json('/short');

# Extract the path of the short URL
$a =~ s#.*/##;

my $info = `MOJO_CONFIG=$cfile carton exec script/lstu url --info $a`;
like($info, qr/lstu\.fr/m, 'Test url --info command');

my $search = `MOJO_CONFIG=$cfile carton exec script/lstu url --search lstu.fr`;
like($search, qr/$a/m, 'Test url --search command');

my $remove = `MOJO_CONFIG=$cfile carton exec script/lstu url --remove $a --yes`;
like($remove, qr/Success/m, 'Test url --remove command');

# Restore configuration
$config_file->spurt($config_orig);

## Test LDAP
$config_content = $config_orig;
$config_content =~ s/^( +)#?ldap => \{ uri/$1ldap => { uri/gm;
$config_file->spurt($config_content);

Lstu::DB::URL->new(app => $m)->delete_all;
$t = Test::Mojo->new('Lstu');

# Give time to provision some short URLs
sleep 3;

$t->get_ok('/')
    ->status_is(302);

$t->get_ok('/login')
    ->status_is(200)
    ->content_like(qr/Signin/i);

$t->post_ok('/a' => form => { lsturl => 'https://google.com', format => 'json' })
    ->status_is(302);

$t->post_ok('/login' => form => { login => 'zoidberg', password => 'zoidberg' })
    ->status_is(302);
#
# Create short URL
$t->post_ok('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })
    ->status_is(200)
    ->json_has('url', 'short', 'success', 'qrcode')
    ->json_is('/success' => true, '/url' => 'https://lstu.fr')
    ->json_like('/short' => qr#http://127\.0\.0\.1:\d+/[-_a-zA-Z0-9]{8}#);

$a = $t->ua->post('/a' => form => { lsturl => 'https://lstu.fr', format => 'json' })->res->json('/short');

# Test redirection
$t->get_ok($a)
    ->status_is(301);

$t->get_ok('/logout')
    ->status_is(200)
    ->content_like(qr/You have been successfully logged out\./);

$t->get_ok('/')
    ->status_is(302);

$t->get_ok('/login')
    ->status_is(200)
    ->content_like(qr/Signin/i);

# Test redirection
$t->get_ok($a)
    ->status_is(301);

# Restore configuration
$config_file->spurt($config_orig);

## Test headers modifications
$config_content = $config_orig;
$config_content =~ s/^( +)#?x_frame_options => 'DENY',/$1x_frame_options => 'SAMEORIGIN',/gm;
$config_content =~ s/^( +)#?x_xss_protection => '1; mode=block',/$1x_xss_protection => '1',/gm;
$config_content =~ s/^( +)#?x_content_type_options => 'nosniff',/$1x_content_type_options => '',/gm;
$config_file->spurt($config_content);

$t = Test::Mojo->new('Lstu');

# Home page
$t->get_ok('/')
    ->status_is(200)
    ->header_is('X-Frame-Options' => 'SAMEORIGIN')
    ->header_is('X-XSS-Protection' => '1')
    ->header_isnt('X-Content-Type-Options' => 'nosniff')
    ->header_is('Content-Security-Policy' => "base-uri 'self'; default-src 'none'; font-src 'self'; form-action 'self'; frame-ancestors 'self'; img-src 'self' data:; script-src 'self'; style-src 'self'");

# Restore configuration
$config_file->spurt($config_orig);

done_testing();

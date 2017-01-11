# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Session;
use Mojo::Base -base;

has 'token';
has 'until';
has 'dbtype';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    if (ref($c) eq 'Lstu::DB::Session') {
        if ($c->dbtype eq 'sqlite') {
            use Lstu::DB::Session::SQLite;
            $c = Lstu::DB::Session::SQLite->new(@_);
        }
    }

    return $c;
}

sub is_valid {
    my $c = shift;

    return ($c->until > time);
}

sub to_hash {
    my $c = shift;

    return {
        token => $c->token,
        until => $c->until
    }
}

1;

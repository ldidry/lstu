# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Ban::SQLite;
use Mojo::Base 'Lstu::DB::Ban';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->ip);

    return $c;
}

1;

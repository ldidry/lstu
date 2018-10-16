# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::URL::SQLite;
use Mojo::Base 'Lstu::DB::URL';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->short || $c->url);

    return $c;
}

1;

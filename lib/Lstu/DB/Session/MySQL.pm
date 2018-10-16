# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Session::MySQL;
use Mojo::Base 'Lstu::DB::Session';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->token);

    return $c;
}

1;

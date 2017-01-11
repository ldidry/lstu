# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Ban;
use Mojo::Base -base;

has 'ip';
has 'until';
has 'strike' => 0;
has 'dbtype';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    if (ref($c) eq 'Lstu::DB::Ban') {
        if ($c->dbtype eq 'sqlite') {
            use Lstu::DB::Ban::SQLite;
            $c = Lstu::DB::Ban::SQLite->new(@_);
        }
    }

    return $c;
}

sub to_hash {
    my $c = shift;

    return {
        ip     => $c->ip,
        until  => $c->until,
        strike => $c->strike
    };
}

1;

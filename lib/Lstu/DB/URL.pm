# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::URL;
use Mojo::Base -base;

has 'short';
has 'url';
has 'counter' => 0;
has 'timestamp';
has 'dbtype';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    if (ref($c) eq 'Lstu::DB::URL') {
        if ($c->dbtype eq 'sqlite') {
            use Lstu::DB::URL::SQLite;
            $c = Lstu::DB::URL::SQLite->new(@_);
        }
    }

    return $c;
}

sub to_hash {
    my $c = shift;

    return {
        short     => $c->short,
        url       => $c->url,
        counter   => $c->counter,
        timestamp => $c->timestamp
    };
}

1;

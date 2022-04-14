# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::URL::SQLite;
use Mojo::Base 'Lstu::DB::URL';

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    $c = $c->_slurp if ($c->short || $c->url);

    return $c;
}

sub paginate {
    my $c           = shift;
    my $page        = shift;
    my $page_offset = shift;
    my $order       = shift // 'counter';
    my $dir         = shift // '-desc';
    $dir =~ s/^-//;

    return @{$c->app->dbi->db->query("SELECT * FROM lstu WHERE url IS NOT NULL AND disabled = 0 ORDER BY $order $dir LIMIT ? OFFSET ?", $page_offset, $page * $page_offset)->hashes->to_array};
}

1;

# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::URL;
use Mojo::Base -base;

has 'short';
has 'url';
has 'counter' => 0;
has 'timestamp';
has 'created_by';
has 'disabled' => 0;
has 'record' => 0;
has 'app';

=head1 NAME

Lstu::DB::URL - Abstraction layer for Lstu session system

=head1 Contributing

When creating a new database accessor, make sure that it provides the following subroutines.
After that, modify this file and modify the C<new> subroutine to allow to use your accessor.

Have a look at Lstu::DB::URL::SQLite's code: it's simple and may be more understandable that this doc.

=head1 Attributes

=over 1

=item B<short>      : random string

=item B<url>        : string, valid URL

=item B<counter>    : integer

=item B<timestamp>  : unix timestamp

=item B<created_by> : the IP address of the creator

=item B<disabled>   : boolean (0 or 1), is the URL active?

=item B<app>        : a mojolicious object

=back

=head1 Sub routines

=head2 new

=over 1

=item B<Usage>     : C<$c = Lstu::DB::URL-E<gt>new(app =E<gt> $self);>

=item B<Arguments> : any of the attribute above

=item B<Purpose>   : construct a new Lstu::DB::URL object. If the C<short> or the C<url> attribute is provided, it have to load the informations from the database. In the case of multiple records for the same C<url>, choose the first.

=item B<Returns>   : the Lstu::DB::URL object

=item B<Info>      : the app argument is used by Lstu::DB::URL to choose which db accessor will be used, you don't need to use it in new(), but you can use it to access helpers or configuration settings in the other subroutines

=back

=cut

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    if (ref($c) eq 'Lstu::DB::URL') {
        my $dbtype = $c->app->config('dbtype');
        if ($dbtype eq 'sqlite') {
            require Lstu::DB::URL::SQLite;
            $c = Lstu::DB::URL::SQLite->new(@_);
        } elsif ($dbtype eq 'postgresql') {
            require Lstu::DB::URL::Pg;
            $c = Lstu::DB::URL::Pg->new(@_);
        } elsif ($dbtype eq 'mysql') {
            require Lstu::DB::URL::MySQL;
            $c = Lstu::DB::URL::MySQL->new(@_);
        }
    }

    return $c;
}

sub to_hash {
    my $c = shift;

    return {
        short      => $c->short,
        url        => $c->url,
        counter    => $c->counter,
        timestamp  => $c->timestamp,
        created_by => $c->created_by
    };
}

=head2 increment_counter

=over 1

=item B<Usage>     : C<$c-E<gt>increment_counter>

=item B<Arguments> : none

=item B<Purpose>   : increment the C<counter> attribute of the Lstu::DB::URL object and update the database record

=item B<Returns>   : the Lstu::DB::URL object

=back

=cut

sub increment_counter {
    my $c = shift;

    $c->app->dbi->db->query('UPDATE lstu SET counter = counter + 1 WHERE short = ?', $c->short);
    my $h = $c->app->dbi->db->query('SELECT counter FROM lstu WHERE short = ?', $c->short)->hashes->first;
    $c->counter($h->{counter});

    return $c;
}

=head2 write

=over 1

=item B<Usage>     : C<$c-E<gt>write>

=item B<Arguments> : none

=item B<Purpose>   : create or update the object in the database

=item B<Returns>   : the Lstu::DB::URL object

=back

=cut

sub write {
    my $c     = shift;

    if ($c->record) {
        $c->app->dbi->db->query('UPDATE lstu SET url = ?, counter = ?, timestamp = ?, created_by = ?, disabled = ? WHERE short = ?', $c->url, $c->counter, $c->timestamp, $c->created_by, $c->disabled, $c->short);
    } else {
        $c->app->dbi->db->query('INSERT INTO lstu (short, url, counter, timestamp, created_by, disabled) VALUES (?, ?, ?, ?, ?, ?)', $c->short, $c->url, $c->counter, $c->timestamp, $c->created_by, $c->disabled);
        $c->record(1);
    }

    return $c;
}

=head2 remove

=over 1

=item B<Usage>     : C<$c-E<gt>remove>

=item B<Arguments> : none

=item B<Purpose>   : remove the URL record from the database

=item B<Returns>   : 1 for success, 0 for failure

=back

=cut

sub remove {
    my $c = shift;

    my $removed = 0;

    if ($c->app->config('really_delete_urls')) {
        $c->app->dbi->db->query('DELETE FROM lstu WHERE short = ?', $c->short);
        my $count = $c->app->dbi->db->query('SELECT count(*) FROM lstu WHERE short = ?', $c->short)->hashes->first->{count};
        $removed = ($count == 0) ? 1 : 0;
    } else {
        $c->app->dbi->db->query('UPDATE lstu SET disabled = 1 WHERE short = ?', $c->short);
        $removed = $c->app->dbi->db->query('SELECT disabled FROM lstu WHERE short = ?', $c->short)->hashes->first->{disabled};
    }
    if ($removed) {
        if (scalar(@{$c->app->config('memcached_servers')})) {
            $c->app->chi('lstu_urls_cache')->remove($c->short);
        }
        $c = Lstu::DB::URL->new(app => $c->app);
    }
    return $removed;
}

=head2 exist

=over 1

=item B<Usage>     : C<$c-E<gt>exist('short')>

=item B<Arguments> : string

=item B<Purpose>   : count how many database record there is with C<short> equal to the argument.

eg: COUNT(short) WHERE short = ?, $argument

=item B<Returns>   : integer. Should be 0 or 1

=back

=cut

sub exist {
    my $c     = shift;
    my $short = shift;

    return undef unless $short;

    return $c->app->dbi->db->query('SELECT count(short) AS count FROM lstu WHERE short = ?', $short)->hashes->first->{count};
}

=head2 choose_empty

=over 1

=item B<Usage>     : C<$c-E<gt>choose_empty>

=item B<Arguments> : none

=item B<Purpose>   : choose an unassigned short string in the database

=item B<Returns>   : string, an unassigned short string

=back

=cut

sub choose_empty {
    my $c = shift;

    my $h = $c->app->dbi->db->query('SELECT * FROM lstu WHERE url IS NULL')->hashes->shuffle;

    if ($h->size) {
        $c->short($h->first->{short});
        $c->record(1);
        return $c;
    } else {
        return undef;
    }
}

=head2 count_empty

=over 1

=item B<Usage>     : C<$c-E<gt>count_empty>

=item B<Arguments> : none

=item B<Purpose>   : count how many unassigned short string there is in the database

eg: C<COUNT(short) WHERE url IS NULL>

=item B<Returns>   : integer

=back

=cut

sub count_empty {
    my $c = shift;

    return $c->app->dbi->db->query('SELECT count(short) AS count FROM lstu WHERE url IS NULL')->hashes->first->{count};
}

=head2 paginate

=over 1

=item B<Usage>     : C<$c-E<gt>paginate($page, $page_offset)>

=item B<Arguments> : two integers.

=over 2

=item B<$page>        : the number of the page you want

=item B<$page_offset> : the number of records per page.

=back

=item B<Purpose>   : returns all the URL records, page per page, ordered by the C<counter> attribute

eg: SELECT * WHERE url IS NOT NULL ORDER BY counter DESC LIMIT ? OFFSET ?, $page_offset, $page * $page_offset

=item B<Returns>   : an array of hash references, containing all the Lstu::DB::URL attributes, except C<dbtype>

=back

=cut

sub paginate {
    my $c           = shift;
    my $page        = shift;
    my $page_offset = shift;
    my $order       = shift // 'counter';
    my $dir         = shift // '-desc';

    return @{$c->app->dbi->db->select('lstu', undef, { url => { '!=', undef }, disabled => 0 }, { order_by => { $dir => $order }, limit => $page_offset, offset => $page * $page_offset })->hashes->to_array};
}

=head2 get_a_lot

=over 1

=item B<Usage>     : C<$c-E<gt>get_a_lot(['short1', 'short2'])>

=item B<Arguments> : an array reference of strings, which are C<short> attributes

=item B<Purpose>   : returns all the URL records which C<short> attribute are in the array ref

=item B<Returns>   : an array of hash references, containing all the Lstu::DB::URL attributes, except C<dbtype>

=back

=cut

sub get_a_lot {
    my $c = shift;
    my $u = shift;

    if (scalar @{$u}) {
        my $p = join ",", (('?') x @{$u});
        return @{$c->app->dbi->db->query('SELECT * FROM lstu WHERE short IN ('.$p.') ORDER BY counter DESC', @{$u})->hashes->to_array};
    } else {
        return ();
    }
}

=head2 total

=over 1

=item B<Usage>     : C<$c-E<gt>total>

=item B<Arguments> : none

=item B<Purpose>   : count how many shorten links there is in the database.

eg: C<COUNT(short) WHERE url IS NOT NULL>

=item B<Returns>   : integer

=back

=cut

sub total {
    my $c = shift;

    return $c->app->dbi->db->query('SELECT count(short) AS count FROM lstu WHERE url IS NOT NULL AND disabled = 0')->hashes->first->{count};
}

=head2 delete_all

=over 1

=item B<Usage>     : C<$c-E<gt>delete_all>

=item B<Arguments> : none

=item B<Purpose>   : delete all URL records from database unconditionnally

=item B<Returns>   : nothing is expected

=back

=cut

sub delete_all {
    my $c = shift;

    $c->app->dbi->db->query('DELETE FROM lstu');
}

=head2 search_url

=over 1

=item B<Usage>     : C<$c-E<gt>search_url($string)>

=item B<Arguments> : string, part of URL to search

=item B<Purpose>   : search records which real url matches the given string

=item B<Returns>   : a Mojo::Collection containing hashes of the matching records

=back

=cut

sub search_url {
    my $c = shift;
    my $s = shift;

    $c->app->dbi->db->select('lstu', undef, { url => {-like => '%'.$s.'%'}})->hashes;
}

=head2 search_creator

=over 1

=item B<Usage>     : C<$c-E<gt>search_creator($string)>

=item B<Arguments> : string, IP address to search

=item B<Purpose>   : search records which creator's IP address matches the given string

=item B<Returns>   : a Mojo::Collection containing hashes of the matching records

=back

=cut

sub search_creator {
    my $c = shift;
    my $s = shift;

    $c->app->dbi->db->select('lstu', undef, { created_by => $s })->hashes;
}

=head2 get_all_urls

=over 1

=item B<Usage>     : C<$c-E<gt>get_all_urls()>

=item B<Arguments> : none

=item B<Purpose>   : return all non-empty records

=item B<Returns>   : a Mojo::Collection containing hashes of all non-empty records

=back

=cut

sub get_all_urls {
    my $c = shift;

    $c->app->dbi->db->select('lstu', undef, { url => { '!=', undef } })->hashes;
}

=head2 get_all_urls_created_ago

=over 1

=item B<Usage>     : C<$c-E<gt>get_all_urls_created_ago($seconds)>

=item B<Arguments> : integer, number of seconds

=item B<Purpose>   : return all non-empty records created less than $seconds agog

=item B<Returns>   : a Mojo::Collection containing hashes of matching records

=back

=cut

sub get_all_urls_created_ago {
    my $c     = shift;
    my $delay = shift;

    $c->app->dbi->db->select('lstu', undef, { url => { '!=', undef }, timestamp => { '>=', time - $delay } })->hashes;
}

=head2 _slurp

=over 1

=item B<Usage>     : C<$c-E<gt>_slurp>

=item B<Arguments> : none

=item B<Purpose>   : put a database record's columns into the Lstu::DB::URL object's attributes

=item B<Returns>   : the Lstu::DB::URL object

=back

=cut

sub _slurp {
    my $c = shift;

    my $h;
    if ($c->short) {
       $h = $c->app->dbi->db->query('SELECT * FROM lstu WHERE short = ?', $c->short)->hashes;
   } else {
       $h = $c->app->dbi->db->query('SELECT * FROM lstu WHERE url = ?', $c->url)->hashes;
   }
    if ($h->size) {
        $c->url($h->first->{url});
        $c->short($h->first->{short});
        $c->counter($h->first->{counter});
        $c->timestamp($h->first->{timestamp});
        $c->created_by($h->first->{created_by});
        $c->disabled($h->first->{disabled});
        $c->record(1);
    }

    return $c;
}

1;

# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::URL;
use Mojo::Base -base;

has 'short';
has 'url';
has 'counter' => 0;
has 'timestamp';
has 'app';

=head1 NAME

Lstu::DB::URL - Abstraction layer for Lstu session system

=head1 Contributing

When creating a new database accessor, make sure that it provides the following subroutines.
After that, modify this file and modify the C<new> subroutine to allow to use your accessor.

Have a look at Lstu::DB::URL::SQLite's code: it's simple and may be more understandable that this doc.

=head1 Attributes

=over 1

=item B<short>     : random string

=item B<url>       : string, valid URL

=item B<counter>   : integer

=item B<timestamp> : unix timestamp

=item B<app>       : a mojolicious object

=back

=head1 Sub routines

=head2 new

=over 1

=item B<Usage>     : C<$c = Lstu::DB::URL-E<gt>new(app =E<gt> $self);>

=item B<Arguments> : any of the attribute above

=item B<Purpose>   : construct a new db accessor object. If the C<short> or the C<url> attribute is provided, it have to load the informations from the database. In the case of multiple records for the same C<url>, choose the first.

=item B<Returns>   : the db accessor object

=item B<Info>      : the app argument is used by Lstu::DB::URL to choose which db accessor will be used, you don't need to use it in new(), but you can use it to access helpers or configuration settings in the other subroutines

=back

=cut

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    if (ref($c) eq 'Lstu::DB::URL') {
        my $dbtype = $c->app->config('dbtype');
        if ($dbtype eq 'sqlite') {
            use Lstu::DB::URL::SQLite;
            $c = Lstu::DB::URL::SQLite->new(@_);
        } elsif ($dbtype eq 'postgresql') {
            use Lstu::DB::URL::Pg;
            $c = Lstu::DB::URL::Pg->new(@_);
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

=head2 increment_counter

=over 1

=item B<Usage>     : C<$c-E<gt>increment_counter>

=item B<Arguments> : none

=item B<Purpose>   : increment the C<counter> attribute of the db accessor object and update the database record

=item B<Returns>   : the db accessor object

=back

=head2 write

=over 1

=item B<Usage>     : C<$c-E<gt>write>

=item B<Arguments> : none

=item B<Purpose>   : create or update the object in the database

=item B<Returns>   : the db accessor object

=back

=head2 delete

=over 1

=item B<Usage>     : C<$c-E<gt>delete>

=item B<Arguments> : none

=item B<Purpose>   : delete the URL record from the database

=item B<Returns>   : the db accessor object

=back

=head2 exist

=over 1

=item B<Usage>     : C<$c-E<gt>exist('short')>

=item B<Arguments> : string

=item B<Purpose>   : count how many database record there is with C<short> equal to the argument.

eg: COUNT(short) WHERE short = ?, $argument

=item B<Returns>   : integer. Should be 0 or 1

=back

=head2 choose_empty

=over 1

=item B<Usage>     : C<$c-E<gt>choose_empty>

=item B<Arguments> : none

=item B<Purpose>   : choose an unassigned short string in the database

=item B<Returns>   : string, an unassigned short string

=back

=head2 count_empty

=over 1

=item B<Usage>     : C<$c-E<gt>count_empty>

=item B<Arguments> : none

=item B<Purpose>   : count how many unassigned short string there is in the database

eg: C<COUNT(short) WHERE url IS NULL>

=item B<Returns>   : integer

=back

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

=head2 get_a_lot

=over 1

=item B<Usage>     : C<$c-E<gt>paginate(['short1', 'short2'])>

=item B<Arguments> : an array reference of strings, which are C<short> attributes

=item B<Purpose>   : returns all the URL records which C<short> attribute are in the array ref

=item B<Returns>   : an array of hash references, containing all the Lstu::DB::URL attributes, except C<dbtype>

=back

=head2 total

=over 1

=item B<Usage>     : C<$c-E<gt>total>

=item B<Arguments> : none

=item B<Purpose>   : count how many shorten links there is in the database.

eg: C<COUNT(short) WHERE url IS NOT NULL>

=item B<Returns>   : integer

=back

=head2 delete_all

=over 1

=item B<Usage>     : C<$c-E<gt>delete_all>

=item B<Arguments> : none

=item B<Purpose>   : delete all URL records from database unconditionnally

=item B<Returns>   : nothing is expected

=back

=cut

1;

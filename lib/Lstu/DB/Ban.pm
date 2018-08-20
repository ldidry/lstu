# vim:set sw=4 ts=4 sts=4 ft=perl expandtab:
package Lstu::DB::Ban;
use Mojo::Base -base;

has 'ip';
has 'until';
has 'strike' => 0;
has 'app';

=head1 NAME

Lstu::DB::Ban - Abstraction layer for Lstu ban system

=head1 Contributing

When creating a new database accessor, make sure that it provides the following subroutines.
After that, modify this file and modify the C<new> subroutine to allow to use your accessor.

Have a look at Lstu::DB::Ban::SQLite's code: it's simple and may be more understandable that this doc.

=head1 Attributes

=over 1

=item B<ip>     : string, an IP address

=item B<until>  : unix timestamp

=item B<strike> : integer

=item B<app>    : a mojolicious object

=back

=head1 Sub routines

=head2 new

=over 1

=item B<Usage>     : C<$c = Lstu::DB::Ban-E<gt>new(app =E<gt> $self);>

=item B<Arguments> : any of the attribute above

=item B<Purpose>   : construct a new db accessor object. If the C<ip> attribute is provided, it have to load the informations from the database

=item B<Returns>   : the db accessor object

=item B<Info>      : the app argument is used by Lstu::DB::Ban to choose which db accessor will be used, you don't need to use it in new(), but you can use it to access helpers or configuration settings in the other subroutines

=back

=cut

sub new {
    my $c = shift;

    $c = $c->SUPER::new(@_);

    if (ref($c) eq 'Lstu::DB::Ban') {
        my $dbtype = $c->app->config('dbtype');
        if ($dbtype eq 'sqlite') {
            require Lstu::DB::Ban::SQLite;
            $c = Lstu::DB::Ban::SQLite->new(@_);
        } elsif ($dbtype eq 'postgresql') {
            require Lstu::DB::Ban::Pg;
            $c = Lstu::DB::Ban::Pg->new(@_);
        } elsif ($dbtype eq 'mysql') {
            require Lstu::DB::Ban::MySQL;
            $c = Lstu::DB::Ban::MySQL->new(@_);
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

=head2 is_whitelisted

=over 1

=item B<Usage>     : C<$c-E<gt>is_whitelisted>

=item B<Arguments> : none

=item B<Purpose>   : tells you if the current object is in the configured whitelisted IPs

=item B<Returns>   : boolean

=back

=cut

sub is_whitelisted {
    my $c = shift;

    my $ip = $c->ip;
    return scalar(grep(sub { $_ eq $ip }, @{$c->app->config('ban_whitelist')}));
}

=head2 is_blacklisted

=over 1

=item B<Usage>     : C<$c-E<gt>is_blacklisted>

=item B<Arguments> : none

=item B<Purpose>   : tells you if the current object is in the configured blacklisted IPs

=item B<Returns>   : boolean

=back

=cut

sub is_blacklisted {
    my $c = shift;

    my $ip = $c->ip;
    return scalar(grep(sub { $_ eq $ip }, @{$c->app->config('ban_blacklist')}));
}

=head2 is_banned

=over 1

=item B<Usage>     : C<$c-E<gt>is_banned(3)>

=item B<Arguments> : an integer. Will be config('ban_min_strike'), which is the number of strike before being banned (default: 3)

=item B<Purpose>   : check the db record with C<ip> equal to the object's ip attribute if C<until> is superior to current time and if C<strike> is superior or equal to the argument.

eg: C<WHERE ip = ? AND until E<gt> ? AND strike E<gt>= ?', $c->ip, time, $argument>

=item B<Returns>   : the db accessor object if the ip is banned, undef otherwise

=item B<Info>      : if the IP is whitelisted (see C<is_whitelisted> above), it must return undef

=back

=head2 increment_ban_delay

=over 1

=item B<Usage>     : C<$c-E<gt>increment_ban_delay(3600)>

=item B<Arguments> : an integer. This number is a penalty (in second) that will be added to the C<until> attribute of the db accessor object

=item B<Purpose>   : add penalty to the C<until> attribute of the db accessor object, increment the C<strike> attribute by one and write the db accessor object's attribute to the database.
Update the database record if one already exists, create one otherwise.

=item B<Returns>   : the db accessor object

=back

=head2 clear

=over 1

=item B<Usage>     : C<$c-E<gt>clear>

=item B<Arguments> : none

=item B<Purpose>   : delete all ban records from database where until < time

eg: C<WHERE until E<lt> ?, time>

=item B<Returns>   : nothing is expected

=back

=head2 delete_all

=over 1

=item B<Usage>     : C<$c-E<gt>delete_all>

=item B<Arguments> : none

=item B<Purpose>   : delete all ban records from database unconditionnally

=item B<Returns>   : nothing is expected

=back

=cut

1;

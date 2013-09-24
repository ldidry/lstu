package LstuModel;

# Create database
use ORLite {
      file    => 'lstu.db',
      unicode => 1,
      create  => sub {
          my $dbh = shift;
          $dbh->do(
              'CREATE TABLE lstu (
               short     TEXT PRIMARY KEY,
               url       TEXT,
               counter   INTEGER,
               timestamp INTEGER)'
          );
          return 1;
        }
};

1;

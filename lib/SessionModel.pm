package SessionModel;

# Create database
use ORLite {
      file    => 'sessions.db',
      unicode => 1,
      create  => sub {
          my $dbh = shift;
          $dbh->do(
              'CREATE TABLE sessions (
              token TEXT PRIMARY KEY,
              until INTEGER)'
          );
          return 1;
        }
};

1;

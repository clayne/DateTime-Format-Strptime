use strict;
use warnings;

use Test::More 0.96;
use Test::Fatal;

use DateTime::Format::Strptime;

for my $test ( _tests_from_data() ) {
    subtest(
        qq{$test->{name}},
        sub {
            my $parser;
            is(
                exception {
                    $parser = DateTime::Format::Strptime->new(
                        pattern => $test->{pattern},
                        (
                            $test->{locale}
                            ? ( locale => $test->{locale} )
                            : ()
                        ),
                        on_error => 'croak',
                    );
                },
                undef,
                "no exception building parser for $test->{pattern}"
            ) or return;

            ( my $real_input = $test->{input} ) =~ s/\\n/\n/g;
            my $dt;
            is(
                exception { $dt = $parser->parse_datetime( $real_input ) },
                undef,
                "no exception parsing $test->{input}"
            ) or return;

            _test_dt_methods( $dt, $test->{expect} );

            unless ( $test->{skip_round_trip} ) {
                is(
                    $parser->format_datetime($dt),
                    $real_input,
                    'round trip via strftime produces original input'
                );
            }
        }
    );
}

subtest(
    'parsing whitespace',
    sub {
        my $parser = DateTime::Format::Strptime->new(
            pattern  => '%n%Y%t%m%n',
            on_error => 'croak',
        );

        my $dt = $parser->parse_datetime(<<"EOF");
\t
  2015
12
EOF

        my %expect = (
            year  => 2015,
            month => 12,
        );
        _test_dt_methods( $dt, \%expect );
    }
);

subtest(
    'parser time zone is set on returned object',
    sub {
        my $parser = DateTime::Format::Strptime->new(
            pattern   => '%Y %H:%M:%S %Z',
            time_zone => 'America/New_York',
            on_error  => 'croak',
        );

        my $dt     = $parser->parse_datetime('2003 23:45:56 MDT');
        my %expect = (
            year                => 2003,
            hour                => 0,
            minute              => 45,
            second              => 56,
            time_zone_long_name => 'America/New_York',
        );

        _test_dt_methods( $dt, \%expect );
    }
);

sub _tests_from_data {
    my @tests;

    my $d = do { local $/; <DATA> };

    my $test_re = qr/
        \[(.+?)\]\n             # test name
        (.+?)\n                 # pattern
        (.+?)\n                 # input
        (?:locale = (.+)\n)?    # optional locale
        (skip\ round\ trip\n)?  # skip a round trip?
        (.+?)\n                 # k-v pairs for expected values
        (?:\n|\z)               # end of test
                    /xs;

    while ( $d =~ /$test_re/g ) {
        push @tests, {
            name            => $1,
            pattern         => $2,
            input           => $3,
            locale          => $4,
            skip_round_trip => $5,
            expect          => {
                map { split /\s+=>\s+/ } split /\n/, $6,
            },
        };
    }

    return @tests;
}

sub _test_dt_methods {
    my $dt     = shift;
    my $expect = shift;

    for my $meth ( sort keys %{$expect} ) {
        is(
            $dt->$meth,
            $expect->{$meth},
            "$meth is $expect->{$meth}"
        );
    }
}

done_testing();

__DATA__
[ISO8601]
%Y-%m-%dT%H:%M:%S
2015-10-08T15:39:44
year   => 2015
month  => 10
day    => 8
hour   => 15
minute => 39
second => 44

[date with 4-digit year]
%Y-%m-%d
1998-12-31
year  => 1998
month => 12
day   => 31

[date with 2-digit year]
%y-%m-%d
98-12-31
year  => 1998
month => 12
day   => 31

[date with leading space on month]
%e-%b-%Y
 3-Jun-2010
year  => 2010
month => 6
day   => 3

[year and day of year]
%Y years %j days
1998 years 312 days
year  => 1998
month => 11
day   => 8

[date with abbreviated month]
%b %d %Y
Jan 24 2003
year  => 2003
month => 1
day   => 24

[date with abbreviated month is case-insensitive]
%b %d %Y
jAN 24 2003
skip round trip
year  => 2003
month => 1
day   => 24

[date with full month]
%B %d %Y
January 24 2003
year  => 2003
month => 1
day   => 24

[date with full month is case-insensitive]
%B %d %Y
jAnUAry 24 2003
skip round trip
year  => 2003
month => 1
day   => 24

[24 hour time]
%H:%M:%S
23:45:56
year   => 1
month  => 1
day    => 1
hour   => 23
minute => 45
second => 56

[12 hour time (PM)]
%l:%M:%S %p
11:45:56 PM
year   => 1
month  => 1
day    => 1
hour   => 23
minute => 45
second => 56

[12 hour time (am) and am/pm is case-insensitive]
%l:%M:%S %p
11:45:56 am
skip round trip
year   => 1
month  => 1
day    => 1
hour   => 11
minute => 45
second => 56

[24-hour time]
%T
23:34:45
hour   => 23
minute => 34
second => 45

[12-hour time]
%r
11:34:45 PM
hour   => 23
minute => 34
second => 45

[24-hour time without second]
%R
23:34
hour   => 23
minute => 34
second => 0

[US style date]
%D
11/30/03
year  => 2003
month => 11
day   => 30

[ISO style date]
%F
2003-11-30
year  => 2003
month => 11
day   => 30

[nanosecond with no length]
%H:%M:%S.%N
23:45:56.123456789
hour       => 23
minute     => 45
second     => 56
nanosecond => 123456789

[nanosecond with length of 6]
%H:%M:%S.%6N
23:45:56.123456
hour       => 23
minute     => 45
second     => 56
nanosecond => 123456000

[nanosecond with length of 3]
%H:%M:%S.%3N
23:45:56.123
hour       => 23
minute     => 45
second     => 56
nanosecond => 123000000

[time zone as numeric offset]
%H:%M:%S %z
23:45:56 +1000
hour       => 23
minute     => 45
second     => 56
offset     => 36000

[time zone as abbreviation]
%H:%M:%S %Z
23:45:56 AEST
skip round trip
hour       => 23
minute     => 45
second     => 56
offset     => 36000

[time zone as Olson name]
%H:%M:%S %O
23:45:56 America/Chicago
hour   => 23
minute => 45
second => 56
time_zone_long_name => America/Chicago

[escaped percent]
%Y%%%m%%%d
2015%05%14
year  => 2015
month => 5
day   => 14

[escaped percent followed by letter token]
%Y%%%m%%%d%%H
2015%05%14%H
year  => 2015
month => 5
day   => 14

[every pattern]
%a %b %B %C %d %e %h %H %I %j %k %l %m %M %n %N %O %p %P %S %U %u %w %W %y %Y %s %G %g %z %Z %%Y %%
Wed Nov November 20 05  5 Nov 23 11 309 23 11 11 34 \n 123456789 America/New_York PM pm 45 44 3 3 44 03 2003 1068093285 2003 03 -0500 EST %Y %
year   => 2003
month  => 11
day    => 5
hour   => 23
minute => 34
second => 45
nanosecond => 123456789
time_zone_long_name => America/New_York

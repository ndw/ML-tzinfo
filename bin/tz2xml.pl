#!/usr/bin/perl -- # -*- Perl -*-

use strict;
use English;
use Time::Local;

my $zone = undef;

my %MONTHS = ( 'Jan' => '01', 'Feb' => '02', 'Mar' => '03', 'Apr' => '04',
               'May' => '05', 'Jun' => '06', 'Jul' => '07', 'Aug' => '08',
               'Sep' => '09', 'Oct' => '10', 'Nov' => '11', 'Dec' => '12' );

print "<tzinfo xmlns='http://nwalsh.com/xmlns/pim/tzinfo'>\n";

while (my $file = shift @ARGV) {
    print "<!-- $file -->\n";
    open (F, $file);
    while (<F>) {
        chop;
        next if /^\s*\#/;
        next if /^\s*$/;

        s/\s*\#.*$//;

        if (/^Rule\s/) {
            parseRule($_);
        } elsif (/^Zone\s/ or /^\s/) {
            parseZone($_);
        } elsif (/^Link\s/) {
            parseLink($_);
        } else {
            die "Invalid tzinfo: $_\n";
        }
    }
    close (F);
}

print "</tzinfo>\n";

sub parseRule {
    local $_ = shift;
    my @parts = split(/\s+/, $_);
    shift @parts;

    my $name = shift @parts;
    my $from = shift @parts;
    my $to   = shift @parts;
    my $type = shift @parts;
    my $in   = shift @parts;
    my $on   = shift @parts;
    my $at   = shift @parts;
    my $save = shift @parts;
    my $s    = shift @parts;

    die "Invalid tzinfo: $_\n" if @parts;

    $to = $from if $to eq 'only';
    $to = 9999 if $to eq 'max';

    # Patch exceptions
    $at = "0:00" if $at eq '0';
    $save = "0:00" if $save eq '0';

    # I have no idea what the 's' and 'u' flags mean, dropping them.
    if ($at =~ /^(\d+):(\d+)[su]?$/) {
        $at = sprintf("%02d:%02d", $1, $2);
    } else {
        print STDERR "Unexpected at: $_\n";
    }

    if ($save =~ /^(\d+):(\d+)$/) {
        $save = "PT$1H$2M";
    } else {
        print STDERR "Unexpected save: $_\n";
    }

    $on = sprintf("%02d", $on) if $on =~ /^(\d+)$/;

    if (exists($MONTHS{$in})) {
        $in = $MONTHS{$in};
    } else {
        print STDERR "Unexpected in: $_\n";
    }

    my $dt = undef;
    if (($from eq $to) && ($in =~ /^\d+$/) && ($on =~ /^\d+$/) && ($at =~ /^\d+:\d+[us]?$/)) {
        $at =~ /^(\d+):(\d+)[us]?$/;
        $dt = sprintf("%04d-%02d-%02dT%02d:%02d:00", $from, $in, $on, $1, $2);
    }

    print "<rule name='$name' from='$from' to='$to' ";
    print "dt='$dt' " if defined($dt);
    print "type='$type' " unless $type eq '-';
    print "in='$in' on='$on' at='$at' save='$save' s='$s'";
    print "/>\n";
}

sub parseZone {
    local $_ = shift;
    s/^\s*//;

    my @parts = split(/\s+/, $_);

    if ($parts[0] eq 'Zone') {
        shift @parts;
        $zone = shift @parts;
    }

    my $off = shift @parts;
    my $rules = shift @parts;
    my $format = shift @parts;
    my $until = undef;
    $until = join(' ', @parts) if @parts;

    # I have no idea what the 's' and 'u' flags mean, dropping them.

    if ($off =~ /^(-)?(\d+):(\d+)(:(\d+))?$/) {
        $off = "$1PT$2H$3M";
        $off .= "$5S" if defined($5);
    } elsif ($off =~ /^(-)?(\d+)$/) {
        $off = "$1PT$2H";
    } else {
        print STDERR "Unexpected off: $_\n";
    }

    if (!defined($until)) {
        # nop;
    } elsif ($until =~ /^\d\d\d\d$/) {
        $until = "$until-01-01T00:00:00";
    } elsif ($until =~ /^(\d\d\d\d) (\S+) (\d+)( (\d+):(\d+)(:\d+)?[su]?)?$/) {
        my $year = $1;
        my $month = $MONTHS{$2};
        my $day = $3;
        my $hour = $5 || 0;
        my $min = $6 || 0;
        my $sec = $7 || 0;
        $until = sprintf("%4d-%02d-%02dT%02d:%02d:%02d",
                         $year, $month, $day, $hour, $min, $sec);
    } elsif ($until =~ /^(\d\d\d\d) (\S+)$/) {
        $until = sprintf("%4d-%02d-01T00:00:00", $1, $MONTHS{$2});
    } elsif ($until =~ /^(\d\d\d\d) (\S+) last(\S+)( (\d+):(\d+)(:(\d+))?[su]?)?$/) {
        my $year = $1;
        my $month = $MONTHS{$2};
        my $day = $3;
        my $hour = $5 || 0;
        my $min = $6 || 0;
        my $sec = $8 || 0;

        my $targetday = undef;
        $targetday = 0 if $day eq 'Sun';
        $targetday = 6 if $day eq 'Sat';
        die "No target day? $day\n" if !defined($targetday);

        # Work outt the last $day in $year/$month
        my $nextyear = $year;
        my $nextmonth = $month + 1;
        if ($nextmonth > 12) {
            $nextyear++;
            $nextmonth = 1;
        }

        my $time = timegm(0, 0, 0, 1, $nextmonth-1, $nextyear);
        $time -= 86400; # last day of month
        my ($xsec,$xmin,$xhour,$xmday,$xmon,$xyear,$xwday,$xyday,$xisdst) = gmtime($time);
        while ($xwday != $targetday) {
            $time -= 86400; # previous day
            ($xsec,$xmin,$xhour,$xmday,$xmon,$xyear,$xwday,$xyday,$xisdst) = gmtime($time);
        }

        $until = sprintf("%4d-%02d-%02dT%02d:%02d:%02d",
                         $year, $xmon+1, $xmday, $hour, $min, $sec);
    } elsif ($until =~ /^(\d\d\d\d) (\S+) Sun>=1 (\d+):(\d+)(:(\d+))?[su]?$/) {
        my $year = $1;
        my $month = $MONTHS{$2};
        my $hour = $3 || 0;
        my $min = $4 || 0;
        my $sec = $6 || 0;

        my $targetday = 0;

        my $time = timegm(0, 0, 0, 1, $month-1, $year);
        my ($xsec,$xmin,$xhour,$xmday,$xmon,$xyear,$xwday,$xyday,$xisdst) = gmtime($time);
        while ($xwday != $targetday) {
            $time += 86400; # next day
            ($xsec,$xmin,$xhour,$xmday,$xmon,$xyear,$xwday,$xyday,$xisdst) = gmtime($time);
        }

        $until = sprintf("%4d-%02d-%02dT%02d:%02d:%02d",
                         $year, $xmon+1, $xmday, $hour, $min, $sec);
    } else {
        print STDERR "Until when? $until\n";
    }

    print "<zone name='$zone' rule='$rules' gmtoff='$off' format='$format' ";
    print "until='$until' " if defined($until);
    print "/>\n";
}

sub parseLink {
    local $_ = shift;
    s/^\s*//;

    my @parts = split(/\s+/, $_);

    shift @parts;
    my $to = shift @parts;
    my $from = shift @parts;

    die "Invalid tzinfo: $_\n" if @parts;

    print "<link from='$from' to='$to'/>\n";
}

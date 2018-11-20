#!/usr/bin/perl -- # -*- Perl -*-

# This script reads the tz_world shape files files and produces an XML representation.
#
# Usage: perl shape2xml.pl [-p postURI ] tz_world_mp.shp

use strict;
use English;
use Geo::ShapeFile;
use Getopt::Std;
use LWP;
use vars qw($opt_p);

my $usage = "$0 [-p postto] shapefile\n";

die $usage if ! getopts('p:');

my $postURI = $opt_p;
my $username = "admin";
my $password = "admin";

my $shapefn = shift @ARGV || die $usage;
my $shapefile = new Geo::ShapeFile($shapefn);

my $ua = undef;
if ($postURI) {
    $ua = new LWP::UserAgent;
    $ua->timeout(1200);
    $ua->ssl_opts('verify_hostname' => 0, 'SSL_verify_mode' => 0x00);
}

foreach my $id (1 .. $shapefile->shapes()) {
    my %dbf = $shapefile->get_dbf_record($id);
    my $name = $dbf{'tzid'};
    my $shape = $shapefile->get_shp_record($id);

    next if $name eq 'uninhabited'; # not sure what to do with these

    die unless $name =~ /^(.*)\/([^\/]+)$/;
    my $dir = $1;
    my $xml = "$2.xml";

    my $data = "";

    $data .= "<timezone xmlns='http://nwalsh.com/ns/tzpolygon' ";
    $data .= "type='" . $shapefile->type($shape->shape_type()) . "'>\n";
    $data .= "<name>$name</name>\n";
    $data .= "<boundary>\n";
    for my $point ($shape->upper_left_corner(), $shape->upper_right_corner(),
                   $shape->lower_right_corner(), $shape->lower_left_corner(),
                   $shape->upper_left_corner()) {
        $data .= $point->Y() . "," . $point->X() . "\n";
    }
    $data .= "</boundary>\n";

    my $shapecount = $shape->num_parts();
    for (my $partno = 1; $partno <= $shapecount; $partno++) {
        my @part = $shape->get_part($partno);

        if ($part[0]->Y() != $part[$#part]->Y()
            || $part[0]->X() != $part[$#part]->X()) {
            print STDERR "Not a closed polygon? $name $partno\n";
        }

        $data .= "<polygon vcount='" . ($#part+1) . "'>\n";
        for (my $pointno = 0; $pointno <= $#part; $pointno++) {
            $data .= $part[$pointno]->Y() . "," . $part[$pointno]->X();
            $data .= $pointno % 2 eq 0 ? " " : "\n";
        }
        $data .= "</polygon>\n";
    }

    $data .= "</timezone>\n";

    if ($name =~ /Etc/) {
        print STDERR "Skip $name\n";
    } else {
        if ($postURI) {
            postXML($data);
        } else {
            saveXML($data, $dir, $xml);
        }
    }
}

sub saveXML {
    my $data = shift;
    my $dir = shift;
    my $xml = shift;
    mkpath($dir) unless -d $dir;
    open (TZ, ">$dir/$xml");
    print TZ $data;
    close (TZ);
    print "Stored $dir/$xml\n";
}

sub postXML {
    my $data = shift;

    my $req = new HTTP::Request('POST' => $postURI);
    $req->content($data);
    $req->header("Content-Type" => "application/xml");

    # Insert your authentication details here

    my $resp = $ua->request($req);

    if ($resp->code() == 401 && defined($username) && defined($password)) {
        #print "Authentication required. Trying again with specified credentials.\n";

        my $host = $postURI;
        $host =~ s/^.*?\/([^\/]+).*?$/$1/;

        my $realm = scalar($resp->header('WWW-Authenticate'));
        if ($realm =~ /realm=[\'\"]/) {
            $realm =~ s/^.*?realm=([\'\"])(.*?)\1.*$/$2/;
        } else {
            $realm =~ s/^.*?realm=(.*?)$/$1/;
        }

        # print "Auth: $host, $realm, $username, $password\n";

        $ua->credentials($host, $realm, $username => $password);
        $resp = $ua->request($req);
    }

    die "POST failed: " . $resp->code() . "\n" . $resp->content()
        unless $resp->code eq 200;

    print $resp->content(), "\n";
}

sub mkpath {
    my $path = shift;
    my @dirs = split(/\//, $path);
    $path = "";
    while (@dirs) {
        $path .= "/" unless $path eq '';
        $path .= shift @dirs;
        if (! -d $path) {
            mkdir ($path, 0755) || die "Failed to mkdir: $path\n";
        }
    }
}

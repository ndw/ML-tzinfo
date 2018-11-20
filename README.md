# ML-tzinfo

XQuery and REST interface to the Internet timezone data.

This library relies on MarkLogic 9.0 or later geospatial region
indexes. The last version that worked without the region indexes
feature is tagged `v80` in the repository.

There’s no upgrade path. If you are running the older version and wish to
upgrade, simply create a new database and start over there. The maps data
is stored in a completely different way to take advantage of the region
path indexes.

The library provides two functions:

1. Given a dateTime and a timezone, it will return the corresponding UTC time.

1. Given a latitude and longitude, it will return the timezone of that location.
   This works only for points inside the boundaries of the timezone shapes.
   It makes no effort to handle the timezone of coordinates at sea, for example.

## Getting started

The ability to convert a dateTime and a timezone to UTC requires a copy of the
[Time Zone Database](http://www.iana.org/time-zones). The ability to convert a
latitude and longitude into a timezone requires a copy of the shape files
from [timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder).
Because these resources change frequently, they are not included in this distribution.

### Installing the MarkLogic Server components

MarkLogic Server V9.0 or later is required.

The easiest way is to load `bin/setup-tzinfo.xml` into QConsole, edit the variables
at the top to suit your needs, and run the query.

If you want to do it "by hand":

1. Create a database for the timezone data. If you're going to use the
   maps functionality, you may want to give it a few forests as the
   map data is quite large. Enable the collection lexicon.

2. Create an HTTP appserver and point it at your timezone database.
   You can put it on any port you like. Point the root of the
   appserver at the `modules` directory in this distribution (or copy those
   files into a modules database).

3. For the purposes of this document, I'm assuming that the appserver
   runs on localhost:8302. You must specify `/rewriter.xml` as the URL
   rewriter for the server.

4. Create a `timezone-user` role. Users with this role will be able to
   read the timezone rules and maps.

### Installing the Time Zone Database

1. Download the most recent [Time Zone Database](http://www.iana.org/time-zones).
   On 19 November 2018, the most recent version was
   [tzdata2018g.tar.gz](https://data.iana.org/time-zones/releases/tzdata2018g.tar.gz).

2. Expand this archive somewhere.

3. Run the `bin/tz2xml.pl` script to convert the database into XML and upload it:

        perl bin/tz2xml.pl -p http://localhost:8302/upload \
             africa antarctica asia australasia backward etcetera \
             europe northamerica pacificnew southamerica

   If you need a username/password to access the server, you'll have to edit those
   variables in the script. You will also need to require authentication at least
   temporarily. The upload script requires admin rights.

   If you prefer, you can leave out the `-p` option and upload the data
   file by some other means.

4. You can discard the timezone data and the XML file at this point if you want to.

### Installing the time zone maps

1. Download the most recent
   [timezone-boundary-builder](https://github.com/evansiroky/timezone-boundary-builder)
   shapefiles.

2. Expand this archive somewhere.

3. Run the `bin/shape2xml.pl` script to convert the shapefile into XML and upload it:

        perl bin/shape2xml.pl -p http://localhost:8302/upload \
             combined-shapefile-with-oceans.shp

   If you need a username/password to access the server, you'll have
   to edit those variables in the script. You will also need to
   require authentication at least temporarily. The upload script
   requires admin rights.

   If you prefer, you can leave out the `-p` option and upload the data
   file by some other means.

   Converting the same file takes a while and uploads (or writes to disk) a large
   number of files.

4. You can discard the shapefile and any XML saved at this point if you want to.

## Test it

Setup https: on your application server. (The sample application uses
the geolocation API which requires https:)

Check that it works: [https://localhost:8302/](https://localhost:8302/)

# ML-tzinfo

XQuery and REST interface to the Internet timezone data.

This library provides two functions:

1. Given a dateTime and a timezone, it will return the corresponding UTC time.

1. Given a latitude and longitude, it will return the timezone of that location.
   This works only for points inside the boundaries of the timezone shapes.
   It makes no effort to handle the timezone of coordinates at sea, for example.

## Getting started

The ability to convert a dateTime and a timezone to UTC requires a copy of the
[Time Zone Database](http://www.iana.org/time-zones). The ability to convert a
latitude and longitude into a timezone requires a copy of
[tz_world](http://efele.net/maps/tz/world/). Because these resources change frequently,
they are not included in this distribution.

### Installing the MarkLogic Server components

The easiest way is to load `bin/setup-tzinfo.xml` into QConsole, edit the variables
at the top to suit your needs, and run the query.

If you want to do it "by hand":

1. Create a database for the timezone data. If you're going to use the
   maps functionality, you may want to give it a few forests as the
   map data runs in excess of half a terabyte. Enable the collection
   lexicon.

2. Create an HTTP appserver and point it at your timezone database.
   You can put it on any port you like. Point the root of the
   appserver at the `MLS` directory in this distribution.

3. For the purposes of this document, I'm assuming that the appserver
   runs on localhost:8302.

4. Create a `timezone-user` role. Users with this role will be able to
   read the timezone rules and maps.

### Installing the Time Zone Database

1. Download the most recent [Time Zone Database](http://www.iana.org/time-zones).
   On 05 November 2013, the most recent version was
   [tzdata2013h.tar.gz](http://www.iana.org/time-zones/repository/releases/tzdata2013h.tar.gz)

2. Expand this archive somewhere.

3. Run the `bin/tz2xml.pl` script to convert the database into XML and upload it:

        perl bin/tz2xml.pl -p http://localhost:8302/upload.xqy \
             africa antarctica asia australasia backward etcetera \
             europe northamerica pacificnew southamerica

   If you need a username/password to access the server, you'll have to edit those
   variables in the script.

   If you prefer, you can leave out the `-p` option and upload the data
   file by some other means.

4. You can discard the timezone data and the XML file at this point if you want to.

### Installing the time zone maps

1. Download the most recent [tz\_world](http://efele.net/maps/tz/world/) shapefile.
   Get the "mp" version that has a single geometry for each timezone.
   On 25 May 2013, the most recent version was
   [tz\_world\_mp.zip](http://efele.net/maps/tz/world/tz_world_mp.zip).

2. Expand this archive somewhere.

3. Run the `bin/shape2xml.pl` script to convert the shapefile into XML and upload it:

        perl bin/shape2xml.pl -p http://localhost:8302/upload.xqy tz_world_mp.shp

   If you need a username/password to access the server, you'll have
   to edit those variables in the script.

   If you prefer, you can leave out the `-p` option and upload the data
   file by some other means.

   Converting the same file takes a while and uploads (or writes to disk) a large
   number of files.

4. You can discard the shapefile and any XML saved at this point if you want to.

## Test it

Check that it works: [http://localhost:8302/](http://localhost:8302/)

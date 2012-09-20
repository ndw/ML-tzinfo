# ML-tzinfo

XQuery and REST interface to the Internet timezone data.

+ Create a database and an appserver. For the purposes of this document,
  I'm assuming that the appserver is running on localhost:8302. The root
  should be the `MLS` directory.

+ Install the timezone data in the database:

	curl -X POST -H "Content-type: application/xml" -d@etc/tzinfo.xml \
	http://localhost:8302/upload.xqy

  If you want to rebuild the timezone data with the most recent database,
  get the [Time Zone Database](http://www.iana.org/time-zones). Run

	bin/tz2xml.pl africa antarctica asia australasia backward etcetera \
	europe northamerica pacificnew southamerica

+ Check that it works: [http://localhost:8302/](http://localhost:8302/)





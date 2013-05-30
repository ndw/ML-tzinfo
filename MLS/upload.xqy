xquery version "1.0-ml";

declare namespace tz  = "http://nwalsh.com/ns/tzinfo";
declare namespace tzp = "http://nwalsh.com/ns/tzpolygon";

declare variable $zc := "http://nwalsh.com/collections/tzboxes";
declare variable $bc := "http://nwalsh.com/collections/tzpolyboxes";
declare variable $qc := "http://nwalsh.com/collections/tzpolygons";

declare variable $timezone-collection := "http://nwalsh.com/collections/tzinfo";

declare variable $perm := xdmp:permission("timezone-user", "read");

declare function local:upload-map(
  $data as element(tzp:timezone)
) as xs:string
{
  let $uri   := concat("/tzinfo/boxes/", $data/tzp:name, "/0")
  let $query := cts:element-pair-geospatial-query(xs:QName("feature"),
                    xs:QName("lat"), xs:QName("lon"), cts:polygon($data/tzp:boundary))
  return
    xdmp:document-insert($uri, <query>{$query}</query>/*, $perm, $zc),

  for $pdata at $index in $data/tzp:polygon
  let $polygon := cts:polygon($pdata)
  let $bboxes  := cts:bounding-boxes($polygon, ("box-percent=10"))
  let $boxuris := for $box at $bindex in $bboxes
                  let $uri   := concat("/tzinfo/pboxes/",
                                       $data/tzp:name, "/", $index, "-", $bindex)
                  let $c     := concat($bc, "/", $data/tzp:name, "/0")
                  let $query := cts:element-pair-geospatial-query(xs:QName("feature"),
                                    xs:QName("lat"), xs:QName("lon"), $box)
                  return
                    ($uri,
                     xdmp:document-insert($uri, <query>{$query}</query>/*, $perm, ($bc, $c)))
  let $tzc     := concat("/polys/", $data/tzp:name, "/0")
  let $uri     := concat("/tzinfo/polys/", $data/tzp:name, "/", $index)
  let $query   := cts:element-pair-geospatial-query(xs:QName("feature"),
                      xs:QName("lat"), xs:QName("lon"), $polygon)
  return
    xdmp:document-insert($uri, <query>{$query}</query>/*, $perm, ($boxuris, $tzc, $qc)),

  concat("Inserted ", count($data/tzp:polygon), " polygons for ", $data/tzp:name)
};

declare function local:upload-tzinfo(
  $tzdata as element(tz:tzinfo)
) as xs:string
{
  (for $datum at $index in $tzdata/*
   let $uri := concat("/tzinfo/tz/", local-name($datum), "/",
                      if ($datum/@name) then $datum/@name else "",
                      "-", $index, ".xml")
   return
      xdmp:document-insert($uri, $datum, $perm, $timezone-collection),

   concat("Uploaded ", count($tzdata/*), " timezone documents.&#10;"))
};

let $_    := xdmp:security-assert("http://marklogic.com/xdmp/privileges/admin", "execute")
let $_    := xdmp:set-response-content-type("text/plain")
let $data := xdmp:get-request-body("xml")/*
return
  if ($data/self::tzp:timezone)
  then
    local:upload-map($data)
  else
    if ($data/self::tz:tzinfo)
    then
      local:upload-tzinfo($data)
    else
      error((), "Uploaded file was neither tzinfo nor a timezone map.")

xquery version "1.0-ml";

import module namespace tzinfo="http://nwalsh.com/ns/tzinfo"
       at "tzinfo.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

declare function local:key(
  $key as xs:string,
  $value as xs:string?
) as xs:string
{
  if ($value castable as xs:float)
  then
    concat("""", $key, """: ", $value)
  else
    concat("""", $key, """: """, string($value), """")
};

declare function local:regions(
  $regions as element(region)*
) as xs:string
{
  let $objects := for $region in $regions
                  return
                    concat("{",
                           string-join((local:key("name", $region/name),
                                        local:points($region/points)),
                                       ",&#10;"),
                           "}")
  return
    concat("[", string-join($objects, ",&#10;"), "]")
};

declare function local:points(
  $points as xs:string
) as xs:string
{
  let $points := for $point in tokenize($points, " ")
                 return
                   concat("[", $point, "]")
  return
    concat("""points"":[", string-join($points, ",&#10;"), "]")
};

let $lat := xs:float((xdmp:get-request-field("lat"), 42)[1])
let $lon := xs:float((xdmp:get-request-field("lon"), -117)[1])
let $det := tzinfo:timezone-details($lat,$lon)
return
  (xdmp:set-response-content-type("application/json"),
   "{",
   string-join((local:key("lat", $det/lat),
                local:key("lon", $det/lon),
                local:key("name", $det/name),
                concat("""tzboxes"":", local:regions($det/tzboxes/region)),
                concat("""pboxes"":", local:regions($det/polyboxes/region)),
                concat("""mpolys"":", local:regions($det/mpolygons/region)),
                concat("""polygons"":", local:regions($det/polygons/region))
               ),
               ",&#10;"),
   "}")


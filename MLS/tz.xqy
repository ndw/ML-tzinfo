xquery version "1.0-ml";

import module namespace tzinfo="http://nwalsh.com/xmlns/pim/tzinfo"
       at "tzinfo.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

let $tz     := xdmp:get-request-field("tz")
let $dt     := if (xdmp:get-request-field("dt") castable as xs:dateTime)
               then xs:dateTime(xdmp:get-request-field("dt"))
               else current-dateTime()
let $accept := xdmp:get-request-header("Accept")
let $map    := tzinfo:details($dt, $tz)
return
  if (contains($accept, "application/json"))
  then
    (xdmp:set-response-content-type("application/json"),
     concat("{ ", string-join(for $key in map:keys($map)
                              return concat('"', $key, '": "', map:get($map, $key), '"'),
                              ", "), " }"))
  else
    (: Coerce to XML :)
    let $map := <map>{ $map }</map>
    return
      $map/map:map


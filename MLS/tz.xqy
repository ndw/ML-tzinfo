xquery version "1.0-ml";

import module namespace tzinfo="http://nwalsh.com/xmlns/pim/tzinfo"
       at "tzinfo.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

let $tz  := xdmp:get-request-field("tz")
let $dt  := if (xdmp:get-request-field("dt") castable as xs:dateTime)
            then xs:dateTime(xdmp:get-request-field("dt"))
            else current-dateTime()
let $map := <map> { tzinfo:details($dt, $tz) } </map>
return
  $map/map:map


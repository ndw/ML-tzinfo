xquery version "1.0-ml";

import module namespace tzinfo="http://nwalsh.com/ns/tzinfo"
       at "tzinfo.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

let $lats := xdmp:get-request-field("lat")
let $lons := xdmp:get-request-field("lon")
let $dts  := xdmp:get-request-field("dt")

let $lat  := xs:float(if ($lats castable as xs:float) then $lats else "39.83333")
let $lon  := xs:float(if ($lons castable as xs:float) then $lons else "-98.58333")

let $idt  := if ($dts castable as xs:dateTime)
             then xs:dateTime($dts)
             else current-dateTime()

let $utc  := adjust-dateTime-to-timezone($idt, xs:dayTimeDuration("PT0S"))

let $tz   := tzinfo:timezone($lat,$lon)

let $dt   := if (exists($tz))
             then $utc + tzinfo:dstoffset($utc, $tz) + tzinfo:gmtoffset($utc, $tz)
             else ()

return
  if (exists($dt))
  then
    object-node {
      "lat": $lat,
      "lon": $lon,
      "timezone": $tz,
      "gmtoffset": tzinfo:gmtoffset($dt, $tz),
      "dstoffset": tzinfo:dstoffset($dt, $tz),
      "format": tzinfo:format($dt, $tz),
      "dt": $dt,
      "utc": $utc
    }
  else
    object-node {
      "lat": $lat,
      "lon": $lon,
      "timezone": $tz
    }


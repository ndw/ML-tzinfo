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
  (xdmp:set-response-content-type("application/json"),
   concat("{""lat"": ", $lat, ",&#10;",
          """lon"": ", $lon, ",&#10;",
          """timezone"": """, $tz, """",
          if (exists($dt))
          then
            string-join(("",
                         concat("""gmtoffset"": """, tzinfo:gmtoffset($dt, $tz), """"),
                         concat("""dstoffset"": """, tzinfo:dstoffset($dt, $tz), """"),
                         concat("""format"": """, tzinfo:format($dt, $tz), """"),
                         concat("""dt"": """, $dt, """"),
                         concat("""utc"": """, $utc, """")),
                         ",")
          else
            (),
          "}&#10;"))



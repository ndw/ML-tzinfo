xquery version "1.0-ml";

import module namespace tzinfo="http://nwalsh.com/ns/tzinfo"
       at "/api/tzinfo.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

let $deftz  := "America/Chicago"
let $tzlist := tzinfo:timezone-list()
let $now    := xs:dateTime(substring(string(current-dateTime()), 1, 19)) (: no tz :)

let $tzs    := (xdmp:get-request-field("tz"), $deftz)[1]
let $tzm    := if ($tzs = $tzlist)
               then ()
               else concat("Invalid timezone: ", $tzs, "; using '", $deftz, "'")

let $dts    := (xdmp:get-request-field("dt"), $now)[1]
let $dtm    := if ($dts castable as xs:dateTime)
               then ()
               else concat("Invalid dateTime: ", $dts, "; using ", $now)

let $tz     := if ($tzs = $tzlist) then $tzs else $deftz
let $dt     := if ($dts castable as xs:dateTime) then xs:dateTime($dts) else $now

let $tzm2   := if (empty(timezone-from-dateTime($dt)))
               then ()
               else concat("Ignoring timezone specified on dateTime: ", $dts)

let $dt     := if (empty(timezone-from-dateTime($dt)))
               then $dt
               else xs:dateTime(substring(string($dt), 1, 19))

let $lats    := xdmp:get-request-field("lat")
let $lons    := xdmp:get-request-field("lon")
let $setshow := string(xdmp:get-request-field("bounds")) != ""
let $debugb  := string(xdmp:get-request-field("debugbounds")) != ""

let $lat    := if (exists($lats) and $lats castable as xs:float)
               then xs:float($lats)
               else 39.83333

let $lon    := if (exists($lons) and $lons castable as xs:float)
               then xs:float($lons)
               else -98.58333

let $key    := doc("/etc/config.xml")/config/maps-api-key
let $uri    := if (empty($key))
               then "https://maps.google.com/maps/api/js"
               else "https://maps.google.com/maps/api/js?key=" || $key
return
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>TZ Info</title>
      <script src="//ajax.googleapis.com/ajax/libs/jquery/1.8.0/jquery.min.js"
              type="text/javascript"></script>
      <script src="{$uri}"
              type="text/javascript"></script>
      <script type="text/javascript"
              src="/js/tzmap.js"></script>
      <style type="text/css">
.error {{
  padding-left: 1em;
  padding-top: 0.25em;
  padding-bottom: 0.25em;
  background-color: #AA0000;
  color: #FFFFFF;
}}
      </style>
    </head>
    <body>
      <h1>Timezone map</h1>

      { for $msg in ($dtm, $tzm, $tzm2)
        return
          <p class="error">{$msg}</p>
      }

      <p id="msg"></p>
      <div id="map" style="width: 800px; height: 600px;"/>
      <p><span id="dlat"></span> × <span id="dlon"></span> :
      <span id="tz"></span>
      <br/>
      <span id="utc"></span> <span id="localtime"></span> <span id="offset"></span>
      </p>
      <input type="hidden" id="lat" name="lat" value="{$lats}"/>
      <input type="hidden" id="lon" name="lon" value="{$lons}"/>
      <input type="hidden" id="setshow" name="setshow" value="{$setshow}"/>
      <input type="hidden" id="debugbounds" name="debugbounds" value="{$debugb}"/>
      <p id="button"><input id="show" type="button" value="Show boundaries" disabled="true"/></p>
    </body>
  </html>

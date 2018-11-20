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
let $tzreq   := xdmp:get-request-field("timezone")

return
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Timezone info</title>
      <link rel="stylesheet" type="text/css" href="/css/tz-info.css" />
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.3.1/dist/leaflet.css"
            integrity="sha512-Rksm5RenBEKSKFjgI3a41vrjkw4EVPlJ3+OiI65vTjIdo9brlAacEuKOiQ5OFh7cOI1bkDwLqdLw3Zg0cRJAAQ=="
            crossorigin=""/>
      <script src="/js/jquery-3.1.1.min.js" type="text/javascript" />
    </head>
    <body>
      <h1 id="tz">Timezones</h1>
      <p id="latlon"><span id="dlat"></span> × <span id="dlon"></span></p>

      { for $msg in ($dtm, $tzm, $tzm2)
        return
          <p class="error">{$msg}</p>
      }

      <p id="msg"></p>
      <div id="map"/>
      <p><span id="utc"></span> <span id="localtime"></span> <span id="offset"></span>
      </p>
      <p>Address:
      <input id="addr" name="addr" type="text" width="128" size="128" placeholder="Enter an address"/>
      </p>
      <input type="hidden" id="lat" name="lat" value="{$lats}"/>
      <input type="hidden" id="lon" name="lon" value="{$lons}"/>
      <input type="hidden" id="timezone" name="timezone" value="{$tzreq}"/>
    </body>
    <script src="https://unpkg.com/leaflet@1.3.1/dist/leaflet.js"
            integrity="sha512-/Nsx9X4HebavoBvEBuyp3I7od5tA0UzAxs+j83KgC8PU0kgB4XiK4Lfe4y4cgBtaRJQEIFCW+oC506aPT2L1zw=="
            crossorigin=""/>
    <script src="/js/Leaflet.Geodesic.js"/>
    <script src="/js/Leaflet.MakiMarkers.js"/>
    <script src="/js/tzmap.js"/>
  </html>

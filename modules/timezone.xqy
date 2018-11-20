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

let $lats   := xdmp:get-request-field("lat")
let $lons   := xdmp:get-request-field("lon")

let $lat    := if (exists($lats) and $lats castable as xs:float)
               then xs:float($lats)
               else 39.83333

let $lon    := if (exists($lons) and $lons castable as xs:float)
               then xs:float($lons)
               else -98.58333

return
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <title>Timezone details</title>
      <link rel="stylesheet" type="text/css" href="/css/tz-info.css" />
    </head>
    <body>
      <h1>Timezone details</h1>

      { for $msg in ($dtm, $tzm, $tzm2)
        return
          <p class="error">{$msg}</p>
      }

      <form action="/timezone" method="GET">
        <p>Details for
          <input id="dt" name="dt" value="{$dt}" size="30" onchange="submit()" />
          in the
          <select id="tz" name="tz" onchange="submit()">
            { for $name in tzinfo:timezone-list()
              return
                <option value="{$name}">
                  { if ($tz = $name)
                    then attribute { fn:QName("","selected") } { "selected" }
                    else ()
                  }
                  {$name}
                </option>
            }
          </select>
          timezone
        </p>
        <table border="0">
          <tr>
            <td>Canonical zone</td>
            <td id="czone">{tzinfo:canonical-zone($tz)}</td>
          </tr>
          <tr>
            <td>GMT Offset</td>
            <td id="gmt">{tzinfo:gmtoffset($dt, $tz)}</td>
          </tr>
          <tr>
            <td>DST Offset</td>
            <td id="dst">{tzinfo:dstoffset($dt, $tz)}</td>
          </tr>
          <tr>
            <td>Format</td>
            <td id="format">{tzinfo:format($dt, $tz)}</td>
          </tr>
          <tr>
            <td>UTC</td>
            <td id="utc">{$dt - tzinfo:dstoffset($dt, $tz) - tzinfo:gmtoffset($dt, $tz)}</td>
          </tr>
        </table>
        <p><input type="submit" value="Refresh"/></p>
      </form>
    </body>
  </html>

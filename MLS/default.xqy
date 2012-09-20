xquery version "1.0-ml";

import module namespace tzinfo="http://nwalsh.com/xmlns/pim/tzinfo"
       at "tzinfo.xqy";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

declare function local:form()
{
  <form method="get" action="/default.xqy">
  <p>Enter timezone: <input placeholder="e.g. Europe/London" name="tz"/></p>
  </form>
};

declare function local:showtz(
  $dt as xs:dateTime,
  $tz as xs:string
)
{
  let $details := tzinfo:details($dt, $tz)
  return
    <table xmlns="http://www.w3.org/1999/xhtml">
      <tr>
        <td>Time: </td>
        <td>{$dt}</td>
      </tr>
      <tr>
        <td>Zone: </td>
        <td>{map:get($details, 'zone')}</td>
      </tr>
      <tr>
        <td>Canonical zone: </td>
        <td>{map:get($details, 'canonical-zone')}</td>
      </tr>
      <tr>
        <td>Format string: </td>
        <td>{map:get($details, 'format')}</td>
      </tr>
      <tr>
        <td>GMT offset: </td>
        <td>{map:get($details, 'gmtoff')}</td>
      </tr>
      <tr>
        <td>DST offset: </td>
        <td>{map:get($details, 'dstoff')}</td>
      </tr>
      <tr>
        <td>Time in UTC: </td>
        <td>{map:get($details, 'dtz')}</td>
      </tr>
    </table>
};

let $tz := xdmp:get-request-field("tz")
let $dt := if (xdmp:get-request-field("dt") castable as xs:dateTime)
           then xs:dateTime(xdmp:get-request-field("dt"))
           else current-dateTime()
return
  <html xmlns="http://www.w3.org/1999/xhtml">
  <head>
  <title>Lookup timezone</title>
  </head>
  <body>
  <h1>Lookup timezone{ if (empty($tz)) then "" else concat(": ", $tz)}</h1>

  { if (empty($tz))
    then
      local:form()
    else
      local:showtz($dt, $tz)
  }
  </body>
  </html>

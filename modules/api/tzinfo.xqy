xquery version "1.0-ml";

module namespace tzinfo="http://nwalsh.com/ns/tzinfo";

declare namespace tzp = "http://nwalsh.com/ns/tzpolygon";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare variable $zb := "http://nwalsh.com/collections/tzboxes";
declare variable $zr := "http://nwalsh.com/collections/tzregions";

declare option xdmp:mapping "false";

declare variable $Z := xs:dayTimeDuration("PT0S");

declare function tzinfo:details(
  $dt as xs:dateTime,
  $userzone as xs:string
) as map:map
{
  (: let $_       := xdmp:log(("", "==================================================")) :)

  let $map     := map:map()
  let $zone    := tzinfo:canonical-zone($userzone)

  (: let $_       := xdmp:log(/tzinfo:zone[@name = $zone]) :)

  let $zones   := for $zone in /tzinfo:zone[@name = $zone]
                  where not($zone/@until) or xs:dateTime($zone/@until) > $dt
                  order by $zone/@until
                  return
                    $zone

  let $tzone   := $zones[1]

  (: let $_       := xdmp:log(("timezone:", $tzone)) :)

  let $_       := map:put($map, 'gmtoff', xs:dayTimeDuration($tzone/@gmtoff))

  let $prules  := for $rule in /tzinfo:rule[@name = $tzone/@rule]
                  where $rule/@from le year-from-dateTime($dt)
                        and $rule/@to ge year-from-dateTime($dt)
                  return
                    tzinfo:parseRule($dt, $rule)
  let $rules   := for $rule in $prules
                  order by $rule/@dt descending
                  return $rule

  (: let $_       := xdmp:log(("rules:", $rules)) :)

  let $applies := for $rule in $rules
                  where xs:dateTime($rule/@dt) < $dt
                  return
                    $rule

  (: let $_       := xdmp:log(("applies:", $applies)) :)

  let $apply   := if (empty($applies)) then $rules[1] else $applies[1]

  (: let $_       := xdmp:log(("apply:", $dt, $apply)) :)

  let $_       := map:put($map, 'dstoff', (xs:dayTimeDuration($apply/@save), $Z)[1])

  let $_       := map:put($map, 'dt', $dt)
  let $_       := map:put($map, 'zone', $zone)
  let $_       := map:put($map, 'dtz', $dt + map:get($map, 'gmtoff') - map:get($map, 'dstoff'))

  (: I'm guessing about the meaning of the hyphen ... :)
  let $format  := string($tzone/@format)

  (: Sometimes there's a %s in the format and no @s to insert...e.g. Asia/Urumqi :)
  (: Assume it should be deleted... :)
  let $s       := $apply/@s
  let $_       := map:put($map, 'format', if (contains($format, '%s') and $s)
                                          then replace($format, '%s',
                                                       if ($s = '-') then '' else $s)
                                          else replace($format, '%s', ''))
  return
    $map
};

declare function tzinfo:canonical-zone(
  $userzone as xs:string?
) as xs:string
{
  if (empty($userzone))
  then
    "Z"
  else
    string((/tzinfo:link[@from=$userzone]/@to, $userzone)[1])
};

declare function tzinfo:gmtoffset(
  $dt as xs:dateTime,
  $userzone as xs:string
) as xs:dayTimeDuration
{
  let $map := tzinfo:details($dt, $userzone)
  return
    map:get($map, 'gmtoff')
};

declare function tzinfo:dstoffset(
  $dt as xs:dateTime,
  $userzone as xs:string
) as xs:dayTimeDuration
{
  let $map := tzinfo:details($dt, $userzone)
  return
    map:get($map, 'dstoff')
};

declare function tzinfo:format(
  $dt as xs:dateTime,
  $userzone as xs:string
) as xs:string
{
  let $map := tzinfo:details($dt, $userzone)
  return
    map:get($map, 'format')
};

declare function tzinfo:timezone-list()
as xs:string*
{
  let $zones := for $zone in /tzinfo:zone
                return
                  string($zone/@name)
  for $name in distinct-values($zones)
  order by $name
  return
    $name
};

declare function tzinfo:timezone(
  $lat as xs:float,
  $lon as xs:float
) as xs:string*
{
  let $ref    := cts:geospatial-region-path-reference("/tzp:box")
  let $pt     := cts:point($lat, $lon)
  let $query  := cts:geospatial-region-query($ref, "covers", $pt)
  let $result := cts:search(collection($zb), $query)
  let $result := if (count($result) ne 1)
                 then
                   let $ref   := cts:geospatial-region-path-reference("/tzp:region")
                   let $query := cts:geospatial-region-query($ref, "covers", $pt)
                   return
                     cts:search(collection($zr), $query)
                 else
                   $result
  let $result := if (count($result) le 1)
                 then
                   $result
                 else
                   (xdmp:log("Multiple timezones: " || string-join($result ! xdmp:node-uri(.), " ")),
                    $result[1])
  (: let $_      := xdmp:log($lat || "," || $lon || ": " || $result ! xdmp:node-uri(.)) :)
  where exists($result)
  return
    let $name := xdmp:node-uri($result)
    let $name := if (contains($name, "/box"))
                 then substring-before($name, "/box")
                 else substring-before($name, "/region")
    return
      substring-after($name, "/maps/")
};

declare private function tzinfo:extract-tzname(
  $queries as element(cts:element-pair-geospatial-query)*
) as xs:string*
{
  (: Now find the "base names" of all the timezones. The xdmp:node-uri() of
     each box will be something like /{prefix}/America/Denver/{id}; drop
     the {id} part. :)
  let $names := for $uri in $queries ! xdmp:node-uri(.)
                return
                  replace($uri, "^/tzinfo/[^/]+/(.*)/[^/]*$", "$1")

    (: Here's the subtle part. If a point is in exactly one America/Denver polygon
       then it's in that timezone. If it's in 2, then it's in a whole in that timezone
       (And so *isn't* in that timezone.) If it's in 3, then it's in an island in
       a whole in that timezone, etc. :)
    let $names := for $distinct-name in distinct-values($names)
                  let $appears := $names[. = $distinct-name]
                  where count($appears) mod 2 = 1
                  return
                    $distinct-name
    return
      $names
};

declare private function tzinfo:boxes(
  $boxes as element(cts:element-pair-geospatial-query)*
)
{
   for $box in $boxes
   let $r := $box/cts:region
   return
     <region>
       <name>{replace(xdmp:node-uri($r), "/[^/]+/[^/]+/", "")}</name>
       <points>
         { if ($r/@xsi:type=xs:QName('cts:box'))
           then
             let $n := cts:box-north($r)
             let $s := cts:box-south($r)
             let $e := cts:box-east($r)
             let $w := cts:box-west($r)
             return
               string-join((concat($n,",",$e),
                            concat($n,",",$w),
                            concat($s,",",$w),
                            concat($s,",",$e),
                            concat($n,",",$e)), " ")
           else
             string($r)
         }
       </points>
     </region>
};

declare private function tzinfo:parseRule(
  $dt as xs:dateTime,
  $rule as element(tzinfo:rule)
) as element(tzinfo:rule)
{
  let $year  := year-from-dateTime($dt)
  let $month := xs:int($rule/@in)
  let $day   := if ($rule/@on castable as xs:int)
                then xs:int($rule/@on)
                else tzinfo:computeDay($year, $month, $rule/@on)
  let $dt    := concat($year, "-",
                       if ($month lt 10) then '0' else '', $month, "-",
                       if ($day lt 10) then '0' else '', $day, "T", $rule/@at, ":00")
  return
    <rule xmlns="http://nwalsh.com/ns/tzinfo">
      { $rule/@* }
      { if (empty($rule/@dt))
        then
          ( (:xdmp:log(($rule, $dt)),:)
           attribute { fn:QName("", "dt") } { $dt })
        else
          ()
       }
    </rule>
};

declare private function tzinfo:computeDay(
  $year as xs:int,
  $month as xs:int,
  $day as xs:string
) as xs:int
{
  let $dt := xs:dateTime(concat($year, "-", if ($month > 9) then "" else "0", $month, "-01",
                                "T12:00:00"))
  return
    if ($day eq "lastSun")
    then
      let $nextmonth := $dt + xs:yearMonthDuration("P1M")
      let $lastday := $nextmonth - xs:dayTimeDuration("P1D")
      for $day in (0 to 6)
      let $date := $lastday - ($day * xs:dayTimeDuration("P1D"))
      where tzinfo:weekday-from-dateTime($date) = 0
      return
        day-from-dateTime($date)
    else
      if (matches($day, "(Sat|Sun|Mon)>=(\d+)"))
      then
        let $dayname := replace($day, "(Sat|Sun|Mon)>=(\d+)", "$1")
        let $dow := if ($dayname eq 'Sat')
                    then 6
                    else if ($dayname eq 'Sun')
                         then 0
                         else 1
        let $ord := xs:int(replace($day, "(Sat|Sun|Mon)>=(\d+)", "$2"))
        return
          day-from-dateTime(tzinfo:ordinalDay($dt, $dow, $ord))
      else
        (1, xdmp:log($day))
};

declare private function tzinfo:ordinalDay(
  $first as xs:dateTime,
  $dow as xs:int,
  $ord as xs:int
) as xs:dateTime
{
  let $days := for $count in ($ord - 1 to $ord + 5)
               let $date := $first + ($count * xs:dayTimeDuration("P1D"))
               where tzinfo:weekday-from-dateTime($date) = $dow
               return
                 $date
  return
    $days
};

declare private function tzinfo:weekday-from-dateTime($dt as xs:dateTime) {
  (: Dec 31, 1899 was a Sunday; Sunday = 0, Monday = 1, etc... :)
  let $date := $dt cast as xs:date
  let $dec-31-1899 := xs:date("1899-12-31")
  let $duration := $date - $dec-31-1899
  let $days := days-from-duration($duration)
  return
    if ($days < 0)
    then
      if ($days mod 7 = 0) then 0 else 7 + ($days mod 7)
    else
      $days mod 7
};

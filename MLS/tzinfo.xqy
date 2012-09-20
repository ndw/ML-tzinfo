xquery version "1.0-ml";

module namespace tzinfo="http://nwalsh.com/xmlns/pim/tzinfo";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

declare variable $tzcollection := "http://nwalsh.com/collections/etc";

declare function tzinfo:details(
  $dt as xs:dateTime,
  $userzone as xs:string
) as map:map
{
  let $map     := map:map()
  let $zone    := tzinfo:canonical-zone($userzone)
  let $zones   := for $zone in /tzinfo:zone[@name = $zone]
                  where not($zone/@until) or xs:dateTime($zone/@until) > $dt
                   order by $zone/@until
                  return
                    $zone
  let $tzone   := $zones[1]
  (:let $trace   := xdmp:log($tzone):)
  let $_       := map:put($map, 'gmtoff', xs:dayTimeDuration($tzone/@gmtoff))

  let $prules  := for $rule in /tzinfo:rule[@name = $tzone/@rule]
                  where $rule/@from le year-from-dateTime($dt)
                        and $rule/@to ge year-from-dateTime($dt)
                  return
                    tzinfo:parseRule($dt, $rule)
  let $rules   := for $rule in $prules
                  order by $rule/@dt descending
                  return $rule
  (:let $trace   := xdmp:log(("rules:", $rules)):)

  let $applies := for $rule in $rules
                  where xs:dateTime($rule/@dt) < $dt
                  return
                    $rule

  let $apply   := if (empty($applies)) then $rules[1] else $applies[1]

  (:let $trace   := xdmp:log(("apply:", $dt, $apply)):)

  let $_       := map:put($map, 'dstoff', xs:dayTimeDuration($apply/@save))

  let $_       := map:put($map, 'dt', $dt)
  let $_       := map:put($map, 'zone', $zone)
  let $dtz     := adjust-dateTime-to-timezone(
                      $dt + map:get($map, 'gmtoff') - map:get($map, 'dstoff'),
                      xs:dayTimeDuration("PT0H"))

  let $_       := map:put($map, 'dtz', $dtz)

  let $format  := string($tzone/@format)
  let $s       := $apply/@s
  let $_       := if ($tzone/@format)
                  then
                    map:put($map, 'format', if (contains($format, '%s') and $s)
                                            then replace($format, '%s', $s)
                                            else $format)
                   else
                     ()
  return
    $map
};

declare function tzinfo:canonical-zone(
  $userzone as xs:string
) as xs:string
{
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
) as xs:dayTimeDuration
{
  let $map := tzinfo:details($dt, $userzone)
  return
    map:get($map, 'format')
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
    <rule xmlns="http://nwalsh.com/xmlns/pim/tzinfo">
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

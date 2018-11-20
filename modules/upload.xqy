xquery version "1.0-ml";

declare namespace tz  = "http://nwalsh.com/ns/tzinfo";
declare namespace tzp = "http://nwalsh.com/ns/tzpolygon";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

declare variable $zm := "http://nwalsh.com/collections/tzmaps";
declare variable $zb := "http://nwalsh.com/collections/tzboxes";
declare variable $zr := "http://nwalsh.com/collections/tzregions";
declare variable $zj := "http://nwalsh.com/collections/json";

declare variable $timezone-collection := "http://nwalsh.com/collections/tzinfo";

declare variable $perm  := xdmp:permission("timezone-user", "read");
declare variable $DEBUG := false();

declare function local:upload-map(
  $data as element(tzp:timezone)
) as xs:string
{
  let $uri    := concat("/tzinfo/maps/", $data/tzp:name)

  (: we don't actually need the original document
  let $_      := xdmp:document-insert($uri, $data, $perm, $zm)
  :)

  let $box    := <tzp:box>
                   { let $points := tokenize(normalize-space($data/tzp:boundary), "[\s,]")
                     let $n      := xs:double($points[1])
                     let $w      := xs:double($points[2])
                     let $s      := xs:double($points[5])
                     let $e      := xs:double($points[6])
                     let $box    := cts:box($s, $w, $n, $e)
                     return
                       $box
                   }
                 </tzp:box>
  let $_      := xdmp:document-insert($uri || "/box", $box, $perm, $zb)

  let $_       := xdmp:log(string($data/tzp:name))

  let $polygons := map:map()  
  let $regions := map:map()
  let $include := map:map()
  let $contby  := map:map()
  let $_       := for $points in $data/tzp:polygon
                  let $id   := "p" || (count($points/preceding-sibling::tzp:polygon) + 1)
                  let $_    := xdmp:log("  " || $id || " " || $points/@vcount || " vertices")
                  let $poly := cts:polygon(string($points))
                  let $_    := map:put($regions, $id, $poly)
                  return
                    map:put($polygons, $id, $points)

  let $_       := for $oid in map:keys($regions)
                  for $iid in map:keys($regions)
                  where $oid != $iid
                  return
                    if (geo:region-contains(map:get($regions, $oid), map:get($regions, $iid)))
                    then
                      (map:put($include, $oid, (map:get($include, $oid), $iid)),
                       map:put($contby, $iid, (map:get($contby, $iid), $oid)))
                    else
                      ()

  let $_       := if ($DEBUG)
                  then
                    (xdmp:log("include:"),
                     for $id in map:keys($regions)
                     return
                       xdmp:log($id || " " || string-join(map:get($include, $id), " ")),
                     xdmp:log("contained by:"),
                     for $id in map:keys($regions)
                     return
                       xdmp:log($id || " " || string-join(map:get($contby, $id), " ")))
                  else
                    ()

  let $_       := for $id in map:keys($regions)
                  let $depth := count(map:get($contby, $id))
                  return
                    if ($depth mod 2 = 0)
                    then
                      let $incl   := map:get($regions, $id)
                      let $excl   := local:only-contained-by($contby, $id)
                      let $pgon   := if (empty($excl))
                                     then
                                       $incl
                                     else
                                       (xdmp:log("    " || $id || " excludes " || string-join($excl, " ")),
                                        cts:complex-polygon($incl,
                                            for $id in $excl
                                            return map:get($regions, $id)))
                      let $region := <tzp:region>{$pgon}</tzp:region>
                      return
                        xdmp:document-insert($uri || "/region/" || $id, $region, $perm, $zr)
                    else
                      ()

   let $incl   := for $id in map:keys($regions)
                  let $depth := count(map:get($contby, $id))
                  where $depth mod 2 = 0
                  return
                    map:get($polygons, $id)
   let $excl   := for $id in map:keys($regions)
                  let $depth := count(map:get($contby, $id))
                  where $depth mod 2 = 1
                  return
                    map:get($polygons, $id)

   let $obj    := object-node {
                    "name": string($data/tzp:name),
                    "count": count($data/tzp:polygon),
                    "includeCount": count($incl),
                    "excludeCount": count($excl),
                    "include": local:polygons($incl),
                    "exclude": local:polygons($excl)
                  }
   let $_      := xdmp:document-insert($uri || ".json", $obj, $perm, $zj)

   return
     concat("Inserted ", count($data/tzp:polygon), " polygons for ", $data/tzp:name)
};

declare function local:only-contained-by(
  $contby  as map:map,
  $id      as xs:string
) as xs:string*
{
  let $contained := map:get($contby, $id)
  let $map       := map:map()
  let $_         := for $id in map:keys($contby)
                    return
                      map:put($map, $id, for $cid in map:get($contby, $id)
                                         where not($cid = $contained)
                                         return $cid)
  (: let $_ := xdmp:log(("1:", $id, "2:", $contained, $map)) :)
  return
    for $cid in map:keys($map)
    where count(map:get($map,$cid)) = 1 and map:get($map, $cid) = $id
    return
      $cid
};

declare function local:polygons(
  $polygons as element(tzp:polygon)*
) as array-node()
{
  array-node {
    for $poly in $polygons
    return
      array-node {
        for $pair in tokenize(normalize-space(string($poly)), "\s+")
        let $lat := substring-before($pair, ",")
        let $lng := substring-after($pair, ",")
        return
          array-node { ($lat, $lng) }
      }
  }
};

declare function local:upload-tzinfo(
  $tzdata as element(tz:tzinfo)
) as xs:string
{
  (for $datum at $index in $tzdata/*
   let $uri := concat("/tzinfo/tz/", local-name($datum), "/",
                      if ($datum/@name) then $datum/@name else "",
                      "-", $index, ".xml")
   return
      xdmp:document-insert($uri, $datum, $perm, $timezone-collection),

   concat("Uploaded ", count($tzdata/*), " timezone documents.&#10;"))
};

let $_    := xdmp:security-assert("http://marklogic.com/xdmp/privileges/admin-ui", "execute")
let $_    := xdmp:set-response-content-type("text/plain")
let $data := xdmp:get-request-body("xml")/*
return
  if ($data/self::tzp:timezone)
  then
    local:upload-map($data)
  else
    if ($data/self::tz:tzinfo)
    then
      local:upload-tzinfo($data)
    else
      error((), "Uploaded file was neither tzinfo nor a timezone map.")

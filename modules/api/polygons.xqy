xquery version "1.0-ml";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare namespace tzp = "http://nwalsh.com/ns/tzpolygon";

declare option xdmp:mapping "false";

let $name := xdmp:get-request-field("timezone")
let $zone := doc("/tzinfo/maps/" || $name || ".json")/object-node()
return
  if (empty($zone))
  then
    object-node { }
  else
    $zone

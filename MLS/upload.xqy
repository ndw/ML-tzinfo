xquery version "1.0-ml";

declare namespace tz = "http://nwalsh.com/xmlns/pim/tzinfo";

declare function local:upload-timezone-data(
  $data as element()*
)
{
  for $datum at $index in $data
  let $uri := concat("/etc/timezone/", local-name($datum), "/",
                     if ($datum/@name) then $datum/@name else "",
                     $index, ".xml")
  return
    xdmp:document-insert($uri, $datum, (), "http://nwalsh.com/collections/tzinfo")
};

let $data := xdmp:get-request-body("xml")
return
  if ($data/tz:tzinfo)
  then
    (local:upload-timezone-data($data/tz:tzinfo/*),
     concat("Uploaded ", count($data/tz:tzinfo/*), " timezone records."))
  else
    error((), "You didn't upload a file of events or contacts.")

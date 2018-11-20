/* -*- JavaScript -*- */

"strict";

let map = null;
let curLatitude = 0;
let curLongitude = 0;
let curLocation = "unknown";
let zoom = 4;
let lineWidth = 2;
let lineColor = '#ff0000';
let lineOpacity = 0.5;
let polygons = [];
let markers = [];

$(document).ready(function() {
  map = L.map("map").setView([curLatitude,curLongitude], zoom);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: 'map data © OpenStreetMap contributors',
    minZoom: 1,
    MaxZoom: 18
  }).addTo(map);

  if ($("#lat").val() == "" || $("#lon").val() == "") {
    if (!navigator.geolocation) {
      gpsFail()
    } else {
      navigator.geolocation.getCurrentPosition(gpsSuccess, gpsFail)
    }
  } else {
    curLatitude = parseFloat($("#lat").val())
    curLongitude = parseFloat($("#lon").val())
    map.setView([curLatitude,curLongitude], zoom);
    jQuery.get("/api/timezone",
               { "lat": curLatitude,
                 "lon": curLongitude },
               showTimezone);
  }

  map.on('click', onClick);
});

function gpsSuccess(position) {
  curLatitude = position.coords.latitude;
  curLongitude = position.coords.longitude;
  curLocation = "obtained";
  map.setView([curLatitude,curLongitude], zoom);

  $("#dlat").val(curLatitude);
  $("#dlon").val(curLongitude);
  $("#tz").text("...computing...");
  $("#utc").text("");
  $("#localtime").text("");
  $("#offset").text("");

  window.history.pushState("", "Map Update",
                           "/map/" + curLatitude.toFixed(4)
                           + "/" + curLongitude.toFixed(4));

  jQuery.get("/api/timezone",
             { "lat": curLatitude,
               "lon": curLongitude,
               "dt": $("#dt").val() },
             showTimezone);
}

function gpsFail() {
    curLocation = "unavailable"
}

function onClick(event) {
  curLatitude = event.latlng.lat;
  curLongitude = event.latlng.lng;
  map.setView([curLatitude,curLongitude]);

  $("#dlat").val(curLatitude);
  $("#dlon").val(curLongitude);
  $("#tz").text("...computing...");
  $("#utc").text("");
  $("#localtime").text("");
  $("#offset").text("");

  window.history.pushState("", "Map Update",
                           "/map/" + curLatitude.toFixed(4)
                           + "/" + curLongitude.toFixed(4));

  for (mark of markers) {
    map.removeLayer(mark);
  }
  markers = [];

  let icon = L.MakiMarkers.icon({icon: "marker", color: "#aaaaff", size: "s"});
  let marker = L.marker([curLatitude, curLongitude], { "icon": icon });
  marker.bindPopup("You clicked here").openPopup();
  markers.push(marker)
  marker.addTo(map);

  jQuery.get("/api/timezone",
             { "lat": curLatitude,
               "lon": curLongitude,
               "dt": $("#dt").val() },
             showTimezone);
}

function showTimezone(data, textStatus, jqXHR) {
    var html = "";
    var pos = 0;
    var tmp, offset;

    $("#dlat").html(convert(data.lat, "N", "S"));
    $("#dlon").html(convert(data.lon, "E", "W"));
    if (data.utc !== undefined) {
        $("#utc").text(data.utc.substring(0,19) + " UTC / ");
        $("#localtime").text(data.dt.substring(0,19) + " " + data.format);
        // GMT is a special case
        if (data.gmtoffset === "PT0S") {
            tmp = "PT0H0M".match("^(-?)PT([0-9]+)H(([0-9]+)M)?")
        } else {
            tmp = data.gmtoffset.match("^(-?)PT([0-9]+)H(([0-9]+)M)?")
        }
        offset = tmp[1] + tmp[2];
        if (tmp[4] === undefined) {
            offset += ":00";
        } else {
            offset += ":" + tmp[4];
        }
        $("#offset").text(" (" + offset + ")");
    }

    $("#lat").val(data.lat);
    $("#lon").val(data.lon);

    if (data.timezone === "") {
      $("#tz").text("Unknown; international waters?");
      $("#show").attr("disabled", true);
    } else {
      jQuery.get("/api/polygons/" + data.timezone, {}, showPolygons)
      $("#tz").text(data.timezone);
      if ($("#setshow").val() === "showing") {
        $("#show").attr("disabled", true);
      } else {
        $("#show").attr("disabled", false);
      }
    }
}
  
function convert(value, pos, neg) {
    var l, deg, m, s, v;

    l = value > 0 ? pos : neg;
    v = Math.abs(value);

    deg = Math.floor(v);
    v = v - deg;

    m = Math.floor(v * 60);
    v = (v * 60) - m;

    s = Math.floor(v * 6000) / 100;

    return "<span title='" + value + "'>" + deg + "° " + m + "' " + s + "\" " + l + "</span>";
}

function showPolygons(data, textStatus, jqXHR) {
  for (poly of polygons) {
    map.removeLayer(poly);
  }
  polygons = [];

  for (pos = 0; pos < data.include.length; pos++) {
    let poly = L.polygon(data.include[pos], { color: "green" });
    polygons.push(poly);
    poly.addTo(map);
    
  }
  for (pos = 0; pos < data.exclude.length; pos++) {
    let poly = L.polygon(data.exclude[pos], { color: "red", fillColor: "white" })
    polygons.push(poly);
    poly.addTo(map);
  }
}

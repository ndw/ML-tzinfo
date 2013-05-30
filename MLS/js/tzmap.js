/* -*- JavaScript -*- */

// Globals.

var map;
var bounds;
var marker;
var infowindow;

var lineWidth = 2;
var lines = [];

var deflat = 39.83333;
var deflon = -98.58333;

var initlat = null;
var initlon = null;

var speclat = null;
var speclon = null;

var geoloc = false;

function showTimezone(data, textStatus, jqXHR) {
    var html = "";
    var pos = 0;
    var tmp, offset;

    $("#dlat").html(convert(data.lat, "N", "S"));
    $("#dlon").html(convert(data.lon, "E", "W"));
    if (data.utc !== undefined) {
        $("#utc").text(data.utc.substring(0,19) + " UTC / ");
        $("#localtime").text(data.dt.substring(0,19) + " " + data.format);
        tmp = data.gmtoffset.match("^(-?)PT([0-9]+)H(([0-9]+)M)?")
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
        $("#tz").text(data.timezone);
        $("#show").attr("disabled", false);
    }

    $("#msg").text("Click on map to choose a different location...");

    if (marker !== undefined) {
        marker.setMap(null);
        infowindow.setMap(null);
    }

    bounds = new google.maps.LatLngBounds();

    marker = new google.maps.Marker({
        position: new google.maps.LatLng(data.lat, data.lon),
        map: map
    });

    infowindow = new google.maps.InfoWindow({
        content: " "
    });

    google.maps.event.addListener(marker, 'click', function() {
        html = "Timezone: " + data.name + "<br />";
        html += "Latitude: " + data.lat + "<br />";
        html += "Longitude: " + data.lon;
        infowindow.setContent(html);
        infowindow.open(map, this);
    });

    map.setCenter(marker.getPosition());
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

function show_map(position) {
    var latitude = position.coords.latitude;
    var longitude = position.coords.longitude;
    geoloc = true;

    if (speclat != null) {
        latitude = speclat;
        speclat = null;
    }

    if (speclon != null) {
        longitude = speclon;
        speclon = null;
    }

    $("#dlat").val(latitude);
    $("#dlon").val(longitude);

    jQuery.get("/api/timezone.xqy",
               { "lat": latitude,
                 "lon": longitude },
               showTimezone);
}

function show_click() {
    $("#show").attr("disabled", true);
    $("#msg").text("Calculating timezone polygons...");
    jQuery.get("/api/timezone-details.xqy",
               { "lat": $("#lat").val(),
                 "lon": $("#lon").val() },
               show_boundaries);
}

function show_boundaries(data, textStatus, jqXHR) {
    var html = "";
    var pos = 0;

    $("#msg").text("Click on map to choose a different location...");

    if (marker !== undefined) {
        marker.setMap(null);
        infowindow.setMap(null);
    }

    while (lines[0]) {
        lines.pop().setMap(null);
    }
    bounds = new google.maps.LatLngBounds();

    marker = new google.maps.Marker({
        position: new google.maps.LatLng(data.lat, data.lon),
        map: map
    });

    infowindow = new google.maps.InfoWindow({
        content: " "
    });

    google.maps.event.addListener(marker, 'click', function() {
        for (pos = 0; pos < data.name.length; pos++) {
            if (pos > 0) {
                html += "<br />";
            }
            if (pos > 0 && pos+1 === data.name.length) {
                html += "or ";
            }
            html += data.name[pos];
        }

        infowindow.setContent(html);
        infowindow.open(map, this);
    });

    $(data.tzboxes).each(function() {
        pgon("#000000", this.points);
    });
    $(data.pboxes).each(function() {
        pgon("#0000FF", this.points);
    });
    $(data.mpolys).each(function() {
        pgon("#FF0000", this.points);
    });
    $(data.polygons).each(function() {
        pgon("#00FF00", this.points);
    });
}

function pgon(color, points) {
    var p0, p1;

    try {
	// Calculate the optimal size and center for the map
	for (var i = 0; i < points.length; ++i ) {
	    var p1 = new google.maps.LatLng(points[i][0], points[i][1]);
	    bounds.extend(p1);

            if (i > 0) {
                createLine(map, p0, p1, color, lineWidth);
            }

            p0 = p1;
        }

        map.fitBounds(bounds);
    } catch ( e ) {
        // This used to use GLog, but I don't know where that went...
    }
}

function createLine(map, slatlng, elatlng, color, width) {
    var coords = [ slatlng, elatlng ];
    var line = new google.maps.Polyline({
        path: coords,
        strokeColor: color,
        strokeWidth: width,
        strokeWeight: 1,
        geodesic: true
    });
    lines.push(line);
    line.setMap(map);
}

$(document).ready(function() {
    var mapopts = {
        zoom: 4,
        mapTypeId: google.maps.MapTypeId.ROADMAP
    };
    var mapDiv = document.getElementById('map');

    var geoloc = false;

    if ($("#lat").val() === "") {
        initlat = deflat;
        geoloc = true;
    } else {
        initlat = $("#lat").val()
        speclat = initlat;
    }

    if ($("#lon").val() === "") {
        initlon = deflon;
        geoloc = true;
    } else {
        initlon = $("#lon").val()
        speclon = initlon
    }

    $("#show").click(show_click);

    map = new google.maps.Map(mapDiv, mapopts);

    google.maps.event.addListener(map, "click", function(event) {
        $("#dlat").val(event.latLng.lat());
        $("#dlon").val(event.latLng.lng());
        $("#tz").text("...computing...");
        $("#utc").text("");
        $("#localtime").text("");
        $("#offset").text("");

        if (lines[0]) {
            $("#msg").text("Clearing polygons...");
            while (lines[0]) {
                lines.pop().setMap(null);
            }
            $("#msg").text("Calculating...");
        }

        jQuery.get("/api/timezone.xqy",
                   { "lat": event.latLng.lat(),
                     "lon": event.latLng.lng(),
                     "dt": $("#dt").val() },
                   showTimezone);
    });

    bounds = new google.maps.LatLngBounds();

    if (geoloc && navigator.geolocation) {
        navigator.geolocation.getCurrentPosition(show_map);

        // Let's see if we can get a location
        $("#dlat").val(initlat);
        $("#dlon").val(initlon);
        $("#tz").text("...computing...");

        setTimeout(function() {
            if (!geoloc) {
                jQuery.get("/api/timezone.xqy",
                           { "lat": initlat,
                             "lon": initlon },
                           showTimezone);
            }
        }, 5000);
    } else {
        jQuery.get("/api/timezone.xqy",
                   { "lat": initlat,
                     "lon": initlon },
                   showTimezone);
    }
});

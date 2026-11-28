#!/usr/bin/env python3
# Time zones for the picker, one a line: NAME<tab>ABBR<tab>ZONE<tab>UTC OFFSET NOW (seconds)<tab>MORE TO SEARCH

import datetime, zoneinfo

TZ = "/usr/share/zoneinfo"
# country names as people say them
NAMES = {
    "GB": "United Kingdom", "US": "United States", "AE": "United Arab Emirates", "KR": "South Korea",
    "KP": "North Korea", "CZ": "Czechia", "CD": "DR Congo", "CG": "Congo", "CI": "Ivory Coast",
    "FM": "Micronesia", "VA": "Vatican City",
}
MORE = {"GB": "UK Britain England Scotland Wales", "US": "USA America", "AE": "UAE Dubai", "CZ": "Czech Republic",
        "NL": "Holland", "CI": "Cote d'Ivoire"}

# not countries: states and cities people search for
CITIES = {
    "Alabama":         "America/Chicago",
    "Alaska":          "America/Anchorage",
    "Arizona":         "America/Phoenix",
    "Arkansas":        "America/Chicago",
    "California":      "America/Los_Angeles",
    "Colorado":        "America/Denver",
    "Connecticut":     "America/New_York",
    "Delaware":        "America/New_York",
    "Florida":         "America/New_York",
    "Georgia (US)":    "America/New_York",
    "Hawaii":          "Pacific/Honolulu",
    "Idaho":           "America/Boise",
    "Illinois":        "America/Chicago",
    "Indiana":         "America/Indiana/Indianapolis",
    "Iowa":            "America/Chicago",
    "Kansas":          "America/Chicago",
    "Kentucky":        "America/Kentucky/Louisville",
    "Louisiana":       "America/Chicago",
    "Maine":           "America/New_York",
    "Maryland":        "America/New_York",
    "Massachusetts":   "America/New_York",
    "Michigan":        "America/Detroit",
    "Minnesota":       "America/Chicago",
    "Mississippi":     "America/Chicago",
    "Missouri":        "America/Chicago",
    "Montana":         "America/Denver",
    "Nebraska":        "America/Chicago",
    "Nevada":          "America/Los_Angeles",
    "New Hampshire":   "America/New_York",
    "New Jersey":      "America/New_York",
    "New Mexico":      "America/Denver",
    "New York":        "America/New_York",
    "North Carolina":  "America/New_York",
    "North Dakota":    "America/Chicago",
    "Ohio":            "America/New_York",
    "Oklahoma":        "America/Chicago",
    "Oregon":          "America/Los_Angeles",
    "Pennsylvania":    "America/New_York",
    "Rhode Island":    "America/New_York",
    "South Carolina":  "America/New_York",
    "South Dakota":    "America/Chicago",
    "Tennessee":       "America/Chicago",
    "Texas":           "America/Chicago",
    "Utah":            "America/Denver",
    "Vermont":         "America/New_York",
    "Virginia":        "America/New_York",
    "Washington":      "America/Los_Angeles",
    "West Virginia":   "America/New_York",
    "Wisconsin":       "America/Chicago",
    "Wyoming":         "America/Denver",

    "London":          "Europe/London",
    "Paris":           "Europe/Paris",
    "Berlin":          "Europe/Berlin",
    "Madrid":          "Europe/Madrid",
    "Rome":            "Europe/Rome",
    "Amsterdam":       "Europe/Amsterdam",
    "Brussels":        "Europe/Brussels",
    "Zurich":          "Europe/Zurich",
    "Vienna":          "Europe/Vienna",
    "Stockholm":       "Europe/Stockholm",
    "Oslo":            "Europe/Oslo",
    "Copenhagen":      "Europe/Copenhagen",
    "Helsinki":        "Europe/Helsinki",
    "Warsaw":          "Europe/Warsaw",
    "Prague":          "Europe/Prague",
    "Budapest":        "Europe/Budapest",
    "Bucharest":       "Europe/Bucharest",
    "Athens":          "Europe/Athens",
    "Istanbul":        "Europe/Istanbul",
    "Moscow":          "Europe/Moscow",
    "Dubai":           "Asia/Dubai",
    "Riyadh":          "Asia/Riyadh",
    "Tehran":          "Asia/Tehran",
    "Karachi":         "Asia/Karachi",
    "Mumbai":          "Asia/Kolkata",
    "Delhi":           "Asia/Kolkata",
    "Kolkata":         "Asia/Kolkata",
    "Dhaka":           "Asia/Dhaka",
    "Colombo":         "Asia/Colombo",
    "Kathmandu":       "Asia/Kathmandu",
    "Bangkok":         "Asia/Bangkok",
    "Jakarta":         "Asia/Jakarta",
    "Kuala Lumpur":    "Asia/Kuala_Lumpur",
    "Hong Kong":       "Asia/Hong_Kong",
    "Shanghai":        "Asia/Shanghai",
    "Beijing":         "Asia/Shanghai",
    "Tokyo":           "Asia/Tokyo",
    "Seoul":           "Asia/Seoul",
    "Sydney":          "Australia/Sydney",
    "Melbourne":       "Australia/Melbourne",
    "Brisbane":        "Australia/Brisbane",
    "Perth":           "Australia/Perth",
    "Adelaide":        "Australia/Adelaide",
    "Auckland":        "Pacific/Auckland",
    "Fiji":            "Pacific/Fiji",
    "Papua New Guinea":"Pacific/Port_Moresby",

    "Azores":          "Atlantic/Azores",
    "Bermuda":         "Atlantic/Bermuda",
    "Cape Verde":      "Atlantic/Cape_Verde",
    "Greenland":       "America/Nuuk",
}


def line(name, zone, more=""):
    try:
        t = datetime.datetime.now(zoneinfo.ZoneInfo(zone))
        return f"{name}\t{t.strftime('%Z')}\t{zone}\t{int(t.utcoffset().total_seconds())}\t" + f"{more} {zone}".strip()
    except Exception:
        return None


def table(name):
    with open(f"{TZ}/{name}", encoding="utf-8") as f:
        return [l.rstrip("\n").split("\t") for l in f if l.strip() and not l.startswith("#")]


country = {r[0]: r[1] for r in table("iso3166.tab")}
zones = {}
for r in table("zone.tab"):
    zones.setdefault(r[0], []).append((r[2], r[3] if len(r) > 3 else ""))

rows = []
for cc, zs in zones.items():
    name = NAMES.get(cc, country.get(cc, cc))
    more = " ".join(x for x in (country.get(cc, "") if cc in NAMES else "", MORE.get(cc, "")) if x)
    if len(zs) == 1:
        rows.append(line(name, zs[0][0], more))
        continue
    for zone, note in zs:
        city = zone.rsplit("/", 1)[-1].replace("_", " ")
        rows.append(line(f"{name} · {city}", zone, f"{more} {note}".strip()))
rows.sort(key=lambda l: (l or "").casefold())
# a city or island that's a country row already (Hong Kong, Fiji…) isn't listed twice
have = {l.split("\t", 1)[0] for l in rows if l}
rows += sorted((line(n, z) for n, z in CITIES.items() if n not in have), key=lambda l: l or "")
rows.append(line("UTC", "UTC", "GMT Coordinated Universal Time"))
print("\n".join(l for l in rows if l))

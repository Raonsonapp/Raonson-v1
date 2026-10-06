#!/usr/bin/env python3
"""Builds the bundled places dataset ("Ҷой" picker) from the CSVs in this folder.

    python3 tool/places/build_places.py

Writes:
  backend/places/places.json  — every place; embedded in the Go server
                                (GET /places/search, /places/nearest).
  assets/places/places_tj.json — Tajikistan only; the app's offline fallback.

Sources:
  tj_places.csv     — hand-curated: regions, cities, districts (ноҳияҳо),
                      some towns/villages and landmarks of Tajikistan.
                      Coordinates of towns come from GeoNames; a district's
                      point is its administrative centre (approximate).
                      `pop` is rough and only used for ranking.
  world_cities.csv  — major world cities. Names (ru/tj) curated by hand,
                      coordinates/population from GeoNames (CC BY 4.0,
                      https://www.geonames.org) via the geonamescache package.
  countries.csv     — countries; the point is the capital (approximate).

To improve the list: edit the CSVs, re-run this script, redeploy the server.
The app does not need an update (it asks the server first).
"""
import csv
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

TJ_BOX = (36.6, 41.1, 67.3, 75.2)  # lat min/max, lon min/max

KIND_WEIGHT = {
    'country': 55, 'region': 75, 'city': 72, 'district': 62,
    'town': 46, 'poi': 50,
}


def read(name):
    with open(os.path.join(HERE, name), encoding='utf-8', newline='') as f:
        return list(csv.DictReader(f))


def alts(s):
    return [a.strip() for a in (s or '').split(';') if a.strip()]


def slug(s):
    s = s.lower()
    s = re.sub(r"[’'`‘]", '', s)
    s = re.sub(r'[^a-z0-9]+', '-', s)
    return s.strip('-')


def pop_term(pop, scale):
    pop = int(float(pop or 0))
    return 0 if pop <= 0 else min(scale, round(math.log10(pop) * scale / 7))


def main():
    places = []
    errors = []

    for r in read('tj_places.csv'):
        w = 100 if r['id'] == 'tj' else KIND_WEIGHT[r['kind']] + pop_term(r['pop'], 12)
        if r['id'] == 'tj-dushanbe':
            w = 95
        places.append({
            'id': r['id'], 'k': r['kind'], 'p': r['parent'], 'cc': 'TJ',
            'tj': r['tj'], 'ru': r['ru'], 'en': r['en'], 'a': alts(r['alt']),
            'lat': round(float(r['lat']), 4), 'lon': round(float(r['lon']), 4),
            'w': w,
        })

    for r in read('countries.csv'):
        if r['iso'] == 'TJ':
            continue  # already above as 'tj'
        places.append({
            'id': 'c-' + r['iso'].lower(), 'k': 'country', 'p': '', 'cc': r['iso'],
            'tj': r['tj'], 'ru': r['ru'], 'en': r['en'], 'a': alts(r['alt']),
            'lat': round(float(r['lat']), 4), 'lon': round(float(r['lon']), 4),
            'w': KIND_WEIGHT['country'] + pop_term(r['pop'], 8),
        })

    for r in read('world_cities.csv'):
        places.append({
            'id': 'w-%s-%s' % (r['cc'].lower(), slug(r['en'])), 'k': 'city',
            'p': 'c-' + r['cc'].lower(), 'cc': r['cc'],
            'tj': r['tj'], 'ru': r['ru'], 'en': r['en'], 'a': alts(r['alt']),
            'lat': round(float(r['lat']), 4), 'lon': round(float(r['lon']), 4),
            'w': 28 + pop_term(r['pop'], 24),
        })

    ids = {}
    for p in places:
        if p['id'] in ids:
            errors.append('duplicate id ' + p['id'])
        ids[p['id']] = p
    for p in places:
        if p['p'] and p['p'] not in ids:
            errors.append('%s: unknown parent %s' % (p['id'], p['p']))
        if not (p['tj'] and p['ru'] and p['en']):
            errors.append('%s: missing a name' % p['id'])
        if not (-90 <= p['lat'] <= 90 and -180 <= p['lon'] <= 180):
            errors.append('%s: bad coordinates' % p['id'])
        if p['cc'] == 'TJ':
            a, b, c, d = TJ_BOX
            if not (a <= p['lat'] <= b and c <= p['lon'] <= d):
                errors.append('%s: outside Tajikistan' % p['id'])
    if errors:
        print('\n'.join(errors), file=sys.stderr)
        sys.exit(1)

    meta = {
        'v': 1,
        'source': 'Raonson places; coordinates partly from GeoNames '
                  '(CC BY 4.0, geonames.org). See tool/places/.',
    }
    full = dict(meta, places=places)
    tj = dict(meta, places=[p for p in places if p['cc'] == 'TJ'])

    out1 = os.path.join(ROOT, 'backend', 'places', 'places.json')
    out2 = os.path.join(ROOT, 'assets', 'places', 'places_tj.json')
    for path, data in ((out1, full), (out2, tj)):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
            f.write('\n')
    print('%d places (%d in Tajikistan)' % (len(places), len(tj['places'])))


if __name__ == '__main__':
    main()

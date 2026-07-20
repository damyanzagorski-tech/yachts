-- Marketplace filter data, pass B batch 1 (researched 2026-07-21, manufacturer sites only).
-- Models omitted (nothing verifiable on an official manufacturer source):
--   alva-ocean-eco-60 (alva-yachts.com dead/parked: 403/404, domain listed for sale),
--   blue-innovations-group-r30 (blueinnovationsgroup.com down: Cloudflare origin DNS error),
--   candela-seven (official C-7 page has no cabin/berth/equipment data),
--   candela-p-12 (commercial ferry; official page states no filter-relevant data),
--   chris-craft-launch-25-gte (concept; official press release covers propulsion only),
--   cosmopolitan-yachts-66 (no model page on cosmopolitanyachts.com; only 70/85/111/125 exist).
-- Keel_type: skipped everywhere — all boats here are motorboats and no manufacturer
-- describes a keel; Candela foils are not a keel type in the allowed list.

begin;

-- alfastreet-23-cabin-evo  source: https://alfastreet-yachts.com/23-cabin-evo-electric/
-- 1 cabin stated; berths not published. Bathing platform + dining table (seats 6) standard.
update models set
  cabins = 1,
  equipment = array(select distinct e from unnest(equipment || array['swimming-platform','cockpit-table']::text[]) as e)
where slug = 'alfastreet-23-cabin-evo';

-- alfastreet-28-cabin-electric  source: https://alfastreet-yachts.com/28-cabin-electric/
-- "1 cabin with king-sized bed (sleeps 2), private bathroom"; bathing platform access.
update models set
  cabins = 1,
  berths = 2,
  equipment = array(select distinct e from unnest(equipment || array['toilets','swimming-platform']::text[]) as e)
where slug = 'alfastreet-28-cabin-electric';

-- arc-boats-arc-one  source: https://arcboats.com/arc-one
-- "pop-up pylon" for ski/wakeboard; "premium speakers" standard. Day boat, no accommodation.
update models set
  equipment = array(select distinct e from unnest(equipment || array['ski-pole','cockpit-speakers']::text[]) as e)
where slug = 'arc-boats-arc-one';

-- arc-boats-arc-sport  source: https://arcboats.com/arc-sport (full specs modal)
-- "Height 76-96 in on water" -> max 96 in = 2.44 m (tower up; 1.93 m retracted).
-- Standard: auto-retract carbon tower (tow point), JL Audio; bow+stern thrusters w/ joystick
-- (also sold as Navigation Package upgrade). Day boat, no accommodation.
update models set
  air_draught_m = 2.44,
  equipment = array(select distinct e from unnest(equipment || array['ski-pole','cockpit-speakers','bow-thruster','stern-thruster']::text[]) as e)
where slug = 'arc-boats-arc-sport';

-- axopar-ax-e-25  source: https://www.axopar.com/boat-models/ax-e-100-electric/ax-e-25/
-- "Cabins: 1 (front cabin), Berths: 2". Standard: Q Experience 10" display w/ Navionics,
-- foredeck sunbed, aft convertible sunbathing area, integrated swim platforms with
-- telescopic bathing ladder, two electric bilge pumps, Clarion audio system.
update models set
  cabins = 1,
  berths = 2,
  equipment = array(select distinct e from unnest(equipment || array['plotter','fore-sunbathing-cushions','stern-sunbathing-cushions','swimming-platform','swimming-ladder','bilge-pump','cockpit-speakers']::text[]) as e)
where slug = 'axopar-ax-e-25';

-- boesch-750-portofino-deluxe-electric  source: https://boesch.swiss/de/boats/boesch-750-portofino-de-luxe-electric-power
-- "fest eingebauter Kuehlschrank im Cockpit" (built-in cockpit fridge) standard.
-- Equipment/dimension tabs are AJAX-only and would not load; nothing further verifiable.
update models set
  equipment = array(select distinct e from unnest(equipment || array['fridge']::text[]) as e)
where slug = 'boesch-750-portofino-deluxe-electric';

-- candela-c-8  source: https://candela.com/leisure-boats/candela-c-8/
-- "Marine head" and 15.4-inch touchscreen navigation system standard; cabin "sleeps a
-- small family" but no berth count published -> cabins/berths left null.
update models set
  equipment = array(select distinct e from unnest(equipment || array['marine-head','plotter']::text[]) as e)
where slug = 'candela-c-8';

-- crest-current-model  source: https://crestpontoonboats.com/models/current-model
-- Standard: Simrad touchscreen GPS, Bluetooth stereo w/ lighted speakers, removable table,
-- stainless telescoping ladder, "LED lighting all around". Pontoon day boat, no accommodation.
update models set
  equipment = array(select distinct e from unnest(equipment || array['plotter','cockpit-speakers','cockpit-table','swimming-ladder','cockpit-lighting']::text[]) as e)
where slug = 'crest-current-model';

-- crooze-yachts-ez28  source: https://croozeyachts.com/ (configuration lines) + https://croozeyachts.com/boat-specifications/
-- Factory configuration lines: fridge, barbecue, toilet, picnic/coffee tables, aft+bow
-- sunbeds, swim island with ladder, ambient lighting, sound system, wakeboard/ski tow
-- points, fishing module with rods, ice box. No cabins/berths/air draft published.
update models set
  equipment = array(select distinct e from unnest(equipment || array['fridge','barbecue','toilets','cockpit-table','fore-sunbathing-cushions','stern-sunbathing-cushions','swimming-ladder','cockpit-lighting','cockpit-speakers','ski-pole','fishing-rod-holders','ice-box']::text[]) as e)
where slug = 'crooze-yachts-ez28';

-- delphia-10-electric  source: https://www.delphiayachts.com/boat/delphia-10-lounge
-- Layouts: "1 cabin & 1 bathroom" standard, "2 cabins & 1 bathroom" factory option;
-- sleeps up to 4 -> cabins = 2 (max factory layout), berths = 4. Standard: separate
-- shower bathroom, front-opening fridge, swim platform with built-in ladder.
update models set
  cabins = 2,
  berths = 4,
  equipment = array(select distinct e from unnest(equipment || array['toilets','fridge','swimming-platform','swimming-ladder']::text[]) as e)
where slug = 'delphia-10-electric';

-- duffy-sun-cruiser-22  source: https://www.duffyboats.com/wp-content/uploads/2024/04/Duffy-Boats-Standard-Features-and-Options-Sun-Cruiser-22.pdf
-- Standard: 120V AC outlet via 2000W inverter, Victron Multiplus charger + smart plug w/
-- 50 ft shore cord, movable wood table, seat/backrest cushions, Fusion stereo w/ 4
-- speakers, dome + floor lights, automatic bilge pump. Options: AC/DC refrigerator,
-- aft wood table. Open launch, no accommodation.
update models set
  equipment = array(select distinct e from unnest(equipment || array['power-110v','inverter','battery-charger','shore-power-inlet','cockpit-table','cockpit-cushions','cockpit-speakers','cockpit-lighting','bilge-pump','fridge']::text[]) as e)
where slug = 'duffy-sun-cruiser-22';

-- earthling-e40-power-catamaran  source: https://earthlingethos.com/e-40-power-catamaran/ + https://earthlingethos.com/
-- E-THOS system (included on every identical build): "Hot/potable water, solar
-- optimization, Intensified Wind power"; roof solar array (16 panels, 2000 W) per
-- homepage. No cabin/berth/air-draft figures published.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','hot-water','wind-generator']::text[]) as e)
where slug = 'earthling-e40-power-catamaran';

commit;

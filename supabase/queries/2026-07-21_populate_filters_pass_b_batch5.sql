-- Marketplace filter data, pass B batch 5 (Sialia, Silennis, Silent Yachts,
-- Soel, Strana, Sun Concept, Sunreef). Researched 2026-07-21 on manufacturers'
-- official websites only. Fields the manufacturer does not state are omitted
-- (project rule: verify, don't estimate). No air draught or keel type was
-- published for any model in this batch; the catamarans' builders state no
-- keel, so keel_type left null throughout.

begin;

-- sialia-59-sport  source: https://www.sialia-yachts.com/yachts/59-sport/
-- Center-console day cruiser; no cabin/berth figures published.
-- "Charging: 22 kW AC, 150 kW DC" -> onboard charger + shore inlet;
-- "Optional 100 kW Range Extender" -> generator (factory option).
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','shore-power-inlet','generator']::text[]) as e)
where slug = 'sialia-59-sport';

-- sialia-80-explorer  source: https://www.sialia-yachts.com/yachts/80-explorer/
-- Cabins/berths not on page (brochure-only). "Charging: 3x 22 kW AC, 150 kW DC";
-- serial-hybrid with diesel cruise mode -> generator.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','shore-power-inlet','generator']::text[]) as e)
where slug = 'sialia-80-explorer';

-- silennis-s010  source: https://silennis.com/barco-electrico/silennis-s010/
-- 3.95 m open license-free boat, no accommodation. Standard: battery charger,
-- swim platform. Factory options: retractable swim ladder, picnic table,
-- bow solarium.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','swimming-platform','swimming-ladder','cockpit-table','fore-sunbathing-cushions']::text[]) as e)
where slug = 'silennis-s010';

-- silent-yachts-28-speed  source: https://silent-yachts.com/speed-28/
-- Day speedboat/tender, 10 passengers, no accommodation stated.
-- "704 Wp" solar cells embedded in the hard top (standard).
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'silent-yachts-28-speed';

-- silent-yachts-60  source: https://silent-yachts.com/yacht/60-series-2/
-- Cabins stated only as a range "4-6 (+ crew)" -> not a single value, omitted.
-- 16.8 kWp solar array standard; 130 kW range extender (diesel genset).
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','generator']::text[]) as e)
where slug = 'silent-yachts-60';

-- silent-yachts-62  source: https://silent-yachts.com/de/silent-62-3-deck-offen/
-- Cabins stated only as range 4-6 (+ crew) -> omitted. 16 kWp solar array;
-- range extender (diesel genset) listed in specs.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','generator']::text[]) as e)
where slug = 'silent-yachts-62';

-- silent-yachts-80-tri-deck  source: https://silent-yachts.com/yacht/80-series-2/
-- Cabins stated only as range "4 - 6 (+ Crew)" -> omitted. 22.4 kWp solar
-- array; 2x 75 kW range extenders (diesel gensets) in standard spec.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','generator']::text[]) as e)
where slug = 'silent-yachts-80-tri-deck';

-- soel-senses-62  source: https://soelyachts.com/synew/soelsenses62/
-- Layout stated: owner's cabin + 2 VIP cabins + kids cabin (guest cabins = 4;
-- separate crew cabin additional). "Up to nine people and three crew" ->
-- guest berths = 9. 18.5 kWp solar (42 panels); 60 kW DC genset standard.
update models set
  cabins = 4,
  berths = 9,
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','generator']::text[]) as e)
where slug = 'soel-senses-62';

-- soel-senses-82  source: https://soelyachts.com/synew/soelsenses82/
-- Cabins stated only as configurable range "four to six cabins plus crew
-- cabin" -> omitted. "Up to twelve guests" -> berths = 12 (crew of 4 extra).
-- 29 kWp solar (66 panels); 2x 100 kW DC genset standard.
update models set
  berths = 12,
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','generator']::text[]) as e)
where slug = 'soel-senses-82';

-- soel-shuttle-14  source: https://soelyachts.com/synew/soelshuttle14/
-- Commercial day shuttle (22 pax + 2 crew), no accommodation. 920 Wp solar.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'soel-shuttle-14';

-- soel-soelcat-12  source: https://soelyachts.com/synew/soelcat-12/
-- Day charter cat (12-20 pax), no accommodation. 8.6 kWp solar standard;
-- "can be equipped with a day head" -> toilets (factory option).
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','toilets']::text[]) as e)
where slug = 'soel-soelcat-12';

-- strana-23  source: https://www.stranaboats.com/explore/strana23/customize
-- Open day boat, no accommodation. Fleet edition (standard): all-weather
-- cushions, bathing ladder, LED lanterns. Leisure edition: front sunbed,
-- teak table, USB & 12V outlet. Premium edition: Raymarine AXIOM 9+ plotter,
-- fridge, 2x Bluetooth speakers, comfort lighting.
update models set
  equipment = array(select distinct e from unnest(equipment || array['cockpit-cushions','swimming-ladder','cockpit-lighting','power-12v','cockpit-table','fore-sunbathing-cushions','plotter','fridge','cockpit-speakers']::text[]) as e)
where slug = 'strana-23';

-- sun-concept-cat-12-0-cruise  source: https://sunconcept.pt/SunConceptCatCruise
-- "2 suites equipped with toilet and shower" -> cabins = 2 (berth count not
-- stated). Standard: 40x 170 Wp solar (6.8 kWp), 2 WC, deck shower, 45 L hot
-- water heater, induction cooker, micro/combi oven, 144 L fridge, 91 L
-- freezer, Raymarine AXIOM 9 plotter. Desalinator 50-70 L/h in Comfort Plus
-- version -> fresh-water-maker (factory option).
update models set
  cabins = 2,
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','toilets','cockpit-shower','hot-water','cooker','microwave-oven','fridge','deep-freezer','plotter','fresh-water-maker']::text[]) as e)
where slug = 'sun-concept-cat-12-0-cruise';

-- sun-concept-cat-12-0-lounge  source: https://sunconcept.pt/SunConceptCatLounge
-- Day-passenger version (26/24 seats) -> no cabins/berths set. Standard:
-- 40x 170 Wp solar, 2 WC, induction cooker, 65 L fridge, deck shower,
-- Raymarine Ray 53 (VHF). Options: AXIOM 9 chartplotter, 13000 BTU air
-- conditioning, 50-70 L/h desalinator.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','toilets','cooker','fridge','cockpit-shower','vhf','plotter','air-conditioning','fresh-water-maker']::text[]) as e)
where slug = 'sun-concept-cat-12-0-lounge';

-- sun-concept-evo-7-0-cruise  source: https://sunconcept.pt/SunConceptEVOCruise
-- Cabins/berths not stated. Standard: 9x 170 Wp solar, 65 L fridge, Fusion
-- MS-RA55 radio + speaker, LED deck lighting, 230 VAC system. Options:
-- Raymarine VHF, Dragonfly GPS/chartplotter.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','fridge','cockpit-speakers','cockpit-lighting','power-220v','vhf','plotter']::text[]) as e)
where slug = 'sun-concept-evo-7-0-cruise';

-- sun-concept-evo-7-0-lounge  source: https://sunconcept.pt/SunConceptEVOLounge
-- Open day layout, no accommodation stated. Standard: 9x 170 Wp solar, LED
-- courtesy lighting; Comfort version: 65 L fridge, Fusion MS-RA55 radio +
-- speaker. Options: Raymarine VHF, Dragonfly 5 Pro GPS/plotter, stern table.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','fridge','cockpit-speakers','cockpit-lighting','vhf','plotter','cockpit-table']::text[]) as e)
where slug = 'sun-concept-evo-7-0-lounge';

-- sunreef-80-power-eco  source: https://sunreef-yachts.com/en/launched/80-sunreef-power-eco-sol/
-- Fully-customizable model: launched hulls differ (Sol: 4 cabins / 8 guests),
-- so no single cabins/berths value set. Composite-integrated solar panels
-- (up to 36-40 kWp) define the Eco line; energy-saving air conditioning
-- stated on the manufacturer's page.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','air-conditioning']::text[]) as e)
where slug = 'sunreef-80-power-eco';

commit;

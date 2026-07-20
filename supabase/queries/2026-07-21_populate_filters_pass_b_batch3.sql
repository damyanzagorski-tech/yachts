-- Marketplace filter data, pass B batch 3 (researched 2026-07-21, manufacturer sites only).
-- Models omitted (nothing verifiable on an official manufacturer source):
--   mantaray-m24 (no /m24 page ever archived; archived official homepage
--     [web.archive.org/web/20230330140933/https://www.mantaraycraft.com/] states only
--     length/beam/weight/5 pax/motor/battery — no cabins, air draft, keel or equipment),
--   novaluxe-orphie-39 (orphieboats.com Orphie 39 page lists only length/beam/draft/
--     displacement/8 pax; no accommodation, air draft or equipment; novaluxeyachts.com
--     only carries the smaller Orphie 29 "X-Wing").
-- Keel_type: skipped everywhere — all motorboats, no manufacturer states a keel type
-- (Navier N30 hydrofoils and ELIGHT 40 catamaran hulls are not in the allowed list).
-- Air draught: only NovaLuxe states one ("bridge clearance 12 ft" -> 3.66 m).
-- Marian "Bordcomputer mit GPS" is a speed/battery display, NOT mapped to plotter;
-- plotter only used where Marian states a navigation MFD / GPS-Kartenplotter.

begin;

-- marian-capriole-700  source: https://marianboats.at/en/elektroboot/capriole-700-2/
--   + https://marianboats.at/wp-content/uploads/2019/04/Ausstattungsliste-MARIAN-Capriole-700-ohne-Preise.pdf
-- Cabin stated ("cabin for three to four people", tinted cabin hatch) -> cabins 1;
-- berth count ambiguous ("three to four") so berths left out. Standard: 3 kW charger,
-- custom upholstery. Options: stern shower, teak flooring.
update models set
  cabins = 1,
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','cockpit-cushions','cockpit-shower','teak']::text[]) as e)
where slug = 'marian-capriole-700';

-- marian-delta-600  source: https://marianboats.at/en/elektroboot/delta-600-2-2/
--   + https://marianboats.at/wp-content/uploads/2019/04/Ausstattungsliste-MARIAN-Delta-600-ohne-Preise.pdf
-- Standard: 3 kW charger, stainless swim ladder, custom upholstery. Options: CoolMatic
-- cooling drawer (fridge), teak flooring, teak/Esthec table, Fusion speakers on sunbed.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','swimming-ladder','cockpit-cushions','fridge','teak','cockpit-table','cockpit-speakers']::text[]) as e)
where slug = 'marian-delta-600';

-- marian-eclipse-580  source: https://marianboats.at/en/elektroboot/eclipse-580-2/
--   + https://marianboats.at/wp-content/uploads/2019/04/Aussttattungsliste-MARIAN-Eclipse-580-ohne-PREISE.pdf
-- Standard: 3 kW charger, swim platform in teak (teak also in bow/floor), upholstery.
-- Options: Fusion speakers on sunbed, teak/Esthec table.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','swimming-platform','teak','cockpit-cushions','cockpit-speakers','cockpit-table']::text[]) as e)
where slug = 'marian-eclipse-580';

-- marian-evo-700  source: https://marianboats.at/en/elektroboot/evo-700-2/
--   + https://marianboats.at/wp-content/uploads/2025/06/Ausstattungsliste-MARIAN-EVO-700-ohne-Preise-1.pdf
-- Standard: 12V sockets, automatic bilge pump, 22 kW Type 2 charger, 12" ultrawide
-- navigation/GPS display, radio + "Optic" FM speakers, swim platform w/ integrated
-- stainless ladder, custom upholstery. Options: CoolMatic fridge drawer, bow thruster,
-- stern shower, teak/Esthec table, RGB ambient LED lighting.
update models set
  equipment = array(select distinct e from unnest(equipment || array['power-12v','bilge-pump','battery-charger','plotter','cockpit-speakers','swimming-platform','swimming-ladder','cockpit-cushions','fridge','bow-thruster','cockpit-shower','cockpit-table','cockpit-lighting']::text[]) as e)
where slug = 'marian-evo-700';

-- marian-laguna-760  source: https://marianboats.at/en/elektroboot/laguna-760-2-2/
--   + https://marianboats.at/wp-content/uploads/2019/04/Ausstattungsliste-MARIAN-Laguna-760-ohne-Preise.pdf
-- Standard: 3 kW charger, swim platform w/ fold-away ladder, custom upholstery.
-- Options: CoolMatic fridge drawer, bow thruster, Raymarine Axiom 7 MFD (plotter) with
-- depth gauge + Bidata depth/temp, teak flooring, teak/Esthec table, stern shower,
-- LED ambient lighting.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','swimming-platform','swimming-ladder','cockpit-cushions','fridge','bow-thruster','plotter','depth-sounder','teak','cockpit-table','cockpit-shower','cockpit-lighting']::text[]) as e)
where slug = 'marian-laguna-760';

-- marian-m800  source: https://marianboats.at/en/elektroboot/m-800-2/
--   + https://marianboats.at/wp-content/uploads/2020/03/Ausstattungsliste-MARIAN-M800-ohne-Preise.pdf
-- Standard: 22 kW Type 2 charger, 12" display with navigation (plotter), integrated
-- radio + "Optik" FM speakers, swim platform w/ integrated stainless ladder, custom
-- upholstery. Options: teak/Esthec table, water-ski pole, stern shower.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','plotter','cockpit-speakers','swimming-platform','swimming-ladder','cockpit-cushions','cockpit-table','ski-pole','cockpit-shower']::text[]) as e)
where slug = 'marian-m800';

-- marian-m800-spyder  source: https://marianboats.at/en/elektroboot/m-800-spyder-2/
--   + https://marianboats.at/wp-content/uploads/2020/03/Ausstattungsliste-MARIAN-M800-Spyder-ohne-Preise.pdf
-- Standard: 22 kW Type 2 charger, 12" navigation display (plotter), swim platform w/
-- ladder, custom upholstery; factory BANG & OLUFSEN speakers (JL Audio subwoofer opt).
-- Options: CoolMatic fridge drawer, teak/Esthec flooring, teak table, ski pole,
-- stern shower.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','plotter','cockpit-speakers','swimming-platform','swimming-ladder','cockpit-cushions','fridge','teak','cockpit-table','ski-pole','cockpit-shower']::text[]) as e)
where slug = 'marian-m800-spyder';

-- marian-m800-r  source: https://en.abt-marian.com/ + official price list PDF
--   https://cdn.prod.website-files.com/6627578fda5b97ea66476c8a/68d3ad4cd81ccced013bfc39_ABT%7CMarian%20%20M800-R%20%20P.DE24%20DE.pdf
-- Fixed-spec limited edition. Included: 12V socket, automatic bilge pump, 22 kW Type 2
-- + 120 kW CCS charging, ABT 12" MFD (GPS chartplotter + Echolot -> depth sounder),
-- 30 L compressor cooling drawer, bow thruster, swim platform w/ folding ladder, table,
-- diamond-stitched upholstery, RGB ambient LED, B&O sound system, water-ski pole.
-- Options: stern shower, jet thruster bow & stern.
update models set
  equipment = array(select distinct e from unnest(equipment || array['power-12v','bilge-pump','battery-charger','plotter','depth-sounder','fridge','bow-thruster','stern-thruster','swimming-platform','swimming-ladder','cockpit-table','cockpit-cushions','cockpit-lighting','cockpit-speakers','ski-pole','cockpit-shower']::text[]) as e)
where slug = 'marian-m800-r';

-- marian-magic-640  source: https://marianboats.at/en/elektroboot/magic-640-2/
--   + https://marianboats.at/wp-content/uploads/2019/04/Ausstattungsliste-MARIAN-Magic-640-ohne-Preise.pdf
-- Standard: navigation lights, 12V outlets, automatic bilge pump, 3 kW charger, hull-
-- integrated swim platform + stainless boarding ladder, custom upholstery. Options:
-- CoolMatic fridge drawer, bow thruster, Axiom 7 MFD (plotter) + depth gauges, teak
-- flooring/dashboard, teak table, stern shower, LED ambient lighting.
update models set
  equipment = array(select distinct e from unnest(equipment || array['power-12v','bilge-pump','battery-charger','swimming-platform','swimming-ladder','cockpit-cushions','fridge','bow-thruster','plotter','depth-sounder','teak','cockpit-table','cockpit-shower','cockpit-lighting']::text[]) as e)
where slug = 'marian-magic-640';

-- mayla-fortyfour  source (official site offline, archived manufacturer page):
--   https://web.archive.org/web/20240303163540/https://www.mayla-yacht.com/copy-of-mayla-fortyfour
-- "Luxury cabin with double bed, day head, separate shower ... tv screens, and audio
-- system" -> cabins 1, toilets, tv-set; berths left out (double bed = 2, but marketing
-- also says "family of four ... nights on board" — ambiguous). Compact 22 L hot water
-- system; electric transom door "becomes a beach club platform"; premium sound system;
-- optional Dometic 16,000 BTU cabin air conditioning; optional V8 300 kW diesel
-- aggregate range extender (genset).
update models set
  cabins = 1,
  equipment = array(select distinct e from unnest(equipment || array['toilets','tv-set','hot-water','swimming-platform','cockpit-speakers','air-conditioning','generator']::text[]) as e)
where slug = 'mayla-fortyfour';

-- nautique-gs22e  source (model retired from nautique.com, archived official pages):
--   https://web.archive.org/web/20200807215053/https://www.nautique.com/models/super-air-nautique-gs22e/specs
--   https://web.archive.org/web/20200807205445/https://www.nautique.com/models/super-air-nautique-gs22e/interior
-- Wakesports day boat, no accommodation (cabins/berths legitimately none). Standard:
-- JL Audio M3 stereo with 4 cockpit speakers (tower speakers optional); integrated
-- platform ("Length With Platform 24'1.5""). Height/air draft not published.
update models set
  equipment = array(select distinct e from unnest(equipment || array['cockpit-speakers','swimming-platform']::text[]) as e)
where slug = 'nautique-gs22e';

-- navier-n30  source: https://configurator.navierboat.com/N30 (official configurator)
-- Factory options: "Radar (Garmin)", "Rod Holders", "Shore Charging Package".
-- No cabin/berth counts or air draft published on navierboat.com.
update models set
  equipment = array(select distinct e from unnest(equipment || array['radar','fishing-rod-holders','shore-power-inlet']::text[]) as e)
where slug = 'navier-n30';

-- nero-777-evolution  source: https://www.nero-yachts.com/777evolution/
-- Standard: bow thruster, retractable stainless swim ladder, teak sun deck, LED
-- ambient lighting. Open day boat; no cabin/berth or height figures published.
update models set
  equipment = array(select distinct e from unnest(equipment || array['bow-thruster','swimming-ladder','teak','cockpit-lighting']::text[]) as e)
where slug = 'nero-777-evolution';

-- nimbus-305-coupe-e-power  source (model retired, archived official nimbus.se page):
--   https://web.archive.org/web/20160106115118/http://nimbus.se/305-coupe/
-- Same hull/interior as the E-Power variant (Torqeedo Deep Blue engine alternative
-- listed on the sister 305 page). "The boat has two cabins ... sharing a common head
-- with shower" -> cabins 2, toilets. Spec table: No. of berths 6; battery charger
-- 230V 35A; shore power 230V 35A; 12V start/service batteries. Aft deck level with
-- bathing platform.
update models set
  cabins = 2,
  berths = 6,
  equipment = array(select distinct e from unnest(equipment || array['toilets','battery-charger','shore-power-inlet','power-12v','swimming-platform']::text[]) as e)
where slug = 'nimbus-305-coupe-e-power';

-- nimbus-305-drophead-e-power  source (archived official nimbus.se page listing the
--   Torqeedo Deep Blue engine alternatives in its spec table):
--   https://web.archive.org/web/20161004194509/http://nimbus.se/305-drophead/
-- Spec table: No. of berths 6; septic tank 80 l (marine head) -> toilets; battery
-- charger 230V 35A; shore power 230V 35A; 12V batteries. Cabin count not stated for
-- the open Drophead, left out.
update models set
  berths = 6,
  equipment = array(select distinct e from unnest(equipment || array['toilets','battery-charger','shore-power-inlet','power-12v']::text[]) as e)
where slug = 'nimbus-305-drophead-e-power';

-- novaluxe-elight-40  source: https://www.novaluxeyachts.com/elight-40
-- Solar electric catamaran. Bridge clearance 12 ft -> 3.66 m air draught. 6 kW solar
-- array standard; optional "6kW DC Genset"; 48V system with 110v/220v appliance
-- compatibility. Cabin/berth counts not published.
update models set
  air_draught_m = 3.66,
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','generator','power-110v','power-220v']::text[]) as e)
where slug = 'novaluxe-elight-40';

commit;

-- Populate marketplace filter columns — Pass B, batch 2
-- Researched 2026-07-21 from manufacturers' official websites (archived official pages
-- used where noted). Only manufacturer-stated facts included; nothing estimated.
-- Omitted entirely (nothing verifiable on official/archived-official pages):
--   electracraft-tr-152, hermes-speedster-e — see session report.

begin;

-- elvene-amber  source: https://elveneboats.com/ (single-page site; "Cuddy cabin in bow (2 persons)",
-- "Chart plotter + echo sounder included", "BT stereo included", "Integrated, walkable, antiskid solar panels",
-- EXTRAS: Fridge | Windlass | Freshwater shower | Head (Chemical))
update models set
  cabins = 1,
  berths = 2,
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','plotter','depth-sounder','cockpit-speakers','fridge','cockpit-shower','chemical-head','toilets']::text[]) as e)
where slug = 'elvene-amber';

-- elvene-amy  source: https://elveneboats.com/ (open-bow day boat, no cabin; "PV power 800-1300 Wp",
-- "Chart plotter + echo sounder included", "BT stereo included", EXTRAS: Fridge | Freshwater shower)
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','plotter','depth-sounder','cockpit-speakers','fridge','cockpit-shower']::text[]) as e)
where slug = 'elvene-amy';

-- enata-marine-foiler  source: https://foiler.com/page/layouts (all layouts include "retractable tables,
-- a restroom below the deck and a fridge"; Royale Cabin layout offers "air-conditioned cabin")
update models set
  equipment = array(select distinct e from unnest(equipment || array['toilets','fridge','cockpit-table','air-conditioning']::text[]) as e)
where slug = 'enata-marine-foiler';

-- flux-marine-highfield-sport-660  source: https://www.fluxmarine.com/boat-packages/highfield-660
-- (standard: "Garmin Chartplotter", "Integrated rear seat with cushion and roll bar")
update models set
  equipment = array(select distinct e from unnest(equipment || array['plotter','roll-bar']::text[]) as e)
where slug = 'flux-marine-highfield-sport-660';

-- flux-marine-scout-215-dorado  source: https://www.fluxmarine.com/boat-packages/scout-dorado
-- (standard: "Garmin Chartplotter")
update models set
  equipment = array(select distinct e from unnest(equipment || array['plotter']::text[]) as e)
where slug = 'flux-marine-scout-215-dorado';

-- four-winns-h2e  source: https://web.archive.org/web/20230604184745/https://www.fourwinns.com/intl/boat/h2e
-- (archived official page; "Bridge Clearance 4'11\" / 1.5 m"; standard: GPS plotter, depth sounder,
-- bilge pump(s) automatic, 12V outlet, Premium JL Audio Speakers (4), swim platform stern,
-- stern ladder, "Sundeck, aft w/ chaise lounge", "Cooler, carry-on, cockpit basement, 72qt")
update models set
  air_draught_m = 1.50,
  equipment = array(select distinct e from unnest(equipment || array['plotter','depth-sounder','bilge-pump','power-12v','cockpit-speakers','swimming-platform','swimming-ladder','stern-sunbathing-cushions','ice-box']::text[]) as e)
where slug = 'four-winns-h2e';

-- frauscher-740-mirage-electric  source: https://www.frauscherboats.com/en/boat/740-mirage/
-- (standard: Fusion stereo w/ 2 JL Audio speakers, fridge, stainless bathing ladder w/ teak steps,
-- bow-thruster, teak in cockpit/pass area/bathing platform)
update models set
  equipment = array(select distinct e from unnest(equipment || array['fridge','cockpit-speakers','swimming-ladder','bow-thruster','teak','teak-cockpit','swimming-platform']::text[]) as e)
where slug = 'frauscher-740-mirage-electric';

-- frauscher-850-fantom-air-porsche  source: https://www.frauscherxporsche.com/fantom-air
-- (listed: "Bugstrahlruder" (bow thruster), "Kuehlschublade" (fridge drawer), "High-end Audio",
-- "Ambiente Beleuchtung" (ambient lighting))
update models set
  equipment = array(select distinct e from unnest(equipment || array['bow-thruster','fridge','cockpit-speakers','cockpit-lighting']::text[]) as e)
where slug = 'frauscher-850-fantom-air-porsche';

-- gosun-elcat  source: https://gosun.co/products/gosun-electric-boat-solar
-- (in the box: "Swim Ladder"; solar panels offered to recharge/extend range, "Fuel Type: Electric / Solar")
update models set
  equipment = array(select distinct e from unnest(equipment || array['swimming-ladder','solar-panel']::text[]) as e)
where slug = 'gosun-elcat';

-- greenline-40-electric  source: https://www.greenlinehybridusa.com/yacht/greenline-40/
-- (official Greenline Yachts US site; "Cabins: 2 + salon", "Berths: 4 + 2" (= 6 incl. convertible saloon),
-- "Air Draft: 9'1\"" = 2.77 m; standard: 6x photovoltaic panels in coachroof, automatic inverter,
-- bow thruster, hot water, 224L fridge/freezer, electric oven/microwave, 1 toilet/washroom)
update models set
  cabins = 2,
  berths = 6,
  air_draught_m = 2.77,
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','inverter','bow-thruster','hot-water','fridge','microwave-oven','toilets','convertible-saloon']::text[]) as e)
where slug = 'greenline-40-electric';

-- helios-marine-omega-7-2  source: https://heliosmarine.io/yacht/helios-omega-7-2/
-- ("Solar Array: 1.55kWp"; "AC Type 2 inlet" for shore charging)
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','shore-power-inlet']::text[]) as e)
where slug = 'helios-marine-omega-7-2';

-- helios-marine-sigma-4-5  source: https://heliosmarine.io/yacht/helios-sigma-4-5/
-- ("Marine Solar Panels" standard)
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'helios-marine-sigma-4-5';

-- hinckley-dasher  source: https://www.hinckleyyachts.com/concept-model-dasher/
-- ("Dual 50 Amp Dock Charging"; note: concept model, never entered production —
-- "Artisanal Teak" is a painted epoxy composite, NOT real teak, so no teak slug)
update models set
  equipment = array(select distinct e from unnest(equipment || array['shore-power-inlet']::text[]) as e)
where slug = 'hinckley-dasher';

-- la-bella-verde-lbv-35  source: https://labellaverde.com/our-boats/
-- ("4 x 450W solar panels" / 1.6 kW solar)
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'la-bella-verde-lbv-35';

-- lumen-e10  source: https://lumenyachts.com/the-boat/
-- ("Height - 1,40 M above water")
update models set
  air_draught_m = 1.40
where slug = 'lumen-e10';

-- magonis-wave-e550  source: https://magonisboats.com/wave-e-550/
-- (standard: swim platforms; factory options: 42L ISOTHERM fridge, deck shower (50L tank),
-- telescopic ladder, Garmin Fusion marine audio, telescopic teak table.
-- Deck is Flexiteek (synthetic), so no teak slug.)
update models set
  equipment = array(select distinct e from unnest(equipment || array['swimming-platform','fridge','cockpit-shower','swimming-ladder','cockpit-speakers','cockpit-table']::text[]) as e)
where slug = 'magonis-wave-e550';

commit;

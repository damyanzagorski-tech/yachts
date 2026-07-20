-- Pass B, batch 6 — marketplace filter columns (cabins, berths, air_draught_m, keel_type, equipment)
-- Researched 2026-07-21 from manufacturers' official websites only. Fields not stated by the
-- manufacturer are omitted per project rule (verify, don't estimate).
--
-- Omitted entirely (nothing verifiable on the official site — see session report):
--   tyde-the-icon, vision-marine-wx-20, vision-marine-wx-23, vita-power-seadog,
--   vita-power-seal, volare-artemis-23

begin;

-- vision-marine-fantail-217  source: https://visionelectricboats.com/fantail-217-electric-boat/
-- Spec sheet: "Charger Voltage: 120 – 240 V". Factory options listed: sound system, custom table.
-- Open day boat — no cabins/berths stated.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','cockpit-speakers','cockpit-table']::text[]) as e)
where slug = 'vision-marine-fantail-217';

-- vision-marine-phantom  source: https://visionelectricboats.com/phantom-electric-boat/
-- Factory options with prices: depth finder ($595), JBL Bluetooth marine sound system ($695),
-- J-hook ladder ($595), fish rod holder ($395). Open day boat — no cabins/berths stated.
update models set
  equipment = array(select distinct e from unnest(equipment || array['depth-sounder','cockpit-speakers','swimming-ladder','fishing-rod-holders']::text[]) as e)
where slug = 'vision-marine-phantom';

-- vision-marine-v24  source: https://visionelectricboats.com/v24-electric-pontoon/
-- "Integrated Onboard Charger 120-240V 30 TO 50 AMPS". Pontoon — no cabins/berths.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger']::text[]) as e)
where slug = 'vision-marine-v24';

-- vision-marine-v30  source: https://visionelectricboats.com/v30-electric-pontoon/
-- Standard: "4 x 6.5\" Speakers (Interior)", "12V Port Included", "Ski Tow", "Antenna Included",
-- integrated onboard charger (120V-30A / 240V-50A). Pontoon — no cabins/berths.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','power-12v','cockpit-speakers','antenna','ski-pole']::text[]) as e)
where slug = 'vision-marine-v30';

-- vision-marine-volt-180  source: https://visionelectricboats.com/volt-electric-boat/
-- Spec sheet: "Charger Voltage: 110 – 220 V". Factory options listed: sound system, custom table.
-- Open day boat — no cabins/berths stated.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','cockpit-speakers','cockpit-table']::text[]) as e)
where slug = 'vision-marine-volt-180';

-- vision-marine-volt-x  source: https://visionelectricboats.com/volt-x/
-- Spec sheet: "Charger Voltage: 120 – 240v 30A". Included: "Premium Sound System: Two
-- high-quality marine speakers with Bluetooth technology". Open day boat.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','cockpit-speakers']::text[]) as e)
where slug = 'vision-marine-volt-x';

-- vita-power-lion  source: https://vita-power.com/news/hodgdon-yachts-to-build-vitas-all-electric-flagship-the-lion/
-- (official Vita Power site; product page /boats/vita-lion/ carries performance specs only)
-- "Forward, the enclosed cabin includes a day berth, day head and sink ... integrated Fusion
-- sound system throughout the boat"; "sunpad and bathing area ... together with a shower and
-- ladder for swimming". berths = 1 is a DAY berth, not overnight accommodation.
update models set
  cabins = 1,
  berths = 1,
  equipment = array(select distinct e from unnest(equipment || array['toilets','cockpit-shower','swimming-ladder','cockpit-speakers']::text[]) as e)
where slug = 'vita-power-lion';

-- vita-power-tridente-maserati  source: https://vita-power.com/boats/maserati-tridente/
-- "enclosed cabin forward includes a day berth and WC"; "bathing area with a shower and ladder
-- for swimming". berths = 1 is a DAY berth.
update models set
  cabins = 1,
  berths = 1,
  equipment = array(select distinct e from unnest(equipment || array['toilets','cockpit-shower','swimming-ladder']::text[]) as e)
where slug = 'vita-power-tridente-maserati';

-- voltari-260  source: https://voltarielectric.com/pages/260e-features and /products/voltari-260e
-- "Twin custom 19\" screens (Garmin)", "Rockford Fosgate marine sound system", "3-foot swim
-- platform", "Color-matched 40 AMP mobile charger" included. Performance day boat — no
-- cabins/berths stated.
update models set
  equipment = array(select distinct e from unnest(equipment || array['plotter','cockpit-speakers','swimming-platform','battery-charger']::text[]) as e)
where slug = 'voltari-260';

-- x-shore-eelex-8000  source: https://xshore.com/products/eelex-8000/specifications/
-- "Height above waterline: 2.3 m / 7.5 ft". Standard: Garmin marine maps on 24" touchscreen,
-- Bowers & Wilkins stereo, VHF handheld radio, 22 kW AC charging. Optional: "Front Sunbed with
-- Porta-Potti", DC fast charging. No cabins/berths stated.
update models set
  air_draught_m = 2.3,
  equipment = array(select distinct e from unnest(equipment || array['plotter','cockpit-speakers','vhf','battery-charger','chemical-head','fore-sunbathing-cushions']::text[]) as e)
where slug = 'x-shore-eelex-8000';

-- x-shore-1  source: https://xshore.com/products/x-shore-1/specifications/
-- Cab version: 1 forecabin with 2 beds. Air draft: "2.2m / 7.2 ft" (Top version; Open/Bowrider
-- is 1.7 m — max stored). Standard 22 kW AC charging, Garmin marine maps on 19" touchscreen.
-- Options: premium sound (4 x speakers), table, refrigerated cooler, porta potty.
update models set
  cabins = 1,
  berths = 2,
  air_draught_m = 2.2,
  equipment = array(select distinct e from unnest(equipment || array['plotter','battery-charger','cockpit-speakers','cockpit-table','fridge','chemical-head']::text[]) as e)
where slug = 'x-shore-1';

-- zen-yachts-zenriver  source: https://www.bord-a-bord-boat.com/bateau/zenriver/
-- "Couchage 6 pers." (6 berths); "Tirant d'air 2.4 m"; "Surface solaire 14m2" (solar roof).
-- Cabin count not stated on the page.
update models set
  berths = 6,
  air_draught_m = 2.4,
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'zen-yachts-zenriver';

-- zodiac-450-e-jet  source: https://www.zodiac-nautic.com/us/boats/e-jet-450/
-- Standard: "3kW battery charger with shore power cable", telescopic sliding steel (swim)
-- ladder. Optional: Audio Fusion system with speaker. Open-deck RIB — no cabins/berths.
-- NB page states model is no longer available for sale.
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger','swimming-ladder','cockpit-speakers']::text[]) as e)
where slug = 'zodiac-450-e-jet';

commit;

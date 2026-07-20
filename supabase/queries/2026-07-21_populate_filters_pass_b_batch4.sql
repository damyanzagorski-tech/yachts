-- Pass B, batch 4: marketplace filter columns (cabins, berths, air_draught_m, keel_type, equipment)
-- Researched 2026-07-21 on manufacturers' official sites only. Verified facts only — no estimates.
-- No air draught or keel type was published by any manufacturer in this batch (all motorboats).
-- Omitted (nothing verifiable on official pages): persico-zagato-100-2, pure-watercraft-pure-pontoon,
-- rand-spirit-25-electric, riva-el-iseo, rs-sailing-pulse-63, say-carbon-29e, sialia-45-sport.

begin;

-- optima-e10  source: https://www.optima-yachts.com/optimae10
-- Standard: fridge/freezer, induction hob/grill, hot water, electric toilet w/ holding tank,
-- deck transom shower, VHF, multi-function displays at helm, AC charger, AC inverter.
-- Options: solar panels, radar, electric oven, microwave, heating, air-conditioning, bow thruster.
-- Cabin with large double bed => 1 cabin / 2 berths.
update models set
  cabins = 1,
  berths = 2,
  equipment = array(select distinct e from unnest(equipment || array['fridge','cooker','hot-water','toilets','electric-head','cockpit-shower','vhf','plotter','battery-charger','inverter','solar-panel','radar','oven','microwave-oven','heating','air-conditioning','bow-thruster']::text[]) as e)
where slug = 'optima-e10';

-- pixii-sp800  source: https://pixii.co.uk/pixii-sp800/
-- Standard: solar panels (power onboard appliances), touch screen with 3-D sonar mapping.
-- Options: wireless speakers, infrared heating. Open boat, no accommodation stated.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','plotter','depth-sounder','cockpit-speakers','heating']::text[]) as e)
where slug = 'pixii-sp800';

-- pol-lux  source: https://polboat.se (Readymag content API, page 6196108bd36464002cb6f8dc)
-- "Inlayed solar cells constantly feed energy to the batteries"; "for faster charging simply
-- plug in at the harbour". Sleeping is in an on-board tent on convertible benches — berth count
-- not stated, so cabins/berths skipped.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','shore-power-inlet']::text[]) as e)
where slug = 'pol-lux';

-- princecraft-brio-e17  source: https://www.princecraft.com/us/en/products/Pontoons/2026/Brio-Electric-Series/Brio-e--17.aspx
-- Standard: swim platform, stern boarding ladder, battery chargers.
-- Options: Concert Package (radio, speakers), removable table with cup holders, rod holders (3).
update models set
  equipment = array(select distinct e from unnest(equipment || array['swimming-platform','swimming-ladder','battery-charger','cockpit-speakers','cockpit-table','fishing-rod-holders']::text[]) as e)
where slug = 'princecraft-brio-e17';

-- q-yachts-q30  source: https://q-yachts.com/wp-content/uploads/2022/06/Q_Yachts_Option-list_A4_2022_06_screen_1.pdf (via https://q-yachts.com/q30/)
-- Standard: 12V house battery, shore charger 220VAC, Isotherm 16 L refrigerator (2nd optional),
-- retracting bathing ladder, aft sunbathing platform for two, cockpit cushions, electric + manual
-- bilge pumps, Tecma electric freshwater toilet, aft deck shower, natural teak cockpit sole,
-- courtesy LED exterior lights. Cabin under deck => 1 cabin (berth count not stated).
update models set
  cabins = 1,
  equipment = array(select distinct e from unnest(equipment || array['power-12v','shore-power-inlet','battery-charger','fridge','swimming-ladder','stern-sunbathing-cushions','cockpit-cushions','bilge-pump','toilets','electric-head','cockpit-shower','teak-cockpit','cockpit-lighting']::text[]) as e)
where slug = 'q-yachts-q30';

-- rand-escape-30  source: https://randboats-geneve.com/boats/escape-30/index.html
-- Lower-deck cabin with queen-size bed for two, toilet, triple aft sun lounge, large swim platform.
update models set
  cabins = 1,
  berths = 2,
  equipment = array(select distinct e from unnest(equipment || array['toilets','swimming-platform','stern-sunbathing-cushions']::text[]) as e)
where slug = 'rand-escape-30';

-- rand-leisure-28-electric  source: https://www.randboats.com/boats/leisure-28
-- "2-person luxury cabin on lower deck", "2-split door toilet", triple aft sun lounge.
update models set
  cabins = 1,
  berths = 2,
  equipment = array(select distinct e from unnest(equipment || array['toilets','stern-sunbathing-cushions']::text[]) as e)
where slug = 'rand-leisure-28-electric';

-- rand-mana-23  sources: https://www.randboats.com/boats/mana-23 ; https://randboats-usa.com/mana-23/
-- Solar cells integrated under the aft sun lounge, center dining table, aft double sun lounge.
-- Note: the main-site page at /boats/mana-23 now displays the updated "Mana 24"; the US page
-- still lists Mana 23 with the aft double sun lounge.
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','cockpit-table','stern-sunbathing-cushions']::text[]) as e)
where slug = 'rand-mana-23';

-- rand-source-22-electric  source: https://randboats-usa.com/source-22/
-- Standard adjustable picnic/cockpit table (converts to sun lounge). No other mappable items.
update models set
  equipment = array(select distinct e from unnest(equipment || array['cockpit-table']::text[]) as e)
where slug = 'rand-source-22-electric';

-- ripple-boats-10m-day-cruiser  source: https://www.rippleboats.com/the-launch-edition
-- "a comfortable cabin for two adults for luxurious layovers" => 1 cabin / 2 berths.
update models set
  cabins = 1,
  berths = 2
where slug = 'ripple-boats-10m-day-cruiser';

-- sialia-57-deep-silence  source: https://www.sialia-yachts.com/yachts/57-deep-silence/
-- "wide beach club with folding sides" => swimming-platform. Cabins described only as
-- "spacious cabins" with no count, so cabins/berths skipped.
update models set
  equipment = array(select distinct e from unnest(equipment || array['swimming-platform']::text[]) as e)
where slug = 'sialia-57-deep-silence';

commit;

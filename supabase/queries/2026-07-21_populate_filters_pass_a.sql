-- Pass A: populate marketplace filter columns (cabins, berths, equipment)
-- extracted ONLY from facts explicitly stated in models.description.
-- Conservative: no inference from boat type or brand; ambiguous phrasing skipped.
-- Generated 2026-07-21. Review before applying.

begin;

-- alfastreet-23-cabin-evo: extracted from description ("mini-galley, V-berth, and head")
update models set
  equipment = array(select distinct e from unnest(equipment || array['toilets']::text[]) as e)
where slug = 'alfastreet-23-cabin-evo';

-- alva-ocean-eco-60: extracted from description ("Integrated solar array up to 20kW peak across ~80 sqm of panels")
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'alva-ocean-eco-60';

-- blue-innovations-group-r30: extracted from description ("Air-conditioned cabin with convertible dinette/berth, kitchenette, head with bidet, roof + slide-out solar panels")
update models set
  cabins = 1,
  equipment = array(select distinct e from unnest(equipment || array['air-conditioning','convertible-saloon','toilets','solar-panel']::text[]) as e)
where slug = 'blue-innovations-group-r30';

-- cosmopolitan-yachts-66: extracted from description ("Combines battery, solar panel, and ICE-generator power sources")
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','generator']::text[]) as e)
where slug = 'cosmopolitan-yachts-66';

-- crooze-yachts-ez28: extracted from description ("Features WC, wet bar and grill, stern shower")
update models set
  equipment = array(select distinct e from unnest(equipment || array['toilets','barbecue','cockpit-shower']::text[]) as e)
where slug = 'crooze-yachts-ez28';

-- earthling-e40-power-catamaran: extracted from description ("2kW solar array (also used for water heating)")
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','hot-water']::text[]) as e)
where slug = 'earthling-e40-power-catamaran';

-- elvene-amber: extracted from description ("day-cruiser overnight comfort (2-person cuddy cabin). Integrated walkable solar panels")
update models set
  cabins = 1,
  berths = 2,
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'elvene-amber';

-- gosun-elcat: extracted from description ("rechargeable via a pair of 100W solar panels")
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'gosun-elcat';

-- marian-m800: extracted from description ("teak deck, fully customizable finishes")
update models set
  equipment = array(select distinct e from unnest(equipment || array['teak']::text[]) as e)
where slug = 'marian-m800';

-- novaluxe-elight-40: extracted from description ("Enclosed cabins in each hull, enclosed head" -- power catamaran, one per hull = 2)
update models set
  cabins = 2,
  equipment = array(select distinct e from unnest(equipment || array['toilets','solar-panel']::text[]) as e)
where slug = 'novaluxe-elight-40';

-- novaluxe-orphie-39: extracted from description ("solar integration, minimalist cabin")
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'novaluxe-orphie-39';

-- persico-zagato-100-2: extracted from description ("Reverse bow, wraparound windshield, aft sunpad")
update models set
  equipment = array(select distinct e from unnest(equipment || array['stern-sunbathing-cushions']::text[]) as e)
where slug = 'persico-zagato-100-2';

-- pol-lux: extracted from description ("Roof-mounted solar panels charge the battery underway and while docked")
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'pol-lux';

-- q-yachts-q30: extracted from description ("charges from standard 230V shore power")
update models set
  equipment = array(select distinct e from unnest(equipment || array['shore-power-inlet']::text[]) as e)
where slug = 'q-yachts-q30';

-- rand-escape-30: extracted from description ("aft triple sun lounge, dining/helm area with a toilet")
update models set
  equipment = array(select distinct e from unnest(equipment || array['toilets','stern-sunbathing-cushions']::text[]) as e)
where slug = 'rand-escape-30';

-- rand-spirit-25-electric: extracted from description ("a triple-bed aft sun lounge")
update models set
  equipment = array(select distinct e from unnest(equipment || array['stern-sunbathing-cushions']::text[]) as e)
where slug = 'rand-spirit-25-electric';

-- say-carbon-29e: extracted from description ("Built-in 22kW charger gives a full recharge in 6 hours")
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger']::text[]) as e)
where slug = 'say-carbon-29e';

-- sialia-57-deep-silence: extracted from description ("a diesel engine acts as an onboard generator/backup")
update models set
  equipment = array(select distinct e from unnest(equipment || array['generator']::text[]) as e)
where slug = 'sialia-57-deep-silence';

-- sialia-80-explorer: extracted from description ("4 guest cabins + 2 crew berths" -- guest cabins only; crew figure is berths, not cabins)
update models set
  cabins = 4
where slug = 'sialia-80-explorer';

-- silent-yachts-28-speed: extracted from description ("100kWh battery topped up by built-in solar")
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'silent-yachts-28-speed';

-- silent-yachts-60: extracted from description ("rooftop solar array" -- range-extender generator is optional, so not included)
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'silent-yachts-60';

-- silent-yachts-62: extracted from description ("powered primarily by rooftop solar")
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'silent-yachts-62';

-- silent-yachts-80-tri-deck: extracted from description ("diesel generators as range extenders, up to ~90 m2 solar panel coverage")
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel','generator']::text[]) as e)
where slug = 'silent-yachts-80-tri-deck';

-- soel-soelcat-12: extracted from description ("Fully energy-autonomous (solar) catamaran" -- day head only in the commercial configuration, so toilets not included)
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'soel-soelcat-12';

-- sun-concept-cat-12-0-cruise: extracted from description ("Sleeping capacity for up to 7 across double cabins with private bathrooms")
update models set
  berths = 7,
  equipment = array(select distinct e from unnest(equipment || array['toilets']::text[]) as e)
where slug = 'sun-concept-cat-12-0-cruise';

-- sunreef-80-power-eco: extracted from description ("up to 200 m2 of composite-integrated solar panels")
update models set
  equipment = array(select distinct e from unnest(equipment || array['solar-panel']::text[]) as e)
where slug = 'sunreef-80-power-eco';

-- vision-marine-v24: extracted from description ("Onboard charger supports 120-240V (30-50A)")
update models set
  equipment = array(select distinct e from unnest(equipment || array['battery-charger']::text[]) as e)
where slug = 'vision-marine-v24';

-- zen-yachts-zenriver: extracted from description ("2 cabins, 6 berths, ~25 sqm of living space")
update models set
  cabins = 2,
  berths = 6
where slug = 'zen-yachts-zenriver';

commit;

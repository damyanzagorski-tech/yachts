// Canonical equipment vocabulary for the marketplace filters.
// The DB (models.equipment text[]) stores ONLY these kebab-case slugs —
// this file is the single source of truth for what's allowed, and is the
// vocabulary handed to research agents when populating data, so no
// free-text drift enters the database.
//
// Filter UI rule: an option is only rendered when >=1 model in the
// dataset carries its slug; a group is hidden when none of its items are.

export type EquipmentItem = { slug: string; label: string };
export type EquipmentGroup = { group: string; items: EquipmentItem[] };

export const EQUIPMENT_GROUPS: EquipmentGroup[] = [
  {
    group: 'Electrical',
    items: [
      { slug: 'power-12v', label: '12V system' },
      { slug: 'power-24v', label: '24V system' },
      { slug: 'power-110v', label: '110V system' },
      { slug: 'power-220v', label: '220V system' },
      { slug: 'shore-power-inlet', label: 'Shore power inlet' },
      { slug: 'battery-charger', label: 'Battery charger' },
      { slug: 'inverter', label: 'Inverter' },
      { slug: 'generator', label: 'Generator' },
      { slug: 'solar-panel', label: 'Solar panels' },
      { slug: 'wind-generator', label: 'Wind generator' },
    ],
  },
  {
    group: 'Navigation & electronics',
    items: [
      { slug: 'autopilot', label: 'Autopilot' },
      { slug: 'compass', label: 'Compass' },
      { slug: 'plotter', label: 'GPS / chartplotter' },
      { slug: 'radar', label: 'Radar' },
      { slug: 'radar-detector', label: 'Radar detector' },
      { slug: 'depth-sounder', label: 'Depth sounder' },
      { slug: 'fishing-depth-sounder', label: 'Fishing depth sounder' },
      { slug: 'log-speedometer', label: 'Log / speedometer' },
      { slug: 'wind-instruments', label: 'Wind speed & direction' },
      { slug: 'vhf', label: 'VHF radio' },
      { slug: 'antenna', label: 'Antenna' },
      { slug: 'repeaters', label: 'Instrument repeaters' },
    ],
  },
  {
    group: 'Comfort & interior',
    items: [
      { slug: 'air-conditioning', label: 'Air conditioning' },
      { slug: 'heating', label: 'Heating' },
      { slug: 'hot-water', label: 'Hot water' },
      { slug: 'convertible-saloon', label: 'Convertible saloon' },
      { slug: 'tv-set', label: 'TV set' },
      { slug: 'cd-player', label: 'CD player' },
      { slug: 'dvd-player', label: 'DVD player' },
      { slug: 'cockpit-speakers', label: 'Cockpit speakers' },
    ],
  },
  {
    group: 'Galley',
    items: [
      { slug: 'cooker', label: 'Cooker' },
      { slug: 'oven', label: 'Oven' },
      { slug: 'microwave-oven', label: 'Microwave oven' },
      { slug: 'fridge', label: 'Fridge' },
      { slug: 'deep-freezer', label: 'Deep freezer' },
      { slug: 'ice-box', label: 'Ice box' },
      { slug: 'dish-washer', label: 'Dishwasher' },
      { slug: 'washing-machine', label: 'Washing machine' },
      { slug: 'barbecue', label: 'Barbecue' },
    ],
  },
  {
    group: 'Water & sanitation',
    items: [
      { slug: 'fresh-water-maker', label: 'Fresh water maker' },
      { slug: 'sea-water-pump', label: 'Sea water pump' },
      { slug: 'bilge-pump', label: 'Bilge pump' },
      { slug: 'marine-head', label: 'Marine head (WC)' },
      { slug: 'electric-head', label: 'Electric head' },
      { slug: 'chemical-head', label: 'Chemical head' },
      { slug: 'toilets', label: 'Toilet' },
      { slug: 'cockpit-shower', label: 'Cockpit shower' },
    ],
  },
  {
    group: 'Deck & exterior',
    items: [
      { slug: 'bow-thruster', label: 'Bow thruster' },
      { slug: 'stern-thruster', label: 'Stern thruster' },
      { slug: 'swimming-platform', label: 'Swimming platform' },
      { slug: 'swimming-ladder', label: 'Swimming ladder' },
      { slug: 'gangway', label: 'Gangway' },
      { slug: 'hydraulic-gangway', label: 'Hydraulic gangway' },
      { slug: 'davits', label: 'Davits' },
      { slug: 'beaching-legs', label: 'Beaching legs' },
      { slug: 'roll-bar', label: 'Roll bar' },
      { slug: 'outboard-engine-brackets', label: 'Outboard engine brackets' },
      { slug: 'windscreen-wipers', label: 'Windscreen wipers' },
      { slug: 'cockpit-table', label: 'Cockpit table' },
      { slug: 'cockpit-cushions', label: 'Cockpit cushions' },
      { slug: 'cockpit-lighting', label: 'Cockpit lighting' },
      { slug: 'fore-sunbathing-cushions', label: 'Fore sunbathing cushions' },
      { slug: 'stern-sunbathing-cushions', label: 'Stern sunbathing cushions' },
      { slug: 'teak', label: 'Teak' },
      { slug: 'teak-cockpit', label: 'Teak cockpit' },
      { slug: 'teak-sidedecks', label: 'Teak sidedecks' },
    ],
  },
  {
    group: 'Fishing & watersports',
    items: [
      { slug: 'fishing-rod-holders', label: 'Fishing rod holders' },
      { slug: 'big-game-fishing-chair', label: 'Big game fishing chair' },
      { slug: 'ski-pole', label: 'Ski pole' },
    ],
  },
];

export const EQUIPMENT_LABELS: Record<string, string> = Object.fromEntries(
  EQUIPMENT_GROUPS.flatMap((g) => g.items.map((i) => [i.slug, i.label])),
);

export const ALL_EQUIPMENT_SLUGS: string[] = Object.keys(EQUIPMENT_LABELS);

// Hand-written types mirroring the tables in electroyachts_schema.sql.
// Keep in sync with the schema file — regenerate manually when it changes
// (or swap for `supabase gen types typescript` once the project is live).

export type ManufacturerStatus = 'prospect' | 'contacted' | 'partner' | 'active' | 'inactive';
export type ManufacturerProductLine = 'electric_only' | 'mixed_electric_conventional';
export type BoatCategory = 'day_boat' | 'cruiser' | 'catamaran' | 'tender' | 'sport' | 'limousine' | 'other';
export type PropulsionType = 'electric' | 'hybrid_electric' | 'conventional';
export type MarketTier = 'entry' | 'premium' | 'luxury' | 'ultra_luxury';

export type Manufacturer = {
  id: string;
  name: string;
  slug: string;
  country: string | null;
  website: string | null;
  logo_url: string | null;
  description: string | null;
  founded_year: number | null;
  status: ManufacturerStatus;
  product_line: ManufacturerProductLine;
  has_affiliate_program: boolean;
  listing_tier: string | null;
  is_verified: boolean;
  created_at: string;
  updated_at: string;
};

export type Model = {
  id: string;
  manufacturer_id: string;
  name: string;
  slug: string;
  category: BoatCategory;
  propulsion_type: PropulsionType;
  market_tier: MarketTier | null;
  length_m: number | null;
  beam_m: number | null;
  draft_m: number | null;
  weight_kg: number | null;
  passenger_capacity: number | null;
  battery_kwh: number | null;
  motor_power_kw: number | null;
  top_speed_knots: number | null;
  range_nm: number | null;
  charging_time_hours: number | null;
  price_from_eur: number | null;
  price_to_eur: number | null;
  ce_category: string | null;
  description: string | null;
  hero_image_url: string | null;
  gallery_urls: string[] | null;
  video_url: string | null;
  brochure_url: string | null;
  is_featured: boolean;
  is_sponsored: boolean;
  status: string;
  created_at: string;
  updated_at: string;
};

export type ModelWithManufacturer = Model & {
  manufacturers: Pick<Manufacturer, 'id' | 'name' | 'slug' | 'logo_url' | 'country'>;
};

export type ModelPowertrain = {
  id: string;
  model_id: string;
  propulsion_type: PropulsionType;
  is_primary: boolean;
  motor_brand: string | null;
  motor_model: string | null;
  motor_count: number;
  motor_power_kw: number | null;
  battery_brand: string | null;
  battery_kwh: number | null;
  charging_time_hours: number | null;
  fast_charge_minutes: number | null;
  top_speed_knots: number | null;
  cruise_speed_knots: number | null;
  range_nm: number | null;
  range_at_knots: number | null;
  price_from_eur: number | null;
  notes: string | null;
  created_at: string;
  updated_at: string;
};

export type Database = {
  public: {
    Tables: {
      manufacturers: {
        Row: Manufacturer;
        Insert: Partial<Manufacturer>;
        Update: Partial<Manufacturer>;
      };
      models: {
        Row: Model;
        Insert: Partial<Model>;
        Update: Partial<Model>;
      };
      model_powertrains: {
        Row: ModelPowertrain;
        Insert: Partial<ModelPowertrain>;
        Update: Partial<ModelPowertrain>;
      };
    };
  };
};

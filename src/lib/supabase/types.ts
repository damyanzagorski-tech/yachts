// Hand-written types mirroring the tables in electroyachts_schema.sql.
// Keep in sync with the schema file — regenerate manually when it changes
// (or swap for `supabase gen types typescript` once the project is live).

import type { ContentPage, ContentPageGroup } from './content';

export type ManufacturerStatus = 'prospect' | 'contacted' | 'partner' | 'active' | 'inactive';
export type ManufacturerProductLine = 'electric_only' | 'mixed_electric_conventional';
export type BoatCategory = 'day_boat' | 'cruiser' | 'catamaran' | 'tender' | 'sport' | 'limousine' | 'other';

export const CATEGORY_LABELS: Record<BoatCategory, string> = {
  day_boat: 'Day Boats',
  cruiser: 'Cruisers',
  catamaran: 'Catamarans',
  tender: 'Tenders',
  sport: 'Sport Boats',
  limousine: 'Limousines',
  other: 'Other',
};
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
  cabins: number | null;
  berths: number | null;
  air_draught_m: number | null;
  keel_type: string | null;
  equipment: string[];
  price_from_eur: number | null;
  price_to_eur: number | null;
  ce_category: string | null;
  description: string | null;
  hero_image_url: string | null;
  gallery_urls: string[] | null;
  color_variant_urls: string[] | null;
  video_url: string | null;
  brochure_url: string | null;
  is_featured: boolean;
  is_sponsored: boolean;
  status: string;
  created_at: string;
  updated_at: string;
};

export type ModelWithManufacturer = Model & {
  manufacturers: Pick<Manufacturer, 'id' | 'name' | 'slug' | 'logo_url' | 'country' | 'is_verified' | 'status'>;
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

export type LeadStatus = 'new' | 'qualified' | 'call_booked' | 'offer_sent' | 'won' | 'lost';
export type LeadSource = 'organic_seo' | 'paid_ads' | 'referral' | 'direct' | 'newsletter' | 'partner' | 'other';

export type Lead = {
  id: string;
  full_name: string | null;
  email: string | null;
  phone: string | null;
  country: string | null;
  preferred_language: string | null;
  interested_model_id: string | null;
  interested_category: BoatCategory | null;
  budget_min_eur: number | null;
  budget_max_eur: number | null;
  purchase_timeframe: string | null;
  source: LeadSource;
  source_domain: string | null;
  utm_campaign: string | null;
  lead_score: number | null;
  status: LeadStatus;
  notes: string | null;
  gdpr_consent_at: string | null;
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
        Relationships: [];
      };
      models: {
        Row: Model;
        Insert: Partial<Model>;
        Update: Partial<Model>;
        Relationships: [];
      };
      model_powertrains: {
        Row: ModelPowertrain;
        Insert: Partial<ModelPowertrain>;
        Update: Partial<ModelPowertrain>;
        Relationships: [];
      };
      leads: {
        Row: Lead;
        Insert: Partial<Lead>;
        Update: Partial<Lead>;
        Relationships: [];
      };
      content_page_groups: {
        Row: ContentPageGroup;
        Insert: Partial<ContentPageGroup>;
        Update: Partial<ContentPageGroup>;
        Relationships: [];
      };
      content_pages: {
        Row: ContentPage;
        Insert: Partial<ContentPage>;
        Update: Partial<ContentPage>;
        Relationships: [];
      };
    };
    // supabase-js's GenericSchema needs these keys present for its
    // Insert/Update type inference to resolve (otherwise inserts type as never[])
    Views: Record<string, never>;
    Functions: Record<string, never>;
  };
};

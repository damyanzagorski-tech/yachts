export type ContentType =
  | 'review'
  | 'news'
  | 'buyer_guide'
  | 'comparison'
  | 'landing_page'
  | 'manufacturer_page'
  | 'model_page';

export type ContentStatus = 'draft' | 'in_review' | 'published' | 'needs_update' | 'archived';

export type ContentPage = {
  id: string;
  page_group_id: string;
  title: string;
  slug: string;
  url_path: string;
  language: string;
  primary_keyword: string | null;
  meta_description: string | null;
  body_markdown: string | null;
  status: ContentStatus;
  published_at: string | null;
  created_at: string;
  updated_at: string;
};

export type ContentPageGroup = {
  id: string;
  group_key: string;
  content_type: ContentType;
  country: string | null;
  related_manufacturer_id: string | null;
  related_model_id: string | null;
  created_at: string;
  updated_at: string;
};

export type ContentPageWithGroup = ContentPage & {
  content_page_groups: Pick<ContentPageGroup, 'content_type' | 'related_manufacturer_id' | 'related_model_id'>;
};

export const CONTENT_TYPE_LABELS: Record<ContentType, string> = {
  review: 'Review',
  news: 'News',
  buyer_guide: "Buyer's Guide",
  comparison: 'Comparison',
  landing_page: 'Overview',
  manufacturer_page: 'Manufacturer Feature',
  model_page: 'Model Feature',
};

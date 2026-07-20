'use client';

import Image from 'next/image';
import Link from 'next/link';
import { VerifiedBadge } from '@/components/VerifiedBadge';
import type { MarketplaceModel } from '@/lib/marketplace/filters';

const eurFormatter = new Intl.NumberFormat('en-EU', {
  style: 'currency',
  currency: 'EUR',
  maximumFractionDigits: 0,
});

function formatPrice(model: MarketplaceModel): string {
  return model.price_from_eur ? `From ${eurFormatter.format(model.price_from_eur)}` : 'Price on request';
}

function specLine(model: MarketplaceModel): string {
  const parts: string[] = [];
  if (model.length_m !== null) parts.push(`${model.length_m} m`);
  if (model.motor_power_kw !== null) parts.push(`${model.motor_power_kw} kW`);
  if (model.range_nm !== null) parts.push(`${model.range_nm} nm`);
  return parts.join(' · ');
}

export function ModelCard({
  model,
  checked,
  compareDisabled,
  onToggleCompare,
}: {
  model: MarketplaceModel;
  checked: boolean;
  compareDisabled: boolean;
  onToggleCompare: () => void;
}) {
  const specs = specLine(model);
  return (
    <li className="overflow-hidden rounded-lg border border-rule bg-ink-2 transition-colors hover:border-copper">
      <Link href={`/models/${model.slug}`} className="block">
        <div className="relative aspect-[4/3] overflow-hidden bg-ink-soft">
          {model.manufacturers?.status === 'partner' && <VerifiedBadge />}
          {model.hero_image_url ? (
            <Image
              src={model.hero_image_url}
              alt={`${model.manufacturers?.name ?? ''} ${model.name}`}
              fill
              sizes="(max-width: 640px) 100vw, (max-width: 1280px) 50vw, 33vw"
              className="object-cover"
            />
          ) : (
            <div className="flex h-full items-center justify-center">
              <span className="font-serif text-5xl font-light italic text-paper/20">
                {model.name.charAt(0)}
              </span>
            </div>
          )}
        </div>
      </Link>
      <div className="flex items-start gap-3 p-5">
        <input
          type="checkbox"
          checked={checked}
          onChange={onToggleCompare}
          disabled={compareDisabled}
          aria-label={`Select ${model.name} to compare`}
          className="mt-1.5 accent-copper"
        />
        <div className="min-w-0">
          <Link href={`/models/${model.slug}`} className="font-serif text-lg hover:text-copper">
            {model.name}
          </Link>
          <p className="mt-1 text-xs font-semibold uppercase tracking-[0.16em] text-muted">
            {model.manufacturers?.name} · {model.category.replace('_', ' ')}
          </p>
          {specs && <p className="mt-1.5 text-xs text-paper/70">{specs}</p>}
          <p className="mt-2 font-serif text-sm italic text-copper">{formatPrice(model)}</p>
        </div>
      </div>
    </li>
  );
}

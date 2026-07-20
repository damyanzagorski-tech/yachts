/**
 * Green "Verified" marker overlaid on a model's cover image, shown for
 * models whose manufacturer has status = 'partner' (a signed commission/
 * partnership agreement — currently only Crooze Yachts / EZ 28).
 * NOT keyed to manufacturers.is_verified, which in this dataset means
 * "specs verified by research" and is true for most manufacturers.
 * Parent element must be position: relative.
 */
export function VerifiedBadge() {
  return (
    <span className="absolute left-3 top-3 z-10 inline-flex items-center gap-1.5 rounded-full bg-emerald-600/95 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-[0.14em] text-white shadow-md">
      <svg viewBox="0 0 12 12" className="h-2.5 w-2.5" fill="none" aria-hidden>
        <path d="M2 6.2 4.8 9 10 3.4" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      Verified
    </span>
  );
}

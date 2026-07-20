import type { NextConfig } from "next";

// Manufacturer domains we hotlink model hero/gallery images from (models.hero_image_url,
// color_variant_urls). No commission/content agreement exists for these manufacturers
// (see CLAUDE.md) — we link to their own official site's image, we don't rehost it.
// Add a new entry here whenever a new manufacturer's image is sourced.
const MANUFACTURER_IMAGE_HOSTS = [
  "a.storyblok.com",
  "alfastreet-yachts.com",
  "boesch.swiss",
  "bord-a-bord-boat.com",
  "build.chriscraft.com",
  "build.princecraft.com",
  "candela.com",
  "cdn.prod.website-files.com",
  "cosmopolitanyachts.com",
  "crestpontoonboats.com",
  "elveneboats.com",
  "foiler.com",
  "frg-fwm.azurewebsites.net",
  "gosun.co",
  "heliosmarine.io",
  "images.squarespace-cdn.com",
  "ingenityelectric.com",
  "labellaverde.com",
  "lumenyachts.com",
  "marianboats.at",
  "media.ffycdn.net",
  "nimbusboats.com",
  "pixii.co.uk",
  "q-yachts.com",
  "randboats-usa.com",
  "silennis.com",
  "silent-yachts.com",
  "soelyachts.com",
  "spirityachts.com",
  "static.wixstatic.com",
  "sunreef-catamarans.com",
  "visionelectricboats.com",
  "vita-power.com",
  "voltarielectric.com",
  "www.delphiayachts.com",
  "www.duffyboats.com",
  "www.frauscherboats.com",
  "www.frauscherxporsche.com",
  "www.greenlinehybridusa.com",
  "www.hinckleyyachts.com",
  "www.nero-yachts.com",
  "www.orphieboats.com",
  "www.persicomarine.com",
  "www.randboats-geneve.com",
  "www.rippleboats.com",
  "www.rssailing.com",
  "www.sialia-yachts.com",
  "www.stranaboats.com",
  "www.sunconcept.pt",
  "www.zodiac-nautic.com",
];

const nextConfig: NextConfig = {
  images: {
    remotePatterns: MANUFACTURER_IMAGE_HOSTS.map((hostname) => ({
      protocol: "https" as const,
      hostname,
    })),
  },
  // TODO: remove before public launch — blocks all search indexing (see src/app/layout.tsx too).
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [{ key: "X-Robots-Tag", value: "noindex, nofollow" }],
      },
    ];
  },
};

export default nextConfig;

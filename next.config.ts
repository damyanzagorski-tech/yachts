import type { NextConfig } from "next";

const nextConfig: NextConfig = {
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

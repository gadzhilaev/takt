import type { Metadata } from "next";
import { LandingPage } from "@/components/landing/landing-page";

const TITLE = "Takt — трекер, который не надо обновлять";
const DESCRIPTION =
  "Команда за 10 секунд отвечает на ежедневный чек-ин, задачи двигаются сами, а руководитель видит сводку: что сделано, что застряло и где узкое место. Для колледжей и небольших организаций.";
const OG_IMAGE = { url: "/brand/og-takt.png", width: 1200, height: 630, alt: "Takt — трекер, который не надо обновлять" };

export const metadata: Metadata = {
  title: TITLE,
  description: DESCRIPTION,
  openGraph: {
    title: TITLE,
    description: DESCRIPTION,
    type: "website",
    locale: "ru_RU",
    siteName: "Takt",
    url: "https://taktapp.ru",
    images: [OG_IMAGE],
  },
  twitter: {
    card: "summary_large_image",
    title: TITLE,
    description: DESCRIPTION,
    images: [OG_IMAGE.url],
  },
  alternates: { canonical: "https://taktapp.ru" },
};

export default function HomePage() {
  return <LandingPage />;
}

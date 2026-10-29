import type { Metadata } from "next";
import { LandingPage } from "@/components/landing/landing-page";

export const metadata: Metadata = {
  title: "Takt — работа команды в одном ритме",
  description:
    "Простой Kanban-менеджер проектов и задач: доски, исполнители, приоритеты и уведомления для команды.",
  openGraph: {
    title: "Takt — работа команды в одном ритме",
    description:
      "Простой Kanban-менеджер проектов и задач: доски, исполнители, приоритеты и уведомления.",
    type: "website",
    locale: "ru_RU",
    siteName: "Takt",
    url: "https://taktapp.ru",
    images: [{ url: "/brand/takt-symbol.svg", alt: "Takt" }],
  },
  twitter: {
    card: "summary",
    title: "Takt — работа команды в одном ритме",
    description: "Простой Kanban для проектов и задач команды.",
  },
  alternates: { canonical: "https://taktapp.ru" },
};

export default function HomePage() {
  return <LandingPage />;
}

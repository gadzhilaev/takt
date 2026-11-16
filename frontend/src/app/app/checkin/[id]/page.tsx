"use client";

import { useParams } from "next/navigation";
import { CheckinPage } from "@/components/checkin-page";

export default function CheckinRoute() {
  const { id } = useParams<{ id: string }>();
  return <CheckinPage checkinId={id} />;
}

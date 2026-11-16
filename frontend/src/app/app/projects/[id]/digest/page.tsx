"use client";

import { Suspense } from "react";
import { useParams } from "next/navigation";
import { DigestView } from "@/components/digest-view";

export default function ProjectDigestRoute() {
  const { id } = useParams<{ id: string }>();
  return (
    <Suspense fallback={null}>
      <DigestView projectId={id} />
    </Suspense>
  );
}

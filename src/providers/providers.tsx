"use client";

import { QueryProvider } from "@/providers/query-provider";

export function Providers({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return <QueryProvider>{children}</QueryProvider>;
}

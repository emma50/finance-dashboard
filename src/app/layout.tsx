import type { Metadata } from "next";

import { Providers } from "@/providers/providers";

import "./globals.css";

export const metadata: Metadata = {
  title: {
    default: "Finance Dashboard",
    template: "%s | Finance Dashboard",
  },
  description: "A production-minded personal finance dashboard.",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}

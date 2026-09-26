import Link from "next/link";

import { navigationItems } from "@/lib/constants/navigation";

export function Sidebar() {
  return (
    <aside className="border-border bg-surface fixed inset-y-0 left-0 z-40 hidden w-64 border-r lg:block">
      <div className="flex h-full flex-col">
        <div className="border-border border-b px-6 py-5">
          <Link href="/dashboard" className="font-semibold tracking-tight">
            Finance
          </Link>
        </div>

        <nav className="flex-1 space-y-1 p-4" aria-label="Primary navigation">
          {navigationItems.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="text-muted hover:text-foreground flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm hover:bg-black/5"
            >
              <item.icon aria-hidden="true" className="size-4" />
              {item.label}
            </Link>
          ))}
        </nav>
      </div>
    </aside>
  );
}

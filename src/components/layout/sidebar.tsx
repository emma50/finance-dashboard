import Link from "next/link";
import { X } from "lucide-react";

import { navigationItems } from "@/lib/constants/navigation";

type SidebarProps = {
  isOpen: boolean;
  onClose: () => void;
  onMenuToggle: () => void;
};

export function Sidebar({ isOpen, onClose, onMenuToggle }: SidebarProps) {
  return (
    <>
      {/* Desktop sidebar */}
      <aside className="border-border bg-surface fixed inset-y-0 left-0 z-40 hidden w-64 border-r lg:block">
        <SidebarContent />
      </aside>

      {/* Mobile + tablet sidebar */}
      <div
        className={`fixed inset-0 z-50 lg:hidden ${
          isOpen ? "visible" : "invisible"
        }`}
        aria-hidden={!isOpen}
      >
        <button
          type="button"
          aria-label="Close navigation"
          onClick={onClose}
          className={`absolute inset-0 bg-black/40 transition-opacity ${
            isOpen ? "opacity-100" : "opacity-0"
          }`}
        />

        <aside
          id="mobile-navigation"
          aria-label="Mobile navigation"
          className={`relative z-10 h-full w-72 max-w-[85vw] border-r border-border bg-surface shadow-xl transition-transform duration-200 ease-out ${
            isOpen ? "translate-x-0" : "-translate-x-full"
          }`}
        >
          <div className="flex h-16 items-center justify-between border-b border-border px-4">
            <Link
              href="/dashboard"
              onClick={onClose}
              className="font-semibold tracking-tight"
            >
              Finance
            </Link>

            <button
              type="button"
              aria-label="Close navigation"
              onClick={onClose}
              className="rounded-lg p-2 text-muted hover:bg-black/5 hover:text-foreground"
            >
              <X aria-hidden="true" className="size-5" />
            </button>
          </div>

          <nav
            className="space-y-1 p-4"
            aria-label="Primary mobile navigation"
          >
            {navigationItems.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                onClick={onClose}
                className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-muted hover:bg-black/5 hover:text-foreground"
              >
                <item.icon aria-hidden="true" className="size-4" />
                {item.label}
              </Link>
            ))}
          </nav>
        </aside>
      </div>
    </>
  );
}

function SidebarContent() {
  return (
    <div className="flex h-full flex-col">
      <div className="border-b border-border px-6 py-5">
        <Link href="/dashboard" className="font-semibold tracking-tight">
          Finance
        </Link>
      </div>

      <nav className="flex-1 space-y-1 p-4" aria-label="Primary navigation">
        {navigationItems.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className="flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm text-muted hover:bg-black/5 hover:text-foreground"
          >
            <item.icon aria-hidden="true" className="size-4" />
            {item.label}
          </Link>
        ))}
      </nav>
    </div>
  );
}

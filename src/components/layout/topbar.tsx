import { Menu } from "lucide-react";

type TopbarProps = {
  isSidebarOpen: boolean;
  onMenuToggle: () => void;
};

export function Topbar({
  isSidebarOpen,
  onMenuToggle,
}: TopbarProps) {
  return (
    <header className="border-border bg-background/95 sticky top-0 z-30 border-b backdrop-blur">
      <div className="flex min-h-16 items-center justify-between px-4 sm:px-6 lg:px-8">
        <div className="flex items-center gap-3">
          <button
            type="button"
            aria-label={isSidebarOpen ? "Close navigation" : "Open navigation"}
            aria-controls="mobile-navigation"
            aria-expanded={isSidebarOpen}
            onClick={onMenuToggle}
            className="rounded-lg p-2 text-muted hover:bg-black/5 hover:text-foreground lg:hidden"
          >
            <Menu aria-hidden="true" className="size-5" />
          </button>

          <p className="text-sm font-medium">Finance Dashboard</p>
        </div>

        <div
          aria-label="User menu placeholder"
          className="size-9 rounded-full bg-black/10"
        />
      </div>
    </header>
  );
}

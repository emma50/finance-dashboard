export function Topbar() {
  return (
    <header className="border-border bg-background/95 sticky top-0 z-30 border-b backdrop-blur">
      <div className="flex min-h-16 items-center justify-between px-4 sm:px-6 lg:px-8">
        <p className="text-sm font-medium">Finance Dashboard</p>
        <div
          aria-label="User menu placeholder"
          className="size-9 rounded-full bg-black/10"
        />
      </div>
    </header>
  );
}

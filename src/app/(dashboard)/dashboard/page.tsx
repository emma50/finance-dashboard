export default function DashboardPage() {
  return (
    <section className="space-y-6">
      <header className="space-y-2">
        <p className="text-muted text-sm font-medium">Dashboard</p>
        <h1 className="text-3xl font-semibold tracking-tight">
          Financial overview
        </h1>
        <p className="text-muted text-sm leading-6">
          Dashboard data components will be introduced after the database,
          authorization and query layers are established.
        </p>
      </header>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        {["Balance", "Income", "Expenses", "Savings rate"].map((label) => (
          <article
            key={label}
            className="border-border bg-surface rounded-2xl border p-5"
          >
            <p className="text-muted text-sm">{label}</p>
            <p className="mt-3 text-2xl font-semibold">—</p>
          </article>
        ))}
      </div>
    </section>
  );
}

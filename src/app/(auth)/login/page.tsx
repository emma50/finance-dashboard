import Link from "next/link";

export default function LoginPage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-md items-center px-6 py-12">
      <section className="border-border bg-surface w-full space-y-6 rounded-2xl border p-6 shadow-sm">
        <div className="space-y-2">
          <p className="text-muted text-sm font-medium">Finance Dashboard</p>
          <h1 className="text-2xl font-semibold tracking-tight">Sign in</h1>
          <p className="text-muted text-sm leading-6">
            Authentication UI will be implemented as its own feature commit.
          </p>
        </div>

        <div className="border-border text-muted rounded-xl border border-dashed p-4 text-sm">
          Supabase SSR clients and session proxy are already scaffolded.
        </div>

        <Link
          href="/"
          className="border-border inline-flex rounded-lg border px-4 py-2 text-sm font-medium"
        >
          Back home
        </Link>
      </section>
    </main>
  );
}

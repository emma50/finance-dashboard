import Link from "next/link";

export default function HomePage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-4xl items-center px-6 py-16">
      <section className="w-full space-y-8">
        <div className="space-y-3">
          <p className="text-muted text-sm font-medium tracking-wide uppercase">
            Finance Dashboard
          </p>
          <h1 className="text-4xl font-semibold tracking-tight sm:text-5xl">
            A production-minded finance app we can build and learn from.
          </h1>
          <p className="text-muted max-w-2xl text-base leading-7">
            The project foundation is ready. Domain features, authentication,
            authorization, data queries, caching and performance experiments
            will be added as small, reviewable commits.
          </p>
        </div>

        <div className="flex flex-wrap gap-3">
          <Link
            href="/login"
            className="bg-foreground rounded-lg px-4 py-2.5 text-sm font-medium text-white"
          >
            Open sign in
          </Link>
          <Link
            href="/dashboard"
            className="border-border bg-surface rounded-lg border px-4 py-2.5 text-sm font-medium"
          >
            Open dashboard shell
          </Link>
        </div>
      </section>
    </main>
  );
}

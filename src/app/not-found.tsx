import Link from "next/link";

export default function NotFound() {
  return (
    <main className="mx-auto flex min-h-screen max-w-lg items-center px-6">
      <section className="border-border bg-surface w-full space-y-4 rounded-2xl border p-6">
        <p className="text-muted text-sm font-medium">404</p>
        <h1 className="text-xl font-semibold">Page not found.</h1>
        <Link
          href="/"
          className="bg-foreground inline-flex rounded-lg px-4 py-2 text-sm font-medium text-white"
        >
          Return home
        </Link>
      </section>
    </main>
  );
}

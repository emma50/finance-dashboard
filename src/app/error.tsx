"use client";

export default function GlobalError({ reset }: { reset: () => void }) {
  return (
    <main className="mx-auto flex min-h-screen max-w-lg items-center px-6">
      <section className="border-border bg-surface w-full space-y-4 rounded-2xl border p-6">
        <h1 className="text-xl font-semibold">Something went wrong.</h1>
        <p className="text-muted text-sm leading-6">
          The application encountered an unexpected error. Try the operation
          again before investigating further.
        </p>
        <button
          type="button"
          onClick={reset}
          className="bg-foreground rounded-lg px-4 py-2 text-sm font-medium text-white"
        >
          Try again
        </button>
      </section>
    </main>
  );
}

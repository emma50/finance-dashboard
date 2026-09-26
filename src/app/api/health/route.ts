export async function GET() {
  return Response.json({
    status: "ok",
    service: "finance-dashboard",
    timestamp: new Date().toISOString(),
  });
}

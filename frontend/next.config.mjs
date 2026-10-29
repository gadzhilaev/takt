/** @type {import('next').NextConfig} */
const nextConfig = {
  output: "standalone",
  async rewrites() {
    const backend = process.env.BACKEND_INTERNAL_URL || "http://localhost:8000";
    return [
      { source: "/api/:path*", destination: `${backend}/api/:path*` },
      { source: "/ws", destination: `${backend}/ws` },
    ];
  },
  async redirects() {
    // Compatibility with bookmarks, push deep links, and pre-/app URLs.
    return [
      { source: "/projects", destination: "/app/projects", permanent: false },
      { source: "/projects/:path*", destination: "/app/projects/:path*", permanent: false },
      { source: "/my", destination: "/app/my-tasks", permanent: false },
      { source: "/my-tasks", destination: "/app/my-tasks", permanent: false },
      { source: "/profile", destination: "/app/profile", permanent: false },
      { source: "/board", destination: "/app/board", permanent: false },
      { source: "/list", destination: "/app/list", permanent: false },
      { source: "/inbox", destination: "/app/inbox", permanent: false },
      { source: "/home", destination: "/app/projects", permanent: false },
      { source: "/report", destination: "/app/projects", permanent: false },
      // /admin is the global platform console (not redirected to /app/admin).
      { source: "/tasks/:id", destination: "/app/tasks/:id", permanent: false },
    ];
  },
};

export default nextConfig;

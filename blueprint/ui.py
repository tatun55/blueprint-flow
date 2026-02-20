#!/usr/bin/env python3
"""Blueprint-Flow Web UI

Run HTTP server with dashboard.
Usage:
  python3 ui.py [--port N]   # default port 3141
"""

import json
import sqlite3
import sys
import webbrowser
from pathlib import Path

DB_PATH = "blueprint/blueprint.db"
UI_HTML = Path(__file__).parent / "ui.html"


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.row_factory = sqlite3.Row
    return conn


def query(sql, params=()):
    conn = get_conn()
    rows = conn.execute(sql, params).fetchall()
    conn.close()
    return [dict(r) for r in rows]


def query_one(sql, params=()):
    conn = get_conn()
    row = conn.execute(sql, params).fetchone()
    conn.close()
    return dict(row) if row else None


def get_stats():
    conn = get_conn()
    bp_total = conn.execute("SELECT COUNT(*) FROM blueprints").fetchone()[0]
    bp_done = conn.execute("SELECT COUNT(*) FROM blueprints WHERE step='done' AND step_status='done'").fetchone()[0]
    bp_dirty = conn.execute("SELECT COUNT(*) FROM blueprints WHERE dirty=1").fetchone()[0]
    bp_active = conn.execute("SELECT COUNT(*) FROM blueprints WHERE step_status='doing'").fetchone()[0]
    act_total = conn.execute("SELECT COUNT(*) FROM acts").fetchone()[0]
    act_done = conn.execute("SELECT COUNT(*) FROM acts WHERE status='done'").fetchone()[0]
    core_total = conn.execute("SELECT COUNT(*) FROM cores").fetchone()[0]
    conn.close()
    return {
        "blueprints": {"total": bp_total, "done": bp_done, "dirty": bp_dirty, "active": bp_active},
        "acts": {"total": act_total, "done": act_done},
        "cores": {"total": core_total},
    }


def serve(port):
    import http.server
    from urllib.parse import urlparse, parse_qs

    API_ROUTES = {
        "/api/stats": lambda p: get_stats(),
        "/api/status": lambda p: query(
            "SELECT id, type, slug, name, summary, step, step_status, locked_by, dirty, dirty_reason "
            "FROM blueprints ORDER BY "
            "CASE type WHEN 'table' THEN 1 WHEN 'layout' THEN 2 WHEN 'partial' THEN 3 "
            "WHEN 'action' THEN 4 WHEN 'page' THEN 5 WHEN 'test' THEN 6 END, id"),
        "/api/progress": lambda p: query("SELECT * FROM project_progress"),
        "/api/cores": lambda p: query("SELECT id, type, slug, name, summary, reviewed FROM cores ORDER BY type, slug"),
        "/api/dependencies": lambda p: query("SELECT * FROM dependency_map"),
        "/api/attention": lambda p: query("SELECT * FROM attention_needed"),
        "/api/acts": lambda p: query(
            "SELECT a.id, a.blueprint_id, a.title, a.status, a.locked_by, a.created_at, a.completed_at, "
            "b.type as bp_type, b.slug as bp_slug "
            "FROM acts a JOIN blueprints b ON a.blueprint_id = b.id ORDER BY a.created_at DESC LIMIT 50"),
        "/api/blueprint": lambda p: query_one(
            "SELECT id, type, slug, name, summary, content, step, step_status, "
            "locked_by, dirty, dirty_reason, parent_id, test_level FROM blueprints WHERE id=?",
            (p.get("id", [None])[0],)),
        "/api/core": lambda p: query_one(
            "SELECT id, type, slug, name, summary, content, reviewed FROM cores WHERE slug=?",
            (p.get("slug", [None])[0],)),
    }

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            parsed = urlparse(self.path)
            path = parsed.path
            params = parse_qs(parsed.query)
            if path in ("", "/"):
                content = UI_HTML.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", "text/html; charset=utf-8")
                self.send_header("Content-Length", len(content))
                self.end_headers()
                self.wfile.write(content)
            elif path in API_ROUTES:
                body = json.dumps(API_ROUTES[path](params), ensure_ascii=False, indent=2).encode()
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.send_header("Content-Length", len(body))
                self.end_headers()
                self.wfile.write(body)
            else:
                self.send_error(404)

        def log_message(self, fmt, *args):
            pass

    if not Path(DB_PATH).exists():
        print(f"Error: {DB_PATH} not found.")
        sys.exit(1)

    server = http.server.HTTPServer(("127.0.0.1", port), Handler)
    url = f"http://127.0.0.1:{port}"
    print(f"Blueprint-Flow UI: {url}")
    print("Press Ctrl+C to stop")
    webbrowser.open(url)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
        server.server_close()


def main():
    args = sys.argv[1:]
    port = 3141
    if "--port" in args:
        idx = args.index("--port")
        port = int(args[idx + 1])
    serve(port)


if __name__ == "__main__":
    main()

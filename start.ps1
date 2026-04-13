# Email Pull - Local Proxy Server
# Serves index.html and proxies API calls to capwatch.flwg.internal
# Usage: Right-click > Run with PowerShell  (or: powershell -ExecutionPolicy Bypass -File start.ps1)

$PORT    = 8080
$API_URL = "http://capwatch.flwg.internal:8888"
$HTML    = Join-Path $PSScriptRoot "index.html"

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$PORT/")
$listener.Start()

Write-Host ""
Write-Host "  Email Pull proxy running at http://localhost:$PORT"
Write-Host "  Open that URL in your browser."
Write-Host "  Press Ctrl+C to stop."
Write-Host ""

# Open browser automatically
Start-Process "http://localhost:$PORT"

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response

        $path = $req.Url.PathAndQuery

        # ── Serve the HTML page ──────────────────────────────────────────────
        if ($path -eq "/" -or $path -eq "/index.html") {
            $bytes = [System.IO.File]::ReadAllBytes($HTML)
            $res.ContentType     = "text/html; charset=utf-8"
            $res.ContentLength64 = $bytes.Length
            $res.OutputStream.Write($bytes, 0, $bytes.Length)

        # ── Proxy all other requests to the API ──────────────────────────────
        } else {
            $target = "$API_URL$path"
            try {
                $wc = New-Object System.Net.WebClient
                $wc.Headers.Add("Accept", "application/json")
                $data = $wc.DownloadData($target)

                $res.StatusCode  = 200
                $res.ContentType = "application/json; charset=utf-8"
                $res.Headers.Add("Access-Control-Allow-Origin", "*")
                $res.ContentLength64 = $data.Length
                $res.OutputStream.Write($data, 0, $data.Length)
                Write-Host "  OK  $path"
            } catch {
                $msg  = [System.Text.Encoding]::UTF8.GetBytes($_.Exception.Message)
                $res.StatusCode  = 502
                $res.ContentType = "text/plain"
                $res.ContentLength64 = $msg.Length
                $res.OutputStream.Write($msg, 0, $msg.Length)
                Write-Host "  ERR $path  ->  $($_.Exception.Message)"
            }
        }

        $res.OutputStream.Close()
    }
} finally {
    $listener.Stop()
    Write-Host "Server stopped."
}

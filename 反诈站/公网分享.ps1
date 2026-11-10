# 公网分享：起服务 + 开 Cloudflare 临时隧道，把链接复制到剪贴板
$ErrorActionPreference = "SilentlyContinue"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$cf = "C:\Program Files (x86)\cloudflared\cloudflared.exe"

if (-not (Test-Path $cf)) {
  Write-Host "找不到 cloudflared：" $cf -ForegroundColor Red
  Read-Host "按回车退出"
  exit 1
}

# 1. 本地服务没跑就起一个
$listen = Get-NetTCPConnection -LocalPort 8020 -State Listen -ErrorAction SilentlyContinue
if (-not $listen) {
  Write-Host "正在启动本地服务……" -ForegroundColor Cyan
  Start-Process -FilePath "py" -ArgumentList "-3","server.py" -WorkingDirectory $root -WindowStyle Hidden
  Start-Sleep -Seconds 4
} else {
  Write-Host "本地服务已经在跑（8020）" -ForegroundColor DarkGray
}

# 2. 开隧道，失败就重试
$log = Join-Path $env:TEMP "cf-share.log"
$url = $null
$p = $null

for ($attempt = 1; $attempt -le 4; $attempt++) {
  if (Test-Path $log) { Remove-Item $log -Force }
  Write-Host "第 $attempt 次尝试开通道……" -ForegroundColor Cyan
  $p = Start-Process -FilePath $cf -ArgumentList "tunnel","--url","http://127.0.0.1:8020","--no-autoupdate" -RedirectStandardError $log -RedirectStandardOutput ($log + ".out") -WindowStyle Hidden -PassThru

  for ($i = 0; $i -lt 45; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $log) {
      $m = Select-String -Path $log -Pattern 'https://(?!api\.)[a-z0-9-]{6,}\.trycloudflare\.com' -AllMatches
      if ($m) { $url = $m.Matches[0].Value; break }
    }
  }
  if ($url) { break }
  Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
  Start-Sleep -Seconds 3
}

if (-not $url) {
  Clear-Host
  Write-Host ""
  Write-Host "  通道没连上。Cloudflare 的免费通道时不时抽风，再点一次通常就好了。" -ForegroundColor Red
  Write-Host "  日志：" $log -ForegroundColor DarkGray
  Write-Host ""
  Read-Host "按回车退出"
  exit 1
}

# 3. 亮出来 + 复制
$url | Set-Clipboard
Clear-Host
Write-Host ""
Write-Host "  这个链接发给别人就能打开（已经复制到剪贴板）：" -ForegroundColor Green
Write-Host ""
Write-Host "  $url" -ForegroundColor Yellow
Write-Host ""
Write-Host "  手机、别的电脑都能看，不用跟你同一个 WiFi。" -ForegroundColor Gray
Write-Host "  关掉这个窗口 = 链接失效；电脑关机也会失效。" -ForegroundColor Gray
Write-Host "  每次重新打开，链接都会换一个新的。" -ForegroundColor Gray
Write-Host ""
Start-Process $url
Write-Host "  按 Ctrl+C 关闭分享" -ForegroundColor DarkGray
Write-Host ""
Wait-Process -Id $p.Id

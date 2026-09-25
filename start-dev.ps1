param(
    [ValidateSet("chrome", "windows", "edge")]
    [string]$Device = "chrome"
)

$root = $PSScriptRoot
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Starting Deluzex ERP Full-Stack ($Device)                 " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Start NestJS Backend in new window
Write-Host "[1/2] Launching NestJS Backend (Port 3000)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$root\backend'; npm run start:dev"

Start-Sleep -Seconds 2

# 2. Open Swagger Docs in browser
Write-Host "[2/3] Opening Swagger API Docs in Browser..." -ForegroundColor Yellow
Start-Process "http://localhost:3000/api/docs"

Start-Sleep -Seconds 1

# 3. Start Flutter Frontend in new window
Write-Host "[3/3] Launching Flutter Frontend ($Device)..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$root\frontend'; C:\Users\q3tec\flutter\bin\flutter.bat run -d $Device"

Write-Host "============================================================" -ForegroundColor Green
Write-Host "  All services are running!" -ForegroundColor Green
Write-Host "  Backend:      http://localhost:3000/api/v1" -ForegroundColor Gray
Write-Host "  Swagger Docs: http://localhost:3000/api/docs" -ForegroundColor Gray
Write-Host "  Frontend:     Launching on $Device" -ForegroundColor Gray
Write-Host "  Login:        admin@deluzex.com / Admin@123" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Green

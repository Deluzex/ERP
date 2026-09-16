@echo off
title Deluzex ERP Runner
echo ============================================================
echo   Starting Deluzex ERP Full-Stack Development Servers
echo ============================================================

echo [1/2] Starting NestJS Backend on http://localhost:3000/api/v1...
start "Deluzex Backend" cmd /k "cd /d %~dp0backend && npm run start:dev"

timeout /t 2 /nobreak >nul

echo [2/3] Opening Swagger API Documentation in Browser...
start http://localhost:3000/api/docs

timeout /t 1 /nobreak >nul

echo [3/3] Starting Flutter Frontend in Chrome...
start "Deluzex Frontend" cmd /k "cd /d %~dp0frontend && C:\Users\q3tec\flutter\bin\flutter.bat run -d chrome"

echo ============================================================
echo   All services launched!
echo   - Backend: http://localhost:3000/api/v1
echo   - Swagger API Docs: http://localhost:3000/api/docs
echo   - Frontend: Opening in Chrome
echo   - Admin Login: admin@deluzex.com / Admin@123
echo ============================================================

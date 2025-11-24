# Guest Account Creation - Diagnostic Guide

## Problem Summary
Guest account creation endpoint `/api/auth/create-guest` returns 404, so guests are never created in the database.

## Root Causes Identified & Fixed

### ✅ Fix 1: Missing `is_guest` Column
- **File**: `backend/migrate.sql`
- **Change**: Added migration to create `is_guest BOOLEAN DEFAULT FALSE` column in `owners` table
- **Status**: ✅ Applied

### ✅ Fix 2: GuestService URL Hardcoded
- **File**: `mobile/lib/services/guest_service.dart`
- **Change**: 
  - Added platform-specific URL support (Android emulator uses `10.0.2.2`)
  - Added method `initWithBaseUrl()` for dynamic initialization
  - Added detailed logging for debugging
  - Added 8-second timeout for requests
- **Status**: ✅ Applied

### ✅ Fix 3: GuestService Not Initialized
- **File**: `mobile/lib/main.dart`
- **Change**: Added `GuestService.initWithBaseUrl(apiHost)` at start of `_loadOwner()`
- **Status**: ✅ Applied

### ✅ Fix 4: Enhanced Backend Logging
- **File**: `backend/index.js`
- **Change**: Added detailed startup logging for migrations
- **File**: `backend/routes/auth.js`
- **Change**: Added `/debug/schema` endpoint and health check endpoint
- **Status**: ✅ Applied

## Step-by-Step Verification

### Step 1: Restart Backend Server
```bash
cd C:\Users\bmd-tech\Desktop\Boutique\backend
npm start
```

Expected output:
```
✅ [Startup] Starting migrations...
✅ [Startup] Migrations applied successfully
✅ [Startup] Server running on port 3000
```

### Step 2: Verify Database Schema
```bash
# Test the debug endpoint
curl http://localhost:3000/api/auth/debug/schema
```

Expected response:
```json
{
  "success": true,
  "columns": [...],
  "has_is_guest": true
}
```

If `has_is_guest` is `false`, the migration didn't run.

### Step 3: Verify Auth Routes Are Registered
```bash
curl http://localhost:3000/api/auth/health
```

Expected response:
```json
{
  "status": "ok",
  "message": "Auth endpoints are working"
}
```

If you get 404, the `/api/auth` routes are not mounted.

### Step 4: Test Guest Creation
```bash
curl -X POST http://localhost:3000/api/auth/create-guest \
  -H "Content-Type: application/json"
```

Expected response (201 Created):
```json
{
  "success": true,
  "guest": {
    "id": 1,
    "phone": "guest_...",
    "shop_name": "Boutique Guest",
    "is_guest": true,
    "auth_token": "..."
  },
  "message": "Compte guest créé avec succès"
}
```

### Step 5: Run Automated Tests
```bash
cd C:\Users\bmd-tech\Desktop\Boutique\backend
node test-endpoints.js
```

This will test all critical endpoints and report results.

### Step 6: Check Mobile App Logs
When creating a guest from the mobile app, you should now see:

**App Logs:**
```
🔧 [GuestService] Initialized with baseUrl: http://...
🔧 [GuestService.createGuestAccount] Calling: http://...
✅ [GuestService.createGuestAccount] Response status: 201
✅ [GuestService.createGuestAccount] Guest created: guest_1234567890
```

**Backend Logs:**
```
🔧 [Create Guest] Starting guest creation: guest_1234567890
🔧 [Create Guest] Generated auth token and expiry
✅ [Create Guest] Guest account created: { id: 1, phone: 'guest_...', is_guest: true }
```

## Troubleshooting

### Issue: Still Getting 404
**Possible Causes:**
1. Backend server not restarted after code changes
2. Port 3000 is being used by a different process
3. Routes not properly mounted in `index.js`

**Solution:**
```bash
# Kill existing node process
Get-Process node -ErrorAction SilentlyContinue | Stop-Process -Force

# Wait 2 seconds
Start-Sleep -Seconds 2

# Start fresh
cd C:\Users\bmd-tech\Desktop\Boutique\backend
npm start
```

### Issue: Migration Error
**Check Backend Logs for:**
```
❌ [Startup] Migration error: ...
```

This will show the exact SQL error. Common issues:
- Syntax error in migrate.sql
- Database connection failed
- Invalid column type

### Issue: Guest Created But Conversion Fails
**Next Steps:**
- Guest exists but has `is_guest: false` → Data integrity issue
- Check `/api/auth/guests` to see all guest accounts
- Verify PIN hashing is working (bcryptjs)

## Quick Reference

| Endpoint | Method | Purpose | Expected Status |
|----------|--------|---------|-----------------|
| `/api/auth/health` | GET | Check auth routes loaded | 200 |
| `/api/auth/debug/schema` | GET | Verify `is_guest` column | 200 |
| `/api/auth/guests` | GET | List all guests | 200 |
| `/api/auth/create-guest` | POST | Create new guest | 201 |
| `/api/auth/register-convert-guest` | POST | Convert guest → user | 200 |

## File Changes Summary

| File | Changes | Priority |
|------|---------|----------|
| `backend/migrate.sql` | Added `is_guest` column migration | 🔴 Critical |
| `mobile/lib/services/guest_service.dart` | Added platform-specific URLs, logging | 🟠 High |
| `mobile/lib/main.dart` | Initialize GuestService with correct URL | 🟠 High |
| `backend/index.js` | Enhanced startup logging | 🟡 Medium |
| `backend/routes/auth.js` | Added debug endpoints | 🟡 Medium |
| `backend/test-endpoints.js` | New test script | 🟡 Medium |

# Smart Reconnection Feature

## Overview
When a user logs out, the app intelligently detects if they have cached credentials and offers the fastest reconnection path:

1. **User with PIN set** → Show PIN entry screen (fast reconnection)
2. **User without PIN** → Direct app access (instant reconnection)
3. **New user or cleared cache** → Show phone signup screen (new login)

## Technical Flow

### Logout Flow
```
User clicks logout
    ↓
clearOwner() called
    ↓
Check PinAuthOfflineService.hasCachedCredentials()
    ├─ YES: Check if PIN is configured
    │   ├─ PIN set → Show ReturningUserPage with PIN pad
    │   └─ NO PIN → Show ReturningUserPage (auto-login immediate)
    └─ NO: Clear all data → Show QuickLoginPage
```

### ReturningUserPage Behavior

**When user has PIN set:**
- Display PIN entry interface with keypad
- User enters 4-digit PIN
- POST to `/auth/login-pin` with Bearer token
- On success: Redirect to HomePage with new auth_token

**When user has NO PIN:**
- Show "Accès immédiat en cours..." loading screen
- Auto-call `_doDirectLogin()`
- POST to `/auth/login-phone` with phone number
- Server returns direct access (auth_token)
- Automatically redirect to HomePage

**Back button:**
- Returns to QuickLoginPage
- Allows user to switch to different phone number

## Files Modified

### 1. `mobile/lib/returning_user_page.dart` (NEW)
- Handles returning user authentication
- Two modes: PIN entry or auto-login
- Integrates with PinAuthOfflineService for offline credentials

### 2. `mobile/lib/main.dart`
- Added state variables:
  - `shouldShowPinEntry: bool?` - Trigger for showing ReturningUserPage
  - `cachedPhoneForReturning: String?` - Cached phone number
  - `cachedHasPinForReturning: bool?` - Whether PIN is set
- Modified `clearOwner()` to check cached credentials
- Updated `build()` to show ReturningUserPage when needed
- Added import for ReturningUserPage and PinAuthOfflineService

### 3. `mobile/lib/services/pin_auth_offline_service.dart`
- Added `_KEY_PIN_CONFIGURED` to track if PIN was actually set
- Updated `cacheCredentials()` to store PIN configuration flag
- Updated `clearCachedCredentials()` to remove PIN config flag
- Modified `hasPinSet()` to check `_KEY_PIN_CONFIGURED` instead of just checking if PIN hash exists
- This ensures empty PIN is treated as "no PIN" for reconnection purposes

## Backend Integration

### `/auth/login-phone` Endpoint
```javascript
POST /auth/login-phone
Body: { phone: string }

Response (no PIN):
{
  id: number,
  phone: string,
  first_name: string,
  last_name: string,
  shop_name: string,
  auth_token: string,
  boutique_mode_enabled: boolean
}

Response (has PIN):
{
  id: number,
  phone: string,
  temp_token: string,
  pin_required: true,
  ...
}
```

### `/auth/login-pin` Endpoint
```javascript
POST /auth/login-pin
Headers: Authorization: Bearer <temp_token>
Body: { pin: string }

Response:
{
  id: number,
  phone: string,
  shop_name: string,
  first_name: string,
  last_name: string,
  auth_token: string,
  boutique_mode_enabled: boolean
}
```

## User Experience

### Scenario 1: User with PIN
1. User clicks logout on HomePage
2. App detects cached phone + PIN configured
3. Shows ReturningUserPage with pin entry screen
4. User enters 4-digit PIN
5. Auto-login with new token
6. Back to HomePage with cached data preserved

### Scenario 2: User without PIN
1. User clicks logout on HomePage
2. App detects cached phone + NO PIN configured
3. Shows ReturningUserPage with loading screen
4. Automatically logs in after 300ms
5. Auto-redirect to HomePage
6. No PIN entry required

### Scenario 3: Fresh Start (cache cleared)
1. User clicks logout on HomePage
2. App detects no cached credentials
3. Shows QuickLoginPage
4. User enters phone number as if first time

## Security Considerations

- PIN is never stored in plain text (hashed locally)
- Auth tokens expire after 30 days
- `_KEY_PIN_CONFIGURED` is a boolean flag, not the actual PIN
- Empty PIN is treated as no PIN requirement
- Back button allows switching accounts

## Testing Checklist

- [ ] User with PIN: Logout → See PIN pad → Enter PIN → Auto-login
- [ ] User without PIN: Logout → See loading → Auto-login instant
- [ ] No cache: Logout → See phone entry → New signup
- [ ] PIN incorrect: Enter wrong PIN → Error message → Retry
- [ ] Back button: Return to phone entry → Can use different number
- [ ] Token expiry: 30-day token tested in backend tests
- [ ] Offline: PIN verification works offline (local hash comparison)

## Future Enhancements

- [ ] Biometric support for PIN entry (fingerprint/face)
- [ ] Security question fallback
- [ ] Auto-logout after 30 minutes of inactivity
- [ ] Multi-device login tracking

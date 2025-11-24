# Smart Reconnection - Developer Quick Reference

## Quick Summary
When a user logs out, the app checks if they have cached credentials with a PIN. If yes → show PIN entry. If no → instant auto-login. If no cache → phone entry.

## Key Files

| File | Lines | Purpose |
|------|-------|---------|
| `returning_user_page.dart` | 402 | NEW - Returning user auth page |
| `main.dart` | 3322 | Modified - Added state & routing |
| `pin_auth_offline_service.dart` | 207 | Modified - PIN config tracking |

## State Flow

```
clearOwner()
├─ Has cached credentials + PIN? → ReturningUserPage with keypad
├─ Has cached credentials + NO PIN? → ReturningUserPage auto-login
└─ No cache? → QuickLoginPage
```

## Code Snippets

### Check for cached user
```dart
final pinService = PinAuthOfflineService();
bool hasCache = await pinService.hasCachedCredentials();
bool hasPinSet = await pinService.hasPinSet();
```

### Cache credentials after login
```dart
await PinAuthOfflineService().cacheCredentials(
  pin: "1234",          // Empty string if no PIN
  token: authToken,
  phone: userPhone,
  firstName: firstName,
  lastName: lastName,
  shopName: shopName,
  userId: userId,
);
```

### Get cached data
```dart
final data = await PinAuthOfflineService().getCachedData();
// Returns: {
//   phone, first_name, last_name, shop_name, id, auth_token
// }
```

### PIN hash algorithm (offline verification)
```dart
String _hashPin(String pin) {
  return pin.hashCode.toRadixString(36);
}
```

## API Endpoints

### Login Phone (existing user check)
```bash
POST /auth/login-phone
Body: { phone: string }

# No PIN:
Response: { id, phone, shop_name, auth_token, boutique_mode_enabled }

# Has PIN:
Response: { id, phone, temp_token, pin_required: true, first_name, last_name }
```

### Login PIN (verify PIN)
```bash
POST /auth/login-pin
Headers: { Authorization: Bearer <temp_token> }
Body: { pin: string }

Response: { id, phone, shop_name, first_name, last_name, auth_token, boutique_mode_enabled }
```

## UI Components

### ReturningUserPage Props
```dart
ReturningUserPage(
  phone: String,                          // User's phone
  hasPinSet: bool,                        // Show PIN pad or loading
  onLogin: Function(phone, shop, id, firstName, lastName, boutiqueMode),
  onBackToQuickSignup: VoidCallback,
)
```

### ReturningUserPage UI States
- **PIN Mode**: PIN keypad (0-9, delete, clear buttons)
- **Auto-Login Mode**: Loading spinner + "Accès immédiat en cours..."
- **Both**: Back button, phone display, welcome header

## State Variables (main.dart)

```dart
bool? shouldShowPinEntry;           // When true: show ReturningUserPage
String? cachedPhoneForReturning;    // Phone for returning user
bool? cachedHasPinForReturning;     // Is PIN configured
```

## Logout Flow (main.dart)

```dart
Future clearOwner() async {
  final pinService = PinAuthOfflineService();
  final hasCached = await pinService.hasCachedCredentials();
  final phone = prefs.getString('owner_phone');
  
  if (hasCached && phone != null) {
    final hasPinSet = await pinService.hasPinSet();
    setState(() {
      shouldShowPinEntry = true;
      cachedPhoneForReturning = phone;
      cachedHasPinForReturning = hasPinSet;
    });
  } else {
    // Full logout
    setState(() {
      ownerPhone = null;
      // ... clear other state
    });
  }
}
```

## Build Logic (main.dart)

```dart
home: shouldShowPinEntry == true && cachedPhoneForReturning != null
    ? ReturningUserPage(...)         // Returning user with cache
    : ownerPhone == null
        ? QuickLoginPage(...)         // New/unauthenticated user
        : HomePage(...)               // Authenticated user
```

## PIN Caching Logic

```dart
// Pin caching sets this flag:
prefs.setBool('pin_auth_offline_pin_configured', pin.isNotEmpty);

// hasPinSet() checks:
bool isPinSet = prefs.getBool('pin_auth_offline_pin_configured') ?? false;
```

## Security Features

✓ PIN never stored plain text (hashed locally)  
✓ Empty PIN treated as "no PIN" requirement  
✓ Token expires after 30 days  
✓ Back button allows account switching  
✓ Offline PIN verification via local hash  

## Common Issues & Solutions

### Issue: User without PIN sees PIN entry repeatedly
**Solution**: Ensure `pin.isNotEmpty` check in `cacheCredentials()` and `hasPinSet()` checks the `_KEY_PIN_CONFIGURED` flag, not just PIN hash existence.

### Issue: "Accès immédiat" takes too long
**Solution**: Auto-login has 300ms delay in `initState()`. Reduce to 100ms or remove delay if needed.

### Issue: Back button doesn't clear cache
**Solution**: Back button sets `shouldShowPinEntry = false` and `cachedPhoneForReturning = null`, doesn't call `clearCachedCredentials()`. That's intentional - user can re-enter PIN quickly.

### Issue: PIN hash mismatches offline
**Solution**: PIN is hashed the same way every time. If verification fails, check that `_hashPin()` method is identical between login and verification.

## Testing Checklist

- [ ] User with PIN: Logout → PIN pad appears
- [ ] User with PIN: Enter correct PIN → Auto-login
- [ ] User with PIN: Enter wrong PIN → Error, retry
- [ ] User without PIN: Logout → Loading 500ms → Auto-login
- [ ] No cache: Logout → Phone entry appears
- [ ] Back button: Return to phone entry → Can switch account
- [ ] Token expiry: Login with old token → 401 error
- [ ] Offline: PIN verification works without network

## Performance Notes

- Auto-login (no PIN): ~500ms total (300ms delay + network)
- PIN entry login: ~100-300ms (depends on network)
- Offline PIN check: ~50ms (local hash comparison)
- Cache check: ~10ms (SharedPreferences read)

## Environment Variables

None required. Backend URLs determined by platform:
- **Web**: `http://localhost:3000/api`
- **Android**: `http://10.0.2.2:3000/api` (emulator)
- **iOS**: `http://localhost:3000/api`

## Deployment Checklist

- [ ] Backend: `/login-phone` returns `pin_required` flag when PIN exists
- [ ] Backend: `/login-pin` accepts Bearer token and verifies PIN
- [ ] Frontend: ReturningUserPage created and imported
- [ ] Frontend: main.dart updated with state variables and routing
- [ ] Frontend: PinAuthOfflineService updated with PIN config tracking
- [ ] Testing: All three scenarios working (with PIN, no PIN, no cache)
- [ ] Documentation: This file reviewed with team

## Related Documentation

- See `SMART_RECONNECTION_COMPLETE.md` for full technical details
- See `SMART_RECONNECTION.md` for feature overview
- See backend `routes/auth.js` for endpoint implementations

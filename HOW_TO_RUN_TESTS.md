# How to Run Integration Tests - Quick Guide

## Quick Start (5 Minutes)

### 1. Install Dependencies

```bash
cd "d:\Flutter project\Capstone2\final_ecampuspay"
flutter pub get
```

### 2. Verify Environment

Check that `.env` file exists:

```bash
type .env
```

### 3. Run All Tests

```bash
flutter test integration_test/
```

## Test Execution Commands

### Run All Tests

```bash
# Run complete test suite
flutter test integration_test/test_runner.dart

# Or run all test files
flutter test integration_test/
```

### Run Individual Test Categories

```bash
# Security tests only
flutter test integration_test/security_integration_test.dart

# Database security tests only
flutter test integration_test/database_security_test.dart

# Functional tests only
flutter test integration_test/functional_integration_test.dart

# App UI tests (requires device/emulator)
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_integration_test.dart
```

### Run with Specific Options

```bash
# Run with verbose output
flutter test integration_test/ --verbose

# Run specific test by name
flutter test integration_test/security_integration_test.dart --name "Should enforce secure password"

# Run tests with coverage report
flutter test --coverage integration_test/

# Run on specific device
flutter test integration_test/ -d <device_id>
```

## Understanding Test Results

### Success Output

```
✓ Should enforce secure password requirements (52ms)
✓ Should encrypt sensitive data correctly (23ms)
✓ Should prevent SQL injection (145ms)
All tests passed!
```

### Failure Output

```
✗ Should prevent SQL injection
  Expected: false
  Actual: true

  Test failed: SQL injection was not prevented
```

## What Each Test Suite Validates

### 1. Security Integration Tests

- ✅ Password hashing and verification
- ✅ Data encryption (AES-256)
- ✅ Session security
- ✅ HTTPS enforcement
- ✅ JWT validation

**Run**: `flutter test integration_test/security_integration_test.dart`

### 2. Database Security Tests

- ✅ Row Level Security (RLS)
- ✅ SQL injection prevention
- ✅ Access control
- ✅ Data validation
- ✅ Transaction integrity

**Run**: `flutter test integration_test/database_security_test.dart`

### 3. Functional Tests

- ✅ Login/logout flows
- ✅ Balance management
- ✅ User data operations
- ✅ Role-based access
- ✅ Error handling

**Run**: `flutter test integration_test/functional_integration_test.dart`

### 4. App Integration Tests

- ✅ App initialization
- ✅ UI rendering
- ✅ Lifecycle management
- ✅ Performance
- ✅ Theme configuration

**Run**: `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_integration_test.dart`

## Common Issues and Solutions

### Issue: "Supabase not initialized"

**Solution**: Ensure `.env` file exists with correct credentials

### Issue: "Device not found"

**Solution**: Connect device or start emulator

```bash
flutter devices
flutter emulators --launch <emulator_id>
```

### Issue: "Tests timeout"

**Solution**: Check internet connection and Supabase URL accessibility

### Issue: "RLS tests fail"

**Solution**: Verify RLS policies are enabled in Supabase dashboard

## Test Coverage Report

Generate HTML coverage report:

```bash
# Run tests with coverage
flutter test --coverage integration_test/

# Generate HTML report (requires lcov)
genhtml coverage/lcov.info -o coverage/html

# Open report in browser
start coverage/html/index.html
```

## CI/CD Integration

These tests can be integrated into your CI/CD pipeline:

```yaml
# GitHub Actions example
- name: Run integration tests
  run: |
    cd final_ecampuspay
    flutter test integration_test/
```

## Expected Test Duration

- Security tests: ~30 seconds
- Database tests: ~45 seconds
- Functional tests: ~20 seconds
- App tests: ~1 minute

**Total**: ~2-3 minutes for complete suite

## Next Steps

After running tests:

1. ✅ Review all test results
2. ✅ Fix any failing tests
3. ✅ Check coverage report
4. ✅ Read full documentation in `SECURITY_TEST_GUIDE.md`

## Support

For detailed documentation:

- **Full Test Guide**: `SECURITY_TEST_GUIDE.md`
- **Test Documentation**: `integration_test/README.md`
- **Environment Setup**: `ENVIRONMENT_SETUP.md`

























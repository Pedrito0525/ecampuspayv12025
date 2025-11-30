# eCampusPay Security and Functionality Test Guide

## Overview

This guide provides comprehensive instructions for running and analyzing security and functionality tests for the eCampusPay system, covering both the Flutter app and Supabase backend database.

## Test Architecture

```
eCampusPay Testing Framework
├── Security Tests
│   ├── Authentication Security
│   ├── Data Encryption
│   ├── Session Management
│   └── Vulnerability Testing
├── Database Security Tests
│   ├── Row Level Security (RLS)
│   ├── SQL Injection Prevention
│   ├── Access Control
│   └── Data Validation
├── Functional Tests
│   ├── Authentication Flows
│   ├── Balance Management
│   ├── User Data Management
│   └── Role-Based Access
└── App Integration Tests
    ├── UI/UX Testing
    ├── Lifecycle Management
    ├── Performance Testing
    └── Error Handling
```

## Quick Start

### 1. Setup Environment

```bash
# Navigate to project directory
cd "d:\Flutter project\Capstone2\final_ecampuspay"

# Install dependencies
flutter pub get

# Verify environment variables (.env file)
type .env
```

### 2. Run All Tests

```bash
# Run all integration tests
flutter test integration_test/

# Or run the test runner
flutter test integration_test/test_runner.dart
```

### 3. Review Results

Tests will output results in the console with:
- ✅ Green checkmarks for passing tests
- ❌ Red X marks for failing tests
- Detailed error messages for failures

## Detailed Test Execution

### Security Integration Tests

**File**: `integration_test/security_integration_test.dart`

```bash
flutter test integration_test/security_integration_test.dart
```

**What it tests**:
1. **Password Security**
   - Hashing algorithm (SHA-256 with salts)
   - Unique salt generation
   - Password verification
   - Special character handling

2. **Data Encryption**
   - AES-256 encryption
   - Secure key management
   - Encryption/decryption bidirectionality
   - Encrypted data detection

3. **Session Security**
   - Secure session storage
   - Session persistence
   - Role-based session management
   - Session hijacking prevention

4. **Configuration Security**
   - HTTPS enforcement
   - Environment variable loading
   - JWT token validation
   - Secure API keys

**Expected Results**:
```
✅ Should enforce secure password requirements
✅ Should use unique salts for password hashing
✅ Should encrypt sensitive data correctly
✅ Should decrypt data correctly
✅ Should prevent session hijacking
✅ Should enforce HTTPS for Supabase URL
```

**Security Concerns if Tests Fail**:
- Password tests fail → Weak authentication, vulnerable to brute force
- Encryption tests fail → Data leakage, privacy violations
- Session tests fail → Account takeover risk
- HTTPS tests fail → Man-in-the-middle attacks possible

### Database Security Tests

**File**: `integration_test/database_security_test.dart`

```bash
flutter test integration_test/database_security_test.dart
```

**What it tests**:
1. **Row Level Security (RLS)**
   - User data isolation
   - Table-level restrictions
   - Role-based access enforcement
   - Cross-user data protection

2. **SQL Injection Prevention**
   - Malicious input sanitization
   - Parameterized query usage
   - Special character handling
   - NoSQL injection prevention

3. **Access Control**
   - Unauthorized modification prevention
   - Admin access restrictions
   - Service account protection
   - Data deletion controls

4. **Data Validation**
   - Balance constraints
   - Email format validation
   - Unique constraint enforcement
   - Transaction integrity

**Expected Results**:
```
✅ Should enforce RLS on auth_students table
✅ Should prevent SQL injection in student ID lookup
✅ Should prevent unauthorized data modifications
✅ Should validate balance constraints
✅ Should enforce unique constraints
✅ Should prevent transaction tampering
```

**Security Concerns if Tests Fail**:
- RLS tests fail → Users can access others' data
- SQL injection tests fail → Database compromise possible
- Access control tests fail → Unauthorized data manipulation
- Validation tests fail → Data corruption and financial errors

### Functional Integration Tests

**File**: `integration_test/functional_integration_test.dart`

```bash
flutter test integration_test/functional_integration_test.dart
```

**What it tests**:
1. **Authentication Flows**
   - Login with valid/invalid credentials
   - Session persistence
   - Logout functionality
   - Session refresh

2. **Balance Management**
   - Balance retrieval
   - Balance updates
   - Currency precision
   - Large value handling

3. **User Data Management**
   - Encrypted data handling
   - Bulk data operations
   - Role identification
   - Data retrieval

4. **Error Handling**
   - Graceful failure handling
   - Network error recovery
   - Malformed data handling
   - Missing data scenarios

**Expected Results**:
```
✅ Should handle login flow
✅ Should retrieve current balance
✅ Should update user balance
✅ Should handle encrypted user data
✅ Should correctly identify user roles
✅ Should handle missing user data gracefully
```

**Concerns if Tests Fail**:
- Authentication fails → Users cannot access system
- Balance errors → Financial discrepancies
- Encryption errors → Data corruption
- Error handling fails → Poor user experience, crashes

### App Integration Tests

**File**: `integration_test/app_integration_test.dart`

```bash
# Requires device or emulator
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_integration_test.dart
```

**What it tests**:
1. **App Initialization**
   - Service initialization
   - Configuration loading
   - Theme setup
   - Navigation ready

2. **Lifecycle Management**
   - Background/foreground transitions
   - App pause/resume
   - Force close handling
   - State preservation

3. **Performance**
   - Initialization time
   - Response times
   - Memory usage
   - UI responsiveness

4. **Security Throughout Lifecycle**
   - Session clearing on detach
   - Secure config maintenance
   - Data protection during transitions

**Expected Results**:
```
✅ Should launch app successfully
✅ Should initialize services on startup
✅ Should handle lifecycle state changes
✅ Should maintain security throughout app lifecycle
✅ Should initialize within reasonable time
```

## Security Analysis Report

After running tests, analyze the results to generate a security report:

### 1. Authentication & Authorization Security

**Status**: ✅ SECURE / ⚠️ WARNING / ❌ VULNERABLE

**Checks**:
- [ ] Password hashing with unique salts
- [ ] Secure password verification
- [ ] No plaintext password storage
- [ ] Session management secure
- [ ] Role-based access control working

### 2. Data Protection

**Status**: ✅ SECURE / ⚠️ WARNING / ❌ VULNERABLE

**Checks**:
- [ ] AES-256 encryption for sensitive data
- [ ] Encrypted data in database
- [ ] Decryption only when needed
- [ ] Secure key management
- [ ] Data integrity verification

### 3. Network Security

**Status**: ✅ SECURE / ⚠️ WARNING / ❌ VULNERABLE

**Checks**:
- [ ] HTTPS enforced for all connections
- [ ] Valid SSL certificates
- [ ] Secure API key handling
- [ ] No credentials in code
- [ ] Environment variables used

### 4. Database Security

**Status**: ✅ SECURE / ⚠️ WARNING / ❌ VULNERABLE

**Checks**:
- [ ] Row Level Security enabled
- [ ] SQL injection prevented
- [ ] Access control enforced
- [ ] Data validation working
- [ ] Transaction integrity maintained

### 5. Application Security

**Status**: ✅ SECURE / ⚠️ WARNING / ❌ VULNERABLE

**Checks**:
- [ ] Secure session handling
- [ ] Proper error handling
- [ ] No sensitive data in logs
- [ ] Secure lifecycle management
- [ ] Input validation throughout

## Common Security Issues and Solutions

### Issue 1: SQL Injection Vulnerability

**Symptoms**: SQL injection tests pass (succeed in injecting)

**Solution**:
```dart
// BAD - String concatenation
final query = "SELECT * FROM users WHERE id = '$userId'";

// GOOD - Parameterized queries (Supabase does this automatically)
final response = await client
  .from('users')
  .select()
  .eq('id', userId);  // Parameterized
```

### Issue 2: Weak Password Storage

**Symptoms**: Password tests show same hash for same password

**Solution**:
```dart
// BAD - No salt
final hash = sha256.convert(utf8.encode(password)).toString();

// GOOD - With unique salt
final hash = EncryptionService.hashPassword(password);
// Generates unique salt each time
```

### Issue 3: RLS Not Enforced

**Symptoms**: Users can access other users' data

**Solution**:
```sql
-- Enable RLS on table
ALTER TABLE auth_students ENABLE ROW LEVEL SECURITY;

-- Create policy
CREATE POLICY "Users can only access own data"
ON auth_students
FOR SELECT
USING (auth.uid() = auth_user_id);
```

### Issue 4: Unencrypted Sensitive Data

**Symptoms**: Plain text data in database

**Solution**:
```dart
// Encrypt before storing
final encrypted = EncryptionService.encryptUserData(userData);
await client.from('auth_students').insert(encrypted);

// Decrypt after retrieving
final response = await client.from('auth_students').select();
final decrypted = EncryptionService.decryptUserData(response);
```

### Issue 5: No HTTPS Enforcement

**Symptoms**: HTTP URLs detected

**Solution**:
```dart
// In SupabaseConfig
static String _ensureHttps(String url) {
  if (!url.startsWith('https://')) {
    throw StateError('SUPABASE_URL must use HTTPS');
  }
  return url;
}
```

## Performance Benchmarks

Based on integration tests, monitor these metrics:

| Operation | Expected Time | Warning Threshold | Critical Threshold |
|-----------|--------------|-------------------|-------------------|
| App Initialization | < 3s | 3-5s | > 5s |
| Login | < 2s | 2-4s | > 4s |
| Encryption | < 100ms | 100-500ms | > 500ms |
| Database Query | < 1s | 1-3s | > 3s |
| Session Save/Load | < 500ms | 500ms-1s | > 1s |

## Compliance Checklist

Use this checklist to verify security compliance:

### OWASP Mobile Top 10 (2024)

- [ ] **M1: Improper Platform Usage** - Verified secure API usage
- [ ] **M2: Insecure Data Storage** - Encrypted sensitive data
- [ ] **M3: Insecure Communication** - HTTPS enforced
- [ ] **M4: Insecure Authentication** - Strong password hashing
- [ ] **M5: Insufficient Cryptography** - AES-256 encryption
- [ ] **M6: Insecure Authorization** - RLS policies enforced
- [ ] **M7: Client Code Quality** - Error handling tested
- [ ] **M8: Code Tampering** - Data integrity checks
- [ ] **M9: Reverse Engineering** - Obfuscation (production)
- [ ] **M10: Extraneous Functionality** - Debug code removed

### PCI DSS (Payment Card Industry)

- [ ] Secure network architecture (HTTPS)
- [ ] Protect cardholder data (encryption)
- [ ] Vulnerability management (testing)
- [ ] Access control measures (RLS)
- [ ] Monitor and test networks (continuous testing)
- [ ] Information security policy (documented)

## Continuous Testing

### Daily Testing

```bash
# Quick security check
flutter test integration_test/security_integration_test.dart

# Quick database security check
flutter test integration_test/database_security_test.dart
```

### Weekly Testing

```bash
# Full test suite
flutter test integration_test/

# With coverage
flutter test --coverage integration_test/
```

### Pre-Deployment Testing

```bash
# Run all tests
flutter test integration_test/test_runner.dart

# Generate coverage report
flutter test --coverage integration_test/
genhtml coverage/lcov.info -o coverage/html

# Review report
start coverage/html/index.html
```

## Automated Testing Setup

### GitHub Actions

Create `.github/workflows/security_tests.yml`:

```yaml
name: Security Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM

jobs:
  security-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.7.2'
      
      - name: Install dependencies
        run: flutter pub get
      
      - name: Run security tests
        run: flutter test integration_test/security_integration_test.dart
      
      - name: Run database security tests
        run: flutter test integration_test/database_security_test.dart
      
      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results/
```

## Reporting Security Issues

If tests reveal security vulnerabilities:

1. **Document the issue**
   - Test that failed
   - Expected vs. actual behavior
   - Potential impact
   - Steps to reproduce

2. **Assess severity**
   - Critical: Data breach, authentication bypass
   - High: SQL injection, XSS vulnerabilities
   - Medium: Improper error handling
   - Low: Minor configuration issues

3. **Create action plan**
   - Immediate fixes (critical issues)
   - Scheduled fixes (high/medium)
   - Technical debt (low priority)

4. **Verify fixes**
   - Re-run failed tests
   - Run full test suite
   - Document resolution

## Support and Resources

- **Test Documentation**: `integration_test/README.md`
- **Environment Setup**: `ENVIRONMENT_SETUP.md`
- **Database Schema**: `consolidated_database_schema.sql`
- **Supabase Dashboard**: Check RLS policies and security settings

## Version History

- **v1.0** (2025-11-03): Initial comprehensive security test framework
  - Security integration tests
  - Database security tests
  - Functional tests
  - App integration tests
  - Complete documentation


























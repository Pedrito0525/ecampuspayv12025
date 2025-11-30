# eCampusPay Admin Manual

## Quick Navigation

- [Dashboard](#dashboard)
- [Reports](#reports)
- [Transactions](#transactions)
- [Top-Up](#top-up)
- [Withdrawal Requests](#withdrawal-requests)
- [Settings](#settings)
- [User Management](#user-management)
- [Service Ports](#service-ports)
- [Admin Management](#admin-management)
- [Loaning](#loaning)
- [Feedback](#feedback)

---

## Dashboard

**Purpose**: System overview and key metrics

**Key Metrics**:

- Total Active Users Today
- Total Transactions Today
- Total Service Accounts

**Actions**: Monitor daily activity, refresh to update metrics

---

## Reports

**Purpose**: Financial analysis and insights

**Features**:

- **Income Summary**: Top-up income, loan income (filter by date range)
- **Balance Overview**: Student balances, service balances, system-wide balance
- **Analysis**: Top-up trends, loan trends, visual charts
- **Vendor Top-up Ranking**: Commission breakdown per vendor

**Export**: CSV or Excel format

**Usage**: Generate monthly reports, export for audits

---

## Transactions

**Purpose**: View all live transactions

**Display**: Time, User, Type, Amount, Status, Reference Number

**Filters**: By type, user, date range, status

**Actions**: View details

---

## Top-Up

**Purpose**: Add funds to student accounts

**Process**:

1. Enter Student ID
2. Verify payment receipt (GCash/Manual/Bank)
3. Enter amount
4. Click **Approve**

**Important**: Verify payment before approving. Top-ups are irreversible.

---

## Withdrawal Requests

**Purpose**: Process cash-out requests from students and service accounts

**Process**:

1. View pending requests
2. Review user details and balance
3. **Approve**: Auto-deducts balance, creates transaction record
4. **Reject**: Enter reason, no balance deduction

**Note**: Balance deduction is automatic and immediate upon approval.

---

## Settings

**Purpose**: System configuration and maintenance

### Admin Account

- Update login credentials (username, password, email)
- View login history
- Manage active sessions

### Backup & Recovery

- **Generate Backup**: Export data as CSV
- **Restore**: Import CSV backup file
- **Auto Backup**: Configure automatic backup schedule

### Reset Database

- **Full Reset**: Delete all data, reset IDs to 1
- **Safety**: Password confirmation, 5-second cooldown, backup reminder
- **Warning**: Irreversible operation

### API Configuration

- Configure payment gateways
- Set up QR code generation
- Manage API credentials

### System Updates

- Check for updates
- Apply system patches

---

## User Management

**Purpose**: Manage student and service accounts

### Account Registration

1. Click **Register New User**
2. Enter: Student ID, Name, Email, Course, RFID ID
3. System auto-fills if record exists
4. Click **Register**

### ID Replacement

1. Select user profile
2. Click **ID Replacement**
3. Enter new RFID ID
4. Verify old ID
5. Submit replacement

### User Directory

- Search by ID, name, or email
- View: Profile, balance, transactions, loan status
- Export directory

### User Activity

- View transaction history
- Monitor balance changes
- Track login history

### CSV Import

1. Prepare CSV with: Student ID, Name, Email, Course, RFID ID
2. Navigate to **CSV Import**
3. Upload file
4. Preview and confirm import

---

## Service Ports

**Purpose**: Manage service accounts (vendors, canteens)

### Create Service Account

1. Click **Add New Service**
2. Enter: Service Name, Type, Contact, Location
3. Set initial balance (optional)
4. Click **Create Service**

### Scanner Assignment

1. Select service account
2. Click **Assign Scanner**
3. Select available scanner device
4. Confirm assignment
5. Scanner auto-links to service

**Note**: Scanner automatically connects once assigned. No manual configuration needed.

### Manage Services

- View service list (filter by type)
- Edit service information
- Manage service balance
- View transaction history

---

## Admin Management

**Purpose**: Manage admin staff accounts and permissions

### Create Staff Account

1. Enter: Name, Email, Username, Password
2. Set permissions (checkboxes for each tab access)
3. Click **Create Account**

### Manage Staff

- View all staff accounts
- Edit staff information
- Update permissions
- Deactivate accounts

### Scanner Assignment (Admin)

- Assign scanners to admin accounts
- View scanner assignments
- Unassign scanners

---

## Loaning

**Purpose**: Manage loan plans and repayments

### Create Loan Plan

1. Click **Create Loan Plan**
2. Configure: Plan Name, Max Amount, Interest Rate, Repayment Period
3. Set eligibility criteria
4. Save plan

### Monitor Loans

- View active loans
- Track repayment progress
- View due dates
- Loan analytics (disbursement, repayment rates)

### Process Repayments

- Record repayments (full or partial)
- Update loan balance
- Generate receipts
- Track repayment history

**Loan Status**: Pending → Approved → Active → Completed/Defaulted

---

## Feedback

**Purpose**: Collect and manage user feedback

### View Feedback

- Filter by: Type, User type, Date, Status
- Search by keywords
- View full feedback details

### Manage Feedback

- Mark as read/resolved
- Respond to users
- Export feedback reports
- Track feedback trends

**Categories**: Bug Reports, Feature Requests, UX Feedback, Service Quality, General

---

## Quick Reference

### Common Actions

- **Approve**: Confirm and process requests
- **Reject**: Deny with reason
- **Export**: Download CSV/Excel
- **Filter**: Narrow search results
- **Search**: Find specific records

### Security Best Practices

- Change password regularly
- Log out when not in use
- Monitor transaction logs
- Generate backups regularly
- Verify payments before approval

### Important Notes

- Top-ups are **irreversible** once approved
- Withdrawal approvals **auto-deduct** balance immediately
- Full database reset requires password and has 5-second cooldown
- Scanner assignment is **automatic** - no manual configuration needed
- CSV import enables auto-fill during registration

---

## Support

For technical issues:

- Check system documentation
- Review error messages
- Contact system administrator
- Submit feedback through Feedback tab

---

**System**: eCampusPay Admin Dashboard  
**Version**: 1.0

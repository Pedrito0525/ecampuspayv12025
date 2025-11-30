# Admin Dashboard & System Instructions

## Table of Contents

1. [Dashboard](#1-dashboard)
2. [Reports Tab](#2-reports-tab)
3. [Transactions Tab](#3-transactions-tab)
4. [Top-Up](#4-top-up)
5. [Withdrawal Requests Tab](#5-withdrawal-requests-tab)
6. [Settings Tab](#6-settings-tab)
7. [User Management](#7-user-management)
8. [Service Port](#8-service-port)
9. [Loaning Tab](#9-loaning-tab)
10. [Feedback Tab](#10-feedback-tab)
11. [Scanner Connection Instructions](#11-scanner-connection-instructions)

---

## 1. Dashboard

### Purpose

Display a quick overview of system activity and key metrics at a glance.

### Displayed Information

#### Total Active Users Today

- Shows the count of users who have logged in or performed transactions today
- Updates in real-time as users interact with the system
- Helps monitor daily system engagement

#### Total Transactions

- Displays the total number of transactions processed today
- Includes all transaction types: top-ups, loans, withdrawals, and service payments
- Provides a quick view of system activity volume

#### Total Service Accounts

- Shows the number of active service accounts registered in the system
- Service accounts represent vendors, canteens, and other service providers
- Helps track service infrastructure

### Usage Tips

- Refresh the dashboard periodically to see updated metrics
- Use the dashboard as a starting point before diving into detailed tabs
- Monitor trends by comparing daily metrics over time

---

## 2. Reports Tab

### Purpose

Provide comprehensive financial insights and analysis for better decision-making.

### Sections

#### Income Summary

- **Total Income from Top-Ups**: Aggregated revenue from all student account top-ups
- **Total Income from Loans**: Revenue generated from loan interest and fees
- **Period Selection**: Filter by date range (daily, weekly, monthly, custom)
- **Export Options**: Download reports as CSV or PDF for record-keeping

#### Balance Overview

- **Total Student Balance**: Sum of all student account balances
- **Total Service Balance**: Sum of all service account balances
- **System-Wide Balance**: Overall financial position of the platform
- **Balance Trends**: Visual charts showing balance changes over time

#### Analysis

- **Top-Up Trends**:
  - Daily/weekly/monthly top-up patterns
  - Peak hours and days analysis
  - Average top-up amounts
- **Loan Trends**:
  - Loan disbursement patterns
  - Repayment rates and timelines
  - Default rates and risk analysis
- **Visual Charts**: Graphs and charts for better data visualization
- **Comparative Analysis**: Compare periods to identify growth or decline

### Usage Tips

- Generate monthly reports for financial audits
- Use trend analysis to predict future cash flow needs
- Export reports regularly for backup and compliance

---

## 3. Transactions Tab

### Purpose

Display all live transactions for today with detailed information.

### Details Displayed

#### Transaction Information

- **Time**: Exact timestamp of when the transaction occurred
- **User**: Student ID or service account name who initiated the transaction
- **Type**: Transaction category:
  - Top-Up: Student adding funds to their account
  - Loan: Loan disbursement or repayment
  - Withdrawal: Cash-out request processing
  - Service Payment: Payment to service accounts
- **Amount**: Transaction value (positive for credits, negative for debits)
- **Status**: Transaction status (pending, completed, failed, cancelled)
- **Reference Number**: Unique transaction ID for tracking

#### Filtering Options

- Filter by transaction type
- Filter by user or service account
- Filter by date range
- Filter by status
- Search by reference number or student ID

#### Actions Available

- View transaction details
- Export transaction history
- Print transaction receipts
- Flag suspicious transactions

### Usage Tips

- Monitor transactions in real-time for security
- Use filters to find specific transactions quickly
- Export transaction logs regularly for audit purposes

---

## 4. Top-Up

### Purpose

Top-up student accounts with funds, typically after receiving payment via GCash or other payment methods.

### Process

#### Step 1: Enter Student ID

1. Navigate to the **Top-Up** tab
2. Locate the student ID input field
3. Enter the student's ID number
4. System will auto-populate student information if found

#### Step 2: Verify Top-Up Request

1. Review the student's current balance
2. Check for any pending top-up requests from the student
3. Verify payment receipt (e.g., GCash transaction confirmation)
4. Confirm the top-up amount matches the payment received

#### Step 3: Approve Top-Up

1. Enter the top-up amount
2. Add any notes or reference numbers (optional)
3. Click **Approve** or **Confirm Top-Up**
4. System will:
   - Update student balance immediately
   - Create a transaction record
   - Send notification to the student
   - Update dashboard metrics

### Verification Methods

- **GCash**: Verify via GCash transaction reference
- **Manual Payment**: Confirm cash/check receipt
- **Bank Transfer**: Verify via bank transaction details

### Important Notes

- Always verify payment before approving top-ups
- Double-check the amount before confirming
- Keep records of payment confirmations
- Top-ups are irreversible once approved

---

## 5. Withdrawal Requests Tab

### Purpose

Handle cash-out requests submitted by students and service accounts.

### Process

#### Step 1: View Pending Requests

1. Navigate to **Withdrawal Requests** tab
2. View list of pending withdrawal requests
3. Each request shows:
   - Request ID
   - User/Service name
   - Requested amount
   - Current balance
   - Request timestamp
   - Request status

#### Step 2: Review Request Details

1. Click on a request to view full details
2. Verify:
   - User identity
   - Available balance
   - Request amount validity
   - Any previous withdrawal history

#### Step 3: Approve or Reject

1. **To Approve**:

   - Click **Approve** button
   - System automatically deducts the amount from user's balance
   - Transaction record is created
   - User receives notification
   - Admin processes physical cash-out

2. **To Reject**:
   - Click **Reject** button
   - Enter rejection reason (optional)
   - User receives notification with reason
   - No balance deduction occurs

### Auto-Deduction Feature

- Upon approval, the system **automatically deducts** the corresponding balance
- Balance update is immediate and irreversible
- Transaction is logged for audit purposes

### Best Practices

- Verify user identity before approving
- Ensure sufficient balance exists
- Process physical cash-out promptly after approval
- Keep records of all withdrawal transactions

---

## 6. Settings Tab

### Purpose

General system and admin configurations for managing the platform.

### Sections

#### Admin Account

- **Update Login Credentials**:

  - Change username
  - Change password
  - Update email address
  - Enable two-factor authentication (if available)

- **Account Security**:
  - View login history
  - Manage active sessions
  - Set password expiration policies

#### Notification Settings

- **Enable/Disable Notifications**:

  - Toggle email notifications
  - Toggle in-app notifications
  - Configure notification preferences:
    - New withdrawal requests
    - Top-up requests
    - System alerts
    - Error notifications

- **Notification Channels**:
  - Email notifications
  - Push notifications
  - SMS notifications (if configured)

#### Backup & Recovery

##### Backup

- **Generate CSV Backup**:

  1. Navigate to **Settings** → **Backup & Recovery**
  2. Click **Generate Backup**
  3. Select data to include:
     - User accounts
     - Transaction history
     - Service accounts
     - System settings
  4. Click **Download CSV**
  5. Save backup file securely

- **Automatic Backups**:
  - Configure automatic backup schedule
  - Set backup retention period
  - Choose backup storage location

##### Recovery

- **Restore from Backup CSV**:

  1. Navigate to **Settings** → **Backup & Recovery**
  2. Click **Restore Data**
  3. Select backup CSV file
  4. Preview data to be restored
  5. Confirm restoration
  6. System will restore data from backup

- **Recovery Options**:
  - Full restore: Replace all data
  - Partial restore: Restore specific tables only
  - Merge restore: Add backup data without deleting existing

#### E-Wallet & QR Setup

- **Configure Payment Options**:

  - Set up GCash integration
  - Configure QR code generation
  - Set payment gateway credentials
  - Configure payment limits

- **QR Code Settings**:
  - Generate QR codes for top-ups
  - Customize QR code appearance
  - Set QR code expiration
  - Enable/disable QR code scanning

#### Reset Options

##### Full Reset

- **Reset All Data**:

  1. Navigate to **Settings** → **Reset Options**
  2. Select **Full Reset**
  3. Enter admin password for confirmation
  4. Review warning message
  5. Confirm reset action
  6. System will:
     - Reset all data back to ID 1
     - Trigger automatic backup before reset
     - Clear all transactions
     - Reset all balances
     - Remove all user accounts (except admin)

- **⚠️ Warning**: Full reset is irreversible and will delete all data

##### Partial Reset

- **Reset Balances Only**:

  1. Navigate to **Settings** → **Reset Options**
  2. Select **Partial Reset**
  3. Choose reset type:
     - Reset all balances to 0
     - Reset student balances only
     - Reset service balances only
  4. Enter admin password
  5. Confirm reset
  6. System will:
     - Set selected balances to 0
     - Keep `auth_students` table intact
     - Preserve user accounts
     - Preserve transaction history

- **Use Case**: Useful for testing or resetting balances without losing user data

### Security Best Practices

- Change admin password regularly
- Enable two-factor authentication
- Review login history periodically
- Keep backups in secure locations
- Test backup restoration regularly

---

## 7. User Management

### Purpose

Comprehensive management of student and service accounts.

### Features

#### Account Registration

- **Manual Registration**:

  1. Navigate to **User Management** tab
  2. Click **Register New User**
  3. Fill in required fields:
     - Student ID
     - Full Name
     - Email Address
     - Course/Program
     - RFID ID (if available)
  4. System will auto-fill data if existing records exist
  5. Click **Register** to create account

- **Auto-Fill Feature**:
  - System checks for existing student records
  - Auto-populates name, course, and other details
  - Reduces data entry errors
  - Speeds up registration process

#### Account Activation

- **Enable Accounts**:

  1. View user list in User Management
  2. Find user account
  3. Toggle **Active/Inactive** status
  4. Active accounts can use the system
  5. Inactive accounts are blocked from access

- **Bulk Activation**:
  - Select multiple users
  - Activate/deactivate in bulk
  - Useful for batch operations

#### Scanner Connection

- **Auto-Connect Scanner**:

  - System automatically detects connected scanners
  - Scanner appears in user management if connected
  - No manual configuration needed
  - Scanner status shown in real-time

- **Manual Scanner Assignment**:
  - Assign scanner to specific user
  - Test scanner connection
  - View scanner activity logs

#### ID Replacement

- **Update ID Card Information**:

  1. Navigate to user's profile
  2. Click **ID Replacement**
  3. Enter new RFID ID
  4. Verify old ID information
  5. Submit replacement request
  6. System updates ID and logs change

- **Replacement Process**:
  - Old ID is deactivated
  - New ID is activated
  - Transaction history is preserved
  - User is notified of change

#### User Directory

- **View Detailed User Info**:
  - Search users by ID, name, or email
  - View complete user profile:
    - Personal information
    - Account balance
    - Transaction history
    - Loan status
    - Account status
  - Export user directory
  - Print user reports

#### User Activity

- **Track User Transfers**:

  - View all transactions by user
  - Monitor account activity
  - Track balance changes
  - View login history

- **Activity Logs**:
  - Timestamp of all actions
  - Action type and details
  - IP address (if available)
  - Device information

#### CSV Import

- **Add Student Data**:

  1. Prepare CSV file with columns:
     - Student ID
     - Name
     - Email
     - Course
     - RFID ID (optional)
  2. Navigate to **User Management** → **CSV Import**
  3. Upload CSV file
  4. Preview imported data
  5. Confirm import
  6. System validates and imports data

- **Auto-Fill During Registration**:
  - Imported data is used for auto-fill
  - Reduces manual data entry
  - Ensures data consistency
  - Speeds up registration process

### Best Practices

- Verify student information before registration
- Keep user directory updated
- Regularly review user activity logs
- Use CSV import for bulk operations
- Document ID replacements

---

## 8. Service Port

### Purpose

Manage service accounts (vendors, canteens, etc.) and assign devices.

### Features

#### Create Service Accounts

1. Navigate to **Service Ports** tab
2. Click **Add New Service**
3. Fill in service details:
   - Service Name
   - Service Type (Canteen, Store, etc.)
   - Contact Information
   - Location
4. Set initial balance (optional)
5. Configure service settings
6. Click **Create Service**

#### Manage Service Accounts

- **View Service List**:

  - All registered services displayed
  - Filter by service type
  - Search by name or ID

- **Edit Service Information**:

  - Update service details
  - Modify service settings
  - Change service status

- **Service Balance Management**:
  - View service balance
  - Process withdrawals
  - View transaction history

#### Scanner Assignment

- **Assign Scanner to Service**:

  1. Navigate to service account
  2. Click **Assign Scanner** button
  3. View available scanners
  4. Select scanner device to assign
  5. Confirm assignment
  6. Scanner is auto-linked to service account

- **Scanner Management**:

  - View assigned scanners
  - Test scanner connection
  - Unassign scanners
  - View scanner activity

- **Auto-Link Feature**:
  - Once connected, scanner automatically links to service
  - No manual configuration needed
  - Real-time connection status
  - Automatic reconnection on disconnect

### Service Account Types

- **Canteen**: Food service providers
- **Store**: Retail shops
- **Library**: Library services
- **Printing**: Printing services
- **Other**: Custom service types

### Best Practices

- Assign scanners immediately after service creation
- Test scanner connections regularly
- Monitor service balances
- Keep service information updated

---

## 9. Loaning Tab

### Purpose

Manage loan plans and repayment options for students.

### Features

#### Create Loan Plans

1. Navigate to **Loaning** tab
2. Click **Create Loan Plan**
3. Configure plan details:
   - Plan Name
   - Maximum Loan Amount
   - Interest Rate
   - Repayment Period
   - Terms and Conditions
4. Set eligibility criteria
5. Save loan plan

#### Update Loan Plans

- **Modify Existing Plans**:
  - Edit loan parameters
  - Update interest rates
  - Change repayment terms
  - Enable/disable plans

#### Monitor Loan Plans

- **View Active Loans**:

  - List of all active student loans
  - Loan status and details
  - Repayment progress
  - Due dates and reminders

- **Loan Analytics**:
  - Total loans disbursed
  - Repayment rates
  - Default rates
  - Loan trends

#### Repayment Management

- **Process Repayments**:

  - Record loan repayments
  - Update loan balance
  - Generate repayment receipts
  - Track repayment history

- **Repayment Options**:
  - Full repayment
  - Partial repayment
  - Automatic deduction from balance
  - Manual payment processing

### Loan Status Types

- **Pending**: Loan application submitted
- **Approved**: Loan approved and ready for disbursement
- **Active**: Loan disbursed and repayment ongoing
- **Completed**: Loan fully repaid
- **Defaulted**: Loan past due date
- **Cancelled**: Loan application cancelled

### Best Practices

- Review loan applications carefully
- Monitor repayment schedules
- Send reminders for due payments
- Track default rates
- Update loan plans based on performance

---

## 10. Feedback Tab

### Purpose

Collect and monitor feedback from users and service accounts to improve system quality.

### Features

#### View Feedback

- **Feedback List**:
  - All submitted feedback displayed
  - Filter by:
    - Feedback type
    - User type (student/service)
    - Date range
    - Status (new/read/resolved)
  - Search feedback by keywords

#### Feedback Details

- **View Full Feedback**:
  - User information
  - Feedback content
  - Timestamp
  - Attachments (if any)
  - Response history

#### Feedback Management

- **Mark as Read**:

  - Mark feedback as read
  - Organize feedback by status
  - Track response progress

- **Respond to Feedback**:

  - Reply to user feedback
  - Provide solutions or explanations
  - Close resolved feedback

- **Export Feedback**:
  - Export feedback reports
  - Generate feedback analytics
  - Track feedback trends

### Feedback Categories

- **Bug Reports**: System errors and issues
- **Feature Requests**: Suggestions for new features
- **User Experience**: UI/UX feedback
- **Service Quality**: Feedback about services
- **General**: Other feedback

### Usage Tips

- Review feedback regularly
- Prioritize critical issues
- Respond to users promptly
- Use feedback to improve system
- Track feedback resolution rates

---

## 11. Scanner Connection Instructions

### Purpose

Connect and assign scanner devices to service accounts for RFID card scanning.

### Step-by-Step Process

#### Step 1: Navigate to Service Port

1. Open Admin Dashboard
2. Click on **Service Ports** tab in the navigation menu
3. View list of service accounts

#### Step 2: Select Service Account

1. Find the service account that needs scanner assignment
2. Click on the service account to open details
3. Ensure service account is active

#### Step 3: Click Assign Scanner

1. Locate **Assign Scanner** button in the service account details
2. Click the button to open scanner assignment dialog
3. System will scan for available scanner devices

#### Step 4: Select Scanner Device

1. View list of available scanners
2. Scanner devices are automatically detected if connected
3. Select the scanner device you want to assign
4. Verify scanner connection status (connected/disconnected)

#### Step 5: Confirm Assignment

1. Review scanner details:
   - Scanner name/ID
   - Connection status
   - Current assignment (if any)
2. Click **Confirm** or **Assign** button
3. System will link scanner to service account

#### Step 6: Verify Connection

1. Scanner is now auto-linked to the service account
2. Connection status updates in real-time
3. Test scanner by scanning a test RFID card
4. Verify scan appears in service account transactions

### Auto-Link Feature

- **Automatic Connection**:
  - Once assigned, scanner automatically connects
  - No manual configuration required
  - Real-time connection monitoring
  - Automatic reconnection if disconnected

### Troubleshooting

#### Scanner Not Detected

- Check USB/Bluetooth connection
- Verify scanner is powered on
- Restart scanner device
- Check device drivers (if applicable)

#### Scanner Not Connecting

- Verify scanner is not assigned to another service
- Check scanner compatibility
- Restart the application
- Contact technical support if issue persists

#### Scanner Disconnected

- System will attempt automatic reconnection
- Check physical connections
- Verify scanner power
- Reassign scanner if needed

### Best Practices

- Assign scanners immediately after service creation
- Test scanner connection before going live
- Monitor scanner status regularly
- Keep backup scanners available
- Document scanner assignments

---

## General Tips & Best Practices

### Security

- Never share admin credentials
- Change password regularly
- Log out when not in use
- Monitor system activity
- Review transaction logs regularly

### Data Management

- Generate backups regularly
- Test backup restoration
- Keep transaction records
- Export reports periodically
- Maintain audit trails

### System Maintenance

- Monitor system performance
- Review error logs
- Update system regularly
- Test new features before deployment
- Keep documentation updated

### User Support

- Respond to feedback promptly
- Provide clear instructions to users
- Document common issues
- Train staff on system usage
- Maintain communication channels

---

## Quick Reference

### Navigation Shortcuts

- **Dashboard**: Overview of system metrics
- **Reports**: Financial analysis and insights
- **Transactions**: View all transactions
- **Top-Up**: Process student top-ups
- **Withdrawal Requests**: Handle cash-out requests
- **Settings**: System configuration
- **User Management**: Manage user accounts
- **Service Ports**: Manage service accounts
- **Loaning**: Manage loan plans
- **Feedback**: View user feedback

### Common Actions

- **Approve**: Confirm and process requests
- **Reject**: Deny requests with reason
- **Export**: Download data as CSV/PDF
- **Filter**: Narrow down search results
- **Search**: Find specific records
- **Refresh**: Update current view

---

## Support & Contact

For technical support or questions:

- Check system documentation
- Review FAQ section
- Contact system administrator
- Submit feedback through Feedback tab
- Refer to error messages for troubleshooting

---

**Last Updated**: [Current Date]
**Version**: 1.0
**System**: EVSU CampusPay Admin Dashboard

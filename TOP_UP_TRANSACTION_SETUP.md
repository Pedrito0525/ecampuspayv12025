# EVSU Campus Pay - Top-Up Transaction System

This document explains how to set up and use the top-up transaction system for the EVSU Campus Pay application.

## Overview

The top-up transaction system allows administrators to add credits to student accounts and maintains a complete transaction history. The system includes:

- **Admin Top-Up Interface**: Allows admins to search for students and add credits
- **Transaction History**: Complete audit trail of all top-up transactions
- **User Dashboard**: Students can view their transaction history
- **Database Functions**: Secure transaction processing with proper validation

## Database Setup

### 1. Create the Top-Up Transactions Table

Run the SQL script to create the necessary database schema:

```sql
-- Execute the top_up_transactions_schema.sql file
\i top_up_transactions_schema.sql
```

This will create:

- `top_up_transactions` table with proper indexes and constraints
- Database functions for secure transaction processing
- Row Level Security (RLS) policies
- Views for transaction summaries

### 2. Key Database Functions

#### `process_top_up_transaction()`

Processes a top-up transaction and updates the student's balance atomically.

**Parameters:**

- `p_student_id`: Student ID to top up
- `p_amount`: Amount to add to balance
- `p_processed_by`: Admin username or system identifier
- `p_notes`: Optional transaction notes

**Returns:** JSON response with success status and transaction details

#### `get_student_top_up_history()`

Retrieves transaction history for a specific student.

**Parameters:**

- `p_student_id`: Student ID to get history for
- `p_limit`: Maximum number of transactions to return
- `p_offset`: Number of transactions to skip (for pagination)

**Returns:** JSON response with transaction list and pagination info

#### `get_recent_top_up_transactions()`

Gets recent top-up transactions for admin dashboard.

**Parameters:**

- `p_limit`: Maximum number of transactions to return

**Returns:** JSON response with recent transactions including student names

## Features

### Admin Top-Up Interface

The admin interface (`lib/admin/topup_tab.dart`) provides:

1. **Student Search**: Search for students by School ID
2. **Amount Input**: Enter top-up amount with quick amount buttons
3. **User Validation**: Real-time student validation
4. **Transaction Processing**: Secure transaction processing using database functions
5. **Recent Transactions**: Display of recent top-up transactions

### User Transaction History

The user dashboard (`lib/user/user_dashboard.dart`) includes:

1. **Transaction List**: Complete history of user's top-up transactions
2. **Filter Options**: Filter by transaction type (All, Top-ups)
3. **Real-time Data**: Fetches data from database functions
4. **Refresh Capability**: Manual refresh of transaction data

### Security Features

1. **Row Level Security**: Users can only see their own transactions
2. **Admin Access**: Admins can view all transactions
3. **Atomic Transactions**: Database functions ensure data consistency
4. **Input Validation**: Proper validation of amounts and student IDs

## Usage

### For Administrators

1. **Access Top-Up Tab**: Navigate to the admin panel's top-up section
2. **Search Student**: Enter the student's School ID
3. **Enter Amount**: Input the top-up amount or use quick amount buttons
4. **Confirm Transaction**: Review details and confirm the top-up
5. **View History**: Check recent transactions in the admin interface

### For Students

1. **View Transactions**: Navigate to the Transactions tab in the user dashboard
2. **Filter History**: Use filter options to view specific transaction types
3. **Refresh Data**: Pull to refresh or use the refresh button
4. **Transaction Details**: View amount, date, time, and balance information

## Database Schema

### top_up_transactions Table

```sql
CREATE TABLE top_up_transactions (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    previous_balance DECIMAL(10,2) NOT NULL CHECK (previous_balance >= 0),
    new_balance DECIMAL(10,2) NOT NULL CHECK (new_balance >= 0),
    transaction_type VARCHAR(20) NOT NULL DEFAULT 'top_up',
    processed_by VARCHAR(100) NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Key Constraints

- `amount > 0`: Ensures positive top-up amounts
- `previous_balance >= 0`: Ensures non-negative previous balance
- `new_balance = previous_balance + amount`: Ensures correct balance calculation
- `transaction_type = 'top_up'`: Restricts to top-up transactions only

## Error Handling

The system includes comprehensive error handling:

1. **Student Not Found**: Validates student exists before processing
2. **Invalid Amounts**: Prevents negative or zero amounts
3. **Database Errors**: Graceful handling of database connection issues
4. **Transaction Failures**: Rollback on processing errors

## Performance Optimizations

1. **Database Indexes**: Optimized queries with proper indexing
2. **Pagination**: Efficient data loading with limit/offset
3. **Caching**: Session-based data caching
4. **Async Operations**: Non-blocking UI operations

## Monitoring and Logging

1. **Transaction Logging**: All transactions are logged with timestamps
2. **Admin Tracking**: Records which admin processed each transaction
3. **Error Logging**: Comprehensive error logging for debugging
4. **Audit Trail**: Complete history of all balance changes

## Testing

To test the top-up system:

1. **Create Test Student**: Register a test student account
2. **Admin Top-Up**: Use admin interface to add credits
3. **Verify Balance**: Check student balance is updated
4. **View History**: Verify transaction appears in history
5. **User Dashboard**: Check student can see their transactions

## Troubleshooting

### Common Issues

1. **Student Not Found**: Ensure student is registered in `auth_students` table
2. **Permission Denied**: Check RLS policies are properly configured
3. **Transaction Failed**: Verify database functions are created and accessible
4. **Balance Not Updated**: Check for database constraint violations

### Debug Steps

1. Check database connection
2. Verify function permissions
3. Review RLS policies
4. Check transaction logs
5. Validate input parameters

## Future Enhancements

Potential improvements for the top-up system:

1. **Bulk Top-Ups**: Process multiple students at once
2. **Scheduled Top-Ups**: Automated top-up processing
3. **Transaction Exports**: Export transaction data to CSV/PDF
4. **Advanced Filtering**: More filter options for transaction history
5. **Notifications**: Email/SMS notifications for top-ups
6. **Approval Workflow**: Multi-level approval for large amounts

## Support

For technical support or questions about the top-up transaction system:

1. Check this documentation
2. Review database logs
3. Contact the development team
4. Submit an issue in the project repository

---

**Note**: This system is designed for the EVSU Campus Pay application and should be properly configured with the existing database schema and authentication system.

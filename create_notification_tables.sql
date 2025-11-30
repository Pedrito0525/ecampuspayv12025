-- Simple script to create notification tables manually
-- Run this if the notification system functions are not working

-- 1. Create notification_types table
CREATE TABLE IF NOT EXISTS notification_types (
    id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    icon_name VARCHAR(50) NOT NULL,
    color_hex VARCHAR(7) NOT NULL DEFAULT '#B91C1C',
    priority INTEGER NOT NULL DEFAULT 1 CHECK (priority BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create user_notifications table
CREATE TABLE IF NOT EXISTS user_notifications (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    action_data TEXT,
    is_urgent BOOLEAN DEFAULT FALSE,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create indexes
CREATE INDEX IF NOT EXISTS idx_user_notifications_student_id ON user_notifications(student_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_type ON user_notifications(type);
CREATE INDEX IF NOT EXISTS idx_user_notifications_is_read ON user_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_user_notifications_created_at ON user_notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_user_notifications_is_urgent ON user_notifications(is_urgent);

-- 4. Insert default notification types
INSERT INTO notification_types (type_name, display_name, icon_name, color_hex, priority) VALUES
    ('transaction_success', 'Transaction Success', 'check_circle', '#10B981', 2),
    ('payment_success', 'Payment Success', 'payment', '#059669', 2),
    ('transfer_sent', 'Transfer Sent', 'send', '#3B82F6', 2),
    ('transfer_received', 'Transfer Received', 'call_received', '#3B82F6', 2),
    ('loan_due_soon', 'Loan Due Soon', 'schedule', '#F59E0B', 3),
    ('loan_overdue', 'Loan Overdue', 'warning', '#EF4444', 5),
    ('loan_reminder', 'Loan Reminder', 'alarm', '#F59E0B', 3),
    ('security_alert', 'Security Alert', 'security', '#EF4444', 4),
    ('system_notification', 'System Notification', 'info', '#6B7280', 1),
    ('welcome', 'Welcome', 'celebration', '#8B5CF6', 1)
ON CONFLICT (type_name) DO NOTHING;

-- 5. Enable RLS
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- 6. Create RLS policies
CREATE POLICY "Users can view their own notifications" ON user_notifications
    FOR SELECT 
    TO authenticated
    USING (
        auth.uid() IS NOT NULL AND (
            student_id = (
                SELECT student_id FROM auth_students 
                WHERE auth_user_id = auth.uid() AND is_active = true
            )
        )
    );

CREATE POLICY "Users can insert their own notifications" ON user_notifications
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        auth.uid() IS NOT NULL AND (
            student_id = (
                SELECT student_id FROM auth_students 
                WHERE auth_user_id = auth.uid() AND is_active = true
            )
        )
    );

CREATE POLICY "Users can update their own notifications" ON user_notifications
    FOR UPDATE 
    TO authenticated
    USING (
        auth.uid() IS NOT NULL AND (
            student_id = (
                SELECT student_id FROM auth_students 
                WHERE auth_user_id = auth.uid() AND is_active = true
            )
        )
    );

-- 7. Create fallback policy for service role
CREATE POLICY "Service role full access" ON user_notifications
    FOR ALL 
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 8. Grant permissions
GRANT ALL ON notification_types TO service_role;
GRANT SELECT ON notification_types TO authenticated;
GRANT ALL ON user_notifications TO service_role;
GRANT SELECT, INSERT, UPDATE ON user_notifications TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE user_notifications_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE notification_types_id_seq TO authenticated;

-- 9. Insert a test notification (replace 'YOUR_STUDENT_ID' with actual student ID)
-- INSERT INTO user_notifications (student_id, type, title, message, is_read) 
-- VALUES ('YOUR_STUDENT_ID', 'welcome', 'Welcome to eCampusPay!', 'Thank you for joining the eCampusPay system.', false);

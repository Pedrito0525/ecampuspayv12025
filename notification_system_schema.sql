-- Notification System Database Schema
-- This file creates the necessary tables and functions for the inbox notification system

-- 1. Notification Types Table (Defines different types of notifications)
CREATE TABLE IF NOT EXISTS notification_types (
    id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    icon_name VARCHAR(50) NOT NULL,
    color_hex VARCHAR(7) NOT NULL DEFAULT '#B91C1C',
    priority INTEGER NOT NULL DEFAULT 1 CHECK (priority BETWEEN 1 AND 5),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. User Notifications Table (Stores all user notifications)
CREATE TABLE IF NOT EXISTS user_notifications (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    action_data TEXT, -- JSON string for additional data
    is_urgent BOOLEAN DEFAULT FALSE,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_notifications_student_id ON user_notifications(student_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_type ON user_notifications(type);
CREATE INDEX IF NOT EXISTS idx_user_notifications_is_read ON user_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_user_notifications_created_at ON user_notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_user_notifications_is_urgent ON user_notifications(is_urgent);

-- 4. Create notification types table function
CREATE OR REPLACE FUNCTION create_notification_types_table()
RETURNS VOID AS $$
BEGIN
    -- This function is called to ensure the table exists
    -- The table creation is handled above
    RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 5. Insert default notification types function
CREATE OR REPLACE FUNCTION insert_default_notification_types()
RETURNS VOID AS $$
BEGIN
    -- Insert default notification types if they don't exist
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
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Create user notifications table function
CREATE OR REPLACE FUNCTION create_user_notifications_table()
RETURNS VOID AS $$
BEGIN
    -- This function is called to ensure the table exists
    -- The table creation is handled above
    RETURN;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Function to create loan due date notifications
CREATE OR REPLACE FUNCTION create_loan_due_notifications()
RETURNS INTEGER AS $$
DECLARE
    loan_record RECORD;
    days_until_due INTEGER;
    notification_count INTEGER := 0;
    title TEXT;
    message TEXT;
    notification_type TEXT;
    is_urgent BOOLEAN;
BEGIN
    -- Get all active loans
    FOR loan_record IN 
        SELECT al.*, lp.name as loan_plan_name
        FROM active_loans al
        JOIN loan_plans lp ON al.loan_plan_id = lp.id
        WHERE al.status = 'active'
    LOOP
        -- Calculate days until due
        days_until_due := EXTRACT(DAY FROM loan_record.due_date - NOW())::INTEGER;
        
        -- Determine notification details based on days until due
        IF days_until_due < 0 THEN
            -- Overdue
            title := 'Loan Overdue!';
            message := 'Your loan of ₱' || loan_record.loan_amount || ' is ' || ABS(days_until_due) || ' days overdue. Please pay immediately.';
            notification_type := 'loan_overdue';
            is_urgent := TRUE;
        ELSIF days_until_due <= 1 THEN
            -- Due tomorrow or today
            title := 'Loan Due Tomorrow!';
            message := 'Your loan of ₱' || loan_record.loan_amount || ' is due ' || 
                      CASE WHEN days_until_due = 0 THEN 'today' ELSE 'tomorrow' END || '.';
            notification_type := 'loan_due_soon';
            is_urgent := TRUE;
        ELSIF days_until_due <= 3 THEN
            -- Due in 2-3 days
            title := 'Loan Due Soon';
            message := 'Your loan of ₱' || loan_record.loan_amount || ' is due in ' || days_until_due || ' days.';
            notification_type := 'loan_due_soon';
            is_urgent := FALSE;
        ELSIF days_until_due <= 7 THEN
            -- Due in a week
            title := 'Loan Reminder';
            message := 'Your loan of ₱' || loan_record.loan_amount || ' is due in ' || days_until_due || ' days.';
            notification_type := 'loan_reminder';
            is_urgent := FALSE;
        ELSE
            -- Skip loans due far in the future
            CONTINUE;
        END IF;
        
        -- Check if notification already exists for this loan and time period
        IF NOT EXISTS (
            SELECT 1 FROM user_notifications 
            WHERE student_id = loan_record.student_id 
            AND type = notification_type 
            AND action_data = 'loan_id:' || loan_record.id
            AND created_at > NOW() - INTERVAL '1 day'
        ) THEN
            -- Insert notification
            INSERT INTO user_notifications (
                student_id, type, title, message, action_data, is_urgent, is_read
            ) VALUES (
                loan_record.student_id, 
                notification_type, 
                title, 
                message, 
                'loan_id:' || loan_record.id, 
                is_urgent, 
                FALSE
            );
            
            notification_count := notification_count + 1;
        END IF;
    END LOOP;
    
    RETURN notification_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Function to create transaction notifications
CREATE OR REPLACE FUNCTION create_transaction_notification(
    p_student_id VARCHAR(50),
    p_transaction_type VARCHAR(50),
    p_amount DECIMAL(10,2),
    p_service_name VARCHAR(255) DEFAULT NULL,
    p_recipient_name VARCHAR(255) DEFAULT NULL,
    p_sender_name VARCHAR(255) DEFAULT NULL,
    p_transaction_data JSONB DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    title TEXT;
    message TEXT;
    notification_type TEXT;
BEGIN
    -- Determine notification details based on transaction type
    CASE p_transaction_type
        WHEN 'top_up' THEN
            title := 'Top-up Successful';
            message := 'Your account has been topped up with ₱' || p_amount;
            notification_type := 'transaction_success';
        WHEN 'payment' THEN
            title := 'Payment Completed';
            message := 'Payment of ₱' || p_amount || ' at ' || COALESCE(p_service_name, 'service') || ' was successful';
            notification_type := 'payment_success';
        WHEN 'transfer_sent' THEN
            title := 'Transfer Sent';
            message := 'You sent ₱' || p_amount || ' to ' || COALESCE(p_recipient_name, 'user');
            notification_type := 'transfer_sent';
        WHEN 'transfer_received' THEN
            title := 'Transfer Received';
            message := 'You received ₱' || p_amount || ' from ' || COALESCE(p_sender_name, 'user');
            notification_type := 'transfer_received';
        ELSE
            title := 'Transaction Completed';
            message := 'Your transaction has been processed successfully';
            notification_type := 'transaction_success';
    END CASE;
    
    -- Insert notification
    INSERT INTO user_notifications (
        student_id, type, title, message, action_data, is_urgent, is_read
    ) VALUES (
        p_student_id, 
        notification_type, 
        title, 
        message, 
        p_transaction_data::TEXT, 
        FALSE, 
        FALSE
    );
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Function to get user notifications with pagination
CREATE OR REPLACE FUNCTION get_user_notifications(
    p_student_id VARCHAR(50),
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0,
    p_unread_only BOOLEAN DEFAULT FALSE
)
RETURNS JSON AS $$
DECLARE
    notifications JSON;
    total_count INTEGER;
BEGIN
    -- Get total count
    SELECT COUNT(*) INTO total_count
    FROM user_notifications
    WHERE student_id = p_student_id
    AND (NOT p_unread_only OR is_read = FALSE);
    
    -- Get notifications
    SELECT json_agg(
        json_build_object(
            'id', un.id,
            'student_id', un.student_id,
            'type', un.type,
            'title', un.title,
            'message', un.message,
            'action_data', un.action_data,
            'is_urgent', un.is_urgent,
            'is_read', un.is_read,
            'read_at', un.read_at,
            'created_at', un.created_at,
            'type_info', json_build_object(
                'type_name', nt.type_name,
                'display_name', nt.display_name,
                'icon_name', nt.icon_name,
                'color_hex', nt.color_hex,
                'priority', nt.priority
            )
        )
    ) INTO notifications
    FROM user_notifications un
    LEFT JOIN notification_types nt ON un.type = nt.type_name
    WHERE un.student_id = p_student_id
    AND (NOT p_unread_only OR un.is_read = FALSE)
    ORDER BY un.is_urgent DESC, un.created_at DESC
    LIMIT p_limit OFFSET p_offset;
    
    RETURN json_build_object(
        'notifications', COALESCE(notifications, '[]'::json),
        'total_count', total_count,
        'unread_count', (
            SELECT COUNT(*) FROM user_notifications 
            WHERE student_id = p_student_id AND is_read = FALSE
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Function to mark notification as read
CREATE OR REPLACE FUNCTION mark_notification_read(p_notification_id INTEGER)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE user_notifications 
    SET is_read = TRUE, read_at = NOW(), updated_at = NOW()
    WHERE id = p_notification_id;
    
    RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Function to mark all notifications as read for a user
CREATE OR REPLACE FUNCTION mark_all_notifications_read(p_student_id VARCHAR(50))
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE user_notifications 
    SET is_read = TRUE, read_at = NOW(), updated_at = NOW()
    WHERE student_id = p_student_id AND is_read = FALSE;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 12. Function to cleanup old notifications (older than 30 days)
CREATE OR REPLACE FUNCTION cleanup_old_notifications()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM user_notifications 
    WHERE created_at < NOW() - INTERVAL '30 days';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 13. Enable RLS on user_notifications table
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- 14. Create RLS policies for user_notifications
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

-- 15. Create fallback policy for service role
CREATE POLICY "Service role full access" ON user_notifications
    FOR ALL 
    TO service_role
    USING (true)
    WITH CHECK (true);

-- 16. Grant permissions
GRANT ALL ON notification_types TO service_role;
GRANT SELECT ON notification_types TO authenticated;
GRANT ALL ON user_notifications TO service_role;
GRANT SELECT, INSERT, UPDATE ON user_notifications TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE user_notifications_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE notification_types_id_seq TO authenticated;

-- 17. Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION create_notification_types_table TO service_role;
GRANT EXECUTE ON FUNCTION insert_default_notification_types TO service_role;
GRANT EXECUTE ON FUNCTION create_user_notifications_table TO service_role;
GRANT EXECUTE ON FUNCTION create_loan_due_notifications TO service_role;
GRANT EXECUTE ON FUNCTION create_transaction_notification TO service_role;
GRANT EXECUTE ON FUNCTION get_user_notifications TO authenticated;
GRANT EXECUTE ON FUNCTION mark_notification_read TO authenticated;
GRANT EXECUTE ON FUNCTION mark_all_notifications_read TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_notifications TO service_role;

-- 18. Initialize notification types
SELECT insert_default_notification_types();

-- 19. Create a scheduled job to run loan due notifications (this would be set up in your cron/scheduler)
-- For now, this can be called manually or triggered by your application
-- SELECT create_loan_due_notifications();

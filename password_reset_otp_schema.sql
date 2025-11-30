-- Password Reset OTP Table Schema
-- This table stores OTP codes for password reset functionality

CREATE TABLE IF NOT EXISTS password_reset_otp (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL,
    otp_code VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    used_at TIMESTAMP WITH TIME ZONE NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_password_reset_otp_email ON password_reset_otp(email);
CREATE INDEX IF NOT EXISTS idx_password_reset_otp_code ON password_reset_otp(otp_code);
CREATE INDEX IF NOT EXISTS idx_password_reset_otp_expires ON password_reset_otp(expires_at);

-- Create a function to clean up expired OTP codes
CREATE OR REPLACE FUNCTION cleanup_expired_otp_codes()
RETURNS void AS $$
BEGIN
    DELETE FROM password_reset_otp 
    WHERE expires_at < NOW() 
    OR (used = TRUE AND used_at < NOW() - INTERVAL '1 hour');
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to automatically clean up expired OTP codes
CREATE OR REPLACE FUNCTION trigger_cleanup_expired_otp()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM cleanup_expired_otp_codes();
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger that runs cleanup on INSERT
CREATE TRIGGER cleanup_expired_otp_trigger
    AFTER INSERT ON password_reset_otp
    FOR EACH STATEMENT
    EXECUTE FUNCTION trigger_cleanup_expired_otp();

-- Add RLS (Row Level Security) policies if needed
-- ALTER TABLE password_reset_otp ENABLE ROW LEVEL SECURITY;

-- Grant permissions (adjust based on your security requirements)
-- GRANT SELECT, INSERT, UPDATE, DELETE ON password_reset_otp TO authenticated;
-- GRANT USAGE, SELECT ON SEQUENCE password_reset_otp_id_seq TO authenticated;

-- Optional: Add constraints
ALTER TABLE password_reset_otp 
ADD CONSTRAINT check_otp_code_length CHECK (LENGTH(otp_code) = 6);

ALTER TABLE password_reset_otp 
ADD CONSTRAINT check_otp_code_numeric CHECK (otp_code ~ '^[0-9]+$');

-- Add comment for documentation
COMMENT ON TABLE password_reset_otp IS 'Stores OTP codes for password reset functionality';
COMMENT ON COLUMN password_reset_otp.email IS 'Encrypted user email address (for security)';
COMMENT ON COLUMN password_reset_otp.otp_code IS '6-digit numeric OTP code';
COMMENT ON COLUMN password_reset_otp.expires_at IS 'OTP expiration timestamp (typically 5 minutes from creation)';
COMMENT ON COLUMN password_reset_otp.used IS 'Whether the OTP has been used';
COMMENT ON COLUMN password_reset_otp.used_at IS 'Timestamp when OTP was used';

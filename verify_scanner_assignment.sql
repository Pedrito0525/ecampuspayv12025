-- Script to verify scanner assignment in admin_accounts table
-- Run this to check if the scanner assignment is properly stored

-- 1. Check if scanner_id column exists
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'admin_accounts' 
AND column_name = 'scanner_id';

-- 2. Check all admin accounts and their scanner assignments
SELECT 
    id,
    username,
    full_name,
    email,
    role,
    scanner_id,
    CASE 
        WHEN scanner_id IS NULL THEN 'NULL'
        WHEN scanner_id = '' THEN 'EMPTY STRING'
        ELSE 'HAS VALUE: ' || scanner_id
    END as scanner_status,
    created_at,
    updated_at
FROM admin_accounts
ORDER BY username;

-- 3. Check specifically for non-null and non-empty scanner_id values
SELECT 
    id,
    username,
    full_name,
    scanner_id,
    LENGTH(scanner_id) as scanner_id_length,
    updated_at
FROM admin_accounts
WHERE scanner_id IS NOT NULL 
AND scanner_id != ''
ORDER BY username;

-- 4. Count admins with and without scanners
SELECT 
    'Admins with scanners' as category,
    COUNT(*) as count
FROM admin_accounts
WHERE scanner_id IS NOT NULL AND scanner_id != ''
UNION ALL
SELECT 
    'Admins without scanners' as category,
    COUNT(*) as count
FROM admin_accounts
WHERE scanner_id IS NULL OR scanner_id = '';

-- 5. Check if there are any scanner_devices that match the assigned scanner_ids
SELECT 
    aa.id as admin_id,
    aa.username,
    aa.full_name,
    aa.scanner_id,
    sd.device_name,
    sd.is_active as scanner_active,
    CASE 
        WHEN sd.device_name IS NULL THEN 'SCANNER NOT FOUND IN scanner_devices TABLE'
        ELSE 'SCANNER FOUND'
    END as scanner_status
FROM admin_accounts aa
LEFT JOIN scanner_devices sd ON aa.scanner_id = sd.device_name
WHERE aa.scanner_id IS NOT NULL AND aa.scanner_id != ''
ORDER BY aa.username;

-- 6. Show all available scanners in scanner_devices table
SELECT 
    'Available Scanners' as info,
    device_name,
    is_active,
    created_at
FROM scanner_devices
ORDER BY device_name;

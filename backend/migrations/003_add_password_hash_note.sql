-- Migration: Password security
-- Note: All passwords should now be stored as bcryptjs hashes
-- Existing plain passwords will be invalid after this migration

-- This is just a documentation migration
-- The password field will now contain bcrypt hashes instead of plain text
-- Format: $2a$10$... (bcryptjs format)

BEGIN;
-- No schema changes needed as password column already exists
-- Just ensure the password field can store hashes (255+ chars)
-- PostgreSQL TEXT type supports bcrypt hashes

COMMIT;

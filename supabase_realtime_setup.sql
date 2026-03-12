-- Run this in the Supabase SQL Editor to ensure all tables support
-- Realtime UPDATE/DELETE payloads (REPLICA IDENTITY FULL).
-- Without this, UPDATE and DELETE events may not include the full row data.

ALTER TABLE expenses REPLICA IDENTITY FULL;
ALTER TABLE expense_splits REPLICA IDENTITY FULL;
ALTER TABLE settlements REPLICA IDENTITY FULL;
ALTER TABLE trips REPLICA IDENTITY FULL;
ALTER TABLE trip_members REPLICA IDENTITY FULL;
ALTER TABLE friendships REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- Verify: Ensure Realtime is enabled for these tables in Supabase Dashboard:
-- Database → Replication → Realtime → Toggle on for each table above.

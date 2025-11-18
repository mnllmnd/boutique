-- Migration: Add audio_path column to debts table
ALTER TABLE debts ADD COLUMN IF NOT EXISTS audio_path TEXT;

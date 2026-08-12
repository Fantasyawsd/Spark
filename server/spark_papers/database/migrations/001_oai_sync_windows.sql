ALTER TABLE sync_state ADD COLUMN completed_through TEXT;
ALTER TABLE sync_state ADD COLUMN window_from TEXT;
ALTER TABLE sync_state ADD COLUMN window_until TEXT;

UPDATE sync_state
SET completed_through = last_success_at
WHERE source = 'arxiv_oai'
  AND cursor IS NULL
  AND completed_through IS NULL;

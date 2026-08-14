CREATE TABLE IF NOT EXISTS github_star_history (
    paper_id TEXT NOT NULL REFERENCES papers(paper_id),
    observed_at TEXT NOT NULL,
    stars INTEGER NOT NULL,
    PRIMARY KEY (paper_id, observed_at)
);
CREATE INDEX IF NOT EXISTS idx_github_star_history_order
    ON github_star_history(paper_id, observed_at);

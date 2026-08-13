from __future__ import annotations

import unittest

from spark_papers.models import utc_now
from spark_papers.normalization import normalize_record
from spark_papers.policy import AiAdmissionPolicy


class NormalizationTest(unittest.TestCase):
    def test_blank_abstract_is_normalized_to_none(self) -> None:
        paper, _ = normalize_record(
            "arxiv",
            {
                "arxiv_id": "2401.00001",
                "title": "A Paper",
                "abstract": "  \n\t ",
                "authors": ["Ada Lovelace"],
                "published_at": "2024-01-01T00:00:00Z",
                "subjects": ["cs.AI"],
            },
            fetched_at=utc_now(),
            policy=AiAdmissionPolicy(),
        )

        self.assertIsNone(paper.abstract)


if __name__ == "__main__":
    unittest.main()

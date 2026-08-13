from __future__ import annotations

import unittest

from spark_papers.policy import AiAdmissionPolicy


class AiAdmissionPolicyTest(unittest.TestCase):
    def test_openalex_topic_url_and_bare_id_are_equivalent(self) -> None:
        cases = (
            ("T1", "https://openalex.org/T1"),
            ("https://openalex.org/T1", "T1"),
        )

        for configured, observed in cases:
            with self.subTest(configured=configured, observed=observed):
                decision = AiAdmissionPolicy(
                    subject_prefixes=(),
                    openalex_topic_ids=(configured,),
                ).evaluate((), {"openalex": {"topics": ({"id": observed},)}})

                self.assertTrue(decision.admitted)
                self.assertEqual(decision.reason, "openalex_topic:T1")


if __name__ == "__main__":
    unittest.main()

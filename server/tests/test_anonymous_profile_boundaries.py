from __future__ import annotations

import base64
import json
import sys
import unittest
from unittest.mock import patch

from spark_papers.anonymous_profile import (
    MAX_KEYS_PER_DIMENSION,
    AnonymousProfile,
    decode_anonymous_profile,
    encode_anonymous_profile,
    parse_anonymous_profile,
)


def _encoded(payload) -> str:
    raw = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


class AnonymousProfileBoundaryTest(unittest.TestCase):
    def test_huge_integer_weights_are_rejected_without_overflow(self) -> None:
        for weight in (10 ** 400, -(10 ** 400)):
            with self.subTest(negative=weight < 0):
                payload = {"profile_version": "profile.v1", "subjects": {"cs.AI": weight}}
                self.assertIsNone(parse_anonymous_profile(payload))

    def test_encoded_huge_integer_weights_are_rejected_without_overflow(self) -> None:
        payload = {"profile_version": "profile.v1", "subjects": {"cs.AI": 10 ** 400}}
        self.assertIsNone(decode_anonymous_profile(_encoded(payload)))

    def test_normalized_key_collisions_cannot_bypass_dimension_limit(self) -> None:
        raw = {(" " * index) + "cs.AI": 1.0 for index in range(MAX_KEYS_PER_DIMENSION + 1)}
        self.assertEqual(len(raw), MAX_KEYS_PER_DIMENSION + 1)
        self.assertIsNone(parse_anonymous_profile({"profile_version": "profile.v1", "subjects": raw}))

    def test_oversized_dimensions_are_rejected_before_iteration(self) -> None:
        class Oversized(dict):
            def items(self):
                raise AssertionError("oversized input was iterated before its size check")

        raw = Oversized({str(index): 1.0 for index in range(MAX_KEYS_PER_DIMENSION + 1)})
        self.assertIsNone(parse_anonymous_profile({"profile_version": "profile.v1", "subjects": raw}))

    def test_exact_dimension_limit_remains_valid(self) -> None:
        for dimension in ("subjects", "keywords", "venues"):
            with self.subTest(dimension=dimension):
                raw = {str(index): 1.0 for index in range(MAX_KEYS_PER_DIMENSION)}
                profile = parse_anonymous_profile({"profile_version": "profile.v1", dimension: raw})
                self.assertIsNotNone(profile)
                self.assertEqual(dict(getattr(profile, dimension)), raw)

    def test_invalid_base64_characters_are_not_silently_ignored(self) -> None:
        encoded = encode_anonymous_profile(AnonymousProfile(subjects={"cs.AI": 1.0}))
        self.assertIsNone(decode_anonymous_profile(encoded + "!!!!"))

    def test_padded_and_unpadded_unicode_payloads_remain_valid(self) -> None:
        profile = AnonymousProfile(keywords={"多模态": 2.0}, venues={"NeurIPS": 0.5})
        encoded = encode_anonymous_profile(profile)
        for value in (encoded, encoded + "=" * (-len(encoded) % 4)):
            with self.subTest(padded=value.endswith("=")):
                self.assertEqual(decode_anonymous_profile(value), profile)

    def test_excessively_nested_json_is_rejected_without_recursion_error(self) -> None:
        depth = sys.getrecursionlimit() + 100
        raw = ("[" * depth + "0" + "]" * depth).encode("ascii")
        encoded = base64.urlsafe_b64encode(raw).decode("ascii")
        self.assertIsNone(decode_anonymous_profile(encoded))

    def test_decoder_recursion_error_is_rejected(self) -> None:
        encoded = encode_anonymous_profile(AnonymousProfile())
        with patch("spark_papers.anonymous_profile.json.loads", side_effect=RecursionError):
            self.assertIsNone(decode_anonymous_profile(encoded))

    def test_weight_boundaries_and_legacy_numeric_strings_remain_valid(self) -> None:
        payload = {
            "profile_version": "profile.v1",
            "subjects": {"cs.AI": -10, "cs.LG": 10, "cs.CV": "2.5"},
        }
        profile = parse_anonymous_profile(payload)
        self.assertIsNotNone(profile)
        self.assertEqual(dict(profile.subjects), {"cs.AI": -10.0, "cs.LG": 10.0, "cs.CV": 2.5})

    def test_invalid_utf8_and_nonfinite_weights_remain_rejected(self) -> None:
        self.assertIsNone(decode_anonymous_profile(base64.urlsafe_b64encode(b"\xff").decode("ascii")))
        for weight in (True, None, float("nan"), float("inf"), "infinity"):
            with self.subTest(weight=weight):
                payload = {"profile_version": "profile.v1", "subjects": {"cs.AI": weight}}
                self.assertIsNone(parse_anonymous_profile(payload))


if __name__ == "__main__":
    unittest.main()

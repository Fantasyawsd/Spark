from __future__ import annotations

import unittest

from spark_papers.anonymous_profile import (
    AnonymousProfile,
    decode_anonymous_profile,
    encode_anonymous_profile,
    parse_anonymous_profile,
)


class ParseAnonymousProfileTest(unittest.TestCase):
    def test_valid_payload(self) -> None:
        profile = parse_anonymous_profile(
            {
                'profile_version': 'profile.v1',
                'subjects': {'cs.AI': 2.5},
                'keywords': {'多模态': 1.5},
                'venues': {'NeurIPS': 1.0},
            }
        )
        self.assertIsNotNone(profile)
        self.assertEqual(profile.subjects['cs.AI'], 2.5)
        self.assertEqual(profile.keywords['多模态'], 1.5)
        self.assertEqual(profile.venues['NeurIPS'], 1.0)

    def test_unknown_version_rejected(self) -> None:
        self.assertIsNone(
            parse_anonymous_profile({'profile_version': 'profile.v9', 'subjects': {}})
        )

    def test_non_mapping_rejected(self) -> None:
        self.assertIsNone(parse_anonymous_profile(['not', 'a', 'profile']))

    def test_dimension_size_capped(self) -> None:
        payload = {
            'profile_version': 'profile.v1',
            'subjects': {f'k{index}': 1.0 for index in range(65)},
            'keywords': {},
            'venues': {},
        }
        self.assertIsNone(parse_anonymous_profile(payload))

    def test_weight_bounds_enforced(self) -> None:
        for bad in (11.0, -11.0, float('nan'), float('inf'), 'heavy'):
            payload = {
                'profile_version': 'profile.v1',
                'subjects': {'cs.AI': bad},
                'keywords': {},
                'venues': {},
            }
            self.assertIsNone(parse_anonymous_profile(payload), msg=str(bad))

    def test_empty_dimensions_allowed(self) -> None:
        profile = parse_anonymous_profile({'profile_version': 'profile.v1'})
        self.assertIsNotNone(profile)
        self.assertEqual(profile.subjects, {})


class EncodeDecodeTest(unittest.TestCase):
    def test_round_trip_preserves_unicode_weights(self) -> None:
        profile = AnonymousProfile(
            subjects={'cs.AI': 2.5},
            keywords={'多模态': 1.5},
            venues={'NeurIPS': 0.25},
        )
        encoded = encode_anonymous_profile(profile)
        decoded = decode_anonymous_profile(encoded)
        self.assertIsNotNone(decoded)
        self.assertEqual(decoded.subjects, profile.subjects)
        self.assertEqual(decoded.keywords, profile.keywords)
        self.assertEqual(decoded.venues, profile.venues)

    def test_garbage_decode_returns_none(self) -> None:
        self.assertIsNone(decode_anonymous_profile('%%%not-base64%%%'))
        self.assertIsNone(decode_anonymous_profile('e30='))  # '{}' 缺 profile_version


if __name__ == '__main__':
    unittest.main()

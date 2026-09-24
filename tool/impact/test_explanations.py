import copy
import hashlib
import json
import unittest

from bake_explanations import compact
from check_explanations import validate


class ExplanationsTest(unittest.TestCase):
    def test_selects_by_absolute_magnitude_without_losing_negative_sign(self):
        self.assertEqual(compact([0.2, -0.9, 0.5, -0.6]), [[1, -0.9], [3, -0.6], [2, 0.5]])
        self.assertEqual(compact([0.0, 0.0]), [])

    def test_rejects_nonfinite_model_data(self):
        from bake_impact import BakeError
        for value in (float("nan"), float("inf"), -float("inf")):
            with self.assertRaises(BakeError):
                compact([value])

    def test_rejects_stale_or_misassigned_evidence(self):
        from pathlib import Path
        root = Path(__file__).resolve().parents[2]
        raw = (root / "assets/impact/insulin_avi.json").read_bytes()
        data = json.loads((root / "assets/impact_explanations/insulin.json").read_text())
        validate(raw, data)
        stale = copy.deepcopy(data)
        stale["impact_sha256"] = hashlib.sha256(b"wrong").hexdigest()
        with self.assertRaisesRegex(AssertionError, "digest"):
            validate(raw, stale)
        swapped = copy.deepcopy(data)
        swapped["positions"]["5294"][0][0] = -1
        with self.assertRaisesRegex(AssertionError, "allele score"):
            validate(raw, swapped)


if __name__ == "__main__":
    unittest.main()

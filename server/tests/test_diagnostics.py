from __future__ import annotations

import re
import unittest
from pathlib import Path

from spark_papers.diagnostics import (
    DIAGNOSTIC_LOGGER_NAME,
    ServerDiagnosticOperation,
    report_unexpected,
)


class _ExplodingStringError(RuntimeError):
    def __str__(self) -> str:
        raise AssertionError("diagnostics must not stringify exceptions")


def _raise_private_failure() -> None:
    raise _ExplodingStringError()


class DiagnosticsTest(unittest.TestCase):
    def test_operation_values_are_unique_safe_identifiers(self) -> None:
        values = [operation.value for operation in ServerDiagnosticOperation]

        self.assertEqual(len(values), len(set(values)))
        for value in values:
            self.assertRegex(value, r"^[a-z][a-z0-9]*(?:[._][a-z0-9]+)*$")

    def test_report_contains_fixed_metadata_and_sanitized_stack(self) -> None:
        try:
            _raise_private_failure()
        except _ExplodingStringError as error:
            with self.assertLogs(DIAGNOSTIC_LOGGER_NAME, level="ERROR") as logs:
                report_unexpected(ServerDiagnosticOperation.HTTP_REQUEST, error)

        output = "\n".join(logs.output)
        self.assertIn("operation=http.request", output)
        self.assertIn("type=_ExplodingStringError", output)
        self.assertIn("test_diagnostics.py", output)
        self.assertIn("_raise_private_failure", output)
        self.assertNotIn("diagnostics must not stringify", output)
        self.assertEqual(len(logs.records), 1)
        self.assertFalse(
            any(isinstance(argument, BaseException) for argument in logs.records[0].args)
        )

    def test_operation_must_come_from_the_fixed_enum(self) -> None:
        with self.assertRaises(TypeError):
            report_unexpected("dynamic.operation", RuntimeError())  # type: ignore[arg-type]

    def test_production_modules_cannot_bypass_the_diagnostics_logger(self) -> None:
        package_root = Path(__file__).resolve().parents[1] / "spark_papers"
        diagnostics_path = package_root / "diagnostics.py"
        forbidden = re.compile(
            r"(?:^|\n)\s*(?:import\s+logging\b|from\s+logging\b)|\blogging\s*\."
        )
        violations: list[str] = []

        for path in package_root.glob("*.py"):
            if path == diagnostics_path:
                continue
            source = path.read_text(encoding="utf-8")
            for match in forbidden.finditer(source):
                line = source.count("\n", 0, match.start()) + 1
                violations.append(f"{path.name}:{line}")

        self.assertEqual(violations, [])


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import unittest

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

    def test_operation_must_come_from_the_fixed_enum(self) -> None:
        with self.assertRaises(TypeError):
            report_unexpected("dynamic.operation", RuntimeError())  # type: ignore[arg-type]


if __name__ == "__main__":
    unittest.main()

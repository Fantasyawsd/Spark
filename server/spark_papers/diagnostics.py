from __future__ import annotations

import logging
from enum import Enum
from pathlib import Path
from types import TracebackType


DIAGNOSTIC_LOGGER_NAME = "spark_papers.diagnostics"


class ServerDiagnosticOperation(str, Enum):
    HTTP_REQUEST = "http.request"
    CLI_COMMAND = "cli.command"
    CLI_SYNC_JSON = "cli.sync_json"
    CLI_IMPORT_DATASET = "cli.import_dataset"
    CLI_SYNC_EXTERNAL = "cli.sync_external"
    CLI_SYNC_ARXIV_OAI = "cli.sync_arxiv_oai"
    CLI_SERVE = "cli.serve"


_LOGGER = logging.getLogger(DIAGNOSTIC_LOGGER_NAME)


def configure_logging() -> None:
    """Install a minimal standard-library logging fallback for CLI use."""

    logging.basicConfig(
        level=logging.INFO,
        format="%(levelname)s %(name)s %(message)s",
    )


def report_unexpected(
    operation: ServerDiagnosticOperation,
    error: BaseException,
) -> None:
    """Log fixed metadata and stack frames without formatting the exception."""

    if not isinstance(operation, ServerDiagnosticOperation):
        raise TypeError("operation must be a ServerDiagnosticOperation")
    _LOGGER.error(
        "unexpected_error operation=%s type=%s stack=%s",
        operation.value,
        type(error).__name__,
        _safe_stack(error.__traceback__),
    )


def _safe_stack(traceback: TracebackType | None) -> str:
    if traceback is None:
        return "unavailable"
    frames: list[str] = []
    current = traceback
    while current is not None:
        code = current.tb_frame.f_code
        frames.append(
            f"{Path(code.co_filename).name}:{current.tb_lineno}:{code.co_name}"
        )
        current = current.tb_next
    return " <- ".join(frames[-20:])

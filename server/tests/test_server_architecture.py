"""Static import boundaries; no production modules are executed by the scanner."""
from __future__ import annotations

import ast
import unittest
from pathlib import Path

ROOT = Path(__file__).parents[1] / "spark_papers"
PURE = {
    "spark_papers.models", "spark_papers.ports", "spark_papers.anonymous_profile",
    "spark_papers.preference_score", "spark_papers.trend_boost",
    "spark_papers.recommendation_policy", "spark_papers.recommendation_scoring",
    "spark_papers.recommendation_sampling",
}
APPLICATION = {"spark_papers.recommendation", "spark_papers.personalized_pool"}
ALLOWED_EXTERNAL = {
    "__future__", "base64", "dataclasses", "datetime", "enum", "hashlib", "itertools",
    "json", "math", "random", "re", "typing",
}


def _dependencies(module: str, source: str, *, is_package: bool = False) -> set[str]:
    dependencies = set()
    package = module if is_package else module.rpartition(".")[0]
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, ast.Import):
            dependencies.update(alias.name for alias in node.names)
        elif isinstance(node, ast.ImportFrom):
            if node.level:
                pieces = package.split(".")
                prefix = ".".join(pieces[:len(pieces) - node.level + 1])
                target = ".".join(part for part in (prefix, node.module) if part)
            else:
                target = node.module or ""
            dependencies.add(target)
            # Covers both `from . import submodule` and package re-exports.
            dependencies.update(f"{target}.{alias.name}" for alias in node.names)
    return dependencies


def _graph(sources):
    names = set(sources)
    graph = {}
    for name, (source, is_package) in sources.items():
        edges = set()
        for dependency in _dependencies(name, source, is_package=is_package):
            parts = dependency.split(".")
            while parts and ".".join(parts) not in names:
                parts.pop()
            target = ".".join(parts)
            if target in names and target != name:
                edges.add(target)
        graph[name] = edges
    return graph


def _cycle(graph):
    visiting = []
    active = set()
    completed = set()

    def visit(node):
        if node in active:
            return visiting[visiting.index(node):] + [node]
        if node in completed:
            return None
        visiting.append(node)
        active.add(node)
        for child in sorted(graph[node]):
            found = visit(child)
            if found:
                return found
        visiting.pop()
        active.remove(node)
        completed.add(node)
        return None

    for node in sorted(graph):
        found = visit(node)
        if found:
            return found
    return None


class ServerArchitectureTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = {}
        for path in sorted(ROOT.rglob("*.py")):
            relative = path.relative_to(ROOT).with_suffix("")
            parts = list(relative.parts)
            is_package = parts[-1] == "__init__"
            if is_package:
                parts.pop()
            name = ".".join(["spark_papers", *parts])
            cls.sources[name] = (path.read_text(encoding="utf-8"), is_package)

    def test_production_import_graph_is_acyclic(self):
        self.assertIsNone(_cycle(_graph(self.sources)))

    def test_domain_and_use_cases_do_not_import_adapters(self):
        allowed = PURE | APPLICATION | {"spark_papers"}
        violations = []
        for name in sorted(PURE | APPLICATION):
            self.assertIn(name, self.sources, msg="Boundary module missing: " + name)
            source, is_package = self.sources[name]
            for dependency in _dependencies(name, source, is_package=is_package):
                if dependency.startswith("spark_papers"):
                    # Symbol imports resolve to their containing module.
                    target = dependency
                    while target not in self.sources and "." in target:
                        target = target.rpartition(".")[0]
                    if target not in allowed or (name in PURE and target in APPLICATION):
                        violations.append(f"{name} -> {dependency}")
                elif dependency.split(".")[0] not in ALLOWED_EXTERNAL:
                    violations.append(f"{name} -> {dependency}")
        self.assertEqual(violations, [])

    def test_snapshot_mapping_has_no_api_dependency(self):
        graph = _graph(self.sources)
        start = "spark_papers.recommendation_snapshot"
        self.assertIn(start, graph)
        seen = set()
        pending = [start]
        while pending:
            node = pending.pop()
            if node not in seen:
                seen.add(node)
                pending.extend(graph[node])
        self.assertTrue({"spark_papers.api", "spark_papers.dto"}.isdisjoint(seen))


class ImportScannerTest(unittest.TestCase):
    def test_catches_relative_and_absolute_cycles(self):
        for left, right in (("from .b import B", "import demo.a"),
                            ("from . import b", "from .a import A")):
            graph = _graph({"demo.a": (left, False), "demo.b": (right, False)})
            self.assertEqual(_cycle(graph), ["demo.a", "demo.b", "demo.a"])

    def test_nested_imports_are_checked(self):
        source = "def run():\n    from .storage import PaperStore\n"
        self.assertIn("demo.storage", _dependencies("demo.app", source))

    def test_parent_relative_imports_and_package_exports(self):
        sources = {
            "demo": ("from . import app", True),
            "demo.app": ("from .child import model", False),
            "demo.child": ("", True),
            "demo.child.model": ("from .. import app", False),
        }
        graph = _graph(sources)
        self.assertIn("demo.app", graph["demo.child.model"])
        self.assertIsNotNone(_cycle(graph))

    def test_comments_and_strings_are_not_imports(self):
        source = '# import bad\nnote = "from .bad import Value"\n'
        self.assertEqual(_dependencies("demo.app", source), set())


if __name__ == "__main__":
    unittest.main()

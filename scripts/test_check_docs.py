import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('check_docs', Path(__file__).with_name('check-docs.py'))
docs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(docs)


class DocumentationChecks(unittest.TestCase):
    def test_heading_anchors_match_duplicates_and_inline_code(self):
        self.assertEqual(docs.anchors('# Hello `Iris`!\n## Hello Iris!\n## 4. Local-map setup\n'),
                         {'hello-iris', 'hello-iris-1', '4-local-map-setup'})

    def test_fenced_commands_are_not_links_or_headings(self):
        text = '# Real\n```sh\n# Fake\n[no](missing.md)\n```\n[yes](ok.md#real)\n'
        self.assertEqual(docs.anchors(text), {'real'})
        self.assertEqual(list(docs.destinations(text)), ['ok.md#real'])

    def test_missing_file_and_anchor_fail_but_external_urls_are_skipped(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'README.md'
            source.write_text('[ok](target.md#present) [bad](target.md#absent) [gone](gone.md) [remote](https://example.test/missing)')
            (root / 'target.md').write_text('# Present\n')
            errors = docs.link_errors(source, root)
            self.assertEqual(len(errors), 2)
            self.assertIn('missing heading', errors[0])
            self.assertIn('missing target', errors[1])

    def test_example_paths_cannot_escape_and_duplicates_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'docs').mkdir()
            page = root / 'docs/tutorial.md'
            page.write_text('<!-- iris-example: ../escape.idr -->\n```idris\nmodule Escape\n```')
            with self.assertRaisesRegex(ValueError, 'Unsafe'):
                docs.examples(root)
            snippet = '<!-- iris-example: src/App.idr -->\n```idris\nmodule App\n```\n'
            page.write_text(snippet * 2)
            with self.assertRaisesRegex(ValueError, 'Duplicate'):
                docs.examples(root)


if __name__ == '__main__':
    unittest.main()

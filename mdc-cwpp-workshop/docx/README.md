# DOCX Runbook

`RUNBOOK.docx` — Word version of `../RUNBOOK.md`, generated for attendees who want a printable / annotatable version.

- US Letter, 1" margins
- Arial 11pt body, Arial Bold 22 / 17 / 13pt for H1/H2/H3 (coral H3 accent)
- Code blocks in Consolas with soft-gray fill + coral left border
- Auto-generated **table of contents** field (press **F9** in Word to refresh)
- Page break before each numbered section
- Centered footer: *MDC CWPP Workshop · Runbook · 2026-05-20*

## Regenerating

The builder script lives in git history. To regenerate:

```bash
git show HEAD:docx/build_runbook_docx.py > docx/build_runbook_docx.py
pip install python-docx
python docx/build_runbook_docx.py
```

If you'd rather use **pandoc** (cleaner GFM table rendering, requires `pandoc` and a reference style):

```bash
pandoc RUNBOOK.md \
  --from gfm \
  --to docx \
  --toc --toc-depth=3 \
  --reference-doc docx/reference.docx \
  -o docx/RUNBOOK.docx
```

`docx/reference.docx` would carry your styles — generate it once with `pandoc -o reference.docx --print-default-data-file reference.docx`.

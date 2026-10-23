from pypdf import PdfReader

reader = PdfReader("Final_Report.pdf")
print(f"Total pages in Final_Report.pdf: {len(reader.pages)}")

for i, page in enumerate(reader.pages):
    text = page.extract_text() or ""
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    first = lines[0] if lines else "[EMPTY PAGE]"
    print(f"Page {i+1}: {first[:60]} (lines: {len(lines)})")

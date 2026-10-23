from pypdf import PdfReader
import re

reader = PdfReader("TEAM 1 Project Report.pdf")
page = reader.pages[1]
contents = page.get_contents()
data = contents.get_data().decode('latin1', errors='ignore')

print("All rectangles on page 2:")
for m in re.finditer(r'([0-9.-]+)\s+([0-9.-]+)\s+([0-9.-]+)\s+([0-9.-]+)\s+re', data):
    print(m.group(0))

print("\nAll lines on page 2 (m/l):")
for m in re.finditer(r'([0-9.-]+)\s+([0-9.-]+)\s+m\s+([0-9.-]+)\s+([0-9.-]+)\s+l', data):
    print(m.group(0))

from pypdf import PdfReader
import re

reader = PdfReader("TEAM 1 Project Report.pdf")
page = reader.pages[1]
contents = page.get_contents()
data = contents.get_data().decode('latin1', errors='ignore')
# let's look for stroke linewidth 'w' and line 'm ... l'
lines = [l for l in data.splitlines() if any(k in l for k in [' m', ' l', ' w', ' S', ' s', ' f'])]
print(f"Total path lines on page 2: {len(lines)}")
for l in lines[:30]:
    print(l)

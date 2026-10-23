from pypdf import PdfReader
import json

reader = PdfReader("TEAM 1 Project Report.pdf")
print(f"Total pages: {len(reader.pages)}")

for i, page in enumerate(reader.pages):
    print(f"\n=== PAGE {i+1} ===")
    mediabox = page.mediabox
    print(f"MediaBox: w={mediabox.width}, h={mediabox.height}")
    
    text = page.extract_text()
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    print(f"Line count: {len(lines)}")
    for l in lines[:10]:
        print(f"  {l}")

    # Check images or drawings
    images = page.images
    print(f"Images count: {len(images)}")
    for img in images:
        print(f"  Image: {img.name}")

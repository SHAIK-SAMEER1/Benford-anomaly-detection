import os
from pypdf import PdfReader

os.makedirs("report_assets/extracted", exist_ok=True)
reader = PdfReader("TEAM 1 Project Report.pdf")

for i, page in enumerate(reader.pages):
    for j, img in enumerate(page.images):
        name = f"page_{i+1}_{img.name}"
        path = os.path.join("report_assets/extracted", name)
        with open(path, "wb") as f:
            f.write(img.data)
        print(f"Extracted {path}")

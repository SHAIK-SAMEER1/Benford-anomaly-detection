import pdfplumber
import json
from docx import Document

print("Analyzing TEAM 1 Project Report.pdf...")
with pdfplumber.open("TEAM 1 Project Report.pdf") as pdf:
    print(f"Total pages: {len(pdf.pages)}")
    for i, p in enumerate(pdf.pages):
        text = p.extract_text() or ""
        first_line = text.split("\n")[0] if text else ""
        print(f"\n--- PAGE {i+1} ({first_line[:50]}) ---")
        print(f"Dimensions: {p.width} x {p.height}")
        
        # Fonts
        fonts = {}
        for c in p.chars:
            fn = c.get("fontname")
            sz = round(c.get("size"), 1)
            color = c.get("non_stroking_color")
            key = (fn, sz, str(color))
            fonts[key] = fonts.get(key, 0) + 1
        print("Fonts:")
        for k, count in sorted(fonts.items(), key=lambda x: -x[1])[:8]:
            print(f"  {k}: {count} chars")
            
        # Large borders or boxes
        rects = p.rects
        curves = p.curves
        lines = p.lines
        print(f"Rects: {len(rects)}, Curves: {len(curves)}, Lines: {len(lines)}, Images: {len(p.images)}")
        for r in rects:
            if r["width"] > 400 and r["height"] > 600:
                print(f"  PAGE BORDER RECT: x0={r['x0']}, y0={r['y0']}, x1={r['x1']}, y1={r['y1']}, w={r['width']}, h={r['height']}, lw={r.get('linewidth')}, stroke={r.get('stroke')}, fill={r.get('fill')}")
        for c in curves:
            if c["width"] > 400 and c["height"] > 600:
                print(f"  PAGE BORDER CURVE: x0={c['x0']}, y0={c['y0']}, x1={c['x1']}, y1={c['y1']}, w={c['width']}, h={c['height']}, lw={c.get('linewidth')}")
        # check small boxes (like figure boxes or console output boxes)
        box_rects = [r for r in rects if 200 < r["width"] < 500 and 50 < r["height"] < 600]
        box_curves = [c for c in curves if 200 < c["width"] < 500 and 50 < c["height"] < 600]
        if box_rects:
            print(f"  Sample Box Rects ({len(box_rects)}): w={box_rects[0]['width']}, h={box_rects[0]['height']}, lw={box_rects[0].get('linewidth')}")
        if box_curves:
            print(f"  Sample Box Curves ({len(box_curves)}): w={box_curves[0]['width']}, h={box_curves[0]['height']}, lw={box_curves[0].get('linewidth')}")

print("\n\nChecking existing docx template: Benfords_Law_Final_Project_Report_Working_Draft.docx")
doc = Document("Benfords_Law_Final_Project_Report_Working_Draft.docx")
print("Docx styles:")
for s in doc.styles:
    if s.type == 1: # paragraph style
        print(f"  Style: {s.name}")

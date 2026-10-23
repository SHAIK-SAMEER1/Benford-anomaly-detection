from pypdf import PdfReader
import re

reader = PdfReader("TEAM 1 Project Report.pdf")

print("=== DETAILED PAGE INSPECTION ===")
for i, page in enumerate(reader.pages):
    print(f"\n--- PAGE {i+1} ---")
    
    # Extract font information via visitor
    fonts_used = set()
    text_pieces = []
    
    def visitor_body(text, cm, tm, font_dict, font_size):
        if text.strip():
            font_name = font_dict.get('/BaseFont', 'Unknown') if font_dict else 'Unknown'
            fonts_used.add((font_name, round(font_size, 1)))
            text_pieces.append((round(tm[5], 1), round(tm[4], 1), font_name, round(font_size, 1), text))

    page.extract_text(visitor_text=visitor_body)
    print("Fonts detected:", sorted(fonts_used))
    
    # Sort text by y (top to bottom), then x
    text_pieces.sort(key=lambda item: (-item[0], item[1]))
    print(f"Sample lines (first 8):")
    for y, x, fn, sz, txt in text_pieces[:8]:
        print(f"  y={y:.1f}, x={x:.1f} [{fn} {sz}pt]: {txt}")

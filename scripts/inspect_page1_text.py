from pypdf import PdfReader

reader = PdfReader("TEAM 1 Project Report.pdf")
page = reader.pages[0]

text_elements = []
def visitor(text, cm, tm, font_dict, font_size):
    if text.strip():
        fn = font_dict.get('/BaseFont', '') if font_dict else ''
        text_elements.append({
            'text': text,
            'x': round(tm[4], 2),
            'y': round(tm[5], 2),
            'font': fn,
            'size': round(font_size, 2)
        })

page.extract_text(visitor_text=visitor)
# group elements with similar y
from collections import defaultdict
lines = defaultdict(list)
for el in text_elements:
    y_key = round(el['y'], 0)
    lines[y_key].append(el)

for y in sorted(lines.keys(), reverse=True):
    line_els = sorted(lines[y], key=lambda x: x['x'])
    line_text = "".join(el['text'] for el in line_els)
    font_info = f"{line_els[0]['font']} {line_els[0]['size']}pt"
    print(f"y={y}: [{font_info}] (x={line_els[0]['x']}) '{line_text}'")

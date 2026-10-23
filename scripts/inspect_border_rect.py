from pypdf import PdfReader

reader = PdfReader("TEAM 1 Project Report.pdf")
print("Page border analysis:")
for i, page in enumerate(reader.pages):
    # let's look at contents stream for rect or l/m operations
    contents = page.get_contents()
    if contents:
        data = contents.get_data().decode('latin1', errors='ignore')
        # find re (rectangle) commands
        import re
        matches = re.findall(r'([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+re', data)
        # print large rects
        for m in matches:
            x, y, w, h = map(float, m)
            if w > 450 and h > 700:
                print(f"Page {i+1} border rect: x={x}, y={y}, w={w}, h={h}")

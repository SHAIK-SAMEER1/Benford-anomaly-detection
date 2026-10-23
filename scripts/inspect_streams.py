from pypdf import PdfReader

reader = PdfReader("TEAM 1 Project Report.pdf")
page = reader.pages[1]
contents = page.get_contents()
if isinstance(contents, list):
    for idx, c in enumerate(contents):
        data = c.get_data().decode('latin1', errors='ignore')
        print(f"Stream {idx} length: {len(data)}")
        for l in data.splitlines():
            if ' w' in l or ' re' in l or ' m' in l:
                print("  ", l)
else:
    data = contents.get_data().decode('latin1', errors='ignore')
    print("Single stream length:", len(data))
    for l in data.splitlines()[:50]:
        print("  ", l)

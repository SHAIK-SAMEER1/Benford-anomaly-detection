from pypdf import PdfReader

reader = PdfReader("TEAM 1 Project Report.pdf")
page = reader.pages[0]
p13 = page['/Resources']['/Pattern']['/P13'].get_object()
sh = p13['/Shading'].get_object()
fn = sh['/Function'].get_object()
for i, subfn in enumerate(fn['/Functions']):
    sub = subfn.get_object()
    c0 = [round(x, 3) for x in sub.get('/C0', [])]
    c1 = [round(x, 3) for x in sub.get('/C1', [])]
    print(f"Sub-function {i+1}: C0={c0} -> C1={c1}")

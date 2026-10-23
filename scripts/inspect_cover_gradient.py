from pypdf import PdfReader

reader = PdfReader("TEAM 1 Project Report.pdf")
page = reader.pages[0]
print("Page 1 resources:")
print("Keys:", page.keys())
if '/Resources' in page:
    res = page['/Resources']
    print("Resources keys:", res.keys())
    if '/Shading' in res:
        print("Shading:", res['/Shading'])
    if '/Pattern' in res:
        print("Pattern:", res['/Pattern'])
    if '/XObject' in res:
        print("XObjects:", res['/XObject'].keys())

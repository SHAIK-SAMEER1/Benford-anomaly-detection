from pypdf import PdfReader

reader = PdfReader("TEAM 1 Project Report.pdf")
page = reader.pages[0]
p13 = page['/Resources']['/Pattern']['/P13'].get_object()
print("P13 pattern:", p13)
if '/Shading' in p13:
    sh = p13['/Shading'].get_object()
    print("Shading:", sh)
    if '/Function' in sh:
        fn = sh['/Function'].get_object()
        print("Function:", fn)
        if '/C0' in fn and '/C1' in fn:
            print("C0 (start color):", fn['/C0'])
            print("C1 (end color):", fn['/C1'])

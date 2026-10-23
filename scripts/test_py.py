try:
    import docx
    print("docx ok:", docx.__file__)
except Exception as e:
    print("docx err:", e)

try:
    import pdfplumber
    print("pdfplumber ok:", pdfplumber.__file__)
except Exception as e:
    print("pdfplumber err:", e)

import zipfile
import xml.etree.ElementTree as ET

docx_path = "Benfords_Law_Final_Project_Report_Working_Draft.docx"

with zipfile.ZipFile(docx_path, 'r') as z:
    doc_xml = z.read("word/document.xml")
    root = ET.fromstring(doc_xml)
    namespaces = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    paragraphs = root.findall('.//w:p', namespaces)
    
    with open("report_assets/draft_text_dump.txt", "w", encoding="utf-8") as out:
        for i, p in enumerate(paragraphs):
            texts = [t.text for t in p.findall('.//w:t', namespaces) if t.text]
            full_text = "".join(texts).strip()
            if full_text:
                pStyle = p.find('.//w:pStyle', namespaces)
                style_name = pStyle.attrib.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val') if pStyle is not None else 'Normal'
                out.write(f"[{i+1}|{style_name}] {full_text}\n")

print("Dumped draft text to report_assets/draft_text_dump.txt")

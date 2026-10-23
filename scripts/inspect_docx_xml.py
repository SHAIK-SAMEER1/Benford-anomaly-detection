import zipfile
import xml.etree.ElementTree as ET

docx_path = "Benfords_Law_Final_Project_Report_Working_Draft.docx"

with zipfile.ZipFile(docx_path, 'r') as z:
    print("Files in docx:")
    for name in z.namelist():
        if "word/" in name:
            print(" ", name)
            
    doc_xml = z.read("word/document.xml")
    root = ET.fromstring(doc_xml)
    
    # Extract all text
    namespaces = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}
    paragraphs = root.findall('.//w:p', namespaces)
    print(f"\nTotal paragraphs: {len(paragraphs)}")
    
    for i, p in enumerate(paragraphs[:35]):
        texts = [t.text for t in p.findall('.//w:t', namespaces) if t.text]
        full_text = "".join(texts).strip()
        if full_text:
            pStyle = p.find('.//w:pStyle', namespaces)
            style_name = pStyle.attrib.get('{http://schemas.openxmlformats.org/wordprocessingml/2006/main}val') if pStyle is not None else 'Normal'
            print(f"P{i+1} [{style_name}]: {full_text[:80]}")

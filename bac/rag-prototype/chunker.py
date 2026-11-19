from pypdf import PdfReader
from langchain_text_splitters import RecursiveCharacterTextSplitter


# 1. قراءة الـ PDF
pdf_path = "document.pdf"
reader = PdfReader(pdf_path)

# 2. جمع النص من جميع الصفحات
full_text = ""

for page in reader.pages:
    text = page.extract_text()

    if text:
        full_text += text + "\n"


# 3. إنشاء أداة تقسيم النص
text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,
    chunk_overlap=100
)


# 4. تقسيم النص
chunks = text_splitter.split_text(full_text)


# 5. عرض النتائج
print(f"Total chunks: {len(chunks)}")

for i, chunk in enumerate(chunks[:5], start=1):
    print(f"\n--- Chunk {i} ---")
    print(chunk)
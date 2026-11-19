from pypdf import PdfReader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from sentence_transformers import SentenceTransformer


# ==========================================
# 1. قراءة الـ PDF
# ==========================================

pdf_path = "document.pdf"

reader = PdfReader(pdf_path)

full_text = ""

for page in reader.pages:
    text = page.extract_text()

    if text:
        full_text += text + "\n"


# ==========================================
# 2. تقسيم النص إلى Chunks
# ==========================================

text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,
    chunk_overlap=100
)

chunks = text_splitter.split_text(full_text)

print(f"Total chunks: {len(chunks)}")


# ==========================================
# 3. تحميل نموذج Embeddings
# ==========================================

print("\nLoading embedding model...")

model = SentenceTransformer("all-MiniLM-L6-v2")

print("Embedding model loaded!")


# ==========================================
# 4. تحويل الـ Chunks إلى Embeddings
# ==========================================

embeddings = model.encode(chunks)

print(f"\nNumber of embeddings: {len(embeddings)}")
print(f"Embedding dimensions: {embeddings.shape[1]}")


# ==========================================
# 5. عرض أول Embedding
# ==========================================

print("\nFirst chunk:")
print(chunks[0])

print("\nFirst embedding:")
print(embeddings[0])
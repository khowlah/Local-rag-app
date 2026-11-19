
from pypdf import PdfReader
from langchain_text_splitters import RecursiveCharacterTextSplitter
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity


# ==========================================
# 1. Embedding Model
# ==========================================

print("\nLoading embedding model...")

embedding_model = SentenceTransformer(
    "all-MiniLM-L6-v2"
)

print("Embedding model loaded!")


# ==========================================
# 2. Text Splitter
# ==========================================

text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=500,
    chunk_overlap=100
)


# ==========================================
# 3. بيانات الملف الحالي
# ==========================================

chunks = []

chunk_embeddings = None

current_filename = None


# ==========================================
# 4. Similarity Threshold
# ==========================================

MIN_SIMILARITY = 0.30


# ==========================================
# 5. تحميل PDF وبناء Embeddings
# ==========================================

def load_pdf(pdf_path, filename=None):

    global chunks
    global chunk_embeddings
    global current_filename


    print(
        f"\nLoading PDF: {pdf_path}"
    )


    # --------------------------------------
    # قراءة PDF
    # --------------------------------------

    reader = PdfReader(pdf_path)

    full_text = ""


    for page in reader.pages:

        text = page.extract_text()

        if text:

            full_text += text + "\n"


    # --------------------------------------
    # التأكد أن PDF يحتوي على نص
    # --------------------------------------

    if not full_text.strip():

        raise ValueError(
            "The PDF does not contain readable text."
        )


    # --------------------------------------
    # تقسيم النص
    # --------------------------------------

    new_chunks = text_splitter.split_text(
        full_text
    )


    if not new_chunks:

        raise ValueError(
            "Could not create text chunks from PDF."
        )


    print(
        f"Total chunks: {len(new_chunks)}"
    )


    # --------------------------------------
    # إنشاء Embeddings
    # --------------------------------------

    print(
        "\nCreating embeddings..."
    )


    new_embeddings = embedding_model.encode(
        new_chunks
    )


    # --------------------------------------
    # حفظ البيانات
    # --------------------------------------

    chunks = new_chunks

    chunk_embeddings = new_embeddings

    current_filename = filename


    print(
        "Chunk embeddings created!"
    )

    print(
        f"Current PDF: {current_filename}"
    )


    return {
        "filename": current_filename,
        "chunks": len(chunks)
    }


# ==========================================
# 6. التحقق هل يوجد PDF
# ==========================================

def has_document():

    return (
        len(chunks) > 0
        and chunk_embeddings is not None
    )


# ==========================================
# 7. البحث داخل PDF
# ==========================================

def retrieve(question, top_k=1):

    # --------------------------------------
    # التأكد من وجود ملف
    # --------------------------------------

    if not has_document():

        return []


    # --------------------------------------
    # Question Embedding
    # --------------------------------------

    question_embedding = embedding_model.encode(
        [question]
    )


    # --------------------------------------
    # Similarity
    # --------------------------------------

    similarities = cosine_similarity(
        question_embedding,
        chunk_embeddings
    )[0]


    # --------------------------------------
    # أفضل نتيجة
    # --------------------------------------

    best_index = similarities.argmax()

    best_similarity = float(
        similarities[best_index]
    )


    # --------------------------------------
    # Similarity Threshold
    # --------------------------------------

    if best_similarity < MIN_SIMILARITY:

        return []


    # --------------------------------------
    # اختيار أفضل Chunks
    # --------------------------------------

    top_indices = similarities.argsort()[
        -top_k:
    ][::-1]


    # --------------------------------------
    # تجهيز النتائج
    # --------------------------------------

    results = []


    for rank, index in enumerate(
        top_indices,
        start=1
    ):

        results.append(
            {
                "rank": rank,
                "similarity": float(
                    similarities[index]
                ),
                "text": chunks[index]
            }
        )


    return results


# ==========================================
# 8. اختبار Retriever
# ==========================================

if __name__ == "__main__":

    print(
        "\nThis file is now designed "
        "to receive PDFs from the API."
    )

    print(
        "Use /upload from FastAPI."
    )
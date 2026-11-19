from fastapi import (
    FastAPI,
    UploadFile,
    File,
    HTTPException
)

from pydantic import BaseModel

import os
import shutil


from retriever import (
    load_pdf,
    retrieve,
    has_document
)

from generated import generate_answer

from answer_validator import validate_answer


# ==========================================
# إنشاء FastAPI
# ==========================================

app = FastAPI(
    title="PDF RAG Assistant API",
    version="1.0.0"
)


# ==========================================
# مجلد تخزين الملفات
# ==========================================

UPLOAD_DIR = "uploads"

os.makedirs(
    UPLOAD_DIR,
    exist_ok=True
)


# ==========================================
# نموذج السؤال
# ==========================================

class QuestionRequest(BaseModel):

    question: str


# ==========================================
# الصفحة الرئيسية
# ==========================================

@app.get("/")
def root():

    return {
        "message": "PDF RAG Assistant API is running"
    }


# ==========================================
# رفع PDF
# ==========================================

@app.post("/upload")
async def upload_pdf(
    file: UploadFile = File(...)
):

    # --------------------------------------
    # التأكد من نوع الملف
    # --------------------------------------

    if not file.filename:

        raise HTTPException(
            status_code=400,
            detail="No file selected."
        )


    if not file.filename.lower().endswith(
        ".pdf"
    ):

        raise HTTPException(
            status_code=400,
            detail="Only PDF files are allowed."
        )


    # --------------------------------------
    # اسم الملف
    # --------------------------------------

    filename = os.path.basename(
        file.filename
    )


    file_path = os.path.join(
        UPLOAD_DIR,
        filename
    )


    # --------------------------------------
    # حفظ الملف
    # --------------------------------------

    try:

        with open(
            file_path,
            "wb"
        ) as buffer:

            shutil.copyfileobj(
                file.file,
                buffer
            )


        # ----------------------------------
        # قراءة PDF وبناء Embeddings
        # ----------------------------------

        result = load_pdf(
            file_path,
            filename
        )


        return {
            "message": "PDF uploaded successfully.",
            "filename": result["filename"],
            "chunks": result["chunks"]
        }


    except Exception as e:

        # حذف الملف إذا حدث خطأ

        if os.path.exists(file_path):

            os.remove(file_path)


        raise HTTPException(
            status_code=500,
            detail=f"Failed to process PDF: {str(e)}"
        )


# ==========================================
# حالة النظام
# ==========================================

@app.get("/status")
def status():

    if not has_document():

        return {
            "ready": False,
            "message": "No PDF uploaded."
        }


    return {
        "ready": True,
        "message": "PDF is ready for questions."
    }


# ==========================================
# سؤال عن PDF
# ==========================================

@app.post("/ask")
def ask_question(
    request: QuestionRequest
):

    question = request.question.strip()


    # --------------------------------------
    # التحقق من السؤال
    # --------------------------------------

    if not question:

        return {
            "answer": "Please enter a question.",
            "similarity": 0.0,
            "validated": False,
            "source": None
        }


    # --------------------------------------
    # التأكد من وجود PDF
    # --------------------------------------

    if not has_document():

        return {
            "answer": "Please upload a PDF first.",
            "similarity": 0.0,
            "validated": False,
            "source": None
        }


    # --------------------------------------
    # البحث
    # --------------------------------------

    results = retrieve(
        question,
        top_k=1
    )


    # --------------------------------------
    # لا توجد معلومات
    # --------------------------------------

    if not results:

        return {
            "answer": (
                "I couldn't find the answer "
                "in the provided document."
            ),
            "similarity": 0.0,
            "validated": False,
            "source": None
        }


    # --------------------------------------
    # أفضل نتيجة
    # --------------------------------------

    best_result = results[0]


    context = best_result["text"]

    similarity = best_result["similarity"]


    # --------------------------------------
    # توليد الإجابة
    # --------------------------------------

    answer = generate_answer(
        question,
        context
    )


    # --------------------------------------
    # التحقق من الإجابة
    # --------------------------------------

    validated = validate_answer(
        answer,
        context
    )


    # --------------------------------------
    # إذا فشل Validator
    # --------------------------------------

    if not validated:

        answer = (
            "I couldn't find the answer "
            "in the provided document."
        )


    # --------------------------------------
    # Response
    # --------------------------------------

    return {
        "answer": answer,
        "similarity": round(
            similarity,
            4
        ),
        "validated": bool(
            validated
        ),
        "source": int(
            best_result["rank"]
        )
    }
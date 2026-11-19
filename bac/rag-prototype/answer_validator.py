from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity


# ==========================================
# تحميل Embedding Model
# ==========================================

print("\nLoading validator model...")

validator_model = SentenceTransformer(
    "all-MiniLM-L6-v2"
)

print("Validator model loaded!")


# ==========================================
# الحد الأدنى للتشابه
# ==========================================

MIN_ANSWER_SIMILARITY = 0.35


# ==========================================
# العبارات التي تعني أن النموذج لم يجد إجابة
# ==========================================

FALLBACK_PHRASES = [
    "I couldn't find the answer",
    "I could not find the answer",
    "not found in the document",
    "not provided in the document",
    "not present in the document",
    "I don't know"
]


# ==========================================
# التحقق من الإجابة
# ==========================================

def validate_answer(answer, context):

    # --------------------------------------
    # التأكد من وجود Answer
    # --------------------------------------

    if not answer:
        return False


    # --------------------------------------
    # التأكد من وجود Context
    # --------------------------------------

    if not context:
        return False


    # --------------------------------------
    # تحويل الإجابة إلى String
    # --------------------------------------

    answer = str(answer).strip()


    # --------------------------------------
    # إذا كانت الإجابة فارغة
    # --------------------------------------

    if not answer:
        return False


    # --------------------------------------
    # التحقق من إجابات الرفض
    # --------------------------------------

    answer_lower = answer.lower()

    for phrase in FALLBACK_PHRASES:

        if phrase.lower() in answer_lower:

            print(
                "\nValidator rejected fallback answer."
            )

            return False


    # --------------------------------------
    # إنشاء Embedding للإجابة
    # --------------------------------------

    answer_embedding = validator_model.encode(
        [answer]
    )


    # --------------------------------------
    # إنشاء Embedding للـContext
    # --------------------------------------

    context_embedding = validator_model.encode(
        [context]
    )


    # --------------------------------------
    # حساب Similarity
    # --------------------------------------

    similarity = cosine_similarity(
        answer_embedding,
        context_embedding
    )[0][0]


    # --------------------------------------
    # تحويل numpy float إلى Python float
    # --------------------------------------

    similarity = float(similarity)


    # --------------------------------------
    # عرض نتيجة التشابه
    # --------------------------------------

    print(
        f"\nAnswer/Context similarity: "
        f"{similarity:.4f}"
    )


    # --------------------------------------
    # التحقق من الحد الأدنى
    # --------------------------------------

    is_valid = (
        similarity >= MIN_ANSWER_SIMILARITY
    )


    # --------------------------------------
    # تحويل numpy.bool إلى Python bool
    # --------------------------------------

    is_valid = bool(is_valid)


    print(
        f"Answer validated: {is_valid}"
    )


    # --------------------------------------
    # إرجاع النتيجة
    # --------------------------------------

    return is_valid
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch

from retriever import retrieve
from answer_validator import validate_answer


# ==========================================
# 1. إعدادات النموذج
# ==========================================

MODEL_NAME = "Qwen/Qwen2.5-0.5B-Instruct"

FALLBACK_ANSWER = (
    "I couldn't find the answer in the provided document."
)


# ==========================================
# 2. تحميل النموذج
# ==========================================

print("\nLoading LLM...")

tokenizer = AutoTokenizer.from_pretrained(
    MODEL_NAME
)

model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    dtype=torch.float32
)

print("LLM loaded successfully!")


# ==========================================
# 3. توليد الإجابة
# ==========================================

def generate_answer(question, context):

    messages = [
        {
            "role": "system",
            "content": (
                "You are a document question-answering assistant.\n\n"

                "Rules:\n"
                "1. Answer ONLY from the Context.\n"
                "2. Do not use outside knowledge.\n"
                "3. Do not guess.\n"
                "4. Do not add details that are not in the Context.\n"
                "5. Do not rewrite the entire Context.\n"
                "6. Give one short direct answer.\n"
                "7. If the answer is not clearly available, say:\n"
                "\"I couldn't find the answer in the provided document.\""
            )
        },
        {
            "role": "user",
            "content": (
                f"Context:\n{context}\n\n"
                f"Question:\n{question}\n\n"
                "Answer:"
            )
        }
    ]


    # ==========================================
    # إنشاء Chat Prompt
    # ==========================================

    prompt = tokenizer.apply_chat_template(
        messages,
        tokenize=False,
        add_generation_prompt=True
    )


    # ==========================================
    # تحويل Prompt إلى Tokens
    # ==========================================

    inputs = tokenizer(
        prompt,
        return_tensors="pt"
    )


    # ==========================================
    # توليد الإجابة
    # ==========================================

    with torch.no_grad():

        outputs = model.generate(
            **inputs,
            max_new_tokens=50,
            do_sample=False,
            repetition_penalty=1.2,
            no_repeat_ngram_size=3
        )


    # ==========================================
    # أخذ النص المولد فقط
    # ==========================================

    generated_tokens = outputs[0][
        inputs["input_ids"].shape[1]:
    ]


    answer = tokenizer.decode(
        generated_tokens,
        skip_special_tokens=True
    ).strip()


    # ==========================================
    # تنظيف الإجابة
    # ==========================================

    if not answer:

        return FALLBACK_ANSWER


    if "Answer:" in answer:

        answer = answer.split(
            "Answer:",
            1
        )[1].strip()


    # ==========================================
    # تنظيف رسائل الرفض
    # ==========================================

    fallback_checks = [
        "I couldn't find the answer",
        "I could not find the answer",
        "not found in the document",
        "not provided in the document"
    ]

    for phrase in fallback_checks:

        if phrase.lower() in answer.lower():

            return FALLBACK_ANSWER


    return answer


# ==========================================
# 4. تشغيل RAG
# ==========================================

if __name__ == "__main__":

    question = input(
        "\nAsk a question about the PDF: "
    )


    # ==========================================
    # Retrieval
    # ==========================================

    print(
        "\nSearching the document..."
    )

    results = retrieve(
        question,
        top_k=1
    )


    # ==========================================
    # لا توجد معلومات
    # ==========================================

    if not results:

        print(
            "\n===== ANSWER ====="
        )

        print(
            FALLBACK_ANSWER
        )

        raise SystemExit


    # ==========================================
    # أفضل نتيجة
    # ==========================================

    best_result = results[0]

    similarity = best_result[
        "similarity"
    ]

    context = best_result[
        "text"
    ]


    # ==========================================
    # عرض المصدر
    # ==========================================

    print(
        "\n===== RETRIEVED SOURCE ====="
    )

    print(
        f"Source: {best_result['rank']}"
    )

    print(
        f"Similarity: {similarity:.4f}"
    )

    print(
        "\n" + context
    )


    # ==========================================
    # توليد الإجابة
    # ==========================================

    print(
        "\nGenerating answer..."
    )

    answer = generate_answer(
        question,
        context
    )


    # ==========================================
    # التحقق من الإجابة
    # ==========================================

    is_valid = validate_answer(
        answer,
        context
    )


    # ==========================================
    # عرض النتيجة
    # ==========================================

    print(
        "\n===== ANSWER ====="
    )


    if is_valid:

        print(
            answer
        )

    else:

        print(
            FALLBACK_ANSWER
        )


    # ==========================================
    # معلومات RAG
    # ==========================================

    print(
        "\n===== RAG INFO ====="
    )

    print(
        f"Similarity: {similarity:.4f}"
    )

    print(
        f"Answer validated: {is_valid}"
    )
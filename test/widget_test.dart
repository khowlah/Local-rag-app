
// ============================================================
// Flutter Widget Tests
// ============================================================

// مكتبة Flutter الخاصة بالاختبارات
import 'package:flutter_test/flutter_test.dart';

// مكتبة Material التي تحتوي على Widgets مثل:
// TextField
// FilledButton
// OutlinedButton
// Text
// وغيرها
import 'package:flutter/material.dart';

// نستورد التطبيق الذي نريد اختباره
import 'package:rag_pdf_app/main.dart';

void main() {
  // ==========================================================
  // TEST 1
  // التأكد أن التطبيق يفتح بشكل صحيح
  // ==========================================================

  testWidgets(
    'PDF RAG Assistant opens correctly',
    (tester) async {
      // تشغيل التطبيق داخل بيئة الاختبار
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // نبحث عن عنوان التطبيق
      //
      // العنوان موجود مرتين في التطبيق:
      // 1. داخل AppBar
      // 2. داخل الصفحة
      //
      // لذلك نستخدم findsWidgets
      expect(
        find.text('PDF RAG Assistant'),
        findsWidgets,
      );
    },
  );

  // ==========================================================
  // TEST 2
  // التأكد أن زر Choose PDF موجود
  // ==========================================================

  testWidgets(
    'Choose PDF button exists',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // البحث عن النص الموجود داخل زر اختيار الملف
      final choosePdfButton = find.text('Choose PDF');

      // نتوقع وجوده مرة واحدة
      expect(
        choosePdfButton,
        findsOneWidget,
      );
    },
  );

  // ==========================================================
  // TEST 3
  // التأكد أن زر Upload PDF موجود
  // ==========================================================

  testWidgets(
    'Upload PDF button exists',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // البحث عن زر Upload PDF
      final uploadButton = find.text('Upload PDF');

      // يجب أن يظهر مرة واحدة
      expect(
        uploadButton,
        findsOneWidget,
      );
    },
  );

  // ==========================================================
  // TEST 4
  // التأكد أن خانة السؤال موجودة
  // ==========================================================

  testWidgets(
    'Question TextField exists',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // البحث عن TextField
      final questionField = find.byType(TextField);

      // التطبيق يحتوي على TextField واحد
      expect(
        questionField,
        findsOneWidget,
      );
    },
  );

  // ==========================================================
  // TEST 5
  // التأكد أن خانة السؤال معطلة قبل رفع PDF
  // ==========================================================

  testWidgets(
    'Question field is disabled before PDF upload',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // العثور على TextField
      final questionField = find.byType(TextField);

      // الحصول على Widget الخاص بالـ TextField
      final textField = tester.widget<TextField>(
        questionField,
      );

      // في main.dart لدينا:
      //
      // enabled: pdfUploaded && !isLoading
      //
      // في بداية التطبيق:
      //
      // pdfUploaded = false
      //
      // لذلك يجب أن يكون TextField معطلًا.

      expect(
        textField.enabled,
        false,
      );
    },
  );

  // ==========================================================
  // TEST 6
  // التأكد أن زر Ask معطل قبل رفع PDF
  // ==========================================================

  testWidgets(
    'Ask button is disabled before PDF upload',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // البحث عن FilledButton الذي يحتوي على النص Ask
      final askButton = find.widgetWithText(
        FilledButton,
        'Ask',
      );

      // يجب أن يكون زر Ask موجودًا
      expect(
        askButton,
        findsOneWidget,
      );

      // الحصول على FilledButton نفسه
      final button = tester.widget<FilledButton>(
        askButton,
      );

      // في main.dart لدينا:
      //
      // onPressed:
      //     !pdfUploaded || isLoading
      //         ? null
      //         : askQuestion
      //
      // في البداية:
      //
      // pdfUploaded = false
      //
      // لذلك onPressed يجب أن يكون null
      // وهذا يعني أن الزر معطل.

      expect(
        button.onPressed,
        isNull,
      );
    },
  );

  // ==========================================================
  // TEST 7
  // التأكد أن TextField يحتوي على Controller
  // ==========================================================
  //
  // ملاحظة:
  // لا نستطيع اختبار إدخال النص فعليًا هنا لأن TextField
  // يكون Disabled قبل رفع PDF.
  //
  // لذلك نختبر أن TextField مرتبط بالـ Controller
  // الموجود في التطبيق.

  testWidgets(
    'Question TextField has a controller',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // العثور على TextField
      final questionField = find.byType(TextField);

      // الحصول على TextField
      final textField = tester.widget<TextField>(
        questionField,
      );

      // يجب أن يكون TextField مرتبطًا بـ Controller
      expect(
        textField.controller,
        isNotNull,
      );
    },
  );

  // ==========================================================
  // TEST 8
  // التأكد أن النص الافتراضي يظهر قبل رفع PDF
  // ==========================================================

  testWidgets(
    'Question field shows upload PDF hint',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // قبل رفع PDF:
      //
      // hintText:
      //     pdfUploaded
      //         ? 'Ask a question about your PDF...'
      //         : 'Upload a PDF first'
      //
      // لذلك يجب أن يظهر:
      // Upload a PDF first

      expect(
        find.text('Upload a PDF first'),
        findsOneWidget,
      );
    },
  );

  // ==========================================================
  // TEST 9
  // التأكد أن زر Choose PDF يعمل من ناحية وجود onPressed
  // ==========================================================

  testWidgets(
    'Choose PDF button is enabled initially',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // العثور على OutlinedButton الذي يحتوي على Choose PDF
      final choosePdfButton = find.widgetWithText(
        OutlinedButton,
        'Choose PDF',
      );

      // يجب أن يكون موجودًا
      expect(
        choosePdfButton,
        findsOneWidget,
      );

      // الحصول على الزر
      final button = tester.widget<OutlinedButton>(
        choosePdfButton,
      );

      // في البداية isUploading = false
      //
      // لذلك:
      //
      // onPressed: isUploading ? null : pickPdf
      //
      // يجب أن يكون onPressed موجودًا.

      expect(
        button.onPressed,
        isNotNull,
      );
    },
  );

  // ==========================================================
  // TEST 10
  // التأكد أن Upload PDF معطل في البداية
  // ==========================================================

  testWidgets(
    'Upload PDF button is disabled before selecting a PDF',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // البحث عن زر Upload PDF
      final uploadButton = find.widgetWithText(
        FilledButton,
        'Upload PDF',
      );

      // يجب أن يكون موجودًا
      expect(
        uploadButton,
        findsOneWidget,
      );

      // الحصول على الزر
      final button = tester.widget<FilledButton>(
        uploadButton,
      );

      // في البداية:
      //
      // selectedPdf = null
      //
      // والكود:
      //
      // onPressed:
      //     selectedPdf == null || isUploading
      //         ? null
      //         : uploadPdf
      //
      // لذلك يجب أن يكون الزر معطلًا.

      expect(
        button.onPressed,
        isNull,
      );
    },
  );

  // ==========================================================
  // TEST 11
  // التأكد أن التطبيق لا يعرض رسالة خطأ عند البداية
  // ==========================================================

  testWidgets(
    'No error message is shown initially',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // في البداية:
      //
      // errorMessage = null
      //
      // لذلك لا توجد رسالة خطأ.

      expect(
        find.text(
          'Please choose a PDF first.',
        ),
        findsNothing,
      );

      expect(
        find.text(
          'Please upload a PDF first.',
        ),
        findsNothing,
      );
    },
  );

  // ==========================================================
  // TEST 12
  // التأكد أن Answer غير موجودة عند بداية التطبيق
  // ==========================================================

  testWidgets(
    'Answer section is not shown initially',
    (tester) async {
      // تشغيل التطبيق
      await tester.pumpWidget(
        const RagPdfApp(),
      );

      // في البداية:
      //
      // answer = ''
      //
      // والكود:
      //
      // if (answer.isNotEmpty)
      //
      // لذلك قسم Answer لا يجب أن يظهر.

      expect(
        find.text('Answer'),
        findsNothing,
      );
    },
  );
}



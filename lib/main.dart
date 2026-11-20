import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const RagPdfApp());
}

class RagPdfApp extends StatefulWidget {
  const RagPdfApp({super.key});

  @override
  State<RagPdfApp> createState() => _RagPdfAppState();
}

class _RagPdfAppState extends State<RagPdfApp> {
  // اللغة الافتراضية: العربية
  Locale _locale = const Locale('ar');

  void _toggleLanguage() {
    setState(() {
      _locale = _locale.languageCode == 'ar'
          ? const Locale('en')
          : const Locale('ar');
    });
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _locale.languageCode == 'ar';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: isArabic ? 'مساعد المستندات الذكي' : 'PDF RAG Assistant',
      locale: _locale,
      supportedLocales: const [
        Locale('ar'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        fontFamily: isArabic ? null : null,
      ),
      home: ChatPage(
        onToggleLanguage: _toggleLanguage,
        currentLocale: _locale,
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final VoidCallback onToggleLanguage;
  final Locale currentLocale;

  const ChatPage({
    super.key,
    required this.onToggleLanguage,
    required this.currentLocale,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // =========================================================
  // Backend
  // =========================================================

  Process? _backendProcess;

  // يصبح true عندما نتأكد أن FastAPI يعمل.
  bool backendReady = false;

  // =========================================================
  // Controller
  // =========================================================

  final TextEditingController _questionController = TextEditingController();

  // =========================================================
  // API URL (قابل للتعديل ليناسب الهواتف والسيرفرات السحابية)
  // =========================================================

  String baseUrl = 'http://127.0.0.1:8000';

  // =========================================================
  // PDF
  // =========================================================

  File? selectedPdf;
  String? selectedFileName;

  bool isUploading = false;
  bool pdfUploaded = false;

  // =========================================================
  // Answer
  // =========================================================

  String answer = '';
  double similarity = 0.0;
  bool validated = false;
  bool isLoading = false;

  String? errorMessage;

  bool get isArabic => widget.currentLocale.languageCode == 'ar';

  // =========================================================
  // تشغيل Backend
  // =========================================================

  Future<void> startBackend() async {
    if (!Platform.isWindows) {
      debugPrint(
        'Backend auto-start is currently enabled for Windows only. '
        'On Android, connect to your server IP or cloud URL via Settings.',
      );
      // على أندرويد ننتظر الاتصال المباشر بالسيرفر
      await waitForBackend();
      return;
    }

    try {
      debugPrint('Starting FastAPI backend...');

      // مسار مشروع Flutter
      final projectDirectory = Directory.current.path;

      final backendDirectory = Directory(
        '$projectDirectory'
        '${Platform.pathSeparator}bac'
        '${Platform.pathSeparator}rag-prototype',
      );

      final pythonExecutable =
          '${backendDirectory.path}'
          '${Platform.pathSeparator}.venv'
          '${Platform.pathSeparator}Scripts'
          '${Platform.pathSeparator}python.exe';

      if (!await backendDirectory.exists()) {
        throw Exception(
          isArabic
              ? 'مجلد الخادم غير موجود:\n${backendDirectory.path}'
              : 'Backend folder was not found:\n${backendDirectory.path}',
        );
      }

      if (!await File(pythonExecutable).exists()) {
        throw Exception(
          isArabic
              ? 'ملف بايثون الخاص بالخادم غير موجود:\n$pythonExecutable'
              : 'Backend Python was not found:\n$pythonExecutable',
        );
      }

      debugPrint('Backend directory: ${backendDirectory.path}');
      debugPrint('Python executable: $pythonExecutable');

      _backendProcess = await Process.start(
        pythonExecutable,
        [
          '-m',
          'uvicorn',
          'api:app',
          '--host',
          '127.0.0.1',
          '--port',
          '8000',
        ],
        workingDirectory: backendDirectory.path,
        runInShell: false,
      );

      debugPrint('FastAPI process started.');

      _backendProcess!.stdout.transform(utf8.decoder).listen((data) {
        debugPrint('BACKEND: $data');
      });

      _backendProcess!.stderr.transform(utf8.decoder).listen((data) {
        debugPrint('BACKEND ERROR: $data');
      });

      _backendProcess!.exitCode.then((code) {
        debugPrint('FastAPI process exited with code: $code');

        if (!mounted) return;

        setState(() {
          backendReady = false;
        });

        if (code != 0) {
          setState(() {
            errorMessage = isArabic
                ? 'توقف خادم الذكاء الاصطناعي بشكل غير متوقع.\nرمز الخروج: $code'
                : 'RAG server stopped unexpectedly.\nExit code: $code';
          });
        }
      });

      debugPrint('Waiting for FastAPI to become ready...');
      await waitForBackend();
    } catch (e) {
      debugPrint('Failed to start FastAPI backend: $e');

      if (mounted) {
        setState(() {
          backendReady = false;
          errorMessage = isArabic
              ? 'تعذر تشغيل خادم الذكاء الاصطناعي.\n$e'
              : 'Could not start the RAG server.\n$e';
        });
      }
    }
  }

  // =========================================================
  // انتظار FastAPI
  // =========================================================

  Future<void> waitForBackend() async {
    const int maxAttempts = 60;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        debugPrint('Checking backend... $attempt/$maxAttempts');

        final response = await http
            .get(Uri.parse('$baseUrl/status'))
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          debugPrint('FastAPI is READY!');

          if (mounted) {
            setState(() {
              backendReady = true;
              errorMessage = null;
            });
          }
          return;
        }
      } catch (e) {
        debugPrint('Backend not ready yet...');
      }

      await Future.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      setState(() {
        backendReady = false;
        errorMessage = isArabic
            ? 'لم يستجب خادم الذكاء الاصطناعي في الوقت المحدد.\nتأكد من عنوان السيرفر والاتصال.'
            : 'RAG server did not become ready.\nPlease check the backend URL and connection.';
      });
    }
  }

  // =========================================================
  // اختيار PDF
  // =========================================================

  Future<void> pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final path = result.files.single.path;

      if (path == null) {
        setState(() {
          errorMessage = isArabic
              ? 'تعذر الوصول إلى الملف المحدد.'
              : 'Could not access the selected file.';
        });
        return;
      }

      setState(() {
        selectedPdf = File(path);
        selectedFileName = result.files.single.name;
        pdfUploaded = false;
        answer = '';
        similarity = 0.0;
        validated = false;
        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        errorMessage = isArabic
            ? 'تعذر اختيار ملف PDF.\n$e'
            : 'Could not select the PDF.\n$e';
      });
    }
  }

  // =========================================================
  // رفع PDF
  // =========================================================

  Future<void> uploadPdf() async {
    if (!backendReady) {
      setState(() {
        errorMessage = isArabic
            ? 'خادم الذكاء الاصطناعي غير جاهز بعد. يرجى الانتظار.'
            : 'RAG server is not ready yet. Please wait.';
      });
      return;
    }

    if (selectedPdf == null) {
      setState(() {
        errorMessage = isArabic
            ? 'يرجى اختيار ملف PDF أولاً.'
            : 'Please choose a PDF first.';
      });
      return;
    }

    setState(() {
      isUploading = true;
      errorMessage = null;
      pdfUploaded = false;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload'),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          selectedPdf!.path,
          filename: selectedFileName,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          pdfUploaded = true;
          errorMessage = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isArabic
                    ? 'تم رفع وتحليل المستند بنجاح! (${data['chunks'] ?? ''} مقطع دلالي)'
                    : 'PDF uploaded successfully. ${data['chunks'] ?? ''} chunks created.',
              ),
            ),
          );
        }
      } else {
        String message;
        try {
          final data = jsonDecode(response.body);
          message = data['detail'] ??
              (isArabic ? 'فشل رفع الملف.' : 'Upload failed.');
        } catch (_) {
          message = isArabic
              ? 'فشل رفع الملف: رمز ${response.statusCode}'
              : 'Upload failed: ${response.statusCode}';
        }

        setState(() {
          errorMessage = message;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = isArabic
            ? 'تعذر الاتصال بخادم الذكاء الاصطناعي.\n$e'
            : 'Could not connect to the RAG server.\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isUploading = false;
        });
      }
    }
  }

  // =========================================================
  // طرح السؤال
  // =========================================================

  Future<void> askQuestion() async {
    final question = _questionController.text.trim();

    if (question.isEmpty) {
      setState(() {
        errorMessage = isArabic
            ? 'يرجى كتابة سؤال أولاً.'
            : 'Please enter a question.';
      });
      return;
    }

    if (!backendReady) {
      setState(() {
        errorMessage = isArabic
            ? 'خادم الذكاء الاصطناعي غير جاهز بعد.'
            : 'RAG server is not ready yet.';
      });
      return;
    }

    if (!pdfUploaded) {
      setState(() {
        errorMessage = isArabic
            ? 'يرجى رفع وتحليل ملف PDF أولاً.'
            : 'Please upload a PDF first.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      answer = '';
      similarity = 0.0;
      validated = false;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ask'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'question': question,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          answer = data['answer'] ?? '';
          similarity = (data['similarity'] ?? 0.0).toDouble();
          validated = data['validated'] ?? false;
        });
      } else {
        setState(() {
          errorMessage = isArabic
              ? 'خطأ من الخادم: ${response.statusCode}\n${response.body}'
              : 'Server error: ${response.statusCode}\n${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = isArabic
            ? 'تعذر الاتصال بخادم الذكاء الاصطناعي.\n$e'
            : 'Could not connect to the RAG server.\n$e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // نافذة تعديل عنوان السيرفر (مفيدة للأندرويد وتجربة الشبكة)
  // =========================================================

  void _showServerSettingsDialog() {
    final controller = TextEditingController(text: baseUrl);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isArabic ? 'إعدادات الخادم' : 'Server Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isArabic
                    ? 'أدخل عنوان الـ API (يفيد عند تشغيل التطبيق على الهاتف وربطه بالكمبيوتر عبر الـ Wi-Fi أو السحابة):'
                    : 'Enter the API URL (useful when running on a mobile device or cloud):',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'API Base URL',
                  hintText: 'http://192.168.1.50:8000',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  baseUrl = controller.text.trim();
                  backendReady = false;
                });
                Navigator.pop(context);
                waitForBackend();
              },
              child: Text(isArabic ? 'حفظ وإعادة الاتصال' : 'Save & Reconnect'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // تشغيل التطبيق
  // =========================================================

  @override
  void initState() {
    super.initState();
    startBackend();
  }

  // =========================================================
  // Dispose
  // =========================================================

  @override
  void dispose() {
    _backendProcess?.kill();
    _questionController.dispose();
    super.dispose();
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'مساعد المستندات الذكي' : 'PDF RAG Assistant'),
        centerTitle: true,
        actions: [
          // زر إعدادات الخادم (مفيد لنشره واختباره على هواتف أندرويد)
          IconButton(
            tooltip: isArabic ? 'إعدادات الخادم' : 'Server Settings',
            icon: const Icon(Icons.dns_outlined),
            onPressed: _showServerSettingsDialog,
          ),
          // زر تبديل اللغة
          TextButton.icon(
            onPressed: widget.onToggleLanguage,
            icon: const Icon(Icons.language, size: 20),
            label: Text(
              isArabic ? 'English' : 'عربي',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // العنوان والوصف
              Text(
                isArabic ? 'مساعد المستندات الذكي' : 'PDF RAG Assistant',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic
                    ? 'ارفع ملف PDF واطرح أي سؤال حول محتواه بدقة وموثوقية.'
                    : 'Upload a PDF and ask questions about it.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 20),

              // حالة السيرفر
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        backendReady
                            ? Icons.check_circle
                            : Icons.hourglass_top,
                        color: backendReady ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          backendReady
                              ? (isArabic
                                  ? 'خادم الذكاء الاصطناعي متصل وجاهز'
                                  : 'RAG server is ready')
                              : (isArabic
                                  ? 'في انتظار جاهزية خادم الذكاء الاصطناعي...'
                                  : 'Starting RAG server...'),
                        ),
                      ),
                      if (!backendReady)
                        IconButton(
                          tooltip: isArabic ? 'إعادة المحاولة' : 'Retry',
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: waitForBackend,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // اختيار PDF
              OutlinedButton.icon(
                onPressed: isUploading ? null : pickPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(
                  selectedFileName == null
                      ? (isArabic ? 'اختر ملف PDF' : 'Choose PDF')
                      : selectedFileName!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),

              // زر الرفع
              FilledButton.icon(
                onPressed: selectedPdf == null || isUploading || !backendReady
                    ? null
                    : uploadPdf,
                icon: isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(
                  isUploading
                      ? (isArabic ? 'جارٍ الرفع والتحليل...' : 'Uploading...')
                      : !backendReady
                          ? (isArabic
                              ? 'في انتظار الخادم...'
                              : 'Waiting for server...')
                          : (isArabic
                              ? 'رفع وتحليل المستند'
                              : 'Upload PDF'),
                ),
              ),
              const SizedBox(height: 12),

              // بطاقة حالة المستند
              if (selectedFileName != null)
                Card(
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          pdfUploaded
                              ? Icons.check_circle
                              : Icons.picture_as_pdf,
                          color: pdfUploaded ? Colors.green : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pdfUploaded
                                ? (isArabic
                                    ? 'المستند جاهز للاستعلام: $selectedFileName'
                                    : 'PDF ready: $selectedFileName')
                                : (isArabic
                                    ? 'تم اختيار الملف: $selectedFileName'
                                    : 'Selected: $selectedFileName'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),

              // حقل إدخال السؤال
              TextField(
                controller: _questionController,
                maxLines: 3,
                enabled: pdfUploaded && !isLoading && backendReady,
                decoration: InputDecoration(
                  hintText: !backendReady
                      ? (isArabic
                          ? 'في انتظار جاهزية الخادم...'
                          : 'Waiting for RAG server...')
                      : pdfUploaded
                          ? (isArabic
                              ? 'اكتب سؤالك حول محتوى ملف الـ PDF هنا...'
                              : 'Ask a question about your PDF...')
                          : (isArabic
                              ? 'يرجى رفع ملف PDF أولاً لتتمكن من السؤال'
                              : 'Upload a PDF first'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // زر السؤال
              FilledButton(
                onPressed: !pdfUploaded || isLoading || !backendReady
                    ? null
                    : askQuestion,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(isArabic ? 'إرسال السؤال' : 'Ask'),
              ),
              const SizedBox(height: 16),

              // رسائل الخطأ
              if (errorMessage != null)
                Card(
                  color: Colors.red.shade50,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline,
                            color: Colors.red.shade700, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // بطاقة عرض الإجابة
              if (answer.isNotEmpty)
                Expanded(
                  child: SingleChildScrollView(
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isArabic ? 'الإجابة' : 'Answer',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: validated
                                        ? Colors.green.shade100
                                        : Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    validated
                                        ? (isArabic
                                            ? 'تم التحقق دلالياً'
                                            : 'Validated')
                                        : (isArabic
                                            ? 'قيد التحقق'
                                            : 'Unverified'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: validated
                                          ? Colors.green.shade900
                                          : Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            SelectableText(
                              answer,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.analytics_outlined,
                                      size: 16),
                                  label: Text(
                                    isArabic
                                        ? 'نسبة التطابق: ${(similarity * 100).toStringAsFixed(1)}%'
                                        : 'Similarity: ${(similarity * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Chip(
                                  avatar: Icon(
                                    validated
                                        ? Icons.verified
                                        : Icons.help_outline,
                                    size: 16,
                                    color: validated
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  label: Text(
                                    isArabic
                                        ? 'المصداقية: ${validated ? "موثوق" : "غير مؤكد"}'
                                        : 'Reliability: ${validated ? "High" : "Low"}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const RagPdfApp());
}

class RagPdfApp extends StatelessWidget {
  const RagPdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PDF RAG Assistant',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

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

  final TextEditingController _questionController =
      TextEditingController();

  // =========================================================
  // API
  // =========================================================

  static const String baseUrl = 'http://127.0.0.1:8000';

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

  // =========================================================
  // تشغيل Backend
  // =========================================================

  Future<void> startBackend() async {
    if (!Platform.isWindows) {
      debugPrint(
        'Backend auto-start is currently enabled for Windows only.',
      );
      return;
    }

    try {
      debugPrint('Starting FastAPI backend...');

      // =======================================================
      // مسار مشروع Flutter
      // =======================================================

      final projectDirectory = Directory.current.path;

      // =======================================================
      // Backend موجود هنا:
      //
      // rag_pdf_app/
      //     bac/
      //         rag-prototype/
      //
      // =======================================================

      final backendDirectory = Directory(
        '$projectDirectory'
        '${Platform.pathSeparator}bac'
        '${Platform.pathSeparator}rag-prototype',
      );

      // =======================================================
      // Python الموجود داخل:
      //
      // bac/rag-prototype/.venv/Scripts/python.exe
      // =======================================================

      final pythonExecutable =
          '${backendDirectory.path}'
          '${Platform.pathSeparator}.venv'
          '${Platform.pathSeparator}Scripts'
          '${Platform.pathSeparator}python.exe';

      // =======================================================
      // التأكد من وجود Backend
      // =======================================================

      if (!await backendDirectory.exists()) {
        throw Exception(
          'Backend folder was not found:\n'
          '${backendDirectory.path}',
        );
      }

      // =======================================================
      // التأكد من وجود Python
      // =======================================================

      if (!await File(pythonExecutable).exists()) {
        throw Exception(
          'Backend Python was not found:\n'
          '$pythonExecutable',
        );
      }

      debugPrint(
        'Backend directory: ${backendDirectory.path}',
      );

      debugPrint(
        'Python executable: $pythonExecutable',
      );

      // =======================================================
      // تشغيل FastAPI
      // =======================================================

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

      debugPrint(
        'FastAPI process started.',
      );

      // =======================================================
      // قراءة مخرجات Backend
      // =======================================================

      _backendProcess!.stdout
          .transform(utf8.decoder)
          .listen((data) {
        debugPrint(
          'BACKEND: $data',
        );
      });

      // =======================================================
      // قراءة أخطاء Backend
      // =======================================================

      _backendProcess!.stderr
          .transform(utf8.decoder)
          .listen((data) {
        debugPrint(
          'BACKEND ERROR: $data',
        );
      });

      // =======================================================
      // مراقبة إغلاق Backend
      // =======================================================

      _backendProcess!.exitCode.then((code) {
        debugPrint(
          'FastAPI process exited with code: $code',
        );

        if (!mounted) {
          return;
        }

        setState(() {
          backendReady = false;
        });

        if (code != 0) {
          setState(() {
            errorMessage =
                'RAG server stopped unexpectedly.\n'
                'Exit code: $code';
          });
        }
      });

      // =======================================================
      // انتظار جاهزية Backend
      // =======================================================

      debugPrint(
        'Waiting for FastAPI to become ready...',
      );

      await waitForBackend();
    } catch (e) {
      debugPrint(
        'Failed to start FastAPI backend: $e',
      );

      if (mounted) {
        setState(() {
          backendReady = false;

          errorMessage =
              'Could not start the RAG server.\n$e';
        });
      }
    }
  }

  // =========================================================
  // انتظار FastAPI
  // =========================================================

  Future<void> waitForBackend() async {
    const int maxAttempts = 60;

    for (int attempt = 1;
        attempt <= maxAttempts;
        attempt++) {
      try {
        debugPrint(
          'Checking backend... '
          '$attempt/$maxAttempts',
        );

        final response = await http
            .get(
              Uri.parse('$baseUrl/status'),
            )
            .timeout(
              const Duration(seconds: 2),
            );

        if (response.statusCode == 200) {
          debugPrint(
            'FastAPI is READY!',
          );

          if (mounted) {
            setState(() {
              backendReady = true;
              errorMessage = null;
            });
          }

          return;
        }
      } catch (e) {
        debugPrint(
          'Backend not ready yet...',
        );
      }

      await Future.delayed(
        const Duration(seconds: 1),
      );
    }

    if (mounted) {
      setState(() {
        backendReady = false;

        errorMessage =
            'RAG server did not become ready.\n'
            'Please check the backend output in the terminal.';
      });
    }
  }

  // =========================================================
  // اختيار PDF
  // =========================================================

  Future<void> pickPdf() async {
    try {
      final result =
          await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null ||
          result.files.isEmpty) {
        return;
      }

      final path =
          result.files.single.path;

      if (path == null) {
        setState(() {
          errorMessage =
              'Could not access the selected file.';
        });

        return;
      }

      setState(() {
        selectedPdf = File(path);

        selectedFileName =
            result.files.single.name;

        pdfUploaded = false;

        answer = '';
        similarity = 0.0;
        validated = false;

        errorMessage = null;
      });
    } catch (e) {
      setState(() {
        errorMessage =
            'Could not select the PDF.\n$e';
      });
    }
  }

  // =========================================================
  // رفع PDF
  // =========================================================

  Future<void> uploadPdf() async {
    if (!backendReady) {
      setState(() {
        errorMessage =
            'RAG server is not ready yet. Please wait.';
      });

      return;
    }

    if (selectedPdf == null) {
      setState(() {
        errorMessage =
            'Please choose a PDF first.';
      });

      return;
    }

    setState(() {
      isUploading = true;
      errorMessage = null;
      pdfUploaded = false;
    });

    try {
      final request =
          http.MultipartRequest(
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

      final streamedResponse =
          await request.send();

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body);

        setState(() {
          pdfUploaded = true;
          errorMessage = null;
        });

        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'PDF uploaded successfully. '
              '${data['chunks'] ?? ''} chunks created.',
            ),
          ),
        );
      } else {
        String message;

        try {
          final data =
              jsonDecode(response.body);

          message =
              data['detail'] ??
                  'Upload failed.';
        } catch (_) {
          message =
              'Upload failed: '
              '${response.statusCode}';
        }

        setState(() {
          errorMessage = message;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage =
            'Could not connect to the RAG server.\n$e';
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
    final question =
        _questionController.text.trim();

    if (question.isEmpty) {
      setState(() {
        errorMessage =
            'Please enter a question.';
      });

      return;
    }

    if (!backendReady) {
      setState(() {
        errorMessage =
            'RAG server is not ready yet.';
      });

      return;
    }

    if (!pdfUploaded) {
      setState(() {
        errorMessage =
            'Please upload a PDF first.';
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
      final response =
          await http.post(
        Uri.parse('$baseUrl/ask'),
        headers: {
          'Content-Type':
              'application/json',
          'Accept':
              'application/json',
        },
        body: jsonEncode({
          'question': question,
        }),
      );

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body);

        setState(() {
          answer =
              data['answer'] ?? '';

          similarity =
              (data['similarity'] ??
                      0.0)
                  .toDouble();

          validated =
              data['validated'] ??
                  false;
        });
      } else {
        setState(() {
          errorMessage =
              'Server error: '
              '${response.statusCode}\n'
              '${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage =
            'Could not connect to the RAG server.\n$e';
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
  // تشغيل التطبيق
  // =========================================================

  @override
  void initState() {
    super.initState();

    // تشغيل FastAPI تلقائيًا عند فتح التطبيق.
    startBackend();
  }

  // =========================================================
  // Dispose
  // =========================================================

  @override
  void dispose() {
    // إيقاف FastAPI عند إغلاق التطبيق.
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
        title:
            const Text('PDF RAG Assistant'),
        centerTitle: true,
      ),

      body: Padding(
        padding:
            const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,

          children: [
            // =================================================
            // العنوان
            // =================================================

            const Text(
              'PDF RAG Assistant',
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Upload a PDF and ask questions about it.',
            ),

            const SizedBox(height: 20),

            // =================================================
            // حالة Backend
            // =================================================

            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(12),

                child: Row(
                  children: [
                    Icon(
                      backendReady
                          ? Icons.check_circle
                          : Icons.hourglass_top,
                      color:
                          backendReady
                              ? Colors.green
                              : Colors.orange,
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: Text(
                        backendReady
                            ? 'RAG server is ready'
                            : 'Starting RAG server...',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // اختيار PDF
            // =================================================

            OutlinedButton.icon(
              onPressed:
                  isUploading
                      ? null
                      : pickPdf,

              icon: const Icon(
                Icons.picture_as_pdf,
              ),

              label: Text(
                selectedFileName == null
                    ? 'Choose PDF'
                    : selectedFileName!,
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // Upload
            // =================================================

            FilledButton.icon(
              onPressed:
                  selectedPdf == null ||
                          isUploading ||
                          !backendReady
                      ? null
                      : uploadPdf,

              icon: isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.cloud_upload,
                    ),

              label: Text(
                isUploading
                    ? 'Uploading...'
                    : !backendReady
                        ? 'Waiting for server...'
                        : 'Upload PDF',
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // حالة PDF
            // =================================================

            if (selectedFileName != null)
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(12),

                  child: Row(
                    children: [
                      Icon(
                        pdfUploaded
                            ? Icons.check_circle
                            : Icons.picture_as_pdf,
                        color:
                            pdfUploaded
                                ? Colors.green
                                : null,
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: Text(
                          pdfUploaded
                              ? 'PDF ready: '
                                  '$selectedFileName'
                              : 'Selected: '
                                  '$selectedFileName',
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // =================================================
            // Question
            // =================================================

            TextField(
              controller:
                  _questionController,

              maxLines: 3,

              enabled:
                  pdfUploaded &&
                      !isLoading &&
                      backendReady,

              decoration:
                  InputDecoration(
                hintText:
                    !backendReady
                        ? 'Waiting for RAG server...'
                        : pdfUploaded
                            ? 'Ask a question about your PDF...'
                            : 'Upload a PDF first',

                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // =================================================
            // Ask
            // =================================================

            FilledButton(
              onPressed:
                  !pdfUploaded ||
                          isLoading ||
                          !backendReady
                      ? null
                      : askQuestion,

              child:
                  isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Ask',
                        ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // Error
            // =================================================

            if (errorMessage != null)
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.all(16),

                  child: Text(
                    errorMessage!,
                    style:
                        const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
              ),

            // =================================================
            // Answer
            // =================================================

            if (answer.isNotEmpty)
              Expanded(
                child:
                    SingleChildScrollView(
                  child: Card(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(20),

                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [
                          const Text(
                            'Answer',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          Text(
                            answer,
                            style:
                                const TextStyle(
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          Text(
                            'Similarity: '
                            '${similarity.toStringAsFixed(4)}',
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          Text(
                            'Validated: '
                            '${validated ? "Yes" : "No"}',
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
    );
  }
}
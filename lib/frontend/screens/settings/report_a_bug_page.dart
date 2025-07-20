// lib/frontend/screens/settings/report_a_bug_page.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Add this import for Firebase Storage

class ReportABugPage extends StatefulWidget {
  const ReportABugPage({Key? key}) : super(key: key);

  @override
  State<ReportABugPage> createState() => _ReportABugPageState();
}

class _ReportABugPageState extends State<ReportABugPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final List<XFile> _screenshots = [];

  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _pickScreenshot() async {
    if (_screenshots.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can attach up to 5 screenshots only.')),
      );
      return;
    }
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _screenshots.add(picked);
        });
      }
    } catch (e) {
      // silently ignore or show error
    }
  }

  void _removeScreenshot(int index) {
    setState(() {
      _screenshots.removeAt(index);
    });
  }

  Future<List<String>> _uploadScreenshots(String userId, String docId) async {
    List<String> urls = [];
    for (var i = 0; i < _screenshots.length; i++) {
      final file = _screenshots[i];
      final ref = FirebaseStorage.instance
          .ref()
          .child('bug_reports')
          .child(userId)
          .child(docId)
          .child('screenshot_$i${file.name.contains('.') ? '' : '.png'}');
      final uploadTask = ref.putFile(File(file.path));
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      urls.add(downloadUrl);
    }
    return urls;
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      // Sanitize title to use as doc ID:
      String docId = _titleController.text.trim().replaceAll('/', '-').replaceAll(RegExp(r'\s+'), '_');
      if (docId.isEmpty) docId = DateTime.now().millisecondsSinceEpoch.toString();

      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      // Upload screenshots and get URLs (only now, on submit)
      List<String> screenshotUrls = [];
      if (_screenshots.isNotEmpty) {
        screenshotUrls = await _uploadScreenshots(userId, docId);
      }

      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'stepsToReproduce': _stepsController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'userId': userId,
        'screenshots': screenshotUrls,
      };

      await FirebaseFirestore.instance.collection('bug_reports').doc(docId).set(data);

      setState(() => _submitting = false);

      if (!mounted) return;

      // Show thank you popup
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Thank you!'),
          content: const Text(
              'Once we can reproduce this bug your account will be awarded with Elytic coins.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit bug report: $e')),
      );
    }
  }

  String? _validateWordCount(String? value, int maxWords, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    final wordCount = value.trim().split(RegExp(r'\s+')).length;
    if (wordCount > maxWords) {
      return '$fieldName must be at most $maxWords words. Currently $wordCount.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Bug'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  maxLines: 1,
                  maxLength: 100, // approx 30 words limit
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Summarize the bug in 30 words',
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) => _validateWordCount(val, 30, 'Title'),
                ),
                const SizedBox(height: 20),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: 400, // approx 120 words
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the bug (up to 120 words)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (val) => _validateWordCount(val, 120, 'Description'),
                ),
                const SizedBox(height: 20),

                // Steps to reproduce
                TextFormField(
                  controller: _stepsController,
                  maxLines: 8,
                  maxLength: 2000, // approx 500 words
                  decoration: const InputDecoration(
                    labelText: 'Steps to Reproduce',
                    hintText: 'Detail steps to reproduce the bug (up to 500 words)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  validator: (val) => _validateWordCount(val, 500, 'Steps to Reproduce'),
                ),
                const SizedBox(height: 20),

                // Screenshots header + add button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Screenshots (max 5)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    ElevatedButton.icon(
                      onPressed: _pickScreenshot,
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Screenshots preview
                if (_screenshots.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _screenshots.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final file = _screenshots[index];
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(file.path),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: -8,
                              right: -8,
                              child: GestureDetector(
                                onTap: () => _removeScreenshot(index),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  )
                else
                  const Text('No screenshots attached.'),
                const SizedBox(height: 30),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submitReport,
                    child: _submitting
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Submit Bug Report'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

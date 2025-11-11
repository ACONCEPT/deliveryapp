import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

/// Enhanced Image Field with Upload Support
///
/// Supports two methods:
/// 1. Enter image URL directly
/// 2. Upload image file from device
class ImageUploadField extends StatefulWidget {
  final TextEditingController controller;
  final String token; // JWT token for authentication

  const ImageUploadField({
    super.key,
    required this.controller,
    required this.token,
  });

  @override
  State<ImageUploadField> createState() => _ImageUploadFieldState();
}

class _ImageUploadFieldState extends State<ImageUploadField> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadError;
  File? _selectedImageFile;

  Future<void> _pickAndUploadImage() async {
    try {
      // Pick image from gallery
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) {
        return; // User cancelled
      }

      setState(() {
        _isUploading = true;
        _uploadProgress = 0.0;
        _uploadError = null;
      });

      // Upload to server
      await _uploadImageToServer(image);
    } catch (e) {
      setState(() {
        _uploadError = e.toString();
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadImageToServer(XFile image) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/vendor/upload-image');

      var request = http.MultipartRequest('POST', url);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer ${widget.token}';

      // Add image file
      if (kIsWeb) {
        // Web platform - use bytes
        final bytes = await image.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: image.name,
        ));
      } else {
        // Mobile platform - use file path
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          image.path,
          filename: image.name,
        ));
      }

      // Send request
      final streamedResponse = await request.send();

      // Track progress (simplified - in production use StreamedResponse.stream)
      setState(() {
        _uploadProgress = 1.0;
      });

      // Get response
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final imageUrl = responseData['data']['url'];

        // Update controller with uploaded image URL
        widget.controller.text = imageUrl;

        setState(() {
          _isUploading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Upload failed');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = e.toString();
      });
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.image, color: Colors.blue),
                SizedBox(width: 12),
                Text(
                  'Product Image',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // URL Input Field
            TextFormField(
              controller: widget.controller,
              decoration: const InputDecoration(
                labelText: 'Image URL (Optional)',
                hintText: 'https://example.com/image.jpg',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
                helperText: 'Enter a URL or upload an image below',
              ),
              keyboardType: TextInputType.url,
              onChanged: (_) {
                setState(() {}); // Refresh preview
              },
            ),
            const SizedBox(height: 16),

            // Upload Button
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadImage,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: Text(_isUploading ? 'Uploading...' : 'Upload Image'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                if (widget.controller.text.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        widget.controller.clear();
                      });
                    },
                    icon: const Icon(Icons.clear, color: Colors.red),
                    tooltip: 'Clear Image',
                  ),
                ],
              ],
            ),

            // Upload Progress
            if (_isUploading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 4),
              Text(
                '${(_uploadProgress * 100).toInt()}% uploaded',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],

            // Upload Error
            if (_uploadError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _uploadError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Image Preview
            if (widget.controller.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Preview:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.controller.text,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Unable to load image',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Helper Text
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Max file size: 5MB. Supported formats: JPG, PNG, WebP, GIF',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

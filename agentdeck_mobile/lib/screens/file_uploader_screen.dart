import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/directory_browser_modal.dart';

class FileUploaderScreen extends StatefulWidget {
  final String? initialDestination;

  const FileUploaderScreen({super.key, this.initialDestination});

  @override
  State<FileUploaderScreen> createState() => _FileUploaderScreenState();
}

class _FileUploaderScreenState extends State<FileUploaderScreen> {
  final ApiService _api = ApiService();
  late String _destinationPath;
  List<PlatformFile> _selectedFiles = [];
  bool _uploading = false;
  String _uploadStatus = '';
  final List<String> _uploadedFiles = [];

  @override
  void initState() {
    super.initState();
    _destinationPath = widget.initialDestination ?? '';
    _loadDefaultDestination();
    WorkstationManager().addListener(_onWorkstationChanged);
  }

  void _onWorkstationChanged() {
    if (mounted) {
      _loadDefaultDestination();
    }
  }

  @override
  void dispose() {
    WorkstationManager().removeListener(_onWorkstationChanged);
    super.dispose();
  }

  Future<void> _loadDefaultDestination() async {
    final activeWs = WorkstationManager().currentWorkstation;
    final isWin = activeWs?.os == 'Windows';
    final fallback = isWin ? 'C:\\projects' : '/Users/arronkianparejas';

    if (widget.initialDestination == null || _destinationPath.isEmpty) {
      setState(() => _destinationPath = fallback);
      try {
        final res = await _api.browseDirectories();
        if (res['current_path'] != null && mounted && res['current_path'].toString().isNotEmpty) {
          setState(() {
            _destinationPath = res['current_path'];
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _chooseDestinationFolder() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DirectoryBrowserModal(initialPath: _destinationPath),
    );

    if (res != null && res['path'] != null) {
      setState(() {
        _destinationPath = res['path']!;
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles = result.files;
          _uploadStatus = '${result.files.length} file(s) selected for upload.';
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick files: $e', style: GoogleFonts.jetBrainsMono())),
      );
    }
  }

  Future<void> _uploadAllFiles() async {
    if (_selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select files first', style: GoogleFonts.jetBrainsMono())),
      );
      return;
    }

    setState(() {
      _uploading = true;
      _uploadStatus = 'Uploading files to remote machine...';
    });

    int successCount = 0;

    for (var file in _selectedFiles) {
      try {
        setState(() {
          _uploadStatus = 'Reading ${file.name}...';
        });

        Uint8List? fileBytes = file.bytes;
        if (fileBytes == null && file.path != null) {
          final ioFile = File(file.path!);
          if (await ioFile.exists()) {
            fileBytes = await ioFile.readAsBytes();
          }
        }

        if (fileBytes != null) {
          setState(() {
            _uploadStatus = 'Uploading ${file.name} (${(fileBytes!.length / 1024).toStringAsFixed(1)} KB)...';
          });

          final res = await _api.uploadFile(
            destinationPath: _destinationPath,
            filename: file.name,
            bytes: fileBytes,
          );

          if (res['success'] == true) {
            successCount++;
            _uploadedFiles.add(file.name);
          } else {
            debugPrint('Upload failed response for ${file.name}: $res');
          }
        } else {
          debugPrint('Unable to read bytes for ${file.name}, path is ${file.path}');
        }
      } catch (e) {
        debugPrint('Upload exception for ${file.name}: $e');
      }
    }

    setState(() {
      _uploading = false;
      _uploadStatus = 'Upload complete: $successCount of ${_selectedFiles.length} file(s) transferred successfully!';
      if (successCount == _selectedFiles.length) {
        _selectedFiles.clear();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transferred $successCount file(s) to $_destinationPath',
            style: GoogleFonts.jetBrainsMono(),
          ),
        ),
      );
    }
  }

  IconData _getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp') || lower.endsWith('.gif')) {
      return Icons.image;
    } else if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.avi') || lower.endsWith('.mkv')) {
      return Icons.movie;
    } else if (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.aac') || lower.endsWith('.ogg')) {
      return Icons.audio_file;
    } else if (lower.endsWith('.pdf') || lower.endsWith('.doc') || lower.endsWith('.docx') || lower.endsWith('.txt')) {
      return Icons.description;
    } else if (lower.endsWith('.zip') || lower.endsWith('.tar') || lower.endsWith('.gz') || lower.endsWith('.7z')) {
      return Icons.folder_zip;
    } else {
      return Icons.code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'UPLOAD FILES & MEDIA TO MACHINE',
          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Destination Directory Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TerminalColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: TerminalColors.cardBorderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TARGET MACHINE FOLDER',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: TerminalColors.zinc,
                      ),
                    ),
                    InkWell(
                      onTap: _chooseDestinationFolder,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: TerminalColors.pureWhite,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'BROWSE FOLDERS',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _destinationPath,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: TerminalColors.pureWhite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // File Picker Trigger
          InkWell(
            onTap: _uploading ? null : _pickFiles,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: TerminalColors.cardBorderLight,
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 36, color: TerminalColors.pureWhite),
                  const SizedBox(height: 10),
                  Text(
                    'SELECT FILES, PICTURES & MEDIA',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: TerminalColors.pureWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Supports all formats: PNG, JPG, MP4, PDF, ZIP, code & documents',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: TerminalColors.zinc,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Selected Files List
          if (_selectedFiles.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'QUEUE (${_selectedFiles.length} FILES)',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                ),
                TextButton(
                  onPressed: () => setState(() => _selectedFiles.clear()),
                  child: Text('CLEAR', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...List.generate(_selectedFiles.length, (idx) {
              final file = _selectedFiles[idx];
              final sizeKb = (file.size / 1024).toStringAsFixed(1);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: TerminalColors.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: TerminalColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(_getFileIcon(file.name), color: TerminalColors.pureWhite, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.name,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: TerminalColors.pureWhite,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$sizeKb KB',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: TerminalColors.textMuted),
                      onPressed: () {
                        setState(() {
                          _selectedFiles.removeAt(idx);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 14),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: TerminalColors.pureWhite,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 44),
              ),
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.send_to_mobile, size: 18),
              label: Text(
                _uploading ? 'TRANSFERRING FILES...' : 'UPLOAD ${_selectedFiles.length} FILE(S) TO MACHINE',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 11.5),
              ),
              onPressed: _uploading ? null : _uploadAllFiles,
            ),
          ],

          if (_uploadStatus.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: TerminalColors.cardBorderLight),
              ),
              child: Text(
                _uploadStatus,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

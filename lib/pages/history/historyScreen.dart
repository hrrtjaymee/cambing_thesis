import 'package:flutter/material.dart';
import 'package:cambing_thesis/core/theme/colors.dart';
import 'package:cambing_thesis/core/theme/text_styles.dart';
import 'package:cambing_thesis/utils/image_metadata_helper.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() {
    return _HistoryScreenState();
  }
}

enum SortBy { weight, date }

class HistoryImage {
  final String path;
  final String weight;
  final DateTime processedDate;

  HistoryImage({
    required this.path,
    required this.weight,
    required this.processedDate,
  });
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryImage> _historyImages = [];
  bool _isLoading = true;
  SortBy _sortBy = SortBy.date;
  bool _sortDescending = true; // true = newest first, false = oldest first
  bool _showSortMenu = false;
  bool _isRemoveMode = false;
  Set<String> _selectedImages = {};

  @override
  void initState() {
    super.initState();
    _loadHistoryImages();
  }

  Future<void> _loadHistoryImages() async {
    try {
      final directory = Directory('/storage/emulated/0/Pictures/CambingThesis');
      
      if (!await directory.exists()) {
        print('📁 CambingThesis directory does not exist');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('📁 Loading images from: ${directory.path}');
      final List<FileSystemEntity> files = directory.listSync();
      final List<HistoryImage> images = [];

      for (var file in files) {
        if (file is File && file.path.toLowerCase().endsWith('.jpg')) {
          try {
            // Read metadata from image
            final metadata = await ImageMetadataHelper.getMetadata(file.path);
            
            if (metadata != null && metadata['isSegmented'] == true) {
              final weight = metadata['weight'] as String? ?? '---';
              final dateStr = metadata['processedDate'] as String?;
              DateTime processedDate = DateTime.now();
              
              if (dateStr != null) {
                try {
                  processedDate = DateTime.parse(dateStr);
                } catch (e) {
                  print('⚠️ Failed to parse date: $dateStr');
                }
              }

              images.add(HistoryImage(
                path: file.path,
                weight: weight,
                processedDate: processedDate,
              ));
            }
          } catch (e) {
            print('⚠️ Error reading metadata for ${file.path}: $e');
          }
        }
      }

      print('✅ Loaded ${images.length} processed images');

      setState(() {
        _historyImages = images;
        _sortImages();
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading history images: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _sortImages() {
    if (_sortBy == SortBy.weight) {
      _historyImages.sort((a, b) {
        final weightA = double.tryParse(a.weight) ?? 0.0;
        final weightB = double.tryParse(b.weight) ?? 0.0;
        return _sortDescending 
            ? weightB.compareTo(weightA)  // Descending (highest first)
            : weightA.compareTo(weightB); // Ascending (lowest first)
      });
    } else {
      _historyImages.sort((a, b) => _sortDescending
          ? b.processedDate.compareTo(a.processedDate) // Most recent first
          : a.processedDate.compareTo(b.processedDate)); // Oldest first
    }
  }

  Future<void> _removeSelectedImages() async {
    if (_selectedImages.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: Text(
            'Are you sure you want to delete ${_selectedImages.length} image(s)? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // Delete the files
    int deletedCount = 0;
    final imagesToRemove = List<String>.from(_selectedImages);
    
    for (final imagePath in imagesToRemove) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
          deletedCount++;
          print('🗑️ Deleted: $imagePath');
        }
      } catch (e) {
        print('❌ Error deleting $imagePath: $e');
      }
    }

    // Clear selection and exit remove mode
    setState(() {
      _selectedImages.clear();
      _isRemoveMode = false;
    });

    // Reload the history
    await _loadHistoryImages();

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully deleted $deletedCount image(s)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.primary,
          title: const Text(
            'Sort by',
            style: TextStyle(color: Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Colors.black),
                title: const Text(
                  'Date',
                  style: TextStyle(color: Colors.black),
                ),
                trailing: _sortBy == SortBy.date
                    ? const Icon(Icons.check, color: Colors.black)
                    : null,
                onTap: () {
                  setState(() {
                    _sortBy = SortBy.date;
                    _sortDescending = true;
                    _sortImages();
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.fitness_center, color: Colors.black),
                title: const Text(
                  'Weight',
                  style: TextStyle(color: Colors.black),
                ),
                trailing: _sortBy == SortBy.weight
                    ? const Icon(Icons.check, color: Colors.black)
                    : null,
                onTap: () {
                  setState(() {
                    _sortBy = SortBy.weight;
                    _sortDescending = true;
                    _sortImages();
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void backOnPressed(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background
        ),
        child: Stack(
          children: [
            // Background watermark image
            Center(
              child: Opacity(
                opacity: 0.5,
                child: Image.asset(
                  'assets/images/bullet-icon-light.png',
                  width: screenWidth * 0.4,
                  height: screenWidth * 0.4,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Main content
            SafeArea(
              minimum: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Header with back button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      TextButton(
                        onPressed: () => backOnPressed(context),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.foreground,
                          padding: EdgeInsets.all(screenWidth * 0.02),
                          textStyle: AppTextStyles.appbar,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Icon(Icons.arrow_back, size: 20.0),
                        SizedBox(width: 4),
                        Text('BACK'),
                      ]
                    ),
                  ),
                ],
              ),
              
              // Centered title below app bar
              const Center(
                child: Text(
                  'History',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.foreground,
                  ),
                ),
              ),
              
              SizedBox(height: screenHeight * 0.02),
              
              // Sort controls row under History title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: Newest/Oldest toggle icons
                    Row(
                      children: [
                        // Newest/Latest icon
                        IconButton(
                          icon: Icon(
                            Icons.arrow_upward,
                            color: _sortBy == SortBy.date && _sortDescending
                                ? AppColors.primary
                                : Colors.grey[600],
                            size: 24,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          onPressed: () {
                            setState(() {
                              _sortBy = SortBy.date;
                              _sortDescending = true; // Latest first
                              _sortImages();
                            });
                          },
                          tooltip: 'Latest',
                        ),
                        Transform.translate(
                          offset: const Offset(-8, 0),
                          child: IconButton(
                            icon: Icon(
                              Icons.arrow_downward,
                              color: _sortBy == SortBy.date && !_sortDescending
                                  ? AppColors.primary
                                  : Colors.grey[600],
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            onPressed: () {
                              setState(() {
                                _sortBy = SortBy.date;
                                _sortDescending = false; // Oldest first
                                _sortImages();
                              });
                            },
                            tooltip: 'Oldest',
                          ),
                        ),
                      ],
                    ),
                    // Right side: Triple dot menu button
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 24),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 180,
                      ),
                      onSelected: (String value) {
                        if (value == 'sort') {
                          _showSortDialog(context);
                        } else if (value == 'remove') {
                          setState(() {
                            _isRemoveMode = !_isRemoveMode;
                            if (!_isRemoveMode) {
                              _selectedImages.clear();
                            }
                          });
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'sort',
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sort by',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black87),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'remove',
                          child: Text(
                            'Remove',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.01),

              // Sort menu overlay (for triple dot menu)
              if (_showSortMenu)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    margin: const EdgeInsets.only(right: 16, top: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.sort, size: 20),
                          title: const Text('Sort by'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            // Close menu - sort options are visible below title
                            setState(() {
                              _showSortMenu = false;
                            });
                          },
                        ),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.delete_outline, size: 20),
                          title: const Text('Remove'),
                          onTap: () {
                            // TODO: Implement remove functionality
                            setState(() {
                              _showSortMenu = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Remove functionality coming soon'),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

              // Content area
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _historyImages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No processed images yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _historyImages.length,
                            itemBuilder: (context, index) {
                              final image = _historyImages[index];
                              return _buildHistoryItem(image);
                            },
                          ),
              ),

              // Remove button at bottom (only visible in remove mode)
              if (_isRemoveMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ElevatedButton(
                    onPressed: _selectedImages.isEmpty
                        ? null
                        : () => _removeSelectedImages(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      disabledBackgroundColor: Colors.grey[300],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Remove (${_selectedImages.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // Cancel button (only visible in remove mode)
              if (_isRemoveMode)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isRemoveMode = false;
                        _selectedImages.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.foreground,
                      side: BorderSide(color: Colors.grey[400]!, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

  Widget _buildHistoryItem(HistoryImage image) {
    final dateFormat = DateFormat('MMMM d, yyyy');
    final formattedDate = dateFormat.format(image.processedDate);
    final isSelected = _selectedImages.contains(image.path);

    final itemWidget = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Image on the left
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(image.path),
              width: 170,
              height: 140,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          // Text on the right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${image.weight} kilograms',
                  style: const TextStyle(
                    fontFamily: 'League Spartan',
                    fontSize: 22,
                    fontWeight: FontWeight.normal,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic
                  ),
                ),
              ],
            ),
          ),
          // Checkbox in remove mode
          if (_isRemoveMode)
            Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _selectedImages.add(image.path);
                  } else {
                    _selectedImages.remove(image.path);
                  }
                });
              },
              activeColor: AppColors.primary,
            ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        if (_isRemoveMode) {
          // Toggle selection in remove mode
          setState(() {
            if (isSelected) {
              _selectedImages.remove(image.path);
            } else {
              _selectedImages.add(image.path);
            }
          });
        } else {
          // TODO: Navigate to detail view or weight screen with this image
          print('Tapped on image: ${image.path}');
        }
      },
      child: itemWidget,
    );
  }
}
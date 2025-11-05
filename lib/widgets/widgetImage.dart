// widgets/FullImageView.dart
import 'package:chatapp/function/snakbar.dart';
import 'package:flutter/material.dart';

class FullImageView extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final Future<bool>? Function(int)? onDelete; // Future<bool>? qaytaradi

  const FullImageView({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.onDelete,
  });

  @override
  State<FullImageView> createState() => _FullImageViewState();
}

class _FullImageViewState extends State<FullImageView> {
  late PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // CONTEXT'SIZ dialog
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rasm o‘chirilsinmi?"),
        content: const Text("Bu rasm butunlay o‘chib ketadi."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Yo‘q"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await widget.onDelete?.call(_currentIndex);
              if (success == true && mounted) {
                showAppSnackbar(
                  context: context,
                  type: SnackbarType.success,
                  description: "Rasm o'chirildi",
                );
                if (widget.imageUrls.length <= 1) {
                  Navigator.pop(context);
                }
              }
            },
            child: const Text(
              "Ha, o‘chirish",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _showDeleteDialog, // CONTEXT'SIZ
            ),

        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return GestureDetector(
                onLongPress: widget.onDelete != null ? _showDeleteDialog : null, // CONTEXT'SIZ
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5.0,
                  child: Center(
                    child: Image.network(
                      widget.imageUrls[index],
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                      progress == null
                          ? child
                          : const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // NUQTALAR
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.imageUrls.asMap().entries.map((e) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: _currentIndex == e.key ? 14 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: _currentIndex == e.key
                          ? Colors.white
                          : Colors.white38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }).toList(),
              ),
            ),

          // RASM SONI
          Positioned(
            top: 60,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${_currentIndex + 1} / ${widget.imageUrls.length}",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
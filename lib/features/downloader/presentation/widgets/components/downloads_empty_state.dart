import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DownloadsEmptyState extends StatelessWidget {
  const DownloadsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_download_outlined,
              size: 64,
              color: Colors.white10,
            ),
            const SizedBox(height: 16),
            Text(
              'No Media to Download',
              style: GoogleFonts.manrope(
                color: Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paste URLs above and click Fetch',
              style: GoogleFonts.manrope(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_constants.dart';
import '../utils/formatters.dart';
import 'common_widgets.dart';

class CapturedPhoto {
  const CapturedPhoto(this.path, this.takenAt);

  final String path;
  final DateTime takenAt;

  Map<String, dynamic> toJson() => {'path': path, 'takenAt': takenAt.toIso8601String()};

  factory CapturedPhoto.fromJson(Map<String, dynamic> j) =>
      CapturedPhoto(j['path'] as String, DateTime.parse(j['takenAt'] as String));
}

Future<CapturedPhoto?> _takePhoto() async {
  final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 1600);
  return file == null ? null : CapturedPhoto(file.path, DateTime.now());
}

/// Camera only: proof photos must be taken on the spot, not picked from a gallery.
final photoCaptureProvider = Provider<Future<CapturedPhoto?> Function()>((ref) => _takePhoto);

/// Takes a photo, or explains why it can't when the camera permission is refused.
Future<CapturedPhoto?> capturePhoto(BuildContext context, WidgetRef ref) async {
  try {
    return await ref.read(photoCaptureProvider)();
  } on PlatformException {
    if (context.mounted) {
      showMessage(
        context,
        'Please allow camera access for this app in your phone settings, then try again.',
        isError: true,
      );
    }
    return null;
  }
}

/// Thumbnails of the photos taken so far and a button to take another.
class PhotoField extends ConsumerWidget {
  const PhotoField({super.key, required this.photos, required this.onChanged});

  final List<CapturedPhoto> photos;
  final ValueChanged<List<CapturedPhoto>> onChanged;

  Future<void> _capture(BuildContext context, WidgetRef ref) async {
    final photo = await capturePhoto(context, ref);
    if (photo != null) onChanged([...photos, photo]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photos.isNotEmpty) ...[
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  LocalImage(photos[i].path, height: 96, width: 96),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: IconButton.filledTonal(
                      tooltip: 'Remove photo',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => onChanged([...photos]..removeAt(i)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (photos.length < AppConstants.maxPhotos)
          OutlinedButton.icon(
            onPressed: () => _capture(context, ref),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(photos.isEmpty ? 'Take photo' : 'Take another photo'),
          ),
      ],
    );
  }
}

/// Saved proof photos with the time each was taken.
class PhotoGallery extends StatelessWidget {
  const PhotoGallery({super.key, required this.photos});

  final List<CapturedPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final p in photos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(children: [LocalImage(p.path), InfoRow('Taken at', formatDateTime(p.takenAt))]),
          ),
      ],
    );
  }
}

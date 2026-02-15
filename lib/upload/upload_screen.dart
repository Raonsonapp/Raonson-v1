Future<void> upload() async {
  if (media.isEmpty) return;

  setState(() => uploading = true);

  // ⬇️ TEMP: mock upload → URL
  final uploadedMedia = media.map((m) {
    return {
      'url': 'https://picsum.photos/500/500', // 🔜 storage
      'type': m.isVideo ? 'video' : 'image',
    };
  }).toList();

  await UploadApi.uploadPost(
    caption: captionCtrl.text,
    media: uploadedMedia,
  );

  if (!mounted) return;
  Navigator.pop(context);
}

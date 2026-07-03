// lib/create/create_post/photo_filters.dart
// Филтрҳои акс (мисли Instagram) — матрицаи ColorFilter.
import 'package:flutter/widgets.dart';

class PhotoFilter {
  final String name;
  final List<double> matrix;
  const PhotoFilter(this.name, this.matrix);
  ColorFilter get colorFilter => ColorFilter.matrix(matrix);
}

class PhotoFilters {
  static const List<PhotoFilter> presets = [
    PhotoFilter('Оддӣ', [
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0, //
      0, 0, 1, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
    PhotoFilter('Гарм', [
      1.10, 0, 0, 0, 12, //
      0, 1.04, 0, 0, 6, //
      0, 0, 0.90, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
    PhotoFilter('Хунук', [
      0.90, 0, 0, 0, 0, //
      0, 1.00, 0, 0, 5, //
      0, 0, 1.16, 0, 12, //
      0, 0, 0, 1, 0,
    ]),
    PhotoFilter('Ravshan', [
      1.15, 0, 0, 0, 12, //
      0, 1.15, 0, 0, 12, //
      0, 0, 1.15, 0, 12, //
      0, 0, 0, 1, 0,
    ]),
    PhotoFilter('Vivid', [
      1.30, -0.15, -0.15, 0, 0, //
      -0.15, 1.30, -0.15, 0, 0, //
      -0.15, -0.15, 1.30, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
    PhotoFilter('Vintage', [
      0.393, 0.769, 0.189, 0, 0, //
      0.349, 0.686, 0.168, 0, 0, //
      0.272, 0.534, 0.131, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
    PhotoFilter('Сиёҳу сафед', [
      0.33, 0.59, 0.11, 0, 0, //
      0.33, 0.59, 0.11, 0, 0, //
      0.33, 0.59, 0.11, 0, 0, //
      0, 0, 0, 1, 0,
    ]),
    PhotoFilter('Fade', [
      0.80, 0, 0, 0, 32, //
      0, 0.80, 0, 0, 32, //
      0, 0, 0.80, 0, 32, //
      0, 0, 0, 1, 0,
    ]),
    PhotoFilter('Inkwell', [
      0.50, 0.90, 0.16, 0, -28, //
      0.50, 0.90, 0.16, 0, -28, //
      0.50, 0.90, 0.16, 0, -28, //
      0, 0, 0, 1, 0,
    ]),
  ];
}

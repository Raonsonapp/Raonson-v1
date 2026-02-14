import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReelsIcons {
  static Widget like({bool active = false}) {
    return SvgPicture.asset(
      'assets/icons/heart.svg',
      color: active ? Colors.red : Colors.white,
      width: 32,
    );
  }

  static Widget comment() {
    return SvgPicture.asset(
      'assets/icons/comment.svg',
      color: Colors.white,
      width: 32,
    );
  }

  static Widget share() {
    return SvgPicture.asset(
      'assets/icons/share.svg',
      color: Colors.white,
      width: 32,
    );
  }

  static Widget save() {
    return SvgPicture.asset(
      'assets/icons/save.svg',
      color: Colors.white,
      width: 28,
    );
  }

  static Widget more() {
    return const Icon(Icons.more_vert, color: Colors.white);
  }
}

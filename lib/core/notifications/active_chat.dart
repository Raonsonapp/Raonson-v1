// lib/core/notifications/active_chat.dart
// ════════════════════════════════════════════════════════════════════
//  «Ин чат ҲОЗИР дар экран аст?»
//
//  Мисли Instagram/WhatsApp: паёме, ки ба чати кушода меояд, banner ва
//  садо НАМЕДИҲАД — одам онро аллакай мебинад. Паём ба чати дигар —
//  «поп»-и кӯтоҳ ва banner.
//
//  ChatRoomScreen шиносаи худро ҷое сабт намекунад, бинобар ин дарахти
//  виҷетҳои route-и БОЛОӢ пурсида мешавад. Ин танҳо ҳангоми расидани
//  push иҷро мешавад, на дар ҳар кадр.
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/widgets.dart';

import '../../chat/room/chat_room_screen.dart';

class ActiveChat {
  ActiveChat._();

  /// Қисми тоза: chatId-и сервер «a_b» аст (ду шиносаи тартибдодашуда).
  /// Оё [peerId] яке аз ду иштирокчии ин чат аст?
  static bool chatHasPeer(String chatId, String peerId) {
    if (chatId.isEmpty || peerId.isEmpty) return false;
    final parts = chatId.split('_');
    if (parts.length != 2) return chatId == peerId;
    return parts.contains(peerId);
  }

  /// Оё чат бо ин chatId дар route-и болоӣ кушода аст?
  static bool isOpen(GlobalKey<NavigatorState>? navKey, String chatId) {
    if (chatId.isEmpty) return false;
    final root = navKey?.currentContext;
    if (root == null) return false;
    var found = false;
    void visit(Element e) {
      if (found) return;
      final w = e.widget;
      if (w is ChatRoomScreen) {
        // Танҳо route-и БОЛОӢ: чате, ки зери экрани дигар пинҳон аст,
        // «кушода» ҳисоб намешавад.
        final route = ModalRoute.of(e);
        if ((route?.isCurrent ?? false) && chatHasPeer(chatId, w.peer.id)) {
          found = true;
          return;
        }
      }
      e.visitChildElements(visit);
    }

    try {
      (root as Element).visitChildElements(visit);
    } catch (_) {
      return false;
    }
    return found;
  }
}

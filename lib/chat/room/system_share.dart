// lib/chat/room/system_share.dart
//
// Паёмҳои системавии Direct (мисли Instagram): сервер ҳангоми даъвати
// ҳамкорӣ дар пост ва зикр дар сторис корти пост/сторисро аз номи
// даъваткунанда мефиристад (backend/handlers/share_dm.go). Матнҳо
// бояд айнан бо сервер мувофиқ бошанд.
import '../../models/message_model.dart';

const kCollabInviteDMText = 'Шуморо ба ҳамкорӣ дар пост даъват кард';
const kStoryMentionDMText = 'Шуморо дар сторис зикр кард';

enum SystemShare { none, collabInvite, storyMention }

SystemShare classifySystemShare(SharedRef? share, String text) {
  if (share == null) return SystemShare.none;
  final t = text.trim();
  if (share.kind == 'post' && t == kCollabInviteDMText) {
    return SystemShare.collabInvite;
  }
  if (share.kind == 'story' && t == kStoryMentionDMText) {
    return SystemShare.storyMention;
  }
  return SystemShare.none;
}

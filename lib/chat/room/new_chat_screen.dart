import 'dart:convert';
import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../core/api/api_client.dart';
import '../../core/services/user_session.dart';
import '../../core/storage/token_storage.dart';
import '../../core/webrtc_service.dart';
import '../../models/user_model.dart';
import '../../widgets/avatar.dart';
import '../../widgets/verified_badge.dart';
import 'chat_room_screen.dart';
import 'call_screen.dart';
import '../../core/ui/app_icons.dart';
import '../../core/i18n/strings.dart';

class NewChatScreen extends StatefulWidget {
  /// Агар callType дода шавад, интихоби корбар занг оғоз мекунад (на чат).
  final CallType? callType;
  const NewChatScreen({super.key, this.callType});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _ctrl = TextEditingController();
  List<UserModel> _results = [];
  bool _loading = false;
  String _lastQuery = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query == _lastQuery) return;
    _lastQuery = query;

    if (query.isEmpty) {
      setState(() { _results = []; _loading = false; });
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiClient.instance
          .getRequest('/search/users?q=${Uri.encodeComponent(query)}');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        // backend returns array directly OR {users: [...]}
        final List list = body is List
            ? body
            : (body['users'] ?? body['results'] ?? []);
        setState(() {
          _results = list
              .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('[NewChat] search error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat(UserModel user) async {
    // Режими занг — мисли тугмаи «занги нав»-и Instagram.
    if (widget.callType != null) {
      final myId = await TokenStorage.getUserId() ?? '';
      WebRTCService().notifyIncoming(
        toUserId:     user.id,
        fromUserId:   myId,
        fromUsername: UserSession.username ?? '',
        fromAvatar:   UserSession.avatar ?? '',
        isVideo:      widget.callType == CallType.video,
      );
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CallScreen(peer: user, callType: widget.callType!),
      ));
      return;
    }
    Navigator.pop(context); // close NewChatScreen first
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatRoomScreen(peer: user)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(tr('ui.f5baf4632a'),
            style: TextStyle(color: AppColors.textPrimary,
                fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: tr('ui.cb7d37898e'),
                  hintStyle: TextStyle(color: AppColors.textFaint),
                  prefixIcon:
                      Icon(AppIcons.search, color: AppColors.textFaint, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (v) {
                  // Reset so same query can re-fire after clear
                  if (v.trim() != _lastQuery) _lastQuery = '';
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (mounted && _ctrl.text == v) _search(v);
                  });
                },
              ),
            ),
          ),
          Divider(color: AppColors.dividerFaint, height: 1),
          // Results
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.neonBlue))
                : _results.isEmpty
                    ? Center(
                        child: Text(
                          _lastQuery.isEmpty
                              ? 'Касеро барои паём ҷустуҷӯ кунед'
                              : 'No users found',
                          style: TextStyle(
                              color: AppColors.textFaint, fontSize: 14),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (_, i) {
                          final user = _results[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            leading:
                                Avatar(imageUrl: user.avatar, size: 48),
                            title: Row(
                              children: [
                                Text(
                                  user.username,
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15),
                                ),
                                if (user.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const VerifiedBadge(size: 14),
                                ],
                              ],
                            ),
                            subtitle: user.bio != null && user.bio!.isNotEmpty
                                ? Text(
                                    user.bio!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: AppColors.textFaint, fontSize: 12),
                                  )
                                : null,
                            trailing: GestureDetector(
                              onTap: () => _openChat(user),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.neonBlue,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.neonBlue.withOpacity(0.35),
                                      blurRadius: 8,
                                    )
                                  ],
                                ),
                                child: Text(tr('ui.10b76dbc9f'),
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                              ),
                            ),
                            onTap: () => _openChat(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

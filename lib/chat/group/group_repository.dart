// lib/chat/group/group_repository.dart
import 'dart:convert';
import '../../core/api/api_client.dart';
import 'group_model.dart';

class GroupRepository {
  final _api = ApiClient.instance;

  Future<List<GroupModel>> getMyGroups() async {
    try {
      final r = await _api.get('/groups/');
      if (r.statusCode >= 400) return [];
      final body = jsonDecode(r.body);
      final list = (body is List ? body : (body['groups'] ?? [])) as List;
      return list
          .map((e) => GroupModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<GroupModel?> createGroup(String name, List<String> memberIds) async {
    try {
      final r = await _api.post('/groups/',
          body: {'name': name, 'memberIds': memberIds});
      if (r.statusCode >= 400) return null;
      return GroupModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getInfo(String groupId) async {
    try {
      final r = await _api.get('/groups/$groupId');
      if (r.statusCode >= 400) return null;
      return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<GroupMessage>> getMessages(String groupId,
      {int page = 1}) async {
    try {
      final r = await _api.get('/groups/$groupId/messages?page=$page&limit=40');
      if (r.statusCode >= 400) return [];
      final body = jsonDecode(r.body);
      final list = (body is List ? body : (body['messages'] ?? [])) as List;
      return list
          .map((e) => GroupMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<GroupMessage?> sendMessage(String groupId, String text,
      {String type = 'text', String mediaUrl = ''}) async {
    try {
      final r = await _api.post('/groups/$groupId/messages',
          body: {'text': text, 'type': type, 'mediaUrl': mediaUrl});
      if (r.statusCode >= 400) return null;
      return GroupMessage.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> addMembers(String groupId, List<String> userIds) async {
    try {
      await _api.post('/groups/$groupId/members', body: {'userIds': userIds});
    } catch (_) {}
  }

  Future<void> removeMember(String groupId, String userId) async {
    try {
      await _api.delete('/groups/$groupId/members/$userId');
    } catch (_) {}
  }

  Future<void> leave(String groupId) async {
    try {
      await _api.post('/groups/$groupId/leave');
    } catch (_) {}
  }

  Future<GroupModel?> joinByToken(String token) async {
    try {
      final r = await _api.post('/group-join/$token');
      if (r.statusCode >= 400) return null;
      return GroupModel.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

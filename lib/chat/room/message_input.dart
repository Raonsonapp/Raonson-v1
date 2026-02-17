import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final ValueChanged<String> onSend;

  const MessageInput({
    super.key,
    required this.onSend,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  bool _canSend = false;

  void _onChanged(String value) {
    setState(() {
      _canSend = value.trim().isNotEmpty;
    });
  }

  void _send() {
    final text = _controller.text;
    _controller.clear();
    _onChanged('');
    widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: const Border(
            top: BorderSide(color: Colors.black12),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _canSend ? _send() : null,
                decoration: const InputDecoration(
                  hintText: 'Message…',
                  border: InputBorder.none,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.send,
                color: _canSend
                    ? Theme.of(context).primaryColor
                    : Colors.grey,
              ),
              onPressed: _canSend ? _send : null,
            ),
          ],
        ),
      ),
    );
  }
}

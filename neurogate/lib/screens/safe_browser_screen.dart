import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SafeBrowserScreen extends StatefulWidget {
  const SafeBrowserScreen({super.key});

  @override
  State<SafeBrowserScreen> createState() => _SafeBrowserScreenState();
}

class _SafeBrowserScreenState extends State<SafeBrowserScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  final TextEditingController _urlController = TextEditingController();

  // Basic blocklist for adult/social media
  final List<String> _blockedKeywords = [
    'porn', 'gambling', 'casino', 'facebook.com', 'instagram.com', 'tiktok.com', 'twitter.com', 'x.com'
  ];

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _urlController.text = url;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            return _handleNavigation(request.url);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.google.com/search?q=kids+safe+search&safe=active'));
  }

  NavigationDecision _handleNavigation(String url) {
    final lowerUrl = url.toLowerCase();

    // 1. Keyword Blocklist Check
    for (var keyword in _blockedKeywords) {
      if (lowerUrl.contains(keyword)) {
        _showBlockedMessage("This site is not allowed.");
        return NavigationDecision.prevent;
      }
    }

    // 2. Enforce Safe Search on Search Engines
    if (lowerUrl.contains('google.com/search') && !lowerUrl.contains('safe=active')) {
      final safeUrl = url + (url.contains('?') ? '&' : '?') + 'safe=active';
      _controller.loadRequest(Uri.parse(safeUrl));
      return NavigationDecision.prevent;
    }
    
    if (lowerUrl.contains('youtube.com/results') && !lowerUrl.contains('sp=')) {
        // Basic attempt to enforce restricted mode or safe results on youtube
        // YouTube's strict restricted mode is cookie-based, but adding basic safe filters helps
        final safeUrl = url + (url.contains('?') ? '&' : '?') + 'sp=CAISAhAB'; 
        _controller.loadRequest(Uri.parse(safeUrl));
        return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  void _showBlockedMessage(String reason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.block, color: Colors.white),
            const SizedBox(width: 8),
            Text(reason),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _loadUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return;

    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        // Treat as a search query
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}&safe=active';
      }
    }
    
    _controller.loadRequest(Uri.parse(url));
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Container(
          height: 40,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.security, size: 18, color: Colors.greenAccent),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("NeuroGate Safe Browser Active"))
                  );
                },
              ),
              Expanded(
                child: TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search or enter website...',
                    hintStyle: TextStyle(color: Colors.white30),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.go,
                  onSubmitted: _loadUrl,
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.white54),
                  onPressed: () => _controller.reload(),
                ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
            onPressed: () async {
              if (await _controller.canGoBack()) {
                _controller.goBack();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            onPressed: () async {
              if (await _controller.canGoForward()) {
                _controller.goForward();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

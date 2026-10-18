import 'package:flutter/material.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    required this.initialize,
    required this.nextPageBuilder,
    this.imagePath = 'assets/images/welcome_logo.png',
  });

  final Future<void> Function() initialize;
  final WidgetBuilder nextPageBuilder;
  final String imagePath;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scale = Tween<double>(
      begin: 0.97,
      end: 1.03,
    ).animate(_controller.drive(CurveTween(curve: Curves.easeInOut)));

    // Start loading after the first frame can be displayed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadApp();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Respect the device's reduced-motion setting.
    if (MediaQuery.of(context).disableAnimations || _ready) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  Future<void> _loadApp() async {
    setState(() => _failed = false);

    try {
      await widget.initialize();

      if (!mounted) return;

      _controller.stop();
      setState(() => _ready = true);
    } catch (error, stackTrace) {
      debugPrint('Startup failed: $error\n$stackTrace');

      if (!mounted) return;

      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) {
      return widget.nextPageBuilder(context);
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: Image.asset(
                    widget.imagePath,
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                    semanticLabel: 'App logo',
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Welcome',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  _failed
                      ? 'Unable to finish loading. Please try again.'
                      : 'Getting things ready for you…',
                  textAlign: TextAlign.center,
                ),
                if (_failed) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _loadApp,
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

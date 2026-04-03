import 'dart:math' as math;
import 'package:flutter/material.dart';

class FloatingFab extends StatefulWidget {
  final VoidCallback onExpense;
  final VoidCallback onIncome;
  final VoidCallback onTransfer;
  final VoidCallback onNote;
  final VoidCallback onLimit;
  final VoidCallback onChatbot;

  const FloatingFab({
    super.key,
    required this.onExpense,
    required this.onIncome,
    required this.onTransfer,
    required this.onNote,
    required this.onLimit,
    required this.onChatbot,
  });

  @override
  State<FloatingFab> createState() => _FloatingFabState();
}

class _FloatingFabState extends State<FloatingFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  bool open = false;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void toggle() {
    setState(() => open = !open);
    open ? _ctl.forward() : _ctl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action("Chi tiêu", Icons.credit_card, [Colors.pink, Colors.red], widget.onExpense),
      _Action("Thu nhập", Icons.trending_up, [Colors.green, Colors.teal], widget.onIncome),
      _Action("Ghi chép", Icons.description, [Colors.indigo, Colors.purple], widget.onNote),
      _Action("Hũ chi tiêu", Icons.flag, [Colors.orange, Colors.amber], widget.onLimit),
      _Action("Chatbot", Icons.smart_toy, [Colors.cyan, Colors.blue], widget.onChatbot),
    ];

    return SizedBox(
      width: 260,
      height: 450,
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          // ACTIONS
          for (int i = 0; i < actions.length; i++)
            _buildAction(actions[i], i),

          // MAIN FAB
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: toggle,
              child: AnimatedBuilder(
                animation: _ctl,
                builder: (_, __) {
                  return Transform.rotate(
                    angle: _ctl.value * math.pi / 4,
                    child: AnimatedScale(
                      scale: open ? 1.1 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF6366F1)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            )
                          ],
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 24),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction(_Action action, int index) {
    final animation = CurvedAnimation(
      parent: _ctl,
      curve: Interval(
        0.1 * index,
        1,
        curve: Curves.easeOutCubic,
      ),
    );

    return Positioned(
      right: 0,
      bottom: 80.0 + index * 64,
      child: FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25), // ⬅️ từ dưới lên
            end: Offset.zero,
          ).animate(animation),

          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // LABEL
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: const [
                    BoxShadow(color: Color(0x22000000), blurRadius: 14),
                  ],
                ),
                child: Text(action.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),

              // ICON BUTTON
              GestureDetector(
                onTap: () {
                  toggle();
                  action.onTap();
                },
                child: AnimatedScale(
                  scale: open ? 1 : 0.9,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(colors: action.colors),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 16,
                          offset: Offset(0, 10),
                        )
                      ],
                    ),
                    child: Icon(action.icon, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  _Action(this.label, this.icon, this.colors, this.onTap);
}

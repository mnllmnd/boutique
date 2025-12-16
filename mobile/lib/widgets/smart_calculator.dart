import 'package:flutter/material.dart';

class SmartCalculator extends StatefulWidget {
  final Function(double) onResultSelected;
  final double? initialValue;
  final String title;
  final bool isDark;

  const SmartCalculator({
    super.key,
    required this.onResultSelected,
    this.initialValue,
    this.title = 'CALCULATRICE',
    required this.isDark,
  });

  @override
  State<SmartCalculator> createState() => _SmartCalculatorState();
}

class _SmartCalculatorState extends State<SmartCalculator> {
  String _display = '0';
  String _expression = '';
  String _operation = '';
  double _previousValue = 0;

  bool _newNumber = true;
  bool _justCalculated = false;
  bool _showHistory = false;

  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialValue != null) {
      _display = _formatNumber(widget.initialValue!);
      _expression = _display;
    }
  }

  /* ================= FORMAT ================= */

  String _formatNumber(double v) {
    if (v == v.toInt()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
  }

  /* ================= NUMBERS ================= */

  void _handleNumber(String n) {
    setState(() {
      if (_newNumber || _display == '0') {
        _display = n; // empêche 04
        _newNumber = false;

        if (_justCalculated) {
          _expression = n;
          _justCalculated = false;
        } else {
          _expression += n;
        }
      } else {
        _display += n;
        _expression += n;
      }
    });
  }

  /* ================= OPERATIONS ================= */

  void _handleOperation(String op) {
    if (_expression.isEmpty) return;

    setState(() {
      _operation = op;
      _previousValue =
          double.tryParse(_display.replaceAll(',', '.')) ?? 0;
      _expression += ' $op ';
      _newNumber = true;
    });
  }

  /* ================= CALCULATE ================= */

  void _calculate() {
    final historyExpr = _expression;

    final current =
        double.tryParse(_display.replaceAll(',', '.')) ?? 0;
    double result = _previousValue;

    switch (_operation) {
      case '+':
        result += current;
        break;
      case '-':
        result -= current;
        break;
      case '×':
        result *= current;
        break;
      case '÷':
        result = current != 0 ? result / current : 0;
        break;
      case '%':
        result = result * (current / 100);
        break;
    }

    setState(() {
      _display = _formatNumber(result); // empêche 80.00
      _expression = _display;
      _operation = '';
      _newNumber = true;
      _justCalculated = true;

      _history.insert(0, historyExpr);
      if (_history.length > 20) _history.removeLast();
    });
  }

  /* ================= ACTIONS ================= */

  void _clear() {
    setState(() {
      _display = '0';
      _expression = '';
      _operation = '';
      _previousValue = 0;
      _newNumber = true;
    });
  }

  void _selectResult() {
    final value =
        double.tryParse(_display.replaceAll(',', '.')) ?? 0;

    final normalized =
        value == value.toInt() ? value.toInt().toDouble() : value;

    widget.onResultSelected(normalized);
    Navigator.pop(context);
  }

  /* ================= BUTTON ================= */

  Widget _btn(
    String label,
    VoidCallback onTap, {
    Color? bg,
    Color? fg,
    double size = 26,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: size,
            fontWeight: FontWeight.w400,
            color: fg,
          ),
        ),
      ),
    );
  }

  /* ================= DISPLAY ================= */

  Widget _buildDisplay(Color txt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _expression,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            color: txt.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _display,
          style: TextStyle(
            fontSize: 56,
            fontWeight: FontWeight.w300,
            color: txt,
          ),
        ),
      ],
    );
  }

  /* ================= HISTORY ================= */

  Widget _buildHistory(Color txt) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Historique',
              style: TextStyle(
                color: txt,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              color: txt,
              onPressed: () => setState(() => _showHistory = false),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          Text(
            'Aucun historique',
            style: TextStyle(color: txt.withOpacity(0.5)),
          )
        else
          ..._history.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                e,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: txt.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /* ================= UI ================= */

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    final bg = isDark ? Colors.black : Colors.white;
    final btn = isDark ? const Color(0xFF333333) : const Color(0xFFE5E5EA);
    final op = const Color(0xFFFF9500);
    final result = const Color(0xFF34C759);
    final action = const Color(0xFF007AFF);
    final txt = isDark ? Colors.white : Colors.black;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxHeight: 580, // 🔥 ANTI-OVERFLOW
          maxWidth: 380,
        ),
        child: Column(
          children: [
            /* ================= HEADER ================= */

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history),
                    color: txt,
                    onPressed: () => setState(() => _showHistory = true),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: txt,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            /* ================= DISPLAY / HISTORY ================= */

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _showHistory
                      ? _buildHistory(txt)
                      : _buildDisplay(txt),
                ),
              ),
            ),

            /* ================= GRID ================= */

            if (!_showHistory)
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: [
                  _btn('C', _clear, bg: Colors.red, fg: Colors.white),
                  _btn('%', () => _handleOperation('%'), bg: btn, fg: txt),
                  _btn('÷', () => _handleOperation('÷'),
                      bg: op, fg: Colors.white),
                  _btn('×', () => _handleOperation('×'),
                      bg: op, fg: Colors.white),

                  for (var i = 7; i <= 9; i++)
                    _btn('$i', () => _handleNumber('$i'),
                        bg: btn, fg: txt),
                  _btn('-', () => _handleOperation('-'),
                      bg: op, fg: Colors.white),

                  for (var i = 4; i <= 6; i++)
                    _btn('$i', () => _handleNumber('$i'),
                        bg: btn, fg: txt),
                  _btn('+', () => _handleOperation('+'),
                      bg: op, fg: Colors.white),

                  for (var i = 1; i <= 3; i++)
                    _btn('$i', () => _handleNumber('$i'),
                        bg: btn, fg: txt),

                  _btn('0', () => _handleNumber('0'), bg: btn, fg: txt),
                  _btn('=', _calculate, bg: result, fg: Colors.white),
                  _btn('OK', _selectResult, bg: action, fg: Colors.white),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

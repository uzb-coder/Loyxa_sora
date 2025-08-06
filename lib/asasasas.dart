import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class PaymentModal extends StatefulWidget {
  final bool visible;
  final VoidCallback onClose;
  final Map<String, dynamic>? selectedOrder;
  final Function(Map<String, dynamic>) onPaymentSuccess;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>) processPayment;
  final bool isProcessing;

  const PaymentModal({
    Key? key,
    required this.visible,
    required this.onClose,
    this.selectedOrder,
    required this.onPaymentSuccess,
    required this.processPayment,
    required this.isProcessing,
  }) : super(key: key);

  @override
  _PaymentModalState createState() => _PaymentModalState();
}

class _PaymentModalState extends State<PaymentModal> {
  String _paymentMethod = 'cash';
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    decimalDigits: 0,
    symbol: '',
  );

  double _paymentAmount = 0;
  double _changeAmount = 0;
  double _cashAmount = 0;
  double _cardAmount = 0;

  @override
  void initState() {
    super.initState();
    _resetForm();
  }

  @override
  void didUpdateWidget(covariant PaymentModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && widget.selectedOrder != oldWidget.selectedOrder) {
      _resetForm();
    }
  }

  double get _orderTotal {
    if (widget.selectedOrder == null) return 0;
    return (widget.selectedOrder!['finalTotal'] ??
        widget.selectedOrder!['final_total'] ?? 0).toDouble();
  }

  void _resetForm() {
    if (widget.selectedOrder == null) return;

    final total = _orderTotal;

    setState(() {
      _paymentMethod = 'cash';
      _paymentAmount = total;
      _changeAmount = 0;
      _cashAmount = 0;
      _cardAmount = 0;
      _notesController.clear();
    });
  }

  void _handlePaymentMethodChange(String? method) {
    if (method == null) return;

    setState(() {
      _paymentMethod = method;

      if (method == 'cash') {
        _paymentAmount = _orderTotal;
        _changeAmount = 0;
      } else if (['card', 'click', 'transfer'].contains(method)) {
        _paymentAmount = _orderTotal;
        _changeAmount = 0;
      } else if (method == 'mixed') {
        _cashAmount = (_orderTotal / 2).roundToDouble();
        _cardAmount = _orderTotal - _cashAmount;
        _changeAmount = 0;
      }
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      Map<String, dynamic> paymentData = {
        'paymentMethod': _paymentMethod,
        'notes': _notesController.text,
      };

      if (_paymentMethod == 'mixed') {
        final totalAmount = _cashAmount + _cardAmount;

        if (_cashAmount <= 0 || _cardAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aralash to\'lov uchun naqd va karta summasi 0 dan katta bo\'lishi kerak!')),
          );
          return;
        }

        if (totalAmount < _orderTotal) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('To\'lov summasi yetarli emas! Kerak: ${_currencyFormat.format(_orderTotal)}, Kiritildi: ${_currencyFormat.format(totalAmount)}')),
          );
          return;
        }

        paymentData['mixedPayment'] = {
          'cashAmount': _cashAmount,
          'cardAmount': _cardAmount,
          'totalAmount': totalAmount,
          'changeAmount': _changeAmount,
        };
        paymentData['paymentAmount'] = totalAmount;
        paymentData['changeAmount'] = _changeAmount;
      } else {
        if (_paymentAmount <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('To\'lov summasi 0 dan katta bo\'lishi kerak!')),
          );
          return;
        }

        if (_paymentMethod == 'cash' && _paymentAmount < _orderTotal) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Naqd to\'lov summasi yetarli emas! Kerak: ${_currencyFormat.format(_orderTotal)}, Kiritildi: ${_currencyFormat.format(_paymentAmount)}')),
          );
          return;
        }

        paymentData['paymentAmount'] = _paymentAmount;
        paymentData['changeAmount'] = _changeAmount;
      }

      final apiPayload = {
        'orderId': widget.selectedOrder!['_id'] ?? widget.selectedOrder!['id'],
        'paymentData': paymentData,
      };

      final result = await widget.processPayment(apiPayload);

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('To\'lov muvaffaqiyatli qabul qilindi!')),
        );

        _resetForm();
        widget.onClose();
        widget.onPaymentSuccess(result);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'To\'lov qabul qilishda xatolik!')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('To\'lov qabul qilishda xatolik: ${error.toString()}')),
      );
    }
  }

  Widget _buildMixedPaymentValidation() {
    final total = _cashAmount + _cardAmount;
    final isValid = total >= _orderTotal;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? const Color(0xFFd4edda) : const Color(0xFFf8d7da),
        border: Border.all(
          color: isValid ? const Color(0xFFc3e6cb) : const Color(0xFFf5c6cb),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jami to\'lov:'),
              Text(
                '${_currencyFormat.format(total)} so\'m',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kerakli summa:'),
              Text('${_currencyFormat.format(_orderTotal)} so\'m'),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(total >= _orderTotal ? '✅ Yetarli' : '❌ Yetarli emas'),
              Text(
                _currencyFormat.format(total - _orderTotal),
                style: TextStyle(
                  color: total >= _orderTotal ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFf0f8f0),
        border: Border.all(color: const Color(0xFFb7eb8f)),
        borderRadius: BorderRadius.circular(6),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Zakaz summasi:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${_currencyFormat.format(_orderTotal)} so\'m', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),

          if (_paymentMethod == 'mixed') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Naqd:'),
                Text('${_currencyFormat.format(_cashAmount)} so\'m'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Karta:'),
                Text('${_currencyFormat.format(_cardAmount)} so\'m'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Jami to\'lov:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '${_currencyFormat.format(_cashAmount + _cardAmount)} so\'m',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('To\'lov usuli:'),
                Text(
                  _paymentMethod == 'cash' ? '💵 Naqd' :
                  _paymentMethod == 'card' ? '💳 Karta' : '📱 Click',
                ),
              ],
            ),
          ],

          if (_changeAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Qaytim:', style: TextStyle(color: Color(0xFF52c41a), fontWeight: FontWeight.bold)),
                Text(
                  '${_currencyFormat.format(_changeAmount)} so\'m',
                  style: const TextStyle(color: Color(0xFF52c41a), fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Column(
                children: [
                  const Text(
                    '💰 TO\'LOV QABUL QILISH',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Zakaz #${widget.selectedOrder?['formatted_order_number'] ?? widget.selectedOrder?['orderNumber']}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Order total
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFf8f9fa),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Zakaz summasi:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${_currencyFormat.format(_orderTotal)} so\'m',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF28a745),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Payment method
              const Text('To\'lov usuli', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ToggleButtons(
                isSelected: [
                  _paymentMethod == 'cash',
                  _paymentMethod == 'card',
                  _paymentMethod == 'click',
                  _paymentMethod == 'mixed',
                ],
                onPressed: (index) {
                  final methods = ['cash', 'card', 'click', 'mixed'];
                  _handlePaymentMethodChange(methods[index]);
                },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('💵 Naqd'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('💳 Karta'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('📱 Click'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('🔄 Aralash'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Payment amount fields
              if (_paymentMethod != 'mixed')
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('To\'lov summasi'),
                          const SizedBox(height: 8),
                          TextFormField(
                            keyboardType: TextInputType.number,
                            enabled: !['card', 'click', 'transfer'].contains(_paymentMethod),
                            initialValue: _paymentAmount.toStringAsFixed(0),
                            decoration: const InputDecoration(
                              hintText: 'Summa',
                            ),
                            validator: (value) {
                              final amount = double.tryParse(value ?? '') ?? 0;

                              if (amount <= 0) {
                                return 'To\'lov summasi 0 dan katta bo\'lishi kerak!';
                              }

                              if (_paymentMethod == 'cash' && amount < _orderTotal) {
                                return 'Naqd to\'lov summasi yetarli emas!';
                              }

                              if (['card', 'click', 'transfer'].contains(_paymentMethod) &&
                                  (amount - _orderTotal).abs() > 1) {
                                return 'Karta/Click/Transfer uchun aniq summa kiriting!';
                              }

                              return null;
                            },
                            onChanged: (value) {
                              final amount = double.tryParse(value ?? '') ?? 0;
                              setState(() {
                                _paymentAmount = amount;
                                if (_paymentMethod == 'cash') {
                                  _changeAmount = (amount - _orderTotal).clamp(0, double.infinity);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    if (_paymentMethod == 'cash')
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Qaytim'),
                            const SizedBox(height: 8),
                            TextFormField(
                              enabled: false,
                              initialValue: _changeAmount.toStringAsFixed(0),
                              decoration: const InputDecoration(
                                hintText: 'Qaytim',
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (['card', 'click', 'transfer'].contains(_paymentMethod))
                      Expanded(
                        flex: 6,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFe6f7ff),
                            border: Border.all(color: const Color(0xFF91d5ff)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _paymentMethod == 'card'
                                ? '💳 Karta to\'lov - aniq summa'
                                : '📱 Click to\'lov - aniq summa',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0050b3),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

              // Mixed payment
              if (_paymentMethod == 'mixed') ...[
                const Divider(),
                const Text('Aralash to\'lov (Naqd + Karta)'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Naqd summa'),
                          const SizedBox(height: 8),
                          TextFormField(
                            keyboardType: TextInputType.number,
                            initialValue: _cashAmount.toStringAsFixed(0),
                            decoration: const InputDecoration(
                              hintText: 'Naqd',
                            ),
                            validator: (value) {
                              final amount = double.tryParse(value ?? '') ?? 0;
                              if (amount <= 0) {
                                return 'Naqd summa 0\'dan katta bo\'lishi kerak!';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              final amount = double.tryParse(value ?? '') ?? 0;
                              setState(() {
                                _cashAmount = amount;
                                final total = amount + _cardAmount;
                                _changeAmount = (total - _orderTotal).clamp(0, double.infinity);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Karta summa'),
                          const SizedBox(height: 8),
                          TextFormField(
                            keyboardType: TextInputType.number,
                            initialValue: _cardAmount.toStringAsFixed(0),
                            decoration: const InputDecoration(
                              hintText: 'Karta',
                            ),
                            validator: (value) {
                              final amount = double.tryParse(value ?? '') ?? 0;
                              if (amount <= 0) {
                                return 'Karta summa 0\'dan katta bo\'lishi kerak!';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              final amount = double.tryParse(value ?? '') ?? 0;
                              setState(() {
                                _cardAmount = amount;
                                final total = _cashAmount + amount;
                                _changeAmount = (total - _orderTotal).clamp(0, double.infinity);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Qaytim'),
                          const SizedBox(height: 8),
                          TextFormField(
                            enabled: false,
                            initialValue: _changeAmount.toStringAsFixed(0),
                            decoration: const InputDecoration(
                              hintText: 'Qaytim',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildMixedPaymentValidation(),
              ],

              // Notes
              const SizedBox(height: 16),
              const Text('Izohlar'),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(
                  hintText: 'To\'lov haqida qo\'shimcha ma\'lumot...',
                  border: OutlineInputBorder(),
                ),
              ),

              // Payment summary
              const SizedBox(height: 16),
              _buildPaymentSummary(),

              // Buttons
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _resetForm();
                        widget.onClose();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('❌ Bekor qilish'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.isProcessing ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF28a745),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        widget.isProcessing
                            ? '⏳ Qayta ishlanmoqda...'
                            : '✅ To\'lovni qabul qilish',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
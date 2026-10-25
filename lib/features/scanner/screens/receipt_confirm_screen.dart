import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/thousands_separator_input_formatter.dart';
import '../../../data/models/transaction_item.dart';
import '../../extraction/receipt_parser.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../transactions/utils/category_helper.dart';

/// Screen allowing the user to review, edit and confirm values extracted via OCR before saving.
class ReceiptConfirmScreen extends ConsumerStatefulWidget {
  final ParsedReceiptResult parsedResult;
  final String? thumbnailPath;
  final int ocrDurationMs;

  const ReceiptConfirmScreen({
    super.key,
    required this.parsedResult,
    this.thumbnailPath,
    required this.ocrDurationMs,
  });

  @override
  ConsumerState<ReceiptConfirmScreen> createState() =>
      _ReceiptConfirmScreenState();
}

class _ReceiptConfirmScreenState extends ConsumerState<ReceiptConfirmScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  late TextEditingController _noteController;

  late DateTime _selectedDate;
  late String _selectedCategory;
  bool _isSaving = false;
  bool _showRawText = false;

  @override
  void initState() {
    super.initState();
    final ParsedReceiptResult r = widget.parsedResult;
    final NumberFormat format = NumberFormat('#,###', 'vi_VN');
    _amountController = TextEditingController(
      text: r.amount != null ? format.format(r.amount!) : '',
    );
    _merchantController = TextEditingController(text: r.merchant ?? '');
    _noteController = TextEditingController();

    _selectedDate = r.date ?? DateTime.now();
    _selectedCategory = AppConstants.defaultCategories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _confirmAndSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final int amount = int.parse(
      _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final String? merchant = _merchantController.text.trim().isEmpty
        ? null
        : _merchantController.text.trim();
    final String? note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    final TransactionItem transaction = TransactionItem(
      amount: amount,
      date: _selectedDate,
      merchant: merchant,
      category: _selectedCategory,
      note: note,
      thumbnailPath: widget.thumbnailPath,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(transactionListProvider.notifier).addTransaction(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu giao dịch thành công!'),
            backgroundColor: Color(0xFF00684A),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi lưu giao dịch: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận thông tin hóa đơn'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Thumbnail preview
              if (widget.thumbnailPath != null &&
                  File(widget.thumbnailPath!).existsSync()) ...<Widget>[
                Center(
                  child: Container(
                    height: 160,
                    width: 160,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      image: DecorationImage(
                        image: FileImage(File(widget.thumbnailPath!)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],

              // OCR Latency Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.bolt_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Thời gian nhận diện OCR: ${widget.ocrDurationMs} ms (on-device)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Notice pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vui lòng kiểm tra và chỉnh sửa lại các trường trước khi lưu.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: <TextInputFormatter>[
                  ThousandsSeparatorInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Số tiền (VND) *',
                  hintText: 'Nhập số tiền hóa đơn',
                  prefixIcon: Icon(Icons.monetization_on_outlined),
                  suffixText: '₫',
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập số tiền';
                  }
                  final int? parsed = int.tryParse(
                    value.replaceAll(RegExp(r'[^0-9]'), ''),
                  );
                  if (parsed == null || parsed <= 0) {
                    return 'Số tiền phải lớn hơn 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date field
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Ngày giao dịch',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: Text(
                    dateFormatter.format(_selectedDate),
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ),
              if (widget.parsedResult.date == null) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.info_outline, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Không tìm thấy ngày, đang dùng hôm nay',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (widget.parsedResult.date!.isAfter(DateTime.now())) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade800),
                      const SizedBox(width: 4),
                      Text(
                        'Lưu ý: Ngày trên hóa đơn là ngày trong tương lai',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Danh mục *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: AppConstants.defaultCategories.map((String cat) {
                  return DropdownMenuItem<String>(
                    value: cat,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          CategoryHelper.getIcon(cat),
                          color: CategoryHelper.getColor(cat),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(cat),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Merchant field
              TextFormField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Tên quán / Cửa hàng / Người nhận',
                  hintText: 'VD: Highlands, Circle K...',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Note field
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú',
                  hintText: 'Ghi chú thêm về giao dịch này...',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Raw OCR Text accordion for inspection/transparency
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  title: const Text(
                    'Xem văn bản OCR gốc',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  leading: const Icon(Icons.subject_rounded),
                  initiallyExpanded: _showRawText,
                  onExpansionChanged: (bool expanded) {
                    setState(() {
                      _showRawText = expanded;
                    });
                  },
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        widget.parsedResult.rawText.isNotEmpty
                            ? widget.parsedResult.rawText
                            : '(Không nhận diện được ký tự nào)',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Confirm button
              FilledButton.icon(
                onPressed: _isSaving ? null : _confirmAndSave,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text(
                  'Xác nhận & Lưu chi tiêu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

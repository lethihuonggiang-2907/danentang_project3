import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/transaction_item.dart';
import '../providers/transaction_provider.dart';
import '../utils/category_helper.dart';

/// Screen to manually create or edit an existing expense transaction.
class AddEditTransactionScreen extends ConsumerStatefulWidget {
  final TransactionItem? initialItem;

  const AddEditTransactionScreen({
    super.key,
    this.initialItem,
  });

  @override
  ConsumerState<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState
    extends ConsumerState<AddEditTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TextEditingController _amountController;
  late TextEditingController _merchantController;
  late TextEditingController _noteController;

  late DateTime _selectedDate;
  late String _selectedCategory;
  String? _thumbnailPath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final TransactionItem? item = widget.initialItem;
    _amountController = TextEditingController(
      text: item != null ? item.amount.toString() : '',
    );
    _merchantController = TextEditingController(text: item?.merchant ?? '');
    _noteController = TextEditingController(text: item?.note ?? '');

    _selectedDate = item?.date ?? DateTime.now();
    _selectedCategory = item?.category ?? AppConstants.defaultCategories.first;
    _thumbnailPath = item?.thumbnailPath;
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

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final int amount = int.parse(_amountController.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final String? merchant = _merchantController.text.trim().isEmpty
        ? null
        : _merchantController.text.trim();
    final String? note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();

    final TransactionItem toSave = TransactionItem(
      id: widget.initialItem?.id,
      amount: amount,
      date: _selectedDate,
      merchant: merchant,
      category: _selectedCategory,
      note: note,
      thumbnailPath: _thumbnailPath,
      createdAt: widget.initialItem?.createdAt ?? DateTime.now(),
    );

    try {
      if (widget.initialItem == null) {
        await ref.read(transactionListProvider.notifier).addTransaction(toSave);
      } else {
        await ref
            .read(transactionListProvider.notifier)
            .updateTransaction(toSave);
      }

      if (mounted) {
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
    final bool isEditing = widget.initialItem != null;
    final ThemeData theme = Theme.of(context);
    final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Sửa giao dịch' : 'Thêm giao dịch'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Optional receipt thumbnail display
              if (_thumbnailPath != null && File(_thumbnailPath!).existsSync()) ...<Widget>[
                Center(
                  child: Container(
                    height: 140,
                    width: 140,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      image: DecorationImage(
                        image: FileImage(File(_thumbnailPath!)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],

              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền (VND) *',
                  hintText: 'VD: 150000',
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

              // Date Picker Field
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
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Danh mục *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: AppConstants.defaultCategories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Row(
                      children: <Widget>[
                        Icon(
                          CategoryHelper.getIcon(category),
                          color: CategoryHelper.getColor(category),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(category),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
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
                  hintText: 'VD: Circle K, Highland Coffee...',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Note field
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Ghi chú thêm',
                  hintText: 'Ăn trưa, tài liệu học tập...',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 32),

              // Save button
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveTransaction,
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
                    : const Icon(Icons.check_rounded),
                label: Text(
                  isEditing ? 'Cập nhật giao dịch' : 'Lưu giao dịch',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_item.dart';
import '../../scanner/screens/scanner_screen.dart';
import '../providers/transaction_provider.dart';
import '../utils/category_helper.dart';
import 'add_edit_transaction_screen.dart';

/// Screen displaying the list of all expense transactions with category filter chips,
/// search, swipe-to-delete, and quick add actions.
class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  String? _selectedCategoryFilter;

  void _showAddActionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.document_scanner_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: const Text(
                    'Quét hóa đơn (OCR)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Chụp hoặc chọn ảnh hóa đơn để AI tự điền thông tin',
                  ),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (BuildContext context) => const ScannerScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  title: const Text(
                    'Thêm chi tiêu thủ công',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text('Nhập số tiền và chi tiết tự do'),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<bool>(
                        builder: (BuildContext context) =>
                            const AddEditTransactionScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TransactionItem>> transactionsAsync =
        ref.watch(transactionListProvider);
    final ThemeData theme = Theme.of(context);
    final DateFormat dateFormatter = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Giao dịch chi tiêu'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'manual_add_fab',
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm chi tiêu'),
        onPressed: () => _showAddActionSheet(context),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object err, StackTrace stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Đã xảy ra lỗi: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () => ref.invalidate(transactionListProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
        data: (List<TransactionItem> allItems) {
          if (allItems.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 72,
                      color: theme.colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có giao dịch nào',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhấn "Thêm chi tiêu" hoặc quét hóa đơn để bắt đầu theo dõi tài chính!',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Apply category filter
          final List<TransactionItem> displayedItems =
              _selectedCategoryFilter == null
                  ? allItems
                  : allItems
                      .where((TransactionItem item) =>
                          item.category == _selectedCategoryFilter)
                      .toList();

          // Calculate total sum for banner
          final int totalSpending = displayedItems.fold<int>(
            0,
            (int sum, TransactionItem item) => sum + item.amount,
          );

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(transactionListProvider);
              await ref.read(transactionListProvider.future);
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              itemCount: displayedItems.length + 2, // 0: banner, 1: filters, 2..: items
              itemBuilder: (BuildContext context, int index) {
                // Header summary banner
                if (index == 0) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _selectedCategoryFilter == null
                              ? 'Tổng chi tiêu đã ghi nhận'
                              : 'Chi tiêu cho: $_selectedCategoryFilter',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          CurrencyFormatter.formatVND(totalSpending),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${displayedItems.length} giao dịch',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Filter chips row
                if (index == 1) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: <Widget>[
                        FilterChip(
                          label: const Text('Tất cả'),
                          selected: _selectedCategoryFilter == null,
                          onSelected: (bool selected) {
                            setState(() {
                              _selectedCategoryFilter = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ...AppConstants.defaultCategories.map(
                          (String category) {
                            final bool isSel =
                                _selectedCategoryFilter == category;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                avatar: Icon(
                                  CategoryHelper.getIcon(category),
                                  size: 16,
                                  color: isSel
                                      ? Colors.white
                                      : CategoryHelper.getColor(category),
                                ),
                                label: Text(category),
                                selected: isSel,
                                onSelected: (bool selected) {
                                  setState(() {
                                    _selectedCategoryFilter =
                                        selected ? category : null;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }

                // Empty filtered result
                if (displayedItems.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Không có giao dịch nào thuộc danh mục $_selectedCategoryFilter',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }

                final TransactionItem item = displayedItems[index - 2];
                final Color categoryColor =
                    CategoryHelper.getColor(item.category);
                final IconData categoryIcon =
                    CategoryHelper.getIcon(item.category);

                return Dismissible(
                  key: ValueKey<int>(item.id ?? index),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        Icon(Icons.delete_outline_rounded,
                            color: Colors.white, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'Xóa',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  confirmDismiss: (DismissDirection direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (BuildContext dialogContext) => AlertDialog(
                        title: const Text('Xác nhận xóa'),
                        content: Text(
                          'Bạn có chắc chắn muốn xóa giao dịch ${CurrencyFormatter.formatVND(item.amount)} không?',
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('Hủy'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                            ),
                            child: const Text('Xóa'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (DismissDirection direction) {
                    if (item.id != null) {
                      ref
                          .read(transactionListProvider.notifier)
                          .deleteTransaction(item.id!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Đã xóa giao dịch ${CurrencyFormatter.formatVND(item.amount)}',
                          ),
                        ),
                      );
                    }
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<bool>(
                            builder: (BuildContext context) =>
                                AddEditTransactionScreen(initialItem: item),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: <Widget>[
                            // Category Icon / Thumbnail Avatar
                            if (item.thumbnailPath != null &&
                                File(item.thumbnailPath!).existsSync()) ...<Widget>[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(item.thumbnailPath!),
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ] else ...<Widget>[
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  categoryIcon,
                                  color: categoryColor,
                                  size: 24,
                                ),
                              ),
                            ],
                            const SizedBox(width: 14),

                            // Main Details: Merchant, Category, Note, Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    item.merchant ?? item.category,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: <Widget>[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: categoryColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.category,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: categoryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        dateFormatter.format(item.date),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.note != null &&
                                      item.note!.isNotEmpty) ...<Widget>[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.note!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.7),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Amount display
                            Text(
                              '-${CurrencyFormatter.formatVND(item.amount)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pos_print/Auth/printer_services.dart';
import '../utils/app_colors.dart';

class BillPreviewPage extends StatefulWidget {
  const BillPreviewPage({super.key});

  @override
  State<BillPreviewPage> createState() => _BillPreviewPageState();
}

class _BillPreviewPageState extends State<BillPreviewPage> {
  final GlobalKey _receiptKey = GlobalKey(); // receipt capture ke liye
  bool _printing = false;

  // (naam, qty, rate) - baad me API/DB se replace karna
  static const items = <(String, int, double)>[
    ('Product B', 10, 250.0),
    ('Product Name A', 1, 1200.0),
    ('Product C', 10, 500.0),
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('[PRINT] BillPreviewPage open hua');
    PrinterService.logDeviceInfo(); // device info logcat/console me aayegi
  }

  Future<void> _onPrintPressed() async {
    if (_printing) return;
    debugPrint('[PRINT] >>> print icon tap hua');
    setState(() => _printing = true);

    final ok = await PrinterService.printReceipt(_receiptKey);

    debugPrint('[PRINT] <<< print khatam, success = $ok');
    if (!mounted) return;
    setState(() => _printing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppColors.success : AppColors.error,
        content: Text(ok ? 'Print bhej diya gaya' : 'Print fail - console/logcat me [PRINT] ya POS_PRINT dekho'),
      ),
    );
  }

  Text _t(String s, {double size = 12, bool bold = true, TextAlign align = TextAlign.left, TextDecoration? deco}) =>
      Text(s, textAlign: align, style: TextStyle(fontSize: size, color: AppColors.textPrimary, decoration: deco, fontWeight: bold ? FontWeight.bold : FontWeight.normal));

  Widget _lr(String a, String b, {double size = 12}) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_t(a, size: size), _t(b, size: size)]);

  Widget _row(List<String> c, {bool bold = true, bool center = false, double size = 12, List<int> flex = const [1, 5, 1, 2, 2]}) => Row(children: [
    for (final (i, s) in c.indexed)
      Expanded(flex: flex[i], child: _t(s, size: size, bold: bold, align: center ? TextAlign.center : (i < 2 ? TextAlign.left : TextAlign.right))),
  ]);

  Widget get _line => const Divider(color: Colors.grey, height: 12);

  Widget get _doubleLine => Container(
    height: 6,
    margin: const EdgeInsets.symmetric(vertical: 6),
    decoration: const BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: Colors.grey, width: 1.5))),
  );

  @override
  Widget build(BuildContext context) {
    final qty = items.fold<int>(0, (s, e) => s + e.$2);
    final gross = items.fold<double>(0, (s, e) => s + e.$2 * e.$3);
    final net = gross - 790;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: const Text('Bill Preview', style: TextStyle(color: AppColors.white)),
        centerTitle: true,
        actions: [
          _printing
              ? const Padding(
            padding: EdgeInsets.all(14),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white)),
          )
              : IconButton(icon: const Icon(Icons.print), tooltip: 'Print', onPressed: _onPrintPressed),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: RepaintBoundary(
            key: _receiptKey, // isi widget ki image print hogi
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: Colors.grey.shade400)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _t('Sales Invoice', size: 11, bold: false, align: TextAlign.center),
                  _t('Manan Agency', size: 18, align: TextAlign.center),
                  _t('A/12. Shrenik Park, Opp. Jain Temple, Akota,\nVadodara,\nPh. M. 9727955514\nE Mail : softwareketan@gmail.com\nGSTIN =  24AKPPP1343N1ZR', align: TextAlign.center),
                  _line,
                  _lr('Bill No.: 17', 'Date : 09-Jun-2020\nTime : 20:03:22'),
                  _line,
                  _t('To, Mamta Kulkarni'),
                  _t('Add Line 1,Ass Line 2,City name, Ph : 9898989898', bold: false),
                  _t('GSTIN : test gstin', bold: false),
                  _line,
                  _row(['Sr.', 'Description', 'Qty', 'Rate', 'Amount']),
                  const SizedBox(height: 4),
                  for (final (i, (name, q, r)) in items.indexed)
                    _row(['${i + 1}', name, '$q', r.toStringAsFixed(2), (q * r).toStringAsFixed(2)], bold: false),
                  _line,
                  _t('Total Qty    $qty'),
                  _lr('Item Discount  Inclusive', '571.43'),
                  _line,
                  _lr('Gross Amount After Discount', gross.toStringAsFixed(2)),
                  _lr('Bill Discount', '790.00'),
                  _line,
                  _lr('Net Amount', net.toStringAsFixed(2), size: 20),
                  _doubleLine,
                  _t('Rupee Seven Thousand and One Hundred Ten Only', bold: false),
                  const SizedBox(height: 6),
                  _t('Tender Details', size: 13, align: TextAlign.center, deco: TextDecoration.underline),
                  const SizedBox(height: 4),
                  _lr('Advance Amount', '7,110.00'),
                  _lr('Balance Amount', '0.00'),
                  _t('Cash : 7,110.00, Credit Card : 0.00, Card Bank 0.00Card\nBank Wallet : 0.00 Card Bank Chq. 0.00 Card Bank', size: 10.5, bold: false, align: TextAlign.center),
                  _line,
                  _t('Have a Nice Day', align: TextAlign.center),
                  _t('Thanks for your Kind Visit', size: 11, bold: false, align: TextAlign.center),
                  _t('DETAILS OF GST TAX', align: TextAlign.center),
                  const SizedBox(height: 4),
                  _row(['Taxable', 'SGST%', 'Amt.', 'CGST %', 'Amt.'], center: true, size: 10, flex: const [1, 1, 1, 1, 1]),
                  _row(['7523.85', '2.5 %', '188.09', '2.5 %', '188.09'], center: true, size: 10, flex: const [1, 1, 1, 1, 1]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:pos_print/Auth/printer_services.dart';
import '../utils/app_colors.dart';

class BillPreviewPage extends StatefulWidget {
  const BillPreviewPage({super.key});

  @override
  State<BillPreviewPage> createState() => _BillPreviewPageState();
}

class _BillPreviewPageState extends State<BillPreviewPage> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _printing = false;
  static const items = <(String, int, double)>[
    ('Rice 1kg', 1, 250.0),
    ('Wheat Flour 5kg', 4, 104.0),
    ('Sugar 1kg', 7, 330.0),
    ('Salt 1kg', 3, 1215.0),
    ('Tea Powder 250g', 6, 650.0),
    ('Coffee 100g', 2, 50.0),
    ('Milk 1L', 5, 510.0),
    ('Butter 100g', 1, 150.0),
    ('Cheese Slice', 4, 180.0),
    ('Paneer 200g', 7, 80.0),
    ('Curd 400g', 3, 260.0),
    ('Ghee 500ml', 6, 114.0),
    ('Sunflower Oil 1L', 2, 320.0),
    ('Mustard Oil 1L', 5, 1205.0),
    ('Toor Dal 1kg', 1, 660.0),
    ('Moong Dal 1kg', 4, 60.0),
    ('Chana Dal 1kg', 7, 500.0),
    ('Urad Dal 1kg', 3, 140.0),
    ('Masoor Dal 1kg', 6, 190.0),
    ('Rajma 500g', 2, 90.0),
    ('Poha 500g', 5, 250.0),
    ('Suji 500g', 1, 104.0),
    ('Besan 500g', 4, 330.0),
    ('Maida 1kg', 7, 1215.0),
    ('Oats 400g', 3, 650.0),
    ('Corn Flakes', 6, 50.0),
    ('Biscuits Pack', 2, 510.0),
    ('Cream Biscuit', 5, 150.0),
    ('Namkeen 200g', 1, 180.0),
    ('Chips Large', 4, 80.0),
    ('Noodles Pack', 7, 260.0),
    ('Pasta 500g', 3, 114.0),
    ('Ketchup 500g', 6, 320.0),
    ('Jam 500g', 2, 1205.0),
    ('Honey 250g', 5, 660.0),
    ('Pickle 400g', 1, 60.0),
    ('Papad Pack', 4, 500.0),
    ('Turmeric 100g', 7, 140.0),
    ('Red Chilli 100g', 3, 190.0),
    ('Coriander 100g', 6, 90.0),
    ('Cumin 100g', 2, 250.0),
    ('Garam Masala', 5, 104.0),
    ('Black Pepper', 1, 330.0),
    ('Cardamom 50g', 4, 1215.0),
    ('Cloves 50g', 7, 650.0),
    ('Cinnamon 50g', 3, 50.0),
    ('Bay Leaf', 6, 510.0),
    ('Mustard Seeds', 2, 150.0),
    ('Tamarind 200g', 5, 180.0),
    ('Jaggery 500g', 1, 80.0),
    ('Soap Bar', 4, 260.0),
    ('Bath Soap Pack', 7, 114.0),
    ('Shampoo 180ml', 3, 320.0),
    ('Conditioner', 6, 1205.0),
    ('Face Wash', 2, 660.0),
    ('Toothpaste', 5, 60.0),
    ('Toothbrush', 1, 500.0),
    ('Mouthwash', 4, 140.0),
    ('Hair Oil 200ml', 7, 190.0),
    ('Body Lotion', 3, 90.0),
    ('Talcum Powder', 6, 250.0),
    ('Deodorant', 2, 104.0),
    ('Razor Pack', 5, 330.0),
    ('Shaving Cream', 1, 1215.0),
    ('Sanitary Pads', 4, 650.0),
    ('Hand Wash', 7, 50.0),
    ('Sanitizer 100ml', 3, 510.0),
    ('Detergent 1kg', 6, 150.0),
    ('Dish Wash Bar', 2, 180.0),
    ('Dish Wash Liquid', 5, 80.0),
    ('Floor Cleaner', 1, 260.0),
    ('Toilet Cleaner', 4, 114.0),
    ('Glass Cleaner', 7, 320.0),
    ('Phenyl 500ml', 3, 1205.0),
    ('Garbage Bags', 6, 660.0),
    ('Tissue Roll', 2, 60.0),
    ('Napkin Pack', 5, 500.0),
    ('Aluminium Foil', 1, 140.0),
    ('Cling Wrap', 4, 190.0),
    ('Matchbox Pack', 7, 90.0),
    ('Candle Pack', 3, 250.0),
    ('Agarbatti Pack', 6, 104.0),
    ('Camphor Pack', 2, 330.0),
    ('Notebook A4', 5, 1215.0),
    ('Ball Pen Pack', 1, 650.0),
    ('Pencil Box', 4, 50.0),
    ('Eraser Pack', 7, 510.0),
    ('Marker Pen', 3, 150.0),
    ('Glue Stick', 6, 180.0),
    ('Scotch Tape', 2, 80.0),
    ('Water Bottle 1L', 5, 260.0),
    ('Mineral Water 20L', 1, 114.0),
    ('Cold Drink 2L', 4, 320.0),
    ('Orange Juice 1L', 7, 1205.0),
    ('Soda 750ml', 3, 660.0),
    ('Energy Drink', 6, 60.0),
    ('Green Tea Box', 2, 500.0),
    ('Mango Pickle', 5, 140.0),
    ('Dry Fruits 250g', 1, 190.0),
    ('Cashew 250g', 4, 90.0),
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('[PRINT] BillPreviewPage open hua');
    PrinterService.logDeviceInfo();
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
        content: Text(ok ? 'Print request sent successfully' : 'Print failed - please check the console/logcat for [PRINT] or POS_PRINT logs')
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
            key: _receiptKey,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: Colors.grey.shade400)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _t('Sales Invoice', size: 11, bold: false, align: TextAlign.center),
                  _t('Anurag Pratap', size: 18, align: TextAlign.center),
                  _t('A/12. Shrenik Park, Opp. Jain Temple, Akota,\nVadodara,\nPh. M. 9727955514\nE Mail : softwareketan@gmail.com\nGSTIN =  24AKPPP1343N1ZR', align: TextAlign.center),
                  _line,
                  _lr('Bill No.: 17', 'Date : 09-Jun-2020\nTime : 20:03:22'),
                  _line,
                  _t('To, Bspl Haridwar'),
                  _t('Add Line 1,Ass Line 2,City name, Ph : 9807237945', bold: false),
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
import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern('id_ID');

  static String formatRupiah(num? amount) {
    if (amount == null) return 'Rp 0';
    return _rupiahFormat.format(amount);
  }

  static String formatNumber(num? amount, {int decimalDigits = 2}) {
    if (amount == null) return '0';
    if (amount % 1 == 0) {
      return _numberFormat.format(amount.toInt());
    }
    return amount.toStringAsFixed(decimalDigits);
  }

  static String formatPercent(num? percent) {
    if (percent == null) return '0.00%';
    return '${percent.toStringAsFixed(2)}%';
  }
}

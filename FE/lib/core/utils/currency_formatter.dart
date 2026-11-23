import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _rupiahFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _intFormat = NumberFormat.decimalPattern('id_ID');
  static final NumberFormat _decFormat = NumberFormat('#,##0.##', 'id_ID');

  static String formatRupiah(num? amount) {
    if (amount == null) return 'Rp 0';
    return _rupiahFormat.format(amount);
  }

  /// Format tarif rupiah dengan presisi desimal jika bukan bilangan bulat (mis. 0.5 -> Rp 0,5, 1.5 -> Rp 1,5).
  static String formatRate(num? rate) {
    if (rate == null) return 'Rp 0';
    if (rate % 1 == 0) {
      return 'Rp ${_intFormat.format(rate.toInt())}';
    }
    return 'Rp ${_decFormat.format(rate)}';
  }

  static String formatNumber(num? amount, {int decimalDigits = 2}) {
    if (amount == null) return '0';
    if (amount % 1 == 0) {
      return _intFormat.format(amount.toInt());
    }
    if (decimalDigits == 2) {
      return _decFormat.format(amount);
    }
    final pattern = decimalDigits <= 0 ? '#,##0' : '#,##0.${'#' * decimalDigits}';
    return NumberFormat(pattern, 'id_ID').format(amount);
  }

  static String formatPercent(num? percent) {
    if (percent == null) return '0.00%';
    return '${percent.toStringAsFixed(2)}%';
  }
}

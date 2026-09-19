import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../services/bank_service.dart';

// ---------------------------------------------------------------- สี (ตามไฟล์ bank_UI.pdf)

const brandColor = Color(0xFFCAE474); // เขียวมะนาว สีหลักของแอพ
const linkColor = Color(0xFF9DAA6D); // ลิงก์ เช่น "สมัครสมาชิก"
const incomeColor = Color(
  0xFF8FB339,
); // ตัวเลขเงินเข้า (เข้มกว่าสีหลักนิดหน่อยให้อ่านง่าย)
const dangerColor = Color(0xFFFF3131); // ปุ่มลบ / ออกจากระบบ / เงินออก
const greyBoxColor = Color(0xFFE7E6E6); // กล่องแสดงชื่อผู้รับโอน

/// ธีมของทั้งแอพ
ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandColor,
      primary: Colors.black,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
  );

  const fieldRadius = BorderRadius.all(Radius.circular(12));

  return base.copyWith(
    textTheme: GoogleFonts.kanitTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      scrolledUnderElevation: 3,
      shadowColor: Colors.black26,
      titleTextStyle: GoogleFonts.kanit(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      prefixIconColor: brandColor,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: fieldRadius),
      enabledBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: Colors.black, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: Colors.black, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: dangerColor, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: dangerColor, width: 2.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: brandColor,
        foregroundColor: Colors.black,
        disabledBackgroundColor: brandColor.withValues(alpha: 0.5),
        minimumSize: const Size(64, 52),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.kanit(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        side: const BorderSide(color: brandColor, width: 2),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.black),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: brandColor),
  );
}

// ---------------------------------------------------------------- ฟังก์ชันช่วย

final _money = NumberFormat('#,##0.00');

String formatMoney(double amount) => '${_money.format(amount)} ฿';

/// 1234567890 -> 123-4-56789-0 (รูปแบบเลขบัญชีแบบธนาคารไทย)
String formatAccountNumber(String n) {
  if (n.length != 10) return n;
  return '${n.substring(0, 3)}-${n.substring(3, 4)}-'
      '${n.substring(4, 9)}-${n.substring(9)}';
}

String errorMessage(Object e) =>
    e is BankException ? e.message : 'เกิดข้อผิดพลาด: $e';

void showMessage(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: error ? Colors.white : Colors.black),
        ),
        backgroundColor: error ? dangerColor : brandColor,
      ),
    );
}

// ---------------------------------------------------------------- Popup

/// Popup แจ้งผลสำเร็จ (วงกลมเขียวมีเครื่องหมายถูก) / ไม่สำเร็จ (วงกลมแดงมีกากบาท)
Future<void> showResultDialog(
  BuildContext context, {
  required bool success,
  required String title,
  required String message,
}) {
  return showDialog(
    context: context,
    builder: (_) => AlertDialog(
      icon: CircleAvatar(
        radius: 36,
        backgroundColor: success ? brandColor : dangerColor,
        child: Icon(
          success ? Icons.check_rounded : Icons.close_rounded,
          color: Colors.white,
          size: 52,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
      ),
      content: Text(message, style: const TextStyle(fontSize: 16)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ตกลง'),
        ),
      ],
    ),
  );
}

/// Popup ถามยืนยัน มีปุ่ม "ยกเลิก" + ปุ่มยืนยัน (danger = ปุ่มสีแดง)
/// คืนค่า true ถ้ากดยืนยัน
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required Widget content,
  required String confirmLabel,
  bool danger = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(
        title,
        textAlign: danger ? TextAlign.center : TextAlign.start,
        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
      ),
      content: content,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: dangerColor)
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok == true;
}

// ---------------------------------------------------------------- Widget ที่ใช้ร่วมกัน

/// การ์ดสีขาวมีเงา ขอบมน (ใช้กับรายการ, ข้อมูลสมาชิก, อัตราแลกเปลี่ยน)
class ShadowCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const ShadowCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.only(bottom: 16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// การ์ดยอดเงินสีเขียว (ใช้ในหน้าหลัก, โอนเงิน, ถอนเงิน)
class BalanceCard extends StatelessWidget {
  final Account account;
  const BalanceCard({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
      decoration: BoxDecoration(
        color: brandColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          Text(
            formatAccountNumber(account.accountNumber),
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 28),
          const Text('ยอดเงินคงเหลือ', style: TextStyle(fontSize: 16)),
          Text(
            formatMoney(account.balance),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// หัวข้อเล็กๆ เหนือส่วนต่างๆ เช่น "จาก", "ไปยัง", "รายการย้อนหลัง"
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// ตัวหมุนเล็กๆ ในปุ่มตอนกำลังโหลด
class ButtonLoading extends StatelessWidget {
  const ButtonLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
    );
  }
}

/// ช่องกรอกจำนวนเงิน ใช้ร่วมกันในหน้าโอน/ถอน
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  const AmountField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(
        hintText: 'จำนวนเงิน (บาท)',
        prefixIcon: Icon(Icons.credit_card),
      ),
      validator: (v) {
        final amount = double.tryParse(v?.trim() ?? '');
        if (amount == null) return 'กรุณากรอกจำนวนเงิน';
        if (amount <= 0) return 'จำนวนเงินต้องมากกว่า 0';
        return null;
      },
    );
  }
}

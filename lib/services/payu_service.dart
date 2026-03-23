import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:universal_html/html.dart' as html;
import '../screens/payment_waiting_screen.dart';

class PayUService {
  // Test credentials
  static const String merchantKey = '3ywZnk';
  static const String merchantSalt = '6iCuFpgpQBelPoJlanIc09w3tGgzLaB3';

  // Test endpoint
  static const String payuUrl = 'https://test.payu.in/_payment';

  /// Start the PayU Checkout flow via the REAL test gateway.
  void startPayment({
    required BuildContext context,
    required String residentId,
    required String adminId,
    required int amount,
    required String name,
    required String email,
    required String phone,
    required String monthLabel,
    Timestamp? dueDate,
    String? hostelId,
    String? pgId,
    String? floorId,
    String? roomId,
    String? bedId,
  }) async {
    // 1. Generate unique transaction ID
    final txnId = 'TXN_${DateTime.now().millisecondsSinceEpoch}';
    final productInfo = "Rent Payment - $monthLabel";
    final amountStr = amount.toStringAsFixed(2);

    // 2. Generate SHA-512 Hash
    final hashSequence =
        '$merchantKey|$txnId|$amountStr|$productInfo|$name|$email|||||||||||$merchantSalt';
    final hashResult = sha512.convert(utf8.encode(hashSequence)).toString();

    // 3. Success/Failure redirect URL — a simple "close this tab" page
    //    PayU will redirect the browser to this URL after payment.
    final redirectPage = Uri.dataFromString(
      '''<html>
        <head><title>Payment Done</title></head>
        <body style="display:flex;align-items:center;justify-content:center;height:100vh;font-family:sans-serif;background:#F8FAFC;">
          <div style="text-align:center;">
            <div style="font-size:64px;margin-bottom:16px;">✅</div>
            <h2 style="color:#14B8A6;">Payment Complete</h2>
            <p style="color:#64748B;">You can close this tab and return to the SmartStay app.</p>
          </div>
        </body>
      </html>''',
      mimeType: 'text/html',
      encoding: Encoding.getByName('utf-8'),
    ).toString();

    // Capture navigator before any async gap
    final navigator = Navigator.of(context, rootNavigator: true);

    // Close the payment method dialog (context is still alive at this point)
    navigator.pop();

    // --------------------------------------------------------------------------
    // FLUTTER WEB: Open PayU in a new tab, navigate app to waiting screen
    // --------------------------------------------------------------------------
    if (kIsWeb) {
      // Create and submit the form to PayU in a new tab
      final form = html.FormElement()
        ..method = 'POST'
        ..action = payuUrl
        ..target = '_blank';

      void addHiddenInput(String fieldName, String value) {
        final input = html.InputElement()
          ..type = 'hidden'
          ..name = fieldName
          ..value = value;
        form.append(input);
      }

      addHiddenInput('key', merchantKey);
      addHiddenInput('hash', hashResult);
      addHiddenInput('txnid', txnId);
      addHiddenInput('amount', amountStr);
      addHiddenInput('firstname', name);
      addHiddenInput('email', email);
      addHiddenInput('phone', phone);
      addHiddenInput('productinfo', productInfo);
      addHiddenInput('surl', redirectPage);
      addHiddenInput('furl', redirectPage);

      html.document.body?.append(form);
      form.submit();
      form.remove();

      // Navigate Flutter app to the waiting screen
      navigator.push(
        MaterialPageRoute(
          builder: (ctx) => PaymentWaitingScreen(
            residentId: residentId,
            adminId: adminId,
            amount: amount,
            monthLabel: monthLabel,
            txnId: txnId,
            residentName: name,
            dueDate: dueDate,
            hostelId: hostelId,
            pgId: pgId,
            floorId: floorId,
            roomId: roomId,
            bedId: bedId,
          ),
        ),
      );
      return;
    }

    // --------------------------------------------------------------------------
    // FLUTTER MOBILE: Launch PayU in external browser
    // --------------------------------------------------------------------------
    final htmlCode = '''
      <html>
        <head><title>PayU Payment</title></head>
        <body onload="document.payu.submit();">
          <div style="text-align:center; margin-top:50px; font-family:sans-serif;">
            <h3>Redirecting to Secure Payment Gateway...</h3>
            <p>Please wait, do not refresh this page.</p>
          </div>
          <form id="payu" name="payu" method="post" action="$payuUrl">
            <input type="hidden" name="key" value="$merchantKey" />
            <input type="hidden" name="hash" value="$hashResult" />
            <input type="hidden" name="txnid" value="$txnId" />
            <input type="hidden" name="amount" value="$amountStr" />
            <input type="hidden" name="firstname" value="$name" />
            <input type="hidden" name="email" value="$email" />
            <input type="hidden" name="phone" value="$phone" />
            <input type="hidden" name="productinfo" value="$productInfo" />
            <input type="hidden" name="surl" value="$redirectPage" />
            <input type="hidden" name="furl" value="$redirectPage" />
          </form>
        </body>
      </html>
    ''';

    final url = Uri.dataFromString(
      htmlCode,
      mimeType: 'text/html',
      encoding: Encoding.getByName('utf-8'),
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);

      // Navigate Flutter app to the waiting screen
      navigator.push(
        MaterialPageRoute(
          builder: (ctx) => PaymentWaitingScreen(
            residentId: residentId,
            adminId: adminId,
            amount: amount,
            monthLabel: monthLabel,
            txnId: txnId,
            residentName: name,
            dueDate: dueDate,
            hostelId: hostelId,
            pgId: pgId,
            floorId: floorId,
            roomId: roomId,
            bedId: bedId,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment Failed to Launch: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

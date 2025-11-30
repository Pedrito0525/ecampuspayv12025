import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

class PaytacaInvoiceService {
  static const String baseUrl = 'https://payment-hub.paytaca.com/api/invoices/';
  static const String webhookUrl =
      'https://weesgvewyuozivhedhej.supabase.co/functions/v1/paytaca-webhook';

  /// Create a Paytaca invoice using xpub/index/wallet_hash.
  static Future<Map<String, dynamic>?> createInvoiceWithXpub({
    required num amount,
    required String xpubKey,
    required int index,
    required String walletHash,
    required String providerTxId,
    String currency = 'PHP',
    String description = 'Wallet top-up',
    String? memo,
  }) async {
    try {
      final url = Uri.parse(baseUrl);

      // IMPORTANT: Use a clean webhook URL (no query params). Providers POST the payload.
      // Any diagnostics should be handled via logs, not query params.
      final cleanWebhookUrl = webhookUrl;

      final body = {
        'recipients': [
          {
            'amount': amount,
            'xpub_key': xpubKey,
            'index': index,
            'wallet_hash': walletHash,
            'description': description,
          },
        ],
        'currency': currency,
        'webhook_url': cleanWebhookUrl,
        'provider_tx_id': providerTxId,
        if (memo != null && memo.isNotEmpty) 'memo': memo,
      };

      // Debug logs
      // Note: Avoid logging secrets
      print('[PaytacaInvoiceService] Creating invoice');
      print('[PaytacaInvoiceService] Webhook URL: ' + cleanWebhookUrl);
      print('[PaytacaInvoiceService] ProviderTxId: ' + providerTxId);
      print('[PaytacaInvoiceService] Request body: ' + json.encode(body));

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      print(
        '[PaytacaInvoiceService] Response status: ' + res.statusCode.toString(),
      );
      print('[PaytacaInvoiceService] Response body: ' + res.body);
      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = json.decode(res.body) as Map<String, dynamic>;

        // Best-effort: extract invoice_id and persist to paytaca_invoices immediately
        final invoiceId = _extractInvoiceId(decoded);
        if (invoiceId != null && invoiceId.isNotEmpty) {
          try {
            await updatePaytacaInvoiceRecord(
              providerTxId: providerTxId,
              invoiceId: invoiceId,
            );
            print('[PaytacaInvoiceService] invoice_id updated: ' + invoiceId);
          } catch (e) {
            print(
              '[PaytacaInvoiceService] Failed to update invoice_id: ' +
                  e.toString(),
            );
          }
        }

        return decoded;
      }
      return null;
    } catch (e) {
      print(
        '[PaytacaInvoiceService] Exception during createInvoiceWithXpub: ' +
            e.toString(),
      );
      return null;
    }
  }

  static String? _extractInvoiceId(Map<String, dynamic> resp) {
    final candidates = <String?>[
      resp['id']?.toString(),
      resp['invoice_id']?.toString(),
      resp['invoiceId']?.toString(),
      if (resp['data'] is Map<String, dynamic>)
        (resp['data'] as Map<String, dynamic>)['id']?.toString(),
      if (resp['invoice'] is Map<String, dynamic>)
        (resp['invoice'] as Map<String, dynamic>)['id']?.toString(),
    ];
    for (final c in candidates) {
      if (c != null && c.trim().isNotEmpty) return c;
    }
    return null;
  }

  /// Extracts a payment URL from a Paytaca invoice response.
  /// Tries common keys and then falls back to a deep scan of string values.
  static String? extractPaymentUrl(Map<String, dynamic> resp) {
    final candidates = <String?>[
      resp['payment_url'] as String?,
      resp['url'] as String?,
      resp['checkout_url'] as String?,
      resp['link'] as String?,
      if (resp['data'] is Map<String, dynamic>)
        (resp['data'] as Map<String, dynamic>)['url'] as String?,
    ];
    for (final c in candidates) {
      if (c != null && c.startsWith('http')) return c;
    }

    // Deep scan
    String? found;
    void scan(dynamic v) {
      if (found != null) return;
      if (v is String) {
        if (v.startsWith('http://') || v.startsWith('https://')) {
          found = v;
        }
      } else if (v is Map) {
        v.values.forEach(scan);
      } else if (v is List) {
        for (final e in v) {
          scan(e);
          if (found != null) break;
        }
      }
    }

    scan(resp);
    return found;
  }

  /// Insert a record into paytaca_invoices table before creating the invoice
  static Future<String?> insertPaytacaInvoiceRecord({
    required String studentId,
    required num amount,
    String currency = 'PHP',
  }) async {
    try {
      await SupabaseService.initialize();

      // Generate a unique provider_tx_id (you can use UUID or timestamp-based ID)
      final providerTxId =
          'paytaca_${DateTime.now().millisecondsSinceEpoch}_${studentId}';

      final response =
          await SupabaseService.client
              .from('paytaca_invoices')
              .insert({
                'provider_tx_id': providerTxId,
                'student_id': studentId,
                'amount': amount,
                'currency': currency,
                'status': 'pending',
              })
              .select('provider_tx_id')
              .single();

      return response['provider_tx_id'] as String?;
    } catch (e) {
      print('Exception inserting paytaca_invoices record: $e');
      return null;
    }
  }

  /// Update the paytaca_invoices record with invoice details after creation
  static Future<bool> updatePaytacaInvoiceRecord({
    required String providerTxId,
    required String invoiceId,
  }) async {
    try {
      await SupabaseService.initialize();

      await SupabaseService.client
          .from('paytaca_invoices')
          .update({'invoice_id': invoiceId})
          .eq('provider_tx_id', providerTxId);

      return true;
    } catch (e) {
      print('Exception updating paytaca_invoices record: $e');
      return false;
    }
  }
}

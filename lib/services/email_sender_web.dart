import 'dart:html' as html;

Future<bool> sendEmail(String url, String payloadJson) async {
  try {
    final iframe = html.IFrameElement()
      ..name = 'gas_target_${DateTime.now().millisecondsSinceEpoch}'
      ..style.display = 'none';
    html.document.body?.append(iframe);

    final form = html.FormElement()
      ..method = 'POST'
      ..action = url
      ..target = iframe.name
      ..style.display = 'none';

    final input = html.InputElement()
      ..type = 'hidden'
      ..name = 'payload'
      ..value = payloadJson;

    form.append(input);
    html.document.body?.append(form);
    form.submit();

    Future.delayed(const Duration(seconds: 10), () {
      form.remove();
      iframe.remove();
    });

    print('📤 Form submitted to Apps Script');
    return true;
  } catch (e) {
    print('Form submit error: $e');
    return false;
  }
}
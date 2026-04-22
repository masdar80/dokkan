import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:dokkan/core/constants/app_strings.dart';

class ExchangeRateService {
  Future<double?> fetchExchangeRate() async {
    try {
      final response = await http.get(Uri.parse(AppStrings.exchangeRateUrl));
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        
        // البحث عن النص "Sell" في الصفحة
        // بناءً على هيكل الموقع sp-today.com
        // <p ...>Sell</p> يتبعه <p ...><span>13,050</span><span>SYP</span></p>
        
        var paragraphs = document.getElementsByTagName('p');
        for (int i = 0; i < paragraphs.length; i++) {
          if (paragraphs[i].text.trim().toLowerCase() == 'sell') {
            // العنصر التالي غالباً يحتوي على السعر
            var nextElement = paragraphs[i].nextElementSibling;
            if (nextElement != null) {
              var priceSpan = nextElement.querySelector('span');
              if (priceSpan != null) {
                String priceText = priceSpan.text.replaceAll(',', '').trim();
                return double.tryParse(priceText);
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching exchange rate: $e');
    }
    return null;
  }
}

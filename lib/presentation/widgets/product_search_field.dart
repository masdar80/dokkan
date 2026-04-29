import 'package:flutter/material.dart';
import 'package:dokkan/data/models/product_model.dart';
import 'package:provider/provider.dart';
import 'package:dokkan/providers/inventory_provider.dart';

class ProductSearchField extends StatelessWidget {
  final Function(Product) onSelected;
  final Product? selectedProduct;

  const ProductSearchField({
    super.key,
    required this.onSelected,
    this.selectedProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Product>(
      displayStringForOption: (Product p) => p.name,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<Product>.empty();
        }
        final provider = context.read<InventoryProvider>();
        final query = textEditingValue.text.toLowerCase();
        return provider.products.where((Product p) {
          return p.name.toLowerCase().contains(query) ||
                 p.code.toLowerCase().contains(query) ||
                 (p.barcode != null && p.barcode!.contains(query));
        });
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // تحديث النص إذا تم اختيار مادة خارجياً (عن طريق الباركود مثلاً)
        if (selectedProduct != null && controller.text != selectedProduct!.name && !focusNode.hasFocus) {
          Future.microtask(() => controller.text = selectedProduct!.name);
        }

        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onFieldSubmitted: (value) {
            final provider = context.read<InventoryProvider>();
            final match = provider.products.where((p) => 
              p.barcode == value || p.code == value
            ).firstOrNull;
            
            if (match != null) {
              onSelected(match);
              // لا نحتاج لمسح الحقل هنا إذا أردنا بقاء الاسم
            } else {
              onFieldSubmitted();
            }
          },
          decoration: InputDecoration(
            labelText: 'البحث عن مادة (بالاسم، الرمز، أو الباركود)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear), 
                  onPressed: () {
                    controller.clear();
                    // هنا نحتاج لإبلاغ الأب بمسح الاختيار، لكن بما أن onSelected لا تدعم null،
                    // قد نحتاج لحل آخر أو نكتفي بمسح النص.
                  }) 
              : null,
            helperText: 'اضغط Enter عند إدخال الباركود يدوياً',
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final Product option = options.elementAt(index);
                  return ListTile(
                    title: Text(option.name),
                    subtitle: Text('الرمز: ${option.code} | المتوفر: ${option.currentQuantity}'),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

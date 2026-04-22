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
      displayStringForOption: (Product p) => '${p.name} (${p.code})',
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text == '') {
          return const Iterable<Product>.empty();
        }
        final provider = context.read<InventoryProvider>();
        return provider.products.where((Product p) {
          return p.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                 p.code.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: onSelected,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // إذا كانت هناك مادة مختارة مسبقاً، نحدث حقل النص
        if (selectedProduct != null && controller.text.isEmpty) {
          controller.text = '${selectedProduct!.name} (${selectedProduct!.code})';
        }
        
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'البحث عن مادة (بالاسم أو الرمز)',
            prefixIcon: Icon(Icons.search),
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

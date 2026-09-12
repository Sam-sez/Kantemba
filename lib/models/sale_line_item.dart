class SaleLineItem {
  final int? id;
  final int saleId;
  final int itemId;
  final int quantity;
  final double unitPriceAtSale;

  SaleLineItem({
    this.id,
    required this.saleId,
    required this.itemId,
    required this.quantity,
    required this.unitPriceAtSale,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sale_id': saleId,
        'item_id': itemId,
        'quantity': quantity,
        'unit_price_at_sale': unitPriceAtSale,
      };

  factory SaleLineItem.fromMap(Map<String, dynamic> m) => SaleLineItem(
        id: m['id'] as int?,
        saleId: m['sale_id'] as int,
        itemId: m['item_id'] as int,
        quantity: m['quantity'] as int,
        unitPriceAtSale: (m['unit_price_at_sale'] as num).toDouble(),
      );
}

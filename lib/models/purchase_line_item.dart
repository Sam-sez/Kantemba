class PurchaseLineItem {
  final int? id;
  final int purchaseId;
  final int itemId;
  final int quantity;
  final double unitCostAtPurchase;

  PurchaseLineItem({
    this.id,
    required this.purchaseId,
    required this.itemId,
    required this.quantity,
    required this.unitCostAtPurchase,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'purchase_id': purchaseId,
        'item_id': itemId,
        'quantity': quantity,
        'unit_cost_at_purchase': unitCostAtPurchase,
      };

  factory PurchaseLineItem.fromMap(Map<String, dynamic> m) => PurchaseLineItem(
        id: m['id'] as int?,
        purchaseId: m['purchase_id'] as int,
        itemId: m['item_id'] as int,
        quantity: m['quantity'] as int,
        unitCostAtPurchase: (m['unit_cost_at_purchase'] as num).toDouble(),
      );
}

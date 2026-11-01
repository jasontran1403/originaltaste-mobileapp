class PosCustomerData {
  final int id;
  final String phone;
  final String name;
  final int? storeId;
  final double totalSpend;
  final String? dateOfBirth;
  final String? deliveryAddress;
  final int? referredByCustomerId;
  final String? referredByName;
  final String? referredByPhone;
  final int? createdAt;

  const PosCustomerData(
      {required this.id,
      required this.phone,
      required this.name,
      this.storeId,
      required this.totalSpend,
      this.dateOfBirth,
      this.deliveryAddress,
      this.referredByCustomerId,
      this.referredByName,
      this.referredByPhone,
      this.createdAt});

  factory PosCustomerData.fromJson(Map<String, dynamic> j) => PosCustomerData(
        id: (j['id'] as num).toInt(),
        phone: j['phone'] as String,
        name: j['name'] as String,
        storeId: (j['storeId'] as num?)?.toInt(),
        totalSpend: (j['totalSpend'] as num?)?.toDouble() ?? 0,
        dateOfBirth: j['dateOfBirth'] as String?,
        deliveryAddress: j['deliveryAddress'] as String?,
        referredByCustomerId: (j['referredByCustomerId'] as num?)?.toInt(),
        referredByName: j['referredByName'] as String?,
        referredByPhone: j['referredByPhone'] as String?,
        createdAt: (j['createdAt'] as num?)?.toInt(),
      );
}

class PosCustomerPageResult {
  final List<PosCustomerData> content;
  final int totalItems;
  final int currentPage;
  final int totalPages;

  const PosCustomerPageResult({
    required this.content,
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
  });

  factory PosCustomerPageResult.fromJson(Map<String, dynamic> j) =>
      PosCustomerPageResult(
        content: (j['content'] as List? ?? [])
            .map((e) => PosCustomerData.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalItems: (j['totalItems'] as num?)?.toInt() ?? 0,
        currentPage: (j['currentPage'] as num?)?.toInt() ?? 0,
        totalPages: (j['totalPages'] as num?)?.toInt() ?? 0,
      );
}

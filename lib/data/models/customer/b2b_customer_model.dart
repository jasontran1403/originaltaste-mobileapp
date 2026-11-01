class B2bCustomerData {
  final int id;
  final String? customerCode;
  final String customerType; // 'COMPANY' | 'RETAIL'
  final String? companyName;
  final String? shortName;
  final String? taxCode;
  final String? address;
  final String? deliveryAddress;
  final String? contactName;
  final String? dateOfBirth;
  final String? phone;
  final String? name;
  final String? email;
  final int discountRate;
  final bool isActive;
  final int? createdAt;

  const B2bCustomerData(
      {required this.id,
      this.customerCode,
      required this.customerType,
      this.companyName,
      this.shortName,
      this.taxCode,
      this.address,
      this.deliveryAddress,
      this.contactName,
      this.dateOfBirth,
      this.phone,
      this.name,
      this.email,
      required this.discountRate,
      required this.isActive,
      this.createdAt});

  factory B2bCustomerData.fromJson(Map<String, dynamic> j) => B2bCustomerData(
        id: (j['id'] as num).toInt(),
        customerCode: j['customerCode'] as String?,
        customerType: (j['customerType'] as String?) ?? 'RETAIL',
        companyName: j['companyName'] as String?,
        shortName: j['shortName'] as String?,
        taxCode: j['taxCode'] as String?,
        address: j['address'] as String?,
        deliveryAddress: j['deliveryAddress'] as String?,
        contactName: j['contactName'] as String?,
        dateOfBirth: j['dateOfBirth'] as String?,
        phone: j['phone'] as String?,
        name: j['name'] as String?,
        email: j['email'] as String?,
        discountRate: (j['discountRate'] as num?)?.toInt() ?? 0,
        isActive: (j['isActive'] as bool?) ?? true,
        createdAt: (j['createdAt'] as num?)?.toInt(),
      );

  String get displayName =>
      shortName ?? companyName ?? name ?? customerCode ?? 'KH #$id';
  bool get isCompany => customerType == 'COMPANY';
}

class B2bCustomerPageResult {
  final List<B2bCustomerData> content;
  final int totalItems;
  final int currentPage;
  final int totalPages;

  const B2bCustomerPageResult({
    required this.content,
    required this.totalItems,
    required this.currentPage,
    required this.totalPages,
  });

  factory B2bCustomerPageResult.fromJson(Map<String, dynamic> j) =>
      B2bCustomerPageResult(
        content: (j['content'] as List? ?? [])
            .map((e) => B2bCustomerData.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalItems: (j['totalItems'] as num?)?.toInt() ?? 0,
        currentPage: (j['currentPage'] as num?)?.toInt() ?? 0,
        totalPages: (j['totalPages'] as num?)?.toInt() ?? 0,
      );
}

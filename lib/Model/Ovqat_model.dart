class Ovqat {
  final String id;
  final String name;
  final double price;
  final String categoryId;
  final String categoryName;
  final String? description;
  final String? image;

  Ovqat({
    required this.id,
    required this.name,
    required this.price,
    required this.categoryId,
    required this.categoryName,
    this.description,
    this.image,
  });

  factory Ovqat.fromJson(Map<String, dynamic> json) {
    return Ovqat(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      categoryId: json['category']?['_id'] ?? json['category_id'] ?? '',
      categoryName: json['category']?['title'] ?? json['category_name'] ?? '',
      description: json['description'],
      image: json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'price': price,
      'category': {'_id': categoryId, 'title': categoryName},
      'description': description,
      'image': image,
    };
  }
}

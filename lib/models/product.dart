class Product {
  final int id;
  final String name;
  final int price;

  Product({
    required this.id,
    required this.name,
    required this.price,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      // Mengantisipasi jika Supabase mengembalikan num/double
      price: (json['price'] as num).toInt(), 
    );
  }
}
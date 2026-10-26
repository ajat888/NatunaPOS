import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NatunaPOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const KasirPage(),
    );
  }
}

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  int totalHarga = 0;
  List<dynamic> daftarProduk = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProduk();
  }

  // Fungsi untuk mengambil data dari Supabase
  Future<void> fetchProduk() async {
    try {
      final response = await Supabase.instance.client
          .from('products')
          .select()
          .order('id', ascending: true);
      
      setState(() {
        daftarProduk = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error mengambil data: $e');
    }
  }

  void tambahKeKeranjang(int harga) {
    setState(() {
      totalHarga += harga;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasir Natuna'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // Tampilkan loading
          : daftarProduk.isEmpty
              ? const Center(child: Text('Belum ada produk di database'))
              : ListView.builder(
                  itemCount: daftarProduk.length,
                  itemBuilder: (context, index) {
                    final produk = daftarProduk[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      child: ListTile(
                        title: Text(produk['name']), // Sesuaikan dengan nama kolom di Supabase
                        subtitle: Text('Rp ${produk['price']}'),
                        trailing: ElevatedButton(
                          onPressed: () => tambahKeKeranjang(produk['price']),
                          child: const Text('Tambah'),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border(top: BorderSide(color: Colors.grey.shade300)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Total Bayar:', style: TextStyle(fontSize: 14)),
                Text(
                  'Rp $totalHarga',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
              onPressed: () {
                // Logika pembayaran nanti di sini
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tombol Bayar diklik!')),
                );
              },
              child: const Text('BAYAR'),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:stock_app/core/services/api_service.dart';

const _bg = Color(0xFFF5F6FA);
const _card = Color(0xFFFFFFFF);
const _cardBorder = Color(0xFFE8EAF0);
const _accent = Color(0xFF3B4FE8);
const _textPrimary = Color(0xFF111827);
const _textSub = Color(0xFF6B7280);
const _green = Color(0xFF16A34A);
const _red = Color(0xFFDC2626);

class SmallcaseScreen extends StatefulWidget {
  const SmallcaseScreen({super.key});
  @override
  State<SmallcaseScreen> createState() => _SmallcaseScreenState();
}

class _SmallcaseScreenState extends State<SmallcaseScreen> {
  int _selectedCategory = 0;
  final List<String> _categories = ['All', 'Top Rated', 'Low Risk', 'High Returns', 'Trending'];

  final List<Map<String, dynamic>> _smallcases = [
    {
      'name': 'Top 100 Stocks',
      'description': 'India\'s top 100 companies by market cap',
      'returns': '+18.4%',
      'isUp': true,
      'risk': 'Low',
      'minInvest': '₹5,000',
      'stocks': 100,
      'rating': 4.8,
      'category': 'Low Risk',
      'color': 0xFF3B4FE8,
    },
    {
      'name': 'IT Sector Stars',
      'description': 'Best performing IT companies in India',
      'returns': '+24.7%',
      'isUp': true,
      'risk': 'Medium',
      'minInvest': '₹3,500',
      'stocks': 15,
      'rating': 4.6,
      'category': 'High Returns',
      'color': 0xFF8B5CF6,
    },
    {
      'name': 'Green Energy',
      'description': 'Renewable energy & sustainability focused',
      'returns': '+31.2%',
      'isUp': true,
      'risk': 'Medium',
      'minInvest': '₹2,800',
      'stocks': 12,
      'rating': 4.5,
      'category': 'Trending',
      'color': 0xFF16A34A,
    },
    {
      'name': 'Banking & Finance',
      'description': 'Top banks and financial institutions',
      'returns': '+12.8%',
      'isUp': true,
      'risk': 'Low',
      'minInvest': '₹4,200',
      'stocks': 20,
      'rating': 4.7,
      'category': 'Low Risk',
      'color': 0xFFF59E0B,
    },
    {
      'name': 'Pharma Giants',
      'description': 'Leading pharmaceutical companies',
      'returns': '-3.2%',
      'isUp': false,
      'risk': 'Medium',
      'minInvest': '₹3,000',
      'stocks': 10,
      'rating': 4.2,
      'category': 'Top Rated',
      'color': 0xFFEF4444,
    },
    {
      'name': 'Dividend Kings',
      'description': 'High dividend yielding blue chip stocks',
      'returns': '+9.6%',
      'isUp': true,
      'risk': 'Low',
      'minInvest': '₹6,000',
      'stocks': 25,
      'rating': 4.9,
      'category': 'Top Rated',
      'color': 0xFF06B6D4,
    },
    {
      'name': 'Small Cap Gems',
      'description': 'Hidden gems in small cap segment',
      'returns': '+42.3%',
      'isUp': true,
      'risk': 'High',
      'minInvest': '₹1,500',
      'stocks': 18,
      'rating': 4.3,
      'category': 'High Returns',
      'color': 0xFFEC4899,
    },
    {
      'name': 'FMCG Leaders',
      'description': 'Fast moving consumer goods sector',
      'returns': '+7.4%',
      'isUp': true,
      'risk': 'Low',
      'minInvest': '₹4,500',
      'stocks': 14,
      'rating': 4.4,
      'category': 'Low Risk',
      'color': 0xFF84CC16,
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    if (_selectedCategory == 0) return _smallcases;
    final cat = _categories[_selectedCategory];
    return _smallcases.where((s) => s['category'] == cat).toList();
  }

  Color _riskColor(String risk) {
    switch (risk) {
      case 'Low': return _green;
      case 'Medium': return const Color(0xFFF59E0B);
      case 'High': return _red;
      default: return _textSub;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('smallcase', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: _textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B4FE8), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Invest in Ideas', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Curated stock baskets managed\nby SEBI registered experts', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Explore All', style: TextStyle(color: Color(0xFF3B4FE8), fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),

          // Category Filter
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final selected = _selectedCategory == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? _accent : _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? _accent : _cardBorder),
                    ),
                    child: Text(
                      _categories[index],
                      style: TextStyle(
                        color: selected ? Colors.white : _textSub,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Smallcase List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final sc = _filtered[index];
                final isUp = sc['isUp'] as bool;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _cardBorder),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Color(sc['color'] as int).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.auto_graph, color: Color(sc['color'] as int), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(sc['name'], style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(sc['description'], style: const TextStyle(color: _textSub, fontSize: 11), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(sc['returns'], style: TextStyle(color: isUp ? _green : _red, fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('1Y returns', style: const TextStyle(color: _textSub, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0xFFE8EAF0)),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _infoChip(Icons.show_chart, '${sc['stocks']} stocks'),
                          _infoChip(Icons.account_balance_wallet_outlined, sc['minInvest']),
                          _riskChip(sc['risk']),
                          _ratingChip(sc['rating']),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showInvestDialog(context, sc),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Invest Now', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(children: [
      Icon(icon, color: _textSub, size: 13),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: _textSub, fontSize: 11)),
    ]);
  }

  Widget _riskChip(String risk) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _riskColor(risk).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(risk, style: TextStyle(color: _riskColor(risk), fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _ratingChip(double rating) {
    return Row(children: [
      const Icon(Icons.star, color: Color(0xFFF59E0B), size: 13),
      const SizedBox(width: 3),
      Text(rating.toString(), style: const TextStyle(color: _textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }

  void _showInvestDialog(BuildContext context, Map<String, dynamic> sc) {
    final amountController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(sc['name'], style: const TextStyle(color: _textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              Text(sc['returns'], style: TextStyle(color: sc['isUp'] ? _green : _red, fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 4),
            Text('Min Investment: ${sc['minInvest']}', style: const TextStyle(color: _textSub, fontSize: 13)),
            const SizedBox(height: 20),
            const Text('Enter Amount', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: sc['minInvest'].toString().replaceAll('₹', '').replaceAll(',', ''),
                hintStyle: const TextStyle(color: _textSub),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EAF0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE8EAF0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _accent, width: 2)),
              ),
            ),
            const SizedBox(height: 12),
            // Quick amount buttons
            Row(children: [
              _quickAmount(amountController, '5K', '5000'),
              const SizedBox(width: 8),
              _quickAmount(amountController, '10K', '10000'),
              const SizedBox(width: 8),
              _quickAmount(amountController, '25K', '25000'),
              const SizedBox(width: 8),
              _quickAmount(amountController, '50K', '50000'),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amount = amountController.text.trim();
                  if (amount.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter an amount'), backgroundColor: _red),
                    );
                    return;
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✅ ₹$amount invested in ${sc['name']}!'),
                      backgroundColor: _green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Confirm Investment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAmount(TextEditingController controller, String label, String value) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.text = value,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _accent.withOpacity(0.3)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: _accent, fontWeight: FontWeight.w600, fontSize: 12)),
        ),
      ),
    );
  }
}
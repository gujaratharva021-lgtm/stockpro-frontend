import 'package:flutter/material.dart';
import 'package:stock_app/core/theme/app_colors.dart';

class StockLogo extends StatelessWidget {
  final String? symbol;
  final String? companyName;
  final double size;
  final double borderRadiusFactor;

  const StockLogo({
    super.key,
    this.symbol,
    this.companyName,
    this.size = 34,
    this.borderRadiusFactor = 0.3,
  });

  static const _skipWords = {
    'ltd', 'limited', 'pvt', 'private', 'inc', 'incorporated', 'corp',
    'corporation', 'company', 'co', 'industries', 'industry', 'enterprises',
    'group', 'holdings', 'plc', 'llc', 'and', 'the'
  };

  static const Map<String, String> _domainOverrides = {
    'RELIANCE': 'ril.com',
    'TCS': 'tcs.com',
    'INFY': 'infosys.com',
    'HDFCBANK': 'hdfcbank.com',
    'ICICIBANK': 'icicibank.com',
    'SBIN': 'sbi.co.in',
    'HINDUNILVR': 'hul.co.in',
    'ITC': 'itcportal.com',
    'KOTAKBANK': 'kotak.com',
    'LT': 'larsentoubro.com',
    'AXISBANK': 'axisbank.com',
    'BAJFINANCE': 'bajajfinserv.in',
    'BHARTIARTL': 'airtel.in',
    'ASIANPAINT': 'asianpaints.com',
    'MARUTI': 'marutisuzuki.com',
    'WIPRO': 'wipro.com',
    'PERSISTENT': 'persistent.com',
    'HCLTECH': 'hcltech.com',
    'TECHM': 'techmahindra.com',
    'SUNPHARMA': 'sunpharma.com',
    'TITAN': 'titancompany.in',
    'ADANIENT': 'adani.com',
    'ADANIPORTS': 'adaniports.com',
    'NTPC': 'ntpc.co.in',
    'ONGC': 'ongcindia.com',
    'TATASTEEL': 'tatasteel.com',
    'TATAMOTORS': 'tatamotors.com',
    'M&M': 'mahindra.com',
    'ULTRACEMCO': 'ultratechcement.com',
    'NESTLEIND': 'nestle.in',
    'JSWSTEEL': 'jsw.in',
    'GODREJCP': 'godrejcp.com',
    'DRREDDY': 'drreddys.com',
    'CIPLA': 'cipla.com',
    'DIVISLAB': 'divislabs.com',
    'BAJAJFINSV': 'bajajfinserv.in',
    'GRASIM': 'grasim.com',
    'HINDALCO': 'hindalco.com',
    'COALINDIA': 'coalindia.in',
    'POWERGRID': 'powergrid.in',
    'INDUSINDBK': 'indusind.com',
    'EICHERMOT': 'eichermotors.com',
    'BPCL': 'bharatpetroleum.in',
    'BRITANNIA': 'britannia.co.in',
    'SHREECEM': 'shreecement.com',
    'APOLLOHOSP': 'apollohospitals.com',
    'HEROMOTOCO': 'heromotocorp.com',
    'UPL': 'upl-ltd.com',
  };

  String? get _domain {
    final sym = symbol?.trim().toUpperCase();
    if (sym != null && _domainOverrides.containsKey(sym)) {
      return _domainOverrides[sym];
    }
    final name = companyName ?? symbol;
    if (name == null || name.trim().isEmpty) return null;
    final cleaned = name.toLowerCase().replaceAll(RegExp(r'[^a-z\s]'), '');
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty && !_skipWords.contains(w)).toList();
    if (words.isEmpty) return null;
    return '${words.take(1).join('')}.com';
  }

  @override
  Widget build(BuildContext context) {
    final letter = (symbol ?? companyName ?? '?').trim().isNotEmpty
        ? (symbol ?? companyName ?? '?').trim().substring(0, 1).toUpperCase()
        : '?';
    final radius = BorderRadius.circular(size * borderRadiusFactor);

    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: radius),
      child: Center(
        child: Text(letter, style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold, fontSize: size * 0.42)),
      ),
    );

    final domain = _domain;
    if (domain == null) return fallback;

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        'https://logo.clearbit.com/$domain?size=128',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
      ),
    );
  }
}
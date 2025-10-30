import 'package:flutter/material.dart';
import 'package:onboardx_app/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class News1 extends StatelessWidget {
  final String title;
  final String image;
  final String content;

  const News1({
    super.key,
    required this.title,
    required this.image,
    required this.content,
  });

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text((AppLocalizations.of(context)!.news)),
        backgroundColor: const Color.fromRGBO(224, 124, 124, 1),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(image, fit: BoxFit.cover, width: double.infinity),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                content,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "Related News:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            _buildExternalNewsLink(
              "TNB withdraws judicial review, pursues tax incentives application",
              "https://www.businesstoday.com.my/2025/09/18/tnb-withdraws-judicial-review-pursues-tax-incentives-application/",
              context,
            ),
            _buildExternalNewsLink(
              "TNB leads charge in hockey excellence",
              "https://www.nst.com.my/sports/hockey/2025/09/1275821/tnb-leads-charge-hockey-excellence",
              context,
            ),
            _buildExternalNewsLink(
              "TNB continues to strengthen Malaysia's power infrastructure",
              "https://theedgemalaysia.com/node/770755",
              context,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExternalNewsLink(String title, String url, BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.open_in_new),
      onTap: () => _launchURL(url),
    );
  }
}
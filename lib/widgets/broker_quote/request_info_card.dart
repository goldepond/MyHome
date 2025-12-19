import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:property/constants/app_constants.dart';
import 'package:property/models/quote_request.dart';

class RequestInfoCard extends StatelessWidget {
  final QuoteRequest quote;

  const RequestInfoCard({
    super.key,
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AirbnbColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AirbnbColors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AirbnbColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person,
                  color: AirbnbColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '요청자 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AirbnbColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quote.userName,
                      style: TextStyle(
                        fontSize: 14,
                        color: AirbnbColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                dateFormat.format(quote.requestDate),
                style: TextStyle(
                  fontSize: 12,
                  color: AirbnbColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


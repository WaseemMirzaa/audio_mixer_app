import 'package:flutter/material.dart';

import '../../domain/models/mix_session.dart';
import 'home_ceramic_card.dart';

/// Session row — ceramic card (Home / History).
class SessionHistoryListTile extends StatelessWidget {
  const SessionHistoryListTile({super.key, required this.session});

  final MixSession session;

  @override
  Widget build(BuildContext context) {
    return SessionCeramicListCard(session: session);
  }
}

import 'package:flutter/material.dart';
import '../pages/create_meetup_page.dart';
import '../pages/invite_friends_page.dart';

class AppRoutes {
  static const String createMeetup = '/create_meetup';
  static const String inviteFriends = '/invite_friends';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      createMeetup: (context) => CreateMeetupPage(
            selectedPlace: ModalRoute.of(context)?.settings.arguments
                as Map<String, dynamic>?,
          ),
      inviteFriends: (context) => const InviteFriendsPage(),
    };
  }
}

import '../../data/local/db/app_database.dart';

/// Combined data class for displaying organization members with user info
class MembershipWithUser {
  final Membership membership;
  final User user;
  final OfficerTitle? officerTitle;

  MembershipWithUser({
    required this.membership,
    required this.user,
    this.officerTitle,
  });

  String get userName => user.name;
  String get userEmail => user.email;
  String get role => membership.role;
  String get status => membership.status;
  bool get isPending => membership.status == 'pending';
  bool get isApproved => membership.status == 'approved';
  bool get isPresident => membership.role == 'president';
  bool get hasOfficerTitle => officerTitle != null;
  String? get officerTitleName => officerTitle?.title;
}

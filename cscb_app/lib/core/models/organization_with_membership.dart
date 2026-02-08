import '../../data/local/db/app_database.dart';

/// Combined data class for displaying user's organizations with their membership info
class OrganizationWithMembership {
  final Organization organization;
  final Membership membership;

  OrganizationWithMembership({
    required this.organization,
    required this.membership,
  });

  String get userRole => membership.role;
  String get membershipStatus => membership.status;
  bool get isPending => organization.status == 'pending';
  bool get isActive => organization.status == 'active';
  bool get isSuspended => organization.status == 'suspended';
  bool get isPresident => membership.role == 'president';
  bool get isMemberApproved => membership.status == 'approved';
}

// lib/backend/utils/tier_permissions.dart

/// Permission model for user tiers in Elytic.
/// This map can be imported anywhere to enforce capabilities.

enum TierPermission {
  biggerAvatar,             // User gets a larger avatar in the lounge/room
  canSendLinks,             // Can send links in messages
  maxMessageLength,         // Maximum message length allowed
  maxBioLength,             // Maximum bio length allowed
  canMute,                  // Can mute users (value: max duration in hours)
  canRemoveProfilePic,      // Can remove profile picture of others
  canRemoveBio,             // Can remove bio of others
  canPromote,               // Can promote users to mod/admin tiers
  canDemote,                // Can demote users from mod/admin tiers
  canDeleteAccounts,        // Can delete other users' accounts
  canSuspendAccounts,       // Can suspend other users (value: max duration in days)
  canAwardItems,            // Can grant cosmetics/IAPs for free
}

// The avatar size is stored as a multiplier (1.0 is default/normal)
final Map<int, Map<TierPermission, dynamic>> tierPermissions = {
  0: {
    // No special permissions
  },
  1: {
    TierPermission.biggerAvatar: 1.25,
  },
  2: {
    TierPermission.biggerAvatar: 1.25,
    TierPermission.canSendLinks: true,
    TierPermission.maxMessageLength: 400,
    TierPermission.maxBioLength: 6000,
  },
  3: {
    TierPermission.biggerAvatar: 1.5,
    TierPermission.canSendLinks: true,
    TierPermission.maxMessageLength: 500,
    TierPermission.maxBioLength: 10000,
  },
  4: {
    // Junior Mod
    TierPermission.canMute: 24, // in hours
    TierPermission.canRemoveProfilePic: true,
    TierPermission.canRemoveBio: true,
  },
  5: {
    // Senior Mod
    TierPermission.canMute: 120, // in hours (5 days)
    TierPermission.canRemoveProfilePic: true,
    TierPermission.canRemoveBio: true,
  },
  6: {
    // Admin
    TierPermission.canMute: 120, // in hours (5 days)
    TierPermission.canRemoveProfilePic: true,
    TierPermission.canRemoveBio: true,
    TierPermission.canPromote: true,
    TierPermission.canDemote: true,
    TierPermission.canDeleteAccounts: true,
    TierPermission.canSuspendAccounts: 7, // in days
    TierPermission.canAwardItems: true,
  },
};

/// Utility function to check if a user of [tier] has a certain [permission].
bool hasTierPermission(int tier, TierPermission permission) {
  return tierPermissions[tier]?[permission] != null;
}

/// Utility to get a permission's value (if applicable), e.g., max mute duration.
dynamic getTierPermissionValue(int tier, TierPermission permission) {
  return tierPermissions[tier]?[permission];
}

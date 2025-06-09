class LocationCheckResult {
  final bool success;
  final bool? alreadyRewarded;
  final bool? nearMeetup;
  final bool? nearParticipants;
  final int? rewardAmount;
  final int? newBalance;
  final String? message;

  LocationCheckResult({
    required this.success,
    this.alreadyRewarded,
    this.nearMeetup,
    this.nearParticipants,
    this.rewardAmount,
    this.newBalance,
    this.message,
  });

  factory LocationCheckResult.fromJson(Map<String, dynamic> json) {
    return LocationCheckResult(
      success: json['success'] as bool,
      alreadyRewarded: json['alreadyRewarded'] as bool?,
      nearMeetup: json['nearMeetup'] as bool?,
      nearParticipants: json['nearParticipants'] as bool?,
      rewardAmount: json['rewardAmount'] as int?,
      newBalance: json['newBalance'] as int?,
      message: json['message'] as String?,
    );
  }

  LocationCheckResult setSuccess(bool value) {
    return LocationCheckResult(
      success: value,
      alreadyRewarded: alreadyRewarded,
      nearMeetup: nearMeetup,
      nearParticipants: nearParticipants,
      rewardAmount: rewardAmount,
      newBalance: newBalance,
      message: message,
    );
  }

  LocationCheckResult setAlreadyRewarded(bool value) {
    return LocationCheckResult(
      success: success,
      alreadyRewarded: value,
      nearMeetup: nearMeetup,
      nearParticipants: nearParticipants,
      rewardAmount: rewardAmount,
      newBalance: newBalance,
      message: message,
    );
  }

  LocationCheckResult setNearMeetup(bool value) {
    return LocationCheckResult(
      success: success,
      alreadyRewarded: alreadyRewarded,
      nearMeetup: value,
      nearParticipants: nearParticipants,
      rewardAmount: rewardAmount,
      newBalance: newBalance,
      message: message,
    );
  }

  LocationCheckResult setNearParticipants(bool value) {
    return LocationCheckResult(
      success: success,
      alreadyRewarded: alreadyRewarded,
      nearMeetup: nearMeetup,
      nearParticipants: value,
      rewardAmount: rewardAmount,
      newBalance: newBalance,
      message: message,
    );
  }

  LocationCheckResult setRewardAmount(int value) {
    return LocationCheckResult(
      success: success,
      alreadyRewarded: alreadyRewarded,
      nearMeetup: nearMeetup,
      nearParticipants: nearParticipants,
      rewardAmount: value,
      newBalance: newBalance,
      message: message,
    );
  }

  LocationCheckResult setNewBalance(int value) {
    return LocationCheckResult(
      success: success,
      alreadyRewarded: alreadyRewarded,
      nearMeetup: nearMeetup,
      nearParticipants: nearParticipants,
      rewardAmount: rewardAmount,
      newBalance: value,
      message: message,
    );
  }

  LocationCheckResult setMessage(String value) {
    return LocationCheckResult(
      success: success,
      alreadyRewarded: alreadyRewarded,
      nearMeetup: nearMeetup,
      nearParticipants: nearParticipants,
      rewardAmount: rewardAmount,
      newBalance: newBalance,
      message: value,
    );
  }
}

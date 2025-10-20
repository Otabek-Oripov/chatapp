class UserListTileState {
  final bool isFriend;
  final String? requestStatus; // 'pending', 'accepted', null
  final bool isRequestSender;
  final String? pendingRequestId;
  final bool isLoading;

  UserListTileState({
    this.isFriend = false,
    this.requestStatus,
    this.isRequestSender = false,
    this.pendingRequestId,
    this.isLoading = false,
  });

  UserListTileState copyWith({
    bool? isFriend,
    String? requestStatus,
    bool? isRequestSender,
    String? pendingRequestId,
    bool? isLoading,
  }) {
    return UserListTileState(
      isFriend: isFriend ?? this.isFriend,
      requestStatus: requestStatus ?? this.requestStatus,
      isRequestSender: isRequestSender ?? this.isRequestSender,
      pendingRequestId: pendingRequestId ?? this.pendingRequestId,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

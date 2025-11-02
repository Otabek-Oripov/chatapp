import 'package:chatapp/models/MessageModel.dart';

String formatDateHeader(DateTime? date){
  final messageDate = date ?? DateTime.now();

  final now = DateTime.now();
  final today = DateTime(now.year,now.month,now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final msgDate  = DateTime(
    messageDate.year,
    messageDate.month,
    messageDate.day
  );

  if (msgDate == today){
    return 'Today';
  }else if (msgDate == yesterday){
    return 'Yesterday';
  }else if (now.difference(messageDate).inDays<7){
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[messageDate.weekday - 1];
  }else{
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${messageDate.day} ${months[messageDate.month -1]}';
  }
}
bool shouldShowDateHeader(List<MessageModel> messages, int index){
  if (index == messages.length -1 ) return true;

  final currentMessage = messages[index];
  final nextMessage = messages[index+1];

  final currentTime = currentMessage.timestamp ?? DateTime.now();
  final nextTime = nextMessage.timestamp??DateTime.now();

  final currentDate = DateTime(
    currentTime.year,
    currentTime.month,
    currentTime.day,
  );
  final nextDate = DateTime(nextTime.year,nextTime.month,nextTime.day);

  return currentDate != nextDate;
}
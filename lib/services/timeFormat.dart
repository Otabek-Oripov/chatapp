String formateMessageTime(DateTime? time){
  time??=DateTime.now();
  return "${time.hour.toString().padLeft(2,'0')}:${time.minute.toString().padLeft(2,'0')}";

}

String formatTime(DateTime time){
  final now = DateTime.now();
  final difference = now.difference(time);

  if (difference.inDays>0){
    return '${difference.inDays}d';
  }else if(difference.inHours>0){
    return '${difference.inHours}h';
  }else if(difference.inMinutes>0){
    return '${difference.inMinutes}m';
  }else{
    return "Now";
  }
}
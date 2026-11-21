/// Local room state. It is deliberately separate from books and saved writing.
enum CafeSeat {
  window('창가 자리', '창밖을 보며 천천히 써요.'),
  shared('큰 책상', '넓은 책상에 책을 펼쳐요.'),
  quiet('안쪽 자리', '책장 곁에서 차분히 써요.');

  const CafeSeat(this.label, this.description);
  final String label, description;
}

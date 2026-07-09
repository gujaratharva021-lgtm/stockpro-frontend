class NotesService {
  static final NotesService _instance = NotesService._internal();
  factory NotesService() => _instance;
  NotesService._internal();

  final Map<String, String> _notes = {};

  String? getNote(String symbol) => _notes[symbol];

  void setNote(String symbol, String note) {
    if (note.trim().isEmpty) {
      _notes.remove(symbol);
    } else {
      _notes[symbol] = note.trim();
    }
  }
}
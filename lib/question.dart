class Question {
  final String category;
  final String type;
  final String question;
  final String correctAnswer;

  const Question({
    required this.category,
    required this.type,
    required this.question,
    required this.correctAnswer,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      category: json['category'] as String,
      type: json['type'] as String,
      question: json['question'] as String,
      correctAnswer: json['correct_answer'] as String,
    );
  }
}

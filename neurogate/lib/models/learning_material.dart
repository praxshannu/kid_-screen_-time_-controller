class LearningMaterial {
  final String topic;
  final String fact;
  final String question;
  final String answer;
  final String ageGroup;

  LearningMaterial({
    required this.topic,
    required this.fact,
    required this.question,
    required this.answer,
    required this.ageGroup,
  });
}

final List<LearningMaterial> ageAppropriateKnowledge = [
  // Age 3-5
  LearningMaterial(
    topic: "Colors",
    fact: "Apples are usually red, green, or yellow.",
    question: "What color is an apple?",
    answer: "red",
    ageGroup: "3-5",
  ),
  LearningMaterial(
    topic: "Shapes",
    fact: "A triangle has three sides.",
    question: "How many sides does a triangle have?",
    answer: "3",
    ageGroup: "3-5",
  ),
  LearningMaterial(
    topic: "Animals",
    fact: "Cows make a 'moo' sound.",
    question: "What sound does a cow make?",
    answer: "moo",
    ageGroup: "3-5",
  ),

  // Age 6-8
  LearningMaterial(
    topic: "Space",
    fact: "Mars is often called the 'Red Planet' because of its rusty soil.",
    question: "Which planet is called the Red Planet?",
    answer: "mars",
    ageGroup: "6-8",
  ),
  LearningMaterial(
    topic: "Nature",
    fact: "Plants need sunlight, water, and soil to grow.",
    question: "What is one thing plants need to grow?",
    answer: "water",
    ageGroup: "6-8",
  ),
  LearningMaterial(
    topic: "Math",
    fact: "Adding 5 and 3 gives you 8.",
    question: "What is 5 plus 3?",
    answer: "8",
    ageGroup: "6-8",
  ),

  // Age 9-12
  LearningMaterial(
    topic: "Geography",
    fact: "Paris is the capital of France and is famous for the Eiffel Tower.",
    question: "What is the capital city of France?",
    answer: "paris",
    ageGroup: "9-12",
  ),
  LearningMaterial(
    topic: "Human Body",
    fact: "The skin is the largest organ in the human body.",
    question: "What is the largest organ in a human's body?",
    answer: "skin",
    ageGroup: "9-12",
  ),
  LearningMaterial(
    topic: "Math",
    fact: "Multiplying 12 by 4 equals 48.",
    question: "What is 12 times 4?",
    answer: "48",
    ageGroup: "9-12",
  ),

  // Age 13-16
  LearningMaterial(
    topic: "History",
    fact: "The Renaissance was a period of great cultural and artistic change in Europe.",
    question: "In which continent did the Renaissance begin?",
    answer: "europe",
    ageGroup: "13-16",
  ),
  LearningMaterial(
    topic: "Civics",
    fact: "The US government is divided into three branches: Legislative, Executive, and Judicial.",
    question: "How many branches of government are there in the US?",
    answer: "3",
    ageGroup: "13-16",
  ),
  LearningMaterial(
    topic: "Science",
    fact: "H2O is the chemical formula for water, consisting of two hydrogen atoms and one oxygen atom.",
    question: "What is the chemical formula for water?",
    answer: "h2o",
    ageGroup: "13-16",
  ),
];

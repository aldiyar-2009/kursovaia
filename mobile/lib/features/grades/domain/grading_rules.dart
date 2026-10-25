/// All grading thresholds and weights live here (spec: «Правила оценивания»).
/// Provisional Kazakhstan-wide 60/40 scheme until AITU policy is confirmed.
library;

/// Weight of the admission rating (mean of midterm and endterm) in the total.
const double kAdmissionWeight = 0.6;

/// Weight of the final exam in the total.
const double kFinalWeight = 0.4;

/// Minimum score for admission, exam and course pass.
const double kPassThreshold = 50.0;

/// Maximum score of any component or total.
const double kMaxScore = 100.0;

/// Every course total must be at least this for the increased scholarship.
const double kIncreasedScholarship = 90.0;

/// Every course total must be at least this for the regular scholarship.
const double kRegularScholarship = 75.0;

/// Credits assumed for a course until the user changes them.
const int kDefaultCredits = 5;

/// Letter scale as `(min, letter, points)`, highest first; below the last
/// entry the grade is F with 0 points.
const List<(double, String, double)> kLetterScale = [
  (95, 'A', 4.00),
  (90, 'A-', 3.67),
  (85, 'B+', 3.33),
  (80, 'B', 3.00),
  (75, 'B-', 2.67),
  (70, 'C+', 2.33),
  (65, 'C', 2.00),
  (60, 'C-', 1.67),
  (55, 'D+', 1.33),
  (50, 'D', 1.00),
];

/// Letter and points for totals below the last [kLetterScale] entry.
const String kFailLetter = 'F';
const double kFailPoints = 0.0;
